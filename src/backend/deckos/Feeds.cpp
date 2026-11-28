// DeckOS
// See Feeds.h

#include "Feeds.h"

#include "Log.h"
#include "MediaLibrary.h"
#include "Paths.h"
#include "model/Api.h"
#include "model/memory/Memory.h"

#include <QCoreApplication>
#include <QDesktopServices>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QJsonArray>
#include <QJsonDocument>
#include <QNetworkAccessManager>
#include <QNetworkReply>
#include <QNetworkRequest>
#include <QRegularExpression>
#include <QSaveFile>
#include <QSet>
#include <QTimer>
#include <QUrlQuery>
#include <QXmlStreamReader>

#include <algorithm>


namespace {
constexpr qint64 MINUTE = 60 * 1000;
constexpr qint64 FEED_EVERY = 30 * MINUTE;
constexpr qint64 RA_SETS_EVERY = 6 * 60 * MINUTE;
constexpr qint64 RA_COMMUNITY_EVERY = 15 * MINUTE;
constexpr qint64 RA_WEEKLY_EVERY = 6 * 60 * MINUTE;
constexpr qint64 FRIENDS_EVERY = 2 * MINUTE;
constexpr int MAX_ITEMS = 40;
constexpr int MAX_FRIENDS = 30;

const QString RA_MEDIA = QStringLiteral("https://media.retroachievements.org");
const QString RA_SITE = QStringLiteral("https://retroachievements.org");

const char* const NS_MEDIA = "http://search.yahoo.com/mrss/";
const char* const NS_CONTENT = "http://purl.org/rss/1.0/modules/content/";
const char* const NS_YT = "http://www.youtube.com/xml/schemas/2015";

// defaults written to feeds.json the first time (checked 2026-11-28: each feed answered with its items)
struct DefaultFeed { const char* name; const char* value; };
const DefaultFeed DEFAULT_NEWS[] = {
    { "Retro Handhelds", "https://retrohandhelds.gg/feed/" },
    { "RetroAchievements", "https://retroachievements.org/rss-news" },
    { "GameSpot", "https://www.gamespot.com/feeds/news" },
};
const DefaultFeed DEFAULT_YOUTUBE[] = {
    { "Joey's Retro Handhelds", "UCwUiHJUm1wpSaUXiQt_H12A" },
    { "Retro Game Corps", "UCoZQiN0o7f36H7PaW4fVhFw" },
    { "Retro Handhelds", "UC3IYhdamzjvEJ9CwkQa4RAw" },
    { "Taki Udon", "UCKF5151a6yAooOILrYTvfJg" },
    { "ETA PRIME", "UC_0CVCfC_3iuHqmyClu59Uw" },
    { "Retro Dodo", "UCRg2tBkpKYDxOKtX3GvLZcQ" },
};

QString cache_path()
{
    return paths::writableConfigDir() + QStringLiteral("/deckos/feeds-cache.json");
}

qint64 now_ms() { return QDateTime::currentMSecsSinceEpoch(); }

/// RA's "2023-10-27 22:30:49" (UTC) or ISO "2022-01-01T23:48:04+00:00"
qint64 ra_time(const QString& s)
{
    if (s.isEmpty())
        return 0;
    QDateTime t = QDateTime::fromString(s, Qt::ISODateWithMs);
    if (!t.isValid())
        t = QDateTime::fromString(s, Qt::ISODate);
    if (!t.isValid()) {
        t = QDateTime::fromString(s, QStringLiteral("yyyy-MM-dd HH:mm:ss"));
        t.setTimeSpec(Qt::UTC);
    }
    return t.isValid() ? t.toMSecsSinceEpoch() : 0;
}

QString ra_image(const QString& path)
{
    if (path.isEmpty())
        return QString();
    return path.startsWith(QLatin1String("http")) ? path : RA_MEDIA + (path.startsWith(QLatin1Char('/')) ? path : QLatin1Char('/') + path);
}

bool by_date_desc(const QVariant& a, const QVariant& b)
{
    return a.toMap().value(QStringLiteral("date")).toLongLong() > b.toMap().value(QStringLiteral("date")).toLongLong();
}

QJsonObject read_json(const QString& path)
{
    QFile f(path);
    if (!f.open(QIODevice::ReadOnly))
        return QJsonObject();
    return QJsonDocument::fromJson(f.readAll()).object();
}

bool write_json(const QString& path, const QJsonObject& obj, bool indented)
{
    QDir().mkpath(QFileInfo(path).absolutePath());
    QSaveFile f(path);
    if (!f.open(QIODevice::WriteOnly))
        return false;
    f.write(QJsonDocument(obj).toJson(indented ? QJsonDocument::Indented : QJsonDocument::Compact));
    return f.commit();
}
} // namespace


