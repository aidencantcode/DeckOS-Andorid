// DeckOS
// See Scraper.h

#include "Scraper.h"

#include "GameOverrides.h"
#include "Log.h"
#include "Paths.h"
#include "model/Api.h"
#include "model/gaming/Assets.h"
#include "model/gaming/Collection.h"
#include "model/gaming/Game.h"
#include "model/gaming/GameFile.h"
#include "model/gaming/GameListModel.h"
#include "types/AssetType.h"

#include <QDateTime>
#include <algorithm>
#include <QDate>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QHash>
#include <QJsonArray>
#include <QJsonDocument>
#include <QNetworkAccessManager>
#include <QNetworkReply>
#include <QNetworkRequest>
#include <QPair>
#include <QRegularExpression>
#include <QSaveFile>
#include <QTextStream>
#include <QTimer>
#include <QUrl>
#include <QUrlQuery>


namespace {
const QString LOGTAG = QStringLiteral("Scraper");
constexpr int PAUSE_BETWEEN_GAMES_MS = 400;
constexpr int REQUEST_TIMEOUT_MS = 20000;

struct SystemInfo {
    int tgdb_platform;    // TheGamesDB platform id (verified 2026-11-25 via /v1/Platforms), 0 = unknown
    const char* libretro; // libretro-thumbnails folder, nullptr = none
};

// keyed by Pegasus collection short names (and common ES-DE / RetroArch aliases)
const QHash<QString, SystemInfo>& systems()
{
    static const QHash<QString, SystemInfo> map {
        { QStringLiteral("nes"), { 7, "Nintendo - Nintendo Entertainment System" } },
        { QStringLiteral("famicom"), { 7, "Nintendo - Nintendo Entertainment System" } },
        { QStringLiteral("fc"), { 7, "Nintendo - Nintendo Entertainment System" } }, // catalog ids from here on
        { QStringLiteral("scd"), { 21, "Sega - Mega-CD - Sega CD" } },
        { QStringLiteral("mcd"), { 21, "Sega - Mega-CD - Sega CD" } },
        { QStringLiteral("sat"), { 17, "Sega - Saturn" } },
        { QStringLiteral("pce"), { 34, "NEC - PC Engine - TurboGrafx 16" } },
        { QStringLiteral("sg1k"), { 4949, "Sega - SG-1000" } },
        { QStringLiteral("2600"), { 22, "Atari - 2600" } },
        { QStringLiteral("vb"), { 4918, "Nintendo - Virtual Boy" } },
        { QStringLiteral("cps1"), { 23, "FBNeo - Arcade Games" } },
        { QStringLiteral("cps2"), { 23, "FBNeo - Arcade Games" } },
        { QStringLiteral("cps3"), { 23, "FBNeo - Arcade Games" } },
        { QStringLiteral("fds"), { 4936, "Nintendo - Family Computer Disk System" } },
        { QStringLiteral("snes"), { 6, "Nintendo - Super Nintendo Entertainment System" } },
        { QStringLiteral("sfc"), { 6, "Nintendo - Super Nintendo Entertainment System" } },
        { QStringLiteral("n64"), { 3, "Nintendo - Nintendo 64" } },
        { QStringLiteral("gb"), { 4, "Nintendo - Game Boy" } },
        { QStringLiteral("gameboy"), { 4, "Nintendo - Game Boy" } },
        { QStringLiteral("gbc"), { 41, "Nintendo - Game Boy Color" } },
        { QStringLiteral("gba"), { 5, "Nintendo - Game Boy Advance" } },
        { QStringLiteral("nds"), { 8, "Nintendo - Nintendo DS" } },
        { QStringLiteral("ds"), { 8, "Nintendo - Nintendo DS" } },
        { QStringLiteral("3ds"), { 4912, "Nintendo - Nintendo 3DS" } },
        { QStringLiteral("n3ds"), { 4912, "Nintendo - Nintendo 3DS" } },
        { QStringLiteral("gc"), { 2, "Nintendo - GameCube" } },
        { QStringLiteral("ngc"), { 2, "Nintendo - GameCube" } },
        { QStringLiteral("gamecube"), { 2, "Nintendo - GameCube" } },
        { QStringLiteral("wii"), { 9, "Nintendo - Wii" } },
        { QStringLiteral("wiiu"), { 38, nullptr } },
        { QStringLiteral("switch"), { 4971, nullptr } },
        { QStringLiteral("virtualboy"), { 4918, "Nintendo - Virtual Boy" } },
        { QStringLiteral("genesis"), { 18, "Sega - Mega Drive - Genesis" } },
        { QStringLiteral("megadrive"), { 36, "Sega - Mega Drive - Genesis" } },
        { QStringLiteral("md"), { 36, "Sega - Mega Drive - Genesis" } },
        { QStringLiteral("mastersystem"), { 35, "Sega - Master System - Mark III" } },
        { QStringLiteral("sms"), { 35, "Sega - Master System - Mark III" } },
        { QStringLiteral("gamegear"), { 20, "Sega - Game Gear" } },
        { QStringLiteral("gg"), { 20, "Sega - Game Gear" } },
        { QStringLiteral("segacd"), { 21, "Sega - Mega-CD - Sega CD" } },
        { QStringLiteral("megacd"), { 21, "Sega - Mega-CD - Sega CD" } },
        { QStringLiteral("sega32x"), { 33, "Sega - 32X" } },
        { QStringLiteral("32x"), { 33, "Sega - 32X" } },
        { QStringLiteral("saturn"), { 17, "Sega - Saturn" } },
        { QStringLiteral("dreamcast"), { 16, "Sega - Dreamcast" } },
        { QStringLiteral("dc"), { 16, "Sega - Dreamcast" } },
        { QStringLiteral("sg1000"), { 4949, "Sega - SG-1000" } },
        { QStringLiteral("psx"), { 10, "Sony - PlayStation" } },
        { QStringLiteral("ps1"), { 10, "Sony - PlayStation" } },
        { QStringLiteral("playstation"), { 10, "Sony - PlayStation" } },
        { QStringLiteral("ps2"), { 11, "Sony - PlayStation 2" } },
        { QStringLiteral("ps3"), { 12, "Sony - PlayStation 3" } },
        { QStringLiteral("psp"), { 13, "Sony - PlayStation Portable" } },
        { QStringLiteral("psvita"), { 39, nullptr } },
        { QStringLiteral("vita"), { 39, nullptr } },
        { QStringLiteral("pcengine"), { 34, "NEC - PC Engine - TurboGrafx 16" } },
        { QStringLiteral("tg16"), { 34, "NEC - PC Engine - TurboGrafx 16" } },
        { QStringLiteral("turbografx16"), { 34, "NEC - PC Engine - TurboGrafx 16" } },
        { QStringLiteral("pcenginecd"), { 4955, "NEC - PC Engine CD - TurboGrafx-CD" } },
        { QStringLiteral("neogeo"), { 24, "SNK - Neo Geo" } },
        { QStringLiteral("ngp"), { 4922, "SNK - Neo Geo Pocket" } },
        { QStringLiteral("ngpc"), { 4923, "SNK - Neo Geo Pocket Color" } },
        { QStringLiteral("atari2600"), { 22, "Atari - 2600" } },
        { QStringLiteral("arcade"), { 23, "MAME" } },
        { QStringLiteral("mame"), { 23, "MAME" } },
        { QStringLiteral("fbneo"), { 23, "FBNeo - Arcade Games" } },
    };
    return map;
}

// "Legend of Zelda, The - A Link to the Past (USA) [!]" -> "The Legend of Zelda: A Link to the Past"
QString search_title(QString title)
{
    static const QRegularExpression tags(QStringLiteral("\\s*[\\(\\[][^\\)\\]]*[\\)\\]]"));
    static const QRegularExpression article(QStringLiteral("^(.+?), (The|A|An)( - |: |$)"));
    title.remove(tags);
    title = title.trimmed();
    const QRegularExpressionMatch m = article.match(title);
    if (m.hasMatch())
        title = m.captured(2) + QLatin1Char(' ') + m.captured(1) + m.captured(3) + title.mid(m.capturedEnd());
    title.replace(QStringLiteral(" - "), QStringLiteral(": "));
    return title.trimmed();
}

QString normalized(const QString& text)
{
    QString out;
    for (const QChar ch : text.toLower()) {
        if (ch.isLetterOrNumber())
            out += ch;
    }
    return out;
}

// libretro-thumbnails replace these characters in file names
QString libretro_name(QString name)
{
    for (const QChar ch : QStringLiteral("&*/:`<>?\\|\""))
        name.replace(ch, QLatin1Char('_'));
    return name;
}

QString safe_dir_name(QString name)
{
    static const QRegularExpression bad(QStringLiteral("[^\\w\\-. ()\\[\\]]"));
    name.replace(bad, QStringLiteral("_"));
    return name.left(120).trimmed();
}

QString file_extension(const QNetworkReply* reply)
{
    const QString suffix = QFileInfo(reply->url().path()).suffix().toLower();
    if (suffix == QLatin1String("png") || suffix == QLatin1String("jpg")
        || suffix == QLatin1String("jpeg") || suffix == QLatin1String("webp"))
        return suffix;
    const QString type = reply->header(QNetworkRequest::ContentTypeHeader).toString();
    if (type.contains(QLatin1String("png"))) return QStringLiteral("png");
    if (type.contains(QLatin1String("webp"))) return QStringLiteral("webp");
    return QStringLiteral("jpg");
}

bool looks_like_image(const QByteArray& data)
{
    return data.startsWith("\x89PNG") || data.startsWith("\xFF\xD8") || (data.startsWith("RIFF") && data.mid(8, 4) == "WEBP");
}

AssetType asset_type(const QString& name)
{
    static const QHash<QString, AssetType> types {
        { QStringLiteral("boxFront"), AssetType::BOX_FRONT },
        { QStringLiteral("poster"), AssetType::POSTER },
        { QStringLiteral("steam"), AssetType::UI_STEAMGRID },
        { QStringLiteral("background"), AssetType::BACKGROUND },
        { QStringLiteral("logo"), AssetType::LOGO },
        { QStringLiteral("screenshot"), AssetType::SCREENSHOT },
        { QStringLiteral("titlescreen"), AssetType::TITLESCREEN },
    };
    return types.value(name, AssetType::UNKNOWN);
}

const QStringList& scraped_assets()
{
    static const QStringList names {
        QStringLiteral("boxFront"), QStringLiteral("poster"), QStringLiteral("steam"),
        QStringLiteral("background"), QStringLiteral("logo"),
        QStringLiteral("screenshot"), QStringLiteral("titlescreen"),
    };
    return names;
}

QString settings_path()
{
    return paths::writableConfigDir() + QStringLiteral("/deckos/scraper.json");
}
} // namespace


