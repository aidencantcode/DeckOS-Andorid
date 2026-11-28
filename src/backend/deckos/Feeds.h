// DeckOS
// What's New and Friends content from the web (`deckos.feeds` in QML):
// - news: RSS / Atom feeds (Retro Handhelds, RetroAchievements news, GameSpot by default);
// - videos: YouTube channels' public video feeds (Joey's Retro Handhelds, Retro Game Corps, ...) - no API
//   key, the same feed any podcast app reads;
// - RetroAchievements, with the account from Settings › Profile: newly released achievement sets (completed
//   set claims), the community's latest masteries and beaten games, the Achievement of the Week, and the
//   users you follow with what they're playing (their rich presence) for the Friends tab;
// - Discord friends through Lanyard (api.lanyard.rest): the presence of people who joined Lanyard's
//   Discord server, by their Discord user id. Discord itself offers no way to read a friends list
//   without a user token, which its terms forbid (it can get the account banned), so DeckOS doesn't.
//
// The sources are listed in `<DeckOS folder>/feeds.json`, written with the defaults on first use and read
// again at every refresh - add or remove channels and feeds there. Everything fetched is kept in
// `<config>/deckos/feeds-cache.json`, so What's New shows the last content at once and offline.
// Refreshes: news and videos every 30 min, RA sets every 6 h, community every 15 min, friends every
// 2 min while the Friends tab is shown. One request at a time per source, never in a loop on failure.

#pragma once

#include <QDateTime>
#include <QHash>
#include <QJsonObject>
#include <QObject>
#include <QPointer>
#include <QVariantList>

namespace model { class ApiObject; }
class QNetworkAccessManager;
class QNetworkReply;
class QTimer;


namespace deckos {

class Feeds : public QObject {
    Q_OBJECT
    /// news items, newest first: { kind: "news", source, title, link, date (ms), image, summary }
    Q_PROPERTY(QVariantList news READ news NOTIFY newsChanged)
    /// videos, newest first: { kind: "video", source, title, link, videoId, date, image, summary }
    Q_PROPERTY(QVariantList videos READ videos NOTIFY videosChanged)
    /// RetroAchievements sets released lately: { kind: "raset", gameId, title, console, icon, date, link, author, revision }
    Q_PROPERTY(QVariantList raSets READ raSets NOTIFY raChanged)
    /// the community's latest awards: { kind: "raaward", user, userPic, award, gameId, title, console, date, link }
    Q_PROPERTY(QVariantList raCommunity READ raCommunity NOTIFY raChanged)
    /// the Achievement of the Week: { title, description, points, gameId, game, console, icon, players, unlocks, link } or {}
    Q_PROPERTY(QVariantMap raWeekly READ raWeekly NOTIFY raChanged)
    /// RetroAchievements users you follow: { user, userPic, online, presence, game, console, gameIcon, seen (ms), link }
    Q_PROPERTY(QVariantList raFriends READ raFriends NOTIFY friendsChanged)
    /// Discord friends (Lanyard): { id, name, avatar, status: online/idle/dnd/offline, activity, details, image, spotify }
    Q_PROPERTY(QVariantList discordFriends READ discordFriends NOTIFY friendsChanged)
    /// the Discord ids listed in feeds.json (for Settings / the Friends tab's hint)
    Q_PROPERTY(QStringList discordIds READ discordIds NOTIFY sourcesChanged)
    /// a RetroAchievements account is set (Settings › Profile)
    Q_PROPERTY(bool raSignedIn READ raSignedIn NOTIFY sourcesChanged)
    /// any request running
    Q_PROPERTY(bool loading READ loading NOTIFY loadingChanged)
    /// the newest fetch that worked, ms since epoch (0: only cached content so far)
    Q_PROPERTY(qint64 updated READ updated NOTIFY loadingChanged)
    /// the last failure, for a quiet "Offline - showing saved news" line ("" when fine)
    Q_PROPERTY(QString error READ error NOTIFY loadingChanged)
    /// where the sources live (shown in Settings)
    Q_PROPERTY(QString sourcesFile READ sourcesFile NOTIFY sourcesChanged)

public:
    explicit Feeds(model::ApiObject* api, QObject* parent = nullptr);
    ~Feeds() override;