namespace deckos {

Feeds::Feeds(model::ApiObject* api, QObject* parent)
    : QObject(parent)
    , m_api(api)
    , m_net(new QNetworkAccessManager(this))
    , m_timer(new QTimer(this))
    , m_friends_timer(new QTimer(this))
    , m_save_timer(new QTimer(this))
{
    m_save_timer->setSingleShot(true);
    m_save_timer->setInterval(1500);
    connect(m_save_timer, &QTimer::timeout, this, &Feeds::saveCache);

    m_timer->setInterval(MINUTE);
    connect(m_timer, &QTimer::timeout, this, [this]() { refresh(false); });
    m_timer->start();

    m_friends_timer->setInterval(FRIENDS_EVERY);
    connect(m_friends_timer, &QTimer::timeout, this, [this]() {
        fetchRaFriends();
        fetchDiscord();
    });

    loadCache();
    QTimer::singleShot(4000, this, [this]() { refresh(false); }); // after start-up's own work
}

Feeds::~Feeds()
{
    if (m_save_timer->isActive())
        saveCache();
}

QString Feeds::sourcesFile() const
{
    const QString keys = MediaLibrary::keysFilePath();
    if (!keys.isEmpty())
        return QFileInfo(keys).absolutePath() + QStringLiteral("/feeds.json");
    return paths::writableConfigDir() + QStringLiteral("/deckos/feeds.json");
}

QString Feeds::raUser() const { return m_api->memory().get(QStringLiteral("ra_api_user")).toString().trimmed(); }
QString Feeds::raKey() const { return m_api->memory().get(QStringLiteral("ra_api_key")).toString().trimmed(); }
bool Feeds::raSignedIn() const { return !raUser().isEmpty() && !raKey().isEmpty(); }


// --- sources (feeds.json) ----------------------------------------------------------------------------

void Feeds::loadSources()
{
    const QString path = sourcesFile();
    QJsonObject obj = read_json(path);
    const bool empty = obj.value(QStringLiteral("news")).toArray().isEmpty()
                    && obj.value(QStringLiteral("youtube")).toArray().isEmpty();
    if (empty) {
        // first use (or everything removed): the defaults, with how to change them
        QJsonArray news, yt;
        for (const DefaultFeed& d : DEFAULT_NEWS)
            news.append(QJsonObject{ { QStringLiteral("name"), QString::fromUtf8(d.name) }, { QStringLiteral("url"), QString::fromUtf8(d.value) } });
        for (const DefaultFeed& d : DEFAULT_YOUTUBE)
            yt.append(QJsonObject{ { QStringLiteral("name"), QString::fromUtf8(d.name) }, { QStringLiteral("channel"), QString::fromUtf8(d.value) } });
        obj.insert(QStringLiteral("_help"), QStringLiteral(
            "DeckOS What's New sources. news: RSS or Atom feeds. youtube: channel ids (they start with UC; "
            "on YouTube: the channel's About > Share channel > Copy channel ID). discord: Discord user ids of "
            "friends who joined Lanyard's Discord server (discord.gg/lanyard), for the Friends tab. "
            "Empty both lists to get the defaults back."));
        obj.insert(QStringLiteral("news"), news);
        obj.insert(QStringLiteral("youtube"), yt);
        if (!obj.contains(QStringLiteral("discord")))
            obj.insert(QStringLiteral("discord"), QJsonArray());
        if (write_json(path, obj, true))
            Log::info(LOGMSG("What's New sources written to %1").arg(path));
    }

    QList<Source> sources;
    for (const QJsonValue& v : obj.value(QStringLiteral("news")).toArray()) {
        const QJsonObject o = v.toObject();
        const QString url = o.value(QStringLiteral("url")).toString().trimmed();
        if (url.startsWith(QLatin1String("http")))
            sources.append(Source{ QStringLiteral("news:") + url, o.value(QStringLiteral("name")).toString(url), url, false });
    }
    for (const QJsonValue& v : obj.value(QStringLiteral("youtube")).toArray()) {
        const QJsonObject o = v.toObject();
        const QString ch = o.value(QStringLiteral("channel")).toString().trimmed();
        if (ch.startsWith(QLatin1String("UC")))
            sources.append(Source{ QStringLiteral("yt:") + ch, o.value(QStringLiteral("name")).toString(ch),
                                   QStringLiteral("https://www.youtube.com/feeds/videos.xml?channel_id=") + ch, true });
    }
    QStringList ids;
    for (const QJsonValue& v : obj.value(QStringLiteral("discord")).toArray()) {
        const QString id = v.isString() ? v.toString().trimmed() : v.toObject().value(QStringLiteral("id")).toString().trimmed();
        if (!id.isEmpty())
            ids.append(id);
    }
    const bool changed = ids != m_discord_ids;
    m_sources = sources;
    m_discord_ids = ids;
    if (changed)
        emit sourcesChanged();
}

bool Feeds::addDiscordId(const QString& raw)
{
    const QString id = raw.trimmed();
    static const QRegularExpression rx(QStringLiteral("^\\d{15,21}$"));
    if (!rx.match(id).hasMatch())
        return false;
    QJsonObject obj = read_json(sourcesFile());
    QJsonArray list = obj.value(QStringLiteral("discord")).toArray();
    for (const QJsonValue& v : list)
        if (v.toString() == id)
            return true;
    list.append(id);
    obj.insert(QStringLiteral("discord"), list);
    write_json(sourcesFile(), obj, true);
    loadSources();
    fetchDiscord();
    return true;
}

void Feeds::removeDiscordId(const QString& id)
{
    QJsonObject obj = read_json(sourcesFile());
    QJsonArray list = obj.value(QStringLiteral("discord")).toArray(), kept;
    for (const QJsonValue& v : list)
        if (v.toString() != id)
            kept.append(v);
    obj.insert(QStringLiteral("discord"), kept);
    write_json(sourcesFile(), obj, true);
    loadSources();
    QVariantList left;
    for (const QVariant& f : qAsConst(m_discord))
        if (f.toMap().value(QStringLiteral("id")).toString() != id)
            left.append(f);
    m_discord = left;
    emit friendsChanged();
    m_save_timer->start();
}

void Feeds::openSourcesFile()
{
    loadSources(); // makes it if it isn't there
#ifndef Q_OS_ANDROID
    QDesktopServices::openUrl(QUrl::fromLocalFile(QFileInfo(sourcesFile()).absolutePath()));
#endif
}


// --- cache -------------------------------------------------------------------------------------------

void Feeds::loadCache()
{
    const QJsonObject obj = read_json(cache_path());
    const QJsonObject items = obj.value(QStringLiteral("items")).toObject();
    for (auto it = items.begin(); it != items.end(); ++it)
        m_items.insert(it.key(), it.value().toArray().toVariantList());
    const QJsonObject fetched = obj.value(QStringLiteral("fetched")).toObject();
    for (auto it = fetched.begin(); it != fetched.end(); ++it)
        m_fetched.insert(it.key(), qint64(it.value().toDouble()));
    m_ra_sets = obj.value(QStringLiteral("raSets")).toArray().toVariantList();
    m_ra_community = obj.value(QStringLiteral("raCommunity")).toArray().toVariantList();
    m_ra_weekly = obj.value(QStringLiteral("raWeekly")).toObject().toVariantMap();
    m_ra_friends = obj.value(QStringLiteral("raFriends")).toArray().toVariantList();
    m_discord = obj.value(QStringLiteral("discord")).toArray().toVariantList();
    m_updated = qint64(obj.value(QStringLiteral("updated")).toDouble());
    loadSources();
    rebuildMerged();
}

void Feeds::saveCache()
{
    QJsonObject items;
    for (auto it = m_items.cbegin(); it != m_items.cend(); ++it)
        items.insert(it.key(), QJsonArray::fromVariantList(it.value()));
    QJsonObject fetched;
    for (auto it = m_fetched.cbegin(); it != m_fetched.cend(); ++it)
        fetched.insert(it.key(), double(it.value()));
    QJsonObject obj;
    obj.insert(QStringLiteral("items"), items);
    obj.insert(QStringLiteral("fetched"), fetched);
    obj.insert(QStringLiteral("raSets"), QJsonArray::fromVariantList(m_ra_sets));
    obj.insert(QStringLiteral("raCommunity"), QJsonArray::fromVariantList(m_ra_community));
    obj.insert(QStringLiteral("raWeekly"), QJsonObject::fromVariantMap(m_ra_weekly));
    obj.insert(QStringLiteral("raFriends"), QJsonArray::fromVariantList(m_ra_friends));
    obj.insert(QStringLiteral("discord"), QJsonArray::fromVariantList(m_discord));
    obj.insert(QStringLiteral("updated"), double(m_updated));
    write_json(cache_path(), obj, false);
}

void Feeds::rebuildMerged()
{
    QVariantList news, videos;
    for (const Source& s : qAsConst(m_sources)) {
        const QVariantList& list = m_items.value(s.id);
        (s.video ? videos : news).append(list);
    }
    std::stable_sort(news.begin(), news.end(), by_date_desc);
    std::stable_sort(videos.begin(), videos.end(), by_date_desc);
    if (news.size() > MAX_ITEMS) news = news.mid(0, MAX_ITEMS);
    if (videos.size() > MAX_ITEMS) videos = videos.mid(0, MAX_ITEMS);
    if (news != m_news) {
        m_news = news;
        emit newsChanged();
    }
    if (videos != m_videos) {
        m_videos = videos;
        emit videosChanged();
    }
}


// --- fetching ----------------------------------------------------------------------------------------

bool Feeds::due(const QString& key, qint64 everyMs, bool force) const
{
    return force || now_ms() - m_fetched.value(key, 0) >= everyMs;
}

QNetworkReply* Feeds::get(const QUrl& url)
{
    QNetworkRequest request(url);
    request.setRawHeader("User-Agent", QByteArrayLiteral("DeckOS/") + QCoreApplication::applicationVersion().toUtf8()
                                       + QByteArrayLiteral(" (Android game frontend)"));
    request.setAttribute(QNetworkRequest::RedirectPolicyAttribute, QNetworkRequest::NoLessSafeRedirectPolicy);
    request.setTransferTimeout(20000);
    begin();
    return m_net->get(request);
}

void Feeds::begin()
{
    if (m_running++ == 0)
        emit loadingChanged();
}

void Feeds::finish(QNetworkReply* reply, const QString& failure)
{
    if (reply)
        reply->deleteLater();
    if (failure.isEmpty()) {
        m_updated = now_ms();
        m_error.clear();
    }
    else {
        m_error = failure;
    }
    m_running = std::max(0, m_running - 1);
    emit loadingChanged();
    m_save_timer->start();
}

void Feeds::refresh(bool force)
{
    loadSources();
    for (const Source& s : qAsConst(m_sources))
        if (due(s.id, FEED_EVERY, force))
            fetchSource(s);
    if (raSignedIn()) {
        if (due(QStringLiteral("ra.sets"), RA_SETS_EVERY, force)) fetchRaSets();
        if (due(QStringLiteral("ra.community"), RA_COMMUNITY_EVERY, force)) fetchRaCommunity();
        if (due(QStringLiteral("ra.weekly"), RA_WEEKLY_EVERY, force)) fetchRaWeekly();
    }
    if (m_watch_friends && (force || due(QStringLiteral("friends"), FRIENDS_EVERY, false))) {
        fetchRaFriends();
        fetchDiscord();
    }
}

void Feeds::watchFriends(bool on)
{
    if (on == m_watch_friends)
        return;
    m_watch_friends = on;
    if (on) {
        if (due(QStringLiteral("friends"), 30 * 1000, false)) {
            fetchRaFriends();
            fetchDiscord();
        }
        m_friends_timer->start();
    }
    else {
        m_friends_timer->stop();
    }
}

void Feeds::fetchSource(const Source& s)
{
    m_fetched.insert(s.id, now_ms());
    QNetworkReply* reply = get(QUrl(s.url));
    const Source src = s;
    connect(reply, &QNetworkReply::finished, this, [this, reply, src]() {
        if (reply->error() != QNetworkReply::NoError) {
            Log::warning(LOGMSG("What's New: %1 couldn't be read (%2)").arg(src.name, reply->errorString()));
            // tried again in 5 minutes, not 30 (YouTube's feeds answer "503" now and then)
            m_fetched.insert(src.id, now_ms() - FEED_EVERY + 5 * MINUTE);
            finish(reply, QStringLiteral("Offline or unreachable - showing saved news"));
            return;
        }
        const QVariantList items = parseFeed(reply->readAll(), src.name, src.video);
        if (!items.isEmpty()) {
            m_items.insert(src.id, items);
            rebuildMerged();
        }
        finish(reply, QString());
    });
}

QUrl Feeds::raUrl(const QString& endpoint, const QList<QPair<QString, QString>>& query) const
{
    QUrl url(RA_SITE + QStringLiteral("/API/") + endpoint + QStringLiteral(".php"));
    QUrlQuery q;
    q.addQueryItem(QStringLiteral("y"), raKey());
    for (const auto& kv : query)
        q.addQueryItem(kv.first, kv.second);
    url.setQuery(q);
    return url;
}

void Feeds::fetchRaSets()
{
    m_fetched.insert(QStringLiteral("ra.sets"), now_ms());
    // completed set claims = sets released (API_GetClaims k=1; checked 2026-11-28 in the API docs)
    QNetworkReply* reply = get(raUrl(QStringLiteral("API_GetClaims"), { { QStringLiteral("k"), QStringLiteral("1") } }));
    connect(reply, &QNetworkReply::finished, this, [this, reply]() {
        if (reply->error() != QNetworkReply::NoError) {
            finish(reply, QStringLiteral("RetroAchievements couldn't be reached"));
            return;
        }
        QVariantList sets;
        for (const QJsonValue& v : QJsonDocument::fromJson(reply->readAll()).array()) {
            const QJsonObject c = v.toObject();
            if (c.value(QStringLiteral("SetType")).toInt() != 0)
                continue; // revisions of existing sets: only new ones here
            const int id = c.value(QStringLiteral("GameID")).toInt();
            QVariantMap m;
            m.insert(QStringLiteral("kind"), QStringLiteral("raset"));
            m.insert(QStringLiteral("gameId"), id);
            m.insert(QStringLiteral("title"), c.value(QStringLiteral("GameTitle")).toString());
            m.insert(QStringLiteral("console"), c.value(QStringLiteral("ConsoleName")).toString());
            m.insert(QStringLiteral("icon"), ra_image(c.value(QStringLiteral("GameIcon")).toString()));
            m.insert(QStringLiteral("author"), c.value(QStringLiteral("User")).toString());
            m.insert(QStringLiteral("date"), ra_time(c.value(QStringLiteral("DoneTime")).toString()));
            m.insert(QStringLiteral("link"), RA_SITE + QStringLiteral("/game/") + QString::number(id));
            sets.append(m);
        }
        std::stable_sort(sets.begin(), sets.end(), by_date_desc);
        // one card per game (a set can be claimed and finished in parts)
        QVariantList unique;
        QSet<int> seen;
        for (const QVariant& s : qAsConst(sets)) {
            const int id = s.toMap().value(QStringLiteral("gameId")).toInt();
            if (seen.contains(id))
                continue;
            seen.insert(id);
            unique.append(s);
            if (unique.size() >= MAX_ITEMS)
                break;
        }
        if (!unique.isEmpty()) {
            m_ra_sets = unique;
            emit raChanged();
        }
        finish(reply, QString());
    });
}

void Feeds::fetchRaCommunity()
{
    m_fetched.insert(QStringLiteral("ra.community"), now_ms());
    QNetworkReply* reply = get(raUrl(QStringLiteral("API_GetRecentGameAwards"), { { QStringLiteral("c"), QStringLiteral("30") } }));
    connect(reply, &QNetworkReply::finished, this, [this, reply]() {
        if (reply->error() != QNetworkReply::NoError) {
            finish(reply, QStringLiteral("RetroAchievements couldn't be reached"));
            return;
        }
        QVariantList awards;
        const QJsonObject obj = QJsonDocument::fromJson(reply->readAll()).object();
        for (const QJsonValue& v : obj.value(QStringLiteral("Results")).toArray()) {
            const QJsonObject a = v.toObject();
            const QString user = a.value(QStringLiteral("User")).toString();
            const int id = a.value(QStringLiteral("GameID")).toInt();
            QVariantMap m;
            m.insert(QStringLiteral("kind"), QStringLiteral("raaward"));
            m.insert(QStringLiteral("user"), user);
            m.insert(QStringLiteral("userPic"), RA_MEDIA + QStringLiteral("/UserPic/") + user + QStringLiteral(".png"));
            m.insert(QStringLiteral("award"), a.value(QStringLiteral("AwardKind")).toString());
            m.insert(QStringLiteral("gameId"), id);
            m.insert(QStringLiteral("title"), a.value(QStringLiteral("GameTitle")).toString());
            m.insert(QStringLiteral("console"), a.value(QStringLiteral("ConsoleName")).toString());
            m.insert(QStringLiteral("date"), ra_time(a.value(QStringLiteral("AwardDate")).toString()));
            m.insert(QStringLiteral("link"), RA_SITE + QStringLiteral("/game/") + QString::number(id));
            awards.append(m);
        }
        if (!awards.isEmpty()) {
            m_ra_community = awards;
            emit raChanged();
        }
        finish(reply, QString());
    });
}

void Feeds::fetchRaWeekly()
{
    m_fetched.insert(QStringLiteral("ra.weekly"), now_ms());
    QNetworkReply* reply = get(raUrl(QStringLiteral("API_GetAchievementOfTheWeek"), {}));
    connect(reply, &QNetworkReply::finished, this, [this, reply]() {
        if (reply->error() != QNetworkReply::NoError) {
            finish(reply, QStringLiteral("RetroAchievements couldn't be reached"));
            return;
        }
        const QJsonObject o = QJsonDocument::fromJson(reply->readAll()).object();
        const QJsonObject ach = o.value(QStringLiteral("Achievement")).toObject();
        const QJsonObject game = o.value(QStringLiteral("Game")).toObject();
        const int gameId = game.value(QStringLiteral("ID")).toInt();
        QVariantMap m;
        m.insert(QStringLiteral("title"), ach.value(QStringLiteral("Title")).toString());
        m.insert(QStringLiteral("description"), ach.value(QStringLiteral("Description")).toString());
        m.insert(QStringLiteral("points"), ach.value(QStringLiteral("Points")).toInt());
        m.insert(QStringLiteral("gameId"), gameId);
        m.insert(QStringLiteral("game"), game.value(QStringLiteral("Title")).toString());
        m.insert(QStringLiteral("console"), o.value(QStringLiteral("Console")).toObject().value(QStringLiteral("Title")).toString());
        m.insert(QStringLiteral("players"), o.value(QStringLiteral("TotalPlayers")).toInt());
        m.insert(QStringLiteral("unlocks"), o.value(QStringLiteral("UnlocksCount")).toInt());
        m.insert(QStringLiteral("link"), RA_SITE + QStringLiteral("/game/") + QString::number(gameId));
        m.insert(QStringLiteral("icon"), m_ra_weekly.value(QStringLiteral("gameId")).toInt() == gameId
                                             ? m_ra_weekly.value(QStringLiteral("icon")) : QVariant(QString()));
        if (gameId <= 0) {
            finish(reply, QString());
            return;
        }
        m_ra_weekly = m;
        emit raChanged();
        finish(reply, QString());
        // the game's icon and title screen (API_GetGame)
        QNetworkReply* g = get(raUrl(QStringLiteral("API_GetGame"), { { QStringLiteral("i"), QString::number(gameId) } }));
        connect(g, &QNetworkReply::finished, this, [this, g, gameId]() {
            if (g->error() == QNetworkReply::NoError && m_ra_weekly.value(QStringLiteral("gameId")).toInt() == gameId) {
                const QJsonObject info = QJsonDocument::fromJson(g->readAll()).object();
                m_ra_weekly.insert(QStringLiteral("icon"), ra_image(info.value(QStringLiteral("ImageIcon")).toString()));
                m_ra_weekly.insert(QStringLiteral("image"), ra_image(info.value(QStringLiteral("ImageTitle")).toString()));
                m_ra_weekly.insert(QStringLiteral("boxArt"), ra_image(info.value(QStringLiteral("ImageBoxArt")).toString()));
                emit raChanged();
            }
            finish(g, QString());
        });
    });
}

void Feeds::fetchRaFriends()
{
    if (!raSignedIn() || !m_friend_queue.isEmpty())
        return; // signed out, or a round is still going
    m_fetched.insert(QStringLiteral("friends"), now_ms());
    QNetworkReply* reply = get(raUrl(QStringLiteral("API_GetUsersIFollow"), { { QStringLiteral("c"), QString::number(MAX_FRIENDS) } }));
    connect(reply, &QNetworkReply::finished, this, [this, reply]() {
        if (reply->error() != QNetworkReply::NoError) {
            finish(reply, QStringLiteral("RetroAchievements couldn't be reached"));
            return;
        }
        const QJsonObject obj = QJsonDocument::fromJson(reply->readAll()).object();
        QStringList users;
        for (const QJsonValue& v : obj.value(QStringLiteral("Results")).toArray()) {
            const QJsonObject u = v.toObject();
            const QString id = u.value(QStringLiteral("ULID")).toString(u.value(QStringLiteral("User")).toString());
            if (!id.isEmpty())
                users.append(id);
        }
        finish(reply, QString());
        if (users.isEmpty()) {
            if (!m_ra_friends.isEmpty()) {
                m_ra_friends.clear();
                emit friendsChanged();
            }
            return;
        }
        m_friend_queue = users;
        m_friends_building.clear();
        fetchNextFriend();
    });
}

void Feeds::fetchNextFriend()
{
    if (m_friend_queue.isEmpty()) {
        // online first, then whoever played most recently
        std::stable_sort(m_friends_building.begin(), m_friends_building.end(), [](const QVariant& a, const QVariant& b) {
            const QVariantMap x = a.toMap(), y = b.toMap();
            const bool ox = x.value(QStringLiteral("online")).toBool(), oy = y.value(QStringLiteral("online")).toBool();
            if (ox != oy) return ox;
            return x.value(QStringLiteral("seen")).toLongLong() > y.value(QStringLiteral("seen")).toLongLong();
        });
        m_ra_friends = m_friends_building;
        m_friends_building.clear();
        emit friendsChanged();
        m_save_timer->start();
        return;
    }
    const QString user = m_friend_queue.takeFirst();
    QNetworkReply* reply = get(raUrl(QStringLiteral("API_GetUserSummary"),
                                     { { QStringLiteral("u"), user }, { QStringLiteral("g"), QStringLiteral("1") }, { QStringLiteral("a"), QStringLiteral("0") } }));
    connect(reply, &QNetworkReply::finished, this, [this, reply]() {
        if (reply->error() == QNetworkReply::NoError) {
            const QJsonObject o = QJsonDocument::fromJson(reply->readAll()).object();
            const QString name = o.value(QStringLiteral("User")).toString();
            const QJsonObject last = o.value(QStringLiteral("LastGame")).toObject();
            const QJsonArray recent = o.value(QStringLiteral("RecentlyPlayed")).toArray();
            qint64 seen = ra_time(o.value(QStringLiteral("RichPresenceMsgDate")).toString());
            if (!recent.isEmpty())
                seen = std::max(seen, ra_time(recent.first().toObject().value(QStringLiteral("LastPlayed")).toString()));
            QVariantMap m;
            m.insert(QStringLiteral("user"), name);
            m.insert(QStringLiteral("userPic"), ra_image(o.value(QStringLiteral("UserPic")).toString()));
            m.insert(QStringLiteral("online"), o.value(QStringLiteral("Status")).toString().compare(QLatin1String("Online"), Qt::CaseInsensitive) == 0);
            m.insert(QStringLiteral("presence"), o.value(QStringLiteral("RichPresenceMsg")).toString());
            m.insert(QStringLiteral("game"), last.value(QStringLiteral("Title")).toString());
            m.insert(QStringLiteral("console"), last.value(QStringLiteral("ConsoleName")).toString());
            m.insert(QStringLiteral("gameIcon"), ra_image(last.value(QStringLiteral("ImageIcon")).toString()));
            m.insert(QStringLiteral("points"), o.value(QStringLiteral("TotalPoints")).toInt());
            m.insert(QStringLiteral("seen"), seen);
            m.insert(QStringLiteral("link"), RA_SITE + QStringLiteral("/user/") + name);
            if (!name.isEmpty())
                m_friends_building.append(m);
        }
        finish(reply, QString());
        // one at a time, a moment apart: RetroAchievements asks API users to go easy
        QTimer::singleShot(350, this, &Feeds::fetchNextFriend);
    });
}

void Feeds::fetchDiscord()
{
    if (m_discord_ids.isEmpty())
        return;
    m_fetched.insert(QStringLiteral("discord"), now_ms());
    for (const QString& id : qAsConst(m_discord_ids)) {
        // Lanyard: GET /v1/users/:id (checked 2026-11-28: {"success":true,"data":{...}})
        QNetworkReply* reply = get(QUrl(QStringLiteral("https://api.lanyard.rest/v1/users/") + id));
        connect(reply, &QNetworkReply::finished, this, [this, reply, id]() {
            const QJsonObject root = QJsonDocument::fromJson(reply->readAll()).object();
            const QJsonObject d = root.value(QStringLiteral("data")).toObject();
            QVariantMap m;
            m.insert(QStringLiteral("id"), id);
            if (!root.value(QStringLiteral("success")).toBool()) {
                // not in Lanyard's server (or a wrong id): listed, with why
                m.insert(QStringLiteral("name"), id);
                m.insert(QStringLiteral("status"), QStringLiteral("unknown"));
                m.insert(QStringLiteral("activity"), QStringLiteral("Not on Lanyard - they need to join discord.gg/lanyard"));
            }
            else {
                const QJsonObject u = d.value(QStringLiteral("discord_user")).toObject();
                const QString avatar = u.value(QStringLiteral("avatar")).toString();
                const QString global = u.value(QStringLiteral("global_name")).toString();
                m.insert(QStringLiteral("name"), global.isEmpty() ? u.value(QStringLiteral("username")).toString() : global);
                m.insert(QStringLiteral("avatar"), avatar.isEmpty()
                         ? QStringLiteral("https://cdn.discordapp.com/embed/avatars/0.png")
                         : QStringLiteral("https://cdn.discordapp.com/avatars/%1/%2.png?size=128").arg(id, avatar));
                m.insert(QStringLiteral("status"), d.value(QStringLiteral("discord_status")).toString(QStringLiteral("offline")));
                QString activity, details, image;
                // a game first (type 0), then anything but the custom status, then the custom status
                const QJsonArray acts = d.value(QStringLiteral("activities")).toArray();
                QJsonObject pick;
                for (int pass = 0; pass < 3 && pick.isEmpty(); ++pass) {
                    for (const QJsonValue& v : acts) {
                        const QJsonObject a = v.toObject();
                        const int type = a.value(QStringLiteral("type")).toInt();
                        if ((pass == 0 && type == 0) || (pass == 1 && type != 4) || pass == 2) { pick = a; break; }
                    }
                }
                if (!pick.isEmpty()) {
                    const int type = pick.value(QStringLiteral("type")).toInt();
                    const QString name = pick.value(QStringLiteral("name")).toString();
                    activity = type == 0 ? QStringLiteral("Playing ") + name
                             : type == 2 ? QStringLiteral("Listening to ") + name
                             : type == 3 ? QStringLiteral("Watching ") + name
                             : type == 4 ? pick.value(QStringLiteral("state")).toString()
                             : name;
                    details = type == 4 ? QString() : (pick.value(QStringLiteral("details")).toString()
                              + (pick.contains(QStringLiteral("state")) ? QStringLiteral(" · ") + pick.value(QStringLiteral("state")).toString() : QString()));
                    const QString large = pick.value(QStringLiteral("assets")).toObject().value(QStringLiteral("large_image")).toString();
                    const QString app = pick.value(QStringLiteral("application_id")).toString();
                    if (large.startsWith(QLatin1String("mp:external/")))
                        image = QStringLiteral("https://media.discordapp.net/external/") + large.mid(12);
                    else if (!large.isEmpty() && !app.isEmpty() && !large.contains(QLatin1Char(':')))
                        image = QStringLiteral("https://cdn.discordapp.com/app-assets/%1/%2.png").arg(app, large);
                }
                if (d.value(QStringLiteral("listening_to_spotify")).toBool()) {
                    const QJsonObject sp = d.value(QStringLiteral("spotify")).toObject();
                    m.insert(QStringLiteral("spotify"), sp.value(QStringLiteral("song")).toString() + QStringLiteral(" · ")
                                                         + sp.value(QStringLiteral("artist")).toString());
                }
                m.insert(QStringLiteral("activity"), activity);
                m.insert(QStringLiteral("details"), details);
                m.insert(QStringLiteral("image"), image);
            }
            // replace this friend's entry, keeping feeds.json's order
            QVariantList list;
            bool placed = false;
            for (const QString& known : qAsConst(m_discord_ids)) {
                if (known == id) { list.append(m); placed = true; continue; }
                for (const QVariant& f : qAsConst(m_discord))
                    if (f.toMap().value(QStringLiteral("id")).toString() == known) { list.append(f); break; }
            }
            if (!placed)
                list.append(m);
            m_discord = list;
            emit friendsChanged();
            finish(reply, reply->error() == QNetworkReply::NoError || root.contains(QStringLiteral("success"))
                              ? QString() : QStringLiteral("Lanyard couldn't be reached"));
        });
    }
}


// --- parsing -----------------------------------------------------------------------------------------

QString Feeds::firstImage(const QString& html)
{
    static const QRegularExpression rx(QStringLiteral("<img[^>]+src\\s*=\\s*[\"']([^\"']+)[\"']"),
                                       QRegularExpression::CaseInsensitiveOption);
    QRegularExpressionMatchIterator it = rx.globalMatch(html);
    while (it.hasNext()) {
        const QString src = it.next().captured(1);
        if (src.startsWith(QLatin1String("http")) && !src.contains(QLatin1String("feeds.feedburner")) && !src.endsWith(QLatin1String(".gif")))
            return src;
    }
    return QString();
}

QString Feeds::plainText(const QString& html, int maxLength, bool paragraphs)
{
    QString s = html;
    static const QRegularExpression scripts(QStringLiteral("<(script|style)[^>]*>.*?</\\1>"),
                                            QRegularExpression::CaseInsensitiveOption | QRegularExpression::DotMatchesEverythingOption);
    static const QRegularExpression breaks(QStringLiteral("<(br|/p|/div|/li|/h[1-6])[^>]*>"), QRegularExpression::CaseInsensitiveOption);
    static const QRegularExpression tags(QStringLiteral("<[^>]*>"));
    static const QRegularExpression numeric(QStringLiteral("&#(x?)([0-9A-Fa-f]+);"));
    static const QRegularExpression spaces(QStringLiteral("\\s+"));
    static const QRegularExpression blank(QStringLiteral("\\s*\\x{2029}[\\s\\x{2029}]*"));
    const QChar PARA(0x2029); // a paragraph mark through the whitespace clean-up
    s.remove(scripts);
    s.replace(breaks, paragraphs ? QString(PARA) : QStringLiteral(" "));
    s.remove(tags);
    // character references: &#8217; &#x2019;
    QString out;
    int last = 0;
    QRegularExpressionMatchIterator it = numeric.globalMatch(s);
    while (it.hasNext()) {
        const QRegularExpressionMatch m = it.next();
        out += s.midRef(last, m.capturedStart() - last);
        bool ok = false;
        const uint code = m.captured(2).toUInt(&ok, m.captured(1).isEmpty() ? 10 : 16);
        if (ok && code > 0 && code < 0x110000)
            out += QString::fromUcs4(&code, 1);
        last = m.capturedEnd();
    }
    out += s.midRef(last);
    out.replace(QLatin1String("&nbsp;"), QLatin1String(" "));
    out.replace(QLatin1String("&quot;"), QLatin1String("\""));
    out.replace(QLatin1String("&apos;"), QLatin1String("'"));
    out.replace(QLatin1String("&lt;"), QLatin1String("<"));
    out.replace(QLatin1String("&gt;"), QLatin1String(">"));
    out.replace(QLatin1String("&hellip;"), QStringLiteral("…"));
    out.replace(QLatin1String("&amp;"), QLatin1String("&"));
    if (paragraphs) {
        out.replace(QRegularExpression(QStringLiteral("[ \\t\\r\\n]+")), QStringLiteral(" "));
        out.replace(blank, QStringLiteral("\n\n"));
        out = out.trimmed();
    }
    else {
        out = out.replace(spaces, QStringLiteral(" ")).trimmed();
    }
    if (maxLength > 0 && out.size() > maxLength) {
        out.truncate(maxLength);
        const int cut = out.lastIndexOf(QLatin1Char(' '));
        if (cut > maxLength * 2 / 3)
            out.truncate(cut);
        out += QStringLiteral("…");
    }
    return out;
}

QVariantList Feeds::parseFeed(const QByteArray& xml, const QString& sourceName, bool video)
{
    QVariantList out;
    QXmlStreamReader r(xml);
    bool inItem = false;
    QString title, link, summary, content, image, videoId;
    qint64 date = 0;

    while (!r.atEnd()) {
        r.readNext();
        if (r.isStartElement()) {
            const QStringRef name = r.name();
            const QStringRef ns = r.namespaceUri();
            if (name == QLatin1String("item") || name == QLatin1String("entry")) {
                inItem = true;
                title.clear(); link.clear(); summary.clear(); content.clear(); image.clear(); videoId.clear();
                date = 0;
                continue;
            }
            if (!inItem)
                continue;
            const bool media = ns == QLatin1String(NS_MEDIA);
            if (name == QLatin1String("title") && !media && title.isEmpty()) {
                title = r.readElementText(QXmlStreamReader::IncludeChildElements).trimmed();
            }
            else if (name == QLatin1String("link") && !media) {
                const QString href = r.attributes().value(QStringLiteral("href")).toString();
                const QString rel = r.attributes().value(QStringLiteral("rel")).toString();
                if (!href.isEmpty()) {
                    if (link.isEmpty() && (rel.isEmpty() || rel == QLatin1String("alternate")))
                        link = href;
                }
                else if (link.isEmpty()) {
                    link = r.readElementText().trimmed();
                }
            }
            else if (name == QLatin1String("pubDate") || name == QLatin1String("published")
                     || (name == QLatin1String("updated") && date == 0) || (name == QLatin1String("date") && date == 0)) {
                const QString text = r.readElementText().trimmed();
                QDateTime t = QDateTime::fromString(text, Qt::RFC2822Date);
                if (!t.isValid())
                    t = QDateTime::fromString(text, Qt::ISODate);
                if (t.isValid())
                    date = t.toMSecsSinceEpoch();
            }
            else if ((name == QLatin1String("description") || name == QLatin1String("summary")) && summary.isEmpty()) {
                summary = r.readElementText(QXmlStreamReader::IncludeChildElements);
            }
            else if ((name == QLatin1String("encoded") && ns == QLatin1String(NS_CONTENT))
                     || (name == QLatin1String("content") && !media && content.isEmpty())) {
                content = r.readElementText(QXmlStreamReader::IncludeChildElements);
            }
            else if (name == QLatin1String("thumbnail") && media && image.isEmpty()) {
                image = r.attributes().value(QStringLiteral("url")).toString();
            }
            else if (name == QLatin1String("content") && media && image.isEmpty()) {
                const QString type = r.attributes().value(QStringLiteral("type")).toString();
                const QString medium = r.attributes().value(QStringLiteral("medium")).toString();
                if (type.startsWith(QLatin1String("image")) || medium == QLatin1String("image"))
                    image = r.attributes().value(QStringLiteral("url")).toString();
            }
            else if (name == QLatin1String("enclosure") && image.isEmpty()
                     && r.attributes().value(QStringLiteral("type")).startsWith(QLatin1String("image"))) {
                image = r.attributes().value(QStringLiteral("url")).toString();
            }
            else if (name == QLatin1String("videoId") && ns == QLatin1String(NS_YT)) {
                videoId = r.readElementText().trimmed();
            }
        }
        else if (r.isEndElement() && inItem && (r.name() == QLatin1String("item") || r.name() == QLatin1String("entry"))) {
            inItem = false;
            if (title.isEmpty() || link.isEmpty())
                continue;
            if (image.isEmpty())
                image = firstImage(content + summary);
            if (video && !videoId.isEmpty())
                image = QStringLiteral("https://i.ytimg.com/vi/%1/hqdefault.jpg").arg(videoId);
            QVariantMap m;
            m.insert(QStringLiteral("kind"), video ? QStringLiteral("video") : QStringLiteral("news"));
            m.insert(QStringLiteral("source"), sourceName);
            m.insert(QStringLiteral("title"), plainText(title, 0));
            m.insert(QStringLiteral("link"), link);
            m.insert(QStringLiteral("date"), date);
            m.insert(QStringLiteral("image"), image);
            m.insert(QStringLiteral("summary"), plainText(summary.isEmpty() ? content : summary, 260));
            // the article itself, for the reader (tags gone, paragraphs kept)
            if (!video) {
                m.insert(QStringLiteral("body"), plainText(content.isEmpty() ? summary : content, 4000, true));
                // the article's HTML for the reader page (newspage.qml lays out its text and pictures)
                m.insert(QStringLiteral("html"), (content.isEmpty() ? summary : content).left(12000));
            }
            if (!videoId.isEmpty())
                m.insert(QStringLiteral("videoId"), videoId);
            out.append(m);
        }
    }
    if (r.hasError() && out.isEmpty())
        Log::warning(LOGMSG("What's New: %1 isn't a readable feed (%2)").arg(sourceName, r.errorString()));
    return out;
}

} // namespace deckos