namespace deckos {

struct Scraper::Job {
    QPointer<model::Game> game;
    QString key;
    QString title;
    QString search;
    QString rom_name;
    QString system;
    bool force = false;
    QSet<QString> needed;
    QJsonObject fields;
    QHash<QString, QList<int>> tgdb_ids;
    QList<QPair<QString, QString>> downloads;
    QJsonObject saved_assets;
    QStringList sources;
    int download_index = 0;
    QPointer<QNetworkReply> reply;

    bool wants(const QString& name) const { return needed.contains(name); }
    bool hasDownload(const QString& name) const {
        for (const auto& d : downloads)
            if (d.first == name) return true;
        return false;
    }
    void addDownload(const QString& name, const QString& url) {
        if (wants(name) && !url.isEmpty() && !hasDownload(name))
            downloads.append({ name, url });
    }
};


Scraper::Scraper(model::ApiObject* api, QObject* parent)
    : QObject(parent)
    , m_api(api)
    , m_net(new QNetworkAccessManager(this))
    , m_next_timer(new QTimer(this))
{
    m_next_timer->setSingleShot(true);
    m_next_timer->setInterval(PAUSE_BETWEEN_GAMES_MS);
    connect(m_next_timer, &QTimer::timeout, this, &Scraper::startNext);
    loadSettings();
    loadTheGamesDbNames();
}

QString Scraper::currentTitle() const
{
    return m_current ? m_current->title : QString();
}

void Scraper::setStatus(const QString& text)
{
    m_status = text;
    emit progressChanged();
}


// --- settings ---------------------------------------------------------------------------------------

void Scraper::loadSettings()
{
    QFile file(settings_path());
    if (!file.open(QIODevice::ReadOnly))
        return;
    const QJsonObject obj = QJsonDocument::fromJson(file.readAll()).object();
    m_sgdb_key = obj.value(QStringLiteral("steamgriddb_key")).toString();
    m_tgdb_key = obj.value(QStringLiteral("thegamesdb_key")).toString();
    m_auto = obj.value(QStringLiteral("auto_scrape")).toBool(false);
    m_descriptions = obj.value(QStringLiteral("descriptions")).toBool(true);
    m_libretro = obj.value(QStringLiteral("libretro")).toBool(true);
}

void Scraper::saveSettings() const
{
    QDir().mkpath(QFileInfo(settings_path()).absolutePath());
    QSaveFile file(settings_path());
    if (!file.open(QIODevice::WriteOnly)) {
        Log::warning(LOGTAG, LOGMSG("Could not save the scraper settings"));
        return;
    }
    const QJsonObject obj {
        { QStringLiteral("steamgriddb_key"), m_sgdb_key },
        { QStringLiteral("thegamesdb_key"), m_tgdb_key },
        { QStringLiteral("auto_scrape"), m_auto },
        { QStringLiteral("descriptions"), m_descriptions },
        { QStringLiteral("libretro"), m_libretro },
    };
    file.write(QJsonDocument(obj).toJson(QJsonDocument::Indented));
    file.commit();
}

void Scraper::setSteamGridDbKey(const QString& key)
{
    if (m_sgdb_key == key.trimmed()) return;
    m_sgdb_key = key.trimmed();
    saveSettings();
    emit settingsChanged();
}

void Scraper::setTheGamesDbKey(const QString& key)
{
    if (m_tgdb_key == key.trimmed()) return;
    m_tgdb_key = key.trimmed();
    m_tgdb_allowance = -1;
    saveSettings();
    emit settingsChanged();
}

void Scraper::setAutoScrape(bool val)
{
    if (m_auto == val) return;
    m_auto = val;
    saveSettings();
    emit settingsChanged();
    if (m_auto)
        scrapeAll(true);
}

void Scraper::setFetchDescriptions(bool val)
{
    if (m_descriptions == val) return;
    m_descriptions = val;
    saveSettings();
    emit settingsChanged();
}

void Scraper::setUseLibretroThumbnails(bool val)
{
    if (m_libretro == val) return;
    m_libretro = val;
    saveSettings();
    emit settingsChanged();
}

QString Scraper::keysFilePath() const
{
    return paths::writableConfigDir() + QStringLiteral("/api-keys.env");
}

QVariantMap Scraper::importKeys()
{
    QVariantMap out;
    const QString path = keysFilePath();
    out.insert(QStringLiteral("path"), path);
    out.insert(QStringLiteral("found"), 0);

    QFile file(path);
    if (!file.open(QIODevice::ReadOnly | QIODevice::Text)) {
        out.insert(QStringLiteral("error"), tr("No file at %1").arg(path));
        return out;
    }

    int found = 0;
    QTextStream stream(&file);
    stream.setCodec("UTF-8");
    QString line;
    while (stream.readLineInto(&line)) {
        line = line.trimmed();
        if (line.isEmpty() || line.startsWith(QLatin1Char('#')))
            continue;
        const int eq = line.indexOf(QLatin1Char('='));
        if (eq <= 0)
            continue;
        const QString name = line.left(eq).trimmed().toUpper();
        QString value = line.mid(eq + 1).trimmed();
        if (value.size() >= 2 && value.startsWith(QLatin1Char('"')) && value.endsWith(QLatin1Char('"')))
            value = value.mid(1, value.size() - 2);
        if (value.isEmpty())
            continue;

        if (name == QLatin1String("STEAMGRIDDB_API_KEY")) { setSteamGridDbKey(value); found++; }
        else if (name == QLatin1String("THEGAMESDB_API_KEY")) { setTheGamesDbKey(value); found++; }
        else if (name == QLatin1String("RA_USERNAME")) { out.insert(QStringLiteral("raUser"), value); found++; }
        else if (name == QLatin1String("RA_WEB_API_KEY")) { out.insert(QStringLiteral("raKey"), value); found++; }
    }
    out.insert(QStringLiteral("found"), found);
    Log::info(LOGTAG, LOGMSG("Imported %1 keys from %2").arg(found).arg(path)); // never the values
    return out;
}


// --- queue ------------------------------------------------------------------------------------------

Scraper::Job* Scraper::makeJob(model::Game& game, bool force)
{
    auto job = new Job;
    job->game = &game;
    job->key = GameOverrides::keyFor(game);
    job->title = game.title();
    job->search = search_title(game.title());
    job->force = force;

    const auto& files = game.filesModel()->entries();
    if (!files.empty() && !files.front()->path().isEmpty())
        job->rom_name = files.front()->fileinfo().completeBaseName();
    const auto& collections = game.collectionsModel()->entries();
    if (!collections.empty())
        job->system = collections.front()->shortName().toLower();

    // a description the user typed in Properties is never replaced
    const bool user_text = GameOverrides::instance().entry(job->key).value(QStringLiteral("edited_description")).toBool();
    const bool no_text = game.description().isEmpty() && game.summary().isEmpty();
    if (m_descriptions && !user_text && (force || no_text))
        job->needed.insert(QStringLiteral("description"));
    if (force || !game.releaseDate().isValid())
        job->needed.insert(QStringLiteral("release"));
    if (force || game.developerListConst().isEmpty())
        job->needed.insert(QStringLiteral("developer"));
    if (force || game.publisherListConst().isEmpty())
        job->needed.insert(QStringLiteral("publisher"));
    if (force || game.genreListConst().isEmpty())
        job->needed.insert(QStringLiteral("genre"));
    for (const QString& asset : scraped_assets()) {
        if (force || game.assets().urisOf(asset_type(asset)).isEmpty())
            job->needed.insert(asset);
    }
    return job;
}

void Scraper::enqueue(Job* job, bool front)
{
    if (!running() && m_queue.isEmpty()) {
        m_done = 0;
        m_total = 0;
    }
    m_queued_keys.insert(job->key);
    if (front)
        m_queue.prepend(job);
    else
        m_queue.enqueue(job);
    m_total++;
    emit progressChanged();

    if (!running() && !m_next_timer->isActive())
        startNext();
}

void Scraper::scrapeGame(QObject* obj)
{
    auto game = qobject_cast<model::Game*>(obj);
    if (!game)
        return;
    if (m_sgdb_key.isEmpty() && m_tgdb_key.isEmpty() && !m_libretro) {
        emit gameFinished(game, false, tr("Add a SteamGridDB or TheGamesDB key first"));
        return;
    }
    Job* job = makeJob(*game, true);
    if (job->key.isEmpty()) {
        delete job;
        emit gameFinished(game, false, tr("This game has no file to remember the results by"));
        return;
    }
    // a newer request for the same game replaces a queued one
    for (int i = m_queue.size() - 1; i >= 0; i--) {
        if (m_queue.at(i)->key == job->key) {
            delete m_queue.takeAt(i);
            m_total--;
        }
    }
    enqueue(job, true);
}

int Scraper::scrapeAll(bool only_missing, const QStringList& collections)
{
    if (m_sgdb_key.isEmpty() && m_tgdb_key.isEmpty() && !m_libretro)
        return 0;

    const GameOverrides& store = GameOverrides::instance();
    int queued = 0;
    for (model::Game* const game : m_api->allGames()->entries()) {
        const QString key = GameOverrides::keyFor(*game);
        if (key.isEmpty() || m_queued_keys.contains(key))
            continue;
        if (!collections.isEmpty()) { // DECKOS: "Re-scrape" limited to the chosen collections
            const auto& in = game->collectionsModel()->entries();
            const bool picked = std::any_of(in.cbegin(), in.cend(), [&collections](const model::Collection* c) {
                return collections.contains(c->name());
            });
            if (!picked)
                continue;
        }
        if (only_missing) {
            // Android apps and other entries without a ROM file: only on request
            if (key.startsWith(QLatin1String("uri:")))
                continue;
            if (store.entry(key).contains(QStringLiteral("scraped")))
                continue;
        }
        Job* job = makeJob(*game, !only_missing);
        if (job->needed.isEmpty()) {
            delete job;
            continue;
        }
        enqueue(job, false);
        queued++;
    }
    if (queued > 0)
        Log::info(LOGTAG, LOGMSG("%1 games queued").arg(queued));
    return queued;
}

void Scraper::cancel()
{
    qDeleteAll(m_queue);
    m_queue.clear();
    m_queued_keys.clear();
    m_next_timer->stop();
    if (m_current) {
        // clear m_current first: abort() emits finished() right away, and that callback must see the job gone
        Job* const job = m_current;
        m_current = nullptr;
        if (job->reply)
            job->reply->abort();
        delete job;
    }
    m_total = m_done;
    setStatus(tr("Stopped"));
}

void Scraper::onLibraryReady()
{
    if (m_auto)
        scrapeAll(true);
}

void Scraper::startNext()
{
    if (m_current || m_queue.isEmpty()) {
        if (!m_current && m_queue.isEmpty() && m_total > 0)
            setStatus(tr("Finished %1 of %2").arg(m_done).arg(m_total));
        return;
    }
    m_current = m_queue.dequeue();
    setStatus(tr("Looking up %1").arg(m_current->title));
    stepTheGamesDb();
}

void Scraper::finishJob(bool ok, const QString& message)
{
    Job* job = m_current;
    m_current = nullptr;
    if (!job)
        return;

    if (!job->key.isEmpty()) {
        QJsonObject fields = job->fields;
        if (!job->saved_assets.isEmpty())
            fields.insert(QStringLiteral("assets"), job->saved_assets);
        fields.insert(QStringLiteral("scraped"), QDateTime::currentDateTimeUtc().toString(Qt::ISODate));
        fields.insert(QStringLiteral("sources"), job->sources.join(QStringLiteral(", ")));
        GameOverrides::instance().update(job->key, fields);
        if (job->game)
            GameOverrides::apply(*job->game, GameOverrides::instance().entry(job->key), true);
    }

    m_queued_keys.remove(job->key);
    m_done++;
    Log::info(LOGTAG, LOGMSG("%1: %2").arg(job->title, message));
    emit gameFinished(job->game.data(), ok, message);
    delete job;

    emit progressChanged();
    if (m_queue.isEmpty())
        setStatus(tr("Finished %1 of %2").arg(m_done).arg(m_total));
    else
        m_next_timer->start();
}


// --- network helpers --------------------------------------------------------------------------------

QNetworkReply* Scraper::get(const QString& url, bool sgdb_auth)
{
    QNetworkRequest request { QUrl(url) };
    request.setHeader(QNetworkRequest::UserAgentHeader, QStringLiteral("DeckOS (Pegasus Frontend fork)"));
    request.setAttribute(QNetworkRequest::RedirectPolicyAttribute, QNetworkRequest::NoLessSafeRedirectPolicy);
    request.setTransferTimeout(REQUEST_TIMEOUT_MS);
    if (sgdb_auth)
        request.setRawHeader("Authorization", "Bearer " + m_sgdb_key.toUtf8());
    QNetworkReply* reply = m_net->get(request);
    if (m_current)
        m_current->reply = reply;
    return reply;
}

void Scraper::whenDone(QNetworkReply* reply, std::function<void(QNetworkReply*)> callback)
{
    Job* const job = m_current;
    connect(reply, &QNetworkReply::finished, this, [this, reply, job, callback]() {
        reply->deleteLater();
        if (m_current != job || !job) // cancelled meanwhile
            return;
        callback(reply);
    });
}


// --- 1. TheGamesDB ----------------------------------------------------------------------------------

void Scraper::stepTheGamesDb()
{
    Job* const job = m_current;
    const bool useful = job->wants(QStringLiteral("description")) || job->wants(QStringLiteral("release"))
                     || job->wants(QStringLiteral("boxFront"));
    if (m_tgdb_key.isEmpty() || !useful || m_tgdb_allowance == 0) {
        stepSteamGridDbSearch();
        return;
    }

    QUrlQuery query;
    query.addQueryItem(QStringLiteral("apikey"), m_tgdb_key);
    query.addQueryItem(QStringLiteral("name"), job->search);
    query.addQueryItem(QStringLiteral("fields"), QStringLiteral("players,overview,genres,publishers"));
    query.addQueryItem(QStringLiteral("include"), QStringLiteral("boxart"));
    const int platform = systems().value(job->system, { 0, nullptr }).tgdb_platform;
    if (platform > 0)
        query.addQueryItem(QStringLiteral("filter[platform]"), QString::number(platform));
    QUrl url(QStringLiteral("https://api.thegamesdb.net/v1/Games/ByGameName"));
    url.setQuery(query);

    whenDone(get(url.toString()), [this](QNetworkReply* reply) {
        Job* const job = m_current;
        const QJsonObject root = QJsonDocument::fromJson(reply->readAll()).object();
        if (root.contains(QStringLiteral("remaining_monthly_allowance")))
            m_tgdb_allowance = root.value(QStringLiteral("remaining_monthly_allowance")).toInt(-1);

        if (reply->error() != QNetworkReply::NoError) {
            const int http = reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
            Log::warning(LOGTAG, LOGMSG("TheGamesDB: HTTP %1 for %2").arg(http).arg(job->title));
            if (http == 403)
                m_tgdb_allowance = 0; // bad key or this month's lookups used up; stop asking
            stepSteamGridDbSearch();
            return;
        }

        const QJsonArray games = root.value(QStringLiteral("data")).toObject().value(QStringLiteral("games")).toArray();
        const QString wanted = normalized(job->search);
        const bool usa = job->title.contains(QLatin1String("(USA"));
        const bool japan = job->title.contains(QLatin1String("(Japan"));
        QJsonObject best;
        int best_score = -1;
        for (const QJsonValue& val : games) {
            const QJsonObject game = val.toObject();
            int score = 0;
            if (normalized(game.value(QStringLiteral("game_title")).toString()) == wanted)
                score += 10;
            const int region = game.value(QStringLiteral("region_id")).toInt();
            if ((usa && region == 2) || (japan && region == 4))
                score += 2;
            if (!game.value(QStringLiteral("overview")).toString().isEmpty())
                score += 1;
            if (score > best_score) {
                best_score = score;
                best = game;
            }
        }

        if (!best.isEmpty()) {
            job->sources << QStringLiteral("TheGamesDB");
            const QString overview = best.value(QStringLiteral("overview")).toString().trimmed();
            if (job->wants(QStringLiteral("description")) && !overview.isEmpty())
                job->fields.insert(QStringLiteral("description"), QString(overview).replace(QLatin1String("\r\n"), QLatin1String("\n")));
            const QString release = best.value(QStringLiteral("release_date")).toString();
            if (job->wants(QStringLiteral("release")) && QDate::fromString(release, Qt::ISODate).isValid())
                job->fields.insert(QStringLiteral("release"), release);
            const int players = best.value(QStringLiteral("players")).toInt(0);
            if (players > 1 && (job->force || (job->game && job->game->playerCount() <= 1)))
                job->fields.insert(QStringLiteral("players"), players);

            // front box art
            const QJsonObject boxart = root.value(QStringLiteral("include")).toObject().value(QStringLiteral("boxart")).toObject();
            const QString base = boxart.value(QStringLiteral("base_url")).toObject().value(QStringLiteral("large")).toString();
            const QJsonArray images = boxart.value(QStringLiteral("data")).toObject()
                .value(QString::number(best.value(QStringLiteral("id")).toInt())).toArray();
            for (const QJsonValue& img : images) {
                const QJsonObject image = img.toObject();
                if (image.value(QStringLiteral("side")).toString() == QLatin1String("front")) {
                    job->addDownload(QStringLiteral("boxFront"), base + image.value(QStringLiteral("filename")).toString());
                    break;
                }
            }

            // developer / publisher / genre come as ids; names are resolved in stepTheGamesDbNames
            for (const char* list : { "developers", "publishers", "genres" }) {
                QList<int> ids;
                for (const QJsonValue& id : best.value(QLatin1String(list)).toArray())
                    ids << id.toInt();
                job->tgdb_ids.insert(QLatin1String(list), ids);
            }
        }
        stepTheGamesDbNames(0);
    });
}

// TheGamesDB name lists (one lookup each, cached in <config>/deckos/thegamesdb_names.json)
void Scraper::stepTheGamesDbNames(int index)
{
    struct List { const char* key; const char* endpoint; const char* field; };
    static const List LISTS[] = {
        { "developers", "Developers", "developer" },
        { "publishers", "Publishers", "publisher" },
        { "genres", "Genres", "genre" },
    };
    constexpr int LIST_COUNT = sizeof(LISTS) / sizeof(LISTS[0]);

    Job* const job = m_current;
    for (; index < LIST_COUNT; index++) {
        const List& list = LISTS[index];
        const QString key = QLatin1String(list.key);
        if (!job->wants(QLatin1String(list.field)) || job->tgdb_ids.value(key).isEmpty())
            continue;

        if (m_tgdb_names.value(key).isEmpty() && !m_tgdb_names_tried.contains(key) && m_tgdb_allowance != 0) {
            m_tgdb_names_tried.insert(key);
            QUrlQuery query;
            query.addQueryItem(QStringLiteral("apikey"), m_tgdb_key);
            QUrl url(QStringLiteral("https://api.thegamesdb.net/v1/") + QLatin1String(list.endpoint));
            url.setQuery(query);
            whenDone(get(url.toString()), [this, index, key](QNetworkReply* reply) {
                const QJsonObject items = QJsonDocument::fromJson(reply->readAll()).object()
                    .value(QStringLiteral("data")).toObject().value(key).toObject();
                QHash<int, QString>& names = m_tgdb_names[key];
                for (auto it = items.begin(); it != items.end(); ++it)
                    names.insert(it.key().toInt(), it.value().toObject().value(QStringLiteral("name")).toString());
                if (!names.isEmpty())
                    saveTheGamesDbNames();
                stepTheGamesDbNames(index); // now resolvable
            });
            return;
        }

        QJsonArray resolved;
        for (const int id : job->tgdb_ids.value(key)) {
            const QString name = m_tgdb_names.value(key).value(id);
            if (!name.isEmpty())
                resolved.append(name);
        }
        if (!resolved.isEmpty())
            job->fields.insert(QLatin1String(list.field), resolved);
    }
    stepSteamGridDbSearch();
}

void Scraper::loadTheGamesDbNames()
{
    QFile file(paths::writableConfigDir() + QStringLiteral("/deckos/thegamesdb_names.json"));
    if (!file.open(QIODevice::ReadOnly))
        return;
    const QJsonObject root = QJsonDocument::fromJson(file.readAll()).object();
    for (auto list = root.begin(); list != root.end(); ++list) {
        const QJsonObject items = list.value().toObject();
        QHash<int, QString>& names = m_tgdb_names[list.key()];
        for (auto it = items.begin(); it != items.end(); ++it)
            names.insert(it.key().toInt(), it.value().toString());
    }
}

void Scraper::saveTheGamesDbNames() const
{
    QJsonObject root;
    for (auto list = m_tgdb_names.cbegin(); list != m_tgdb_names.cend(); ++list) {
        QJsonObject items;
        for (auto it = list.value().cbegin(); it != list.value().cend(); ++it)
            items.insert(QString::number(it.key()), it.value());
        root.insert(list.key(), items);
    }
    const QString path = paths::writableConfigDir() + QStringLiteral("/deckos/thegamesdb_names.json");
    QDir().mkpath(QFileInfo(path).absolutePath());
    QSaveFile file(path);
    if (file.open(QIODevice::WriteOnly)) {
        file.write(QJsonDocument(root).toJson(QJsonDocument::Compact));
        file.commit();
    }
}


// --- 2. SteamGridDB ---------------------------------------------------------------------------------

void Scraper::stepSteamGridDbSearch()
{
    Job* const job = m_current;
    const bool useful = job->wants(QStringLiteral("poster")) || job->wants(QStringLiteral("steam"))
                     || job->wants(QStringLiteral("background")) || job->wants(QStringLiteral("logo"));
    if (m_sgdb_key.isEmpty() || !useful) {
        stepLibretro();
        return;
    }
    setStatus(tr("Finding artwork for %1").arg(job->title));

    const QString url = QStringLiteral("https://www.steamgriddb.com/api/v2/search/autocomplete/")
                      + QString::fromUtf8(QUrl::toPercentEncoding(job->search));
    whenDone(get(url, true), [this](QNetworkReply* reply) {
        Job* const job = m_current;
        if (reply->error() != QNetworkReply::NoError) {
            Log::warning(LOGTAG, LOGMSG("SteamGridDB: %1 for %2").arg(reply->errorString(), job->title));
            stepLibretro();
            return;
        }
        const QJsonArray results = QJsonDocument::fromJson(reply->readAll()).object().value(QStringLiteral("data")).toArray();
        const QString wanted = normalized(job->search);
        int game_id = 0;
        for (const QJsonValue& val : results) {
            const QJsonObject result = val.toObject();
            if (normalized(result.value(QStringLiteral("name")).toString()) == wanted) {
                game_id = result.value(QStringLiteral("id")).toInt();
                break;
            }
        }
        if (game_id == 0 && !results.isEmpty())
            game_id = results.first().toObject().value(QStringLiteral("id")).toInt();

        if (game_id == 0) {
            stepLibretro();
            return;
        }
        job->sources << QStringLiteral("SteamGridDB");
        stepSteamGridDbAssets(game_id, 0);
    });
}

void Scraper::stepSteamGridDbAssets(int game_id, int step)
{
    struct Kind { const char* asset; const char* path; const char* extra; };
    static const Kind KINDS[] = {
        { "poster", "grids", "&dimensions=600x900" },
        { "steam", "grids", "&dimensions=920x430,460x215" },
        { "background", "heroes", "" },
        { "logo", "logos", "" },
    };
    constexpr int KIND_COUNT = sizeof(KINDS) / sizeof(KINDS[0]);

    Job* const job = m_current;
    while (step < KIND_COUNT && !job->wants(QLatin1String(KINDS[step].asset)))
        step++;
    if (step >= KIND_COUNT) {
        stepLibretro();
        return;
    }

    const Kind& kind = KINDS[step];
    const QString url = QStringLiteral("https://www.steamgriddb.com/api/v2/%1/game/%2?types=static&nsfw=false&humor=false%3")
        .arg(QLatin1String(kind.path)).arg(game_id).arg(QLatin1String(kind.extra));
    whenDone(get(url, true), [this, game_id, step, kind](QNetworkReply* reply) {
        Job* const job = m_current;
        if (reply->error() == QNetworkReply::NoError) {
            const QJsonArray items = QJsonDocument::fromJson(reply->readAll()).object().value(QStringLiteral("data")).toArray();
            if (!items.isEmpty())
                job->addDownload(QLatin1String(kind.asset), items.first().toObject().value(QStringLiteral("url")).toString());
        }
        stepSteamGridDbAssets(game_id, step + 1);
    });
}


// --- 3. libretro-thumbnails -------------------------------------------------------------------------

void Scraper::stepLibretro()
{
    Job* const job = m_current;
    const char* const folder = systems().value(job->system, { 0, nullptr }).libretro;
    if (m_libretro && folder && !job->rom_name.isEmpty()) {
        // thumbnails.libretro.com served an empty index on 2026-11-25; the same files are on GitHub,
        // one repo per system (spaces -> underscores), verified 2026-11-25
        const QString base = QStringLiteral("https://raw.githubusercontent.com/libretro-thumbnails/")
            + QString(QLatin1String(folder)).replace(QLatin1Char(' '), QLatin1Char('_')) + QStringLiteral("/master/");
        const QString file = QString::fromUtf8(QUrl::toPercentEncoding(libretro_name(job->rom_name))) + QStringLiteral(".png");
        job->addDownload(QStringLiteral("boxFront"), base + QStringLiteral("Named_Boxarts/") + file);
        job->addDownload(QStringLiteral("screenshot"), base + QStringLiteral("Named_Snaps/") + file);
        job->addDownload(QStringLiteral("titlescreen"), base + QStringLiteral("Named_Titles/") + file);
    }
    job->download_index = 0;
    stepDownload();
}


// --- 4. downloads -----------------------------------------------------------------------------------

void Scraper::stepDownload()
{
    Job* const job = m_current;
    if (job->download_index >= job->downloads.size()) {
        const bool ok = !job->saved_assets.isEmpty() || !job->fields.isEmpty();
        finishJob(ok, ok ? tr("Found %1").arg(job->sources.isEmpty() ? QStringLiteral("artwork") : job->sources.join(QStringLiteral(", ")))
                         : tr("Nothing found"));
        return;
    }

    const auto& download = job->downloads.at(job->download_index);
    setStatus(tr("Downloading %1 (%2)").arg(job->title, download.first));
    whenDone(get(download.second), [this](QNetworkReply* reply) {
        Job* const job = m_current;
        const QString asset = job->downloads.at(job->download_index).first;
        const QByteArray data = reply->readAll();
        if (reply->error() == QNetworkReply::NoError && looks_like_image(data)) {
            const QString dir = GameOverrides::mediaDir() + QLatin1Char('/')
                + safe_dir_name(job->system.isEmpty() ? QStringLiteral("other") : job->system) + QLatin1Char('/')
                + safe_dir_name(job->rom_name.isEmpty() ? job->title : job->rom_name);
            QDir().mkpath(dir);
            // old files of this asset go; a new name per download so image caches show the new one
            for (const QFileInfo& old : QDir(dir).entryInfoList({ asset + QStringLiteral("-*") }, QDir::Files))
                QFile::remove(old.absoluteFilePath());
            const QString path = dir + QLatin1Char('/') + asset + QLatin1Char('-')
                + QString::number(QDateTime::currentSecsSinceEpoch()) + QLatin1Char('.') + file_extension(reply);
            QSaveFile file(path);
            if (file.open(QIODevice::WriteOnly) && file.write(data) == data.size() && file.commit()) {
                job->saved_assets.insert(asset, QUrl::fromLocalFile(path).toString());
                if (reply->url().toString().contains(QLatin1String("libretro-thumbnails")) && !job->sources.contains(QStringLiteral("libretro")))
                    job->sources << QStringLiteral("libretro");
            }
            else {
                Log::warning(LOGTAG, LOGMSG("Could not save `%1`").arg(path));
            }
        }
        job->download_index++;
        stepDownload();
    });
}

} // namespace deckos