    QVariantList news() const { return m_news; }
    QVariantList videos() const { return m_videos; }
    QVariantList raSets() const { return m_ra_sets; }
    QVariantList raCommunity() const { return m_ra_community; }
    QVariantMap raWeekly() const { return m_ra_weekly; }
    QVariantList raFriends() const { return m_ra_friends; }
    QVariantList discordFriends() const { return m_discord; }
    QStringList discordIds() const { return m_discord_ids; }
    bool raSignedIn() const;
    bool loading() const { return m_running > 0; }
    qint64 updated() const { return m_updated; }
    QString error() const { return m_error; }
    QString sourcesFile() const;

    /// fetches what is due (force: everything now)
    Q_INVOKABLE void refresh(bool force = false);
    /// the Friends tab is on screen: friends are kept fresh (every 2 min), else not polled
    Q_INVOKABLE void watchFriends(bool on);
    /// adds / removes a Discord user id (17-20 digits) in feeds.json; false if it isn't one
    Q_INVOKABLE bool addDiscordId(const QString& id);
    Q_INVOKABLE void removeDiscordId(const QString& id);
    /// opens the sources file's folder / the file in a text editor (PC: the file manager)
    Q_INVOKABLE void openSourcesFile();

signals:
    void newsChanged();
    void videosChanged();
    void raChanged();
    void friendsChanged();
    void sourcesChanged();
    void loadingChanged();

private:
    struct Source {
        QString id;
        QString name;
        QString url;
        bool video = false;
        Source() {}
        Source(QString i, QString n, QString u, bool v) : id(std::move(i)), name(std::move(n)), url(std::move(u)), video(v) {}
    };

    model::ApiObject* const m_api;
    QNetworkAccessManager* const m_net;
    QTimer* const m_timer;          // every minute: anything due?
    QTimer* const m_friends_timer;  // while the Friends tab is shown
    QTimer* const m_save_timer;     // writes the cache a moment after changes

    QList<Source> m_sources;
    QStringList m_discord_ids;
    QHash<QString, QVariantList> m_items;   // per source id
    QHash<QString, qint64> m_fetched;       // per source / "ra.sets" ...: ms since epoch of the last try
    QVariantList m_news, m_videos, m_ra_sets, m_ra_community, m_ra_friends, m_discord;
    QVariantMap m_ra_weekly;
    int m_running = 0;
    qint64 m_updated = 0;
    QString m_error;
    bool m_watch_friends = false;
    QStringList m_friend_queue;             // RA users whose summary is still to fetch
    QVariantList m_friends_building;

    void loadSources();
    void loadCache();
    void saveCache();
    void rebuildMerged();

    bool due(const QString& key, qint64 everyMs, bool force) const;
    QNetworkReply* get(const QUrl& url);
    void begin();
    void finish(QNetworkReply* reply, const QString& failure);

    void fetchSource(const Source& s);
    void fetchRaSets();
    void fetchRaCommunity();
    void fetchRaWeekly();
    void fetchRaFriends();
    void fetchNextFriend();
    void fetchDiscord();

    QString raUser() const;
    QString raKey() const;
    QUrl raUrl(const QString& endpoint, const QList<QPair<QString, QString>>& query) const;

public:
    /// parsing (public for the tests): RSS 2.0 and Atom (YouTube's feeds are Atom)
    static QVariantList parseFeed(const QByteArray& xml, const QString& sourceName, bool video);
    /// tags gone, entities decoded; paragraphs: blank lines between paragraphs instead of one long line
    static QString plainText(const QString& html, int maxLength, bool paragraphs = false);
    static QString firstImage(const QString& html);
};

} // namespace deckos
