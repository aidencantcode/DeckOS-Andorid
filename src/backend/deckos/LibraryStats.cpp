// DeckOS
// See LibraryStats.h

#include "LibraryStats.h"

#include "Log.h"
#include "Paths.h"
#include "model/Api.h"
#include "model/gaming/Assets.h"
#include "model/gaming/Collection.h"
#include "model/gaming/Game.h"
#include "model/gaming/GameFile.h"
#include "utils/PathTools.h"

#include <QCryptographicHash>
#include <QDate>
#include <QDateTime>
#include <QFileInfo>
#include <QHash>
#include <QSqlDatabase>
#include <QSqlQuery>
#include <QTimer>

#include <algorithm>


namespace {
QVariant obj(model::Game* g) { return QVariant::fromValue(static_cast<QObject*>(g)); }

bool has_wide_art(const model::Game* g)
{
    const model::Assets& a = g->assets();
    return !a.background().isEmpty() || !a.steam().isEmpty() || !a.screenshot().isEmpty() || !a.titlescreen().isEmpty();
}

bool has_any_art(const model::Game* g)
{
    const model::Assets& a = g->assets();
    return has_wide_art(g) || !a.poster().isEmpty() || !a.boxFront().isEmpty();
}

/// the same order all day, a new one tomorrow
quint32 daily_rank(const model::Game* g)
{
    const QByteArray key = g->title().toUtf8() + QByteArray::number(QDate::currentDate().toJulianDay());
    const QByteArray h = QCryptographicHash::hash(key, QCryptographicHash::Md5);
    return (quint32(uchar(h[0])) << 24) | (quint32(uchar(h[1])) << 16) | (quint32(uchar(h[2])) << 8) | quint32(uchar(h[3]));
}
} // namespace


namespace deckos {

LibraryStats::LibraryStats(model::ApiObject* api, QObject* parent)
    : QObject(parent)
    , m_api(api)
    , m_delay(new QTimer(this))
{
    // play time is written a moment after a session ends: read after that
    m_delay->setSingleShot(true);
    m_delay->setInterval(1500);
    connect(m_delay, &QTimer::timeout, this, [this]() {
        m_week_cached_at = 0;
        ++m_revision;
        emit changed();
    });
}

void LibraryStats::invalidate()
{
    m_delay->start();
}

QVariantList LibraryStats::recentlyPlayed(int count) const
{
    std::vector<model::Game*> games;
    for (model::Game* g : m_api->allGames()->entries())
        if (g->lastPlayed().isValid())
            games.push_back(g);
    std::sort(games.begin(), games.end(), [](const model::Game* a, const model::Game* b) { return a->lastPlayed() > b->lastPlayed(); });
    QVariantList out;
    for (model::Game* g : games) {
        if (out.size() >= count) break;
        out.append(obj(g));
    }
    return out;
}

QVariantList LibraryStats::mostPlayed(int count) const
{
    std::vector<model::Game*> games;
    for (model::Game* g : m_api->allGames()->entries())
        if (g->playTime() > 0)
            games.push_back(g);
    std::sort(games.begin(), games.end(), [](const model::Game* a, const model::Game* b) { return a->playTime() > b->playTime(); });
    QVariantList out;
    for (model::Game* g : games) {
        if (out.size() >= count) break;
        out.append(obj(g));
    }
    return out;
}

QVariantList LibraryStats::readWeek() const
{
    // Pegasus's play history: one row per session (start, seconds), by the game file's path or URI.
    // Its own connection, read-only: the play-time writer uses the default one on a worker thread.
    QHash<QString, QPair<qint64, int>> per_key; // seconds, sessions
    const QString db_path = paths::writableConfigDir() + QStringLiteral("/stats.db");
    if (!QFileInfo::exists(db_path))
        return {};
    const QString conn = QStringLiteral("deckos-stats-week");
    {
        QSqlDatabase db = QSqlDatabase::addDatabase(QStringLiteral("QSQLITE"), conn);
        db.setDatabaseName(db_path);
        db.setConnectOptions(QStringLiteral("QSQLITE_OPEN_READONLY;QSQLITE_BUSY_TIMEOUT=500"));
        if (db.open()) {
            QSqlQuery q(db);
            q.prepare(QStringLiteral(
                "SELECT paths.path, SUM(plays.duration), COUNT(*) FROM plays"
                " INNER JOIN paths ON plays.path_id = paths.id"
                " WHERE plays.start_time >= ? GROUP BY paths.path"));
            q.addBindValue(QDateTime::currentSecsSinceEpoch() - 7 * 24 * 3600);
            if (q.exec()) {
                while (q.next())
                    per_key.insert(q.value(0).toString(), qMakePair(q.value(1).toLongLong(), q.value(2).toInt()));
            }
            else {
                Log::warning(LOGMSG("What's New: couldn't read this week's play time"));
            }
            db.close();
        }
    }
    QSqlDatabase::removeDatabase(conn);
    if (per_key.isEmpty())
        return {};

    // keys -> games (a game's files by their clean path or URI, as PlaytimeStats writes them)
    QHash<model::Game*, QPair<qint64, int>> per_game;
    for (model::Game* g : m_api->allGames()->entries()) {
        for (model::GameFile* f : g->filesModel()->entries()) {
            const QString key = f->uri().isEmpty() ? ::clean_abs_path(f->fileinfo()) : f->uri();
            auto it = per_key.constFind(key);
            if (it == per_key.cend() && !f->uri().isEmpty())
                it = per_key.constFind(::clean_abs_path(f->fileinfo()));
            if (it != per_key.cend()) {
                auto& sum = per_game[g];
                sum.first += it.value().first;
                sum.second += it.value().second;
            }
        }
    }
    typedef std::pair<model::Game*, QPair<qint64, int>> Played;
    std::vector<Played> list;
    for (auto it = per_game.cbegin(); it != per_game.cend(); ++it)
        list.emplace_back(it.key(), it.value());
    std::sort(list.begin(), list.end(), [](const Played& a, const Played& b) { return a.second.first > b.second.first; });
    QVariantList out;
    for (const auto& e : list) {
        if (e.second.first < 60)
            continue; // under a minute: a launch that didn't stick
        QVariantMap m;
        m.insert(QStringLiteral("game"), obj(e.first));
        m.insert(QStringLiteral("seconds"), e.second.first);
        m.insert(QStringLiteral("sessions"), e.second.second);
        out.append(m);
    }
    return out;
}

QVariantList LibraryStats::weekBest(int count) const
{
    const qint64 now = QDateTime::currentMSecsSinceEpoch();
    if (now - m_week_cached_at > 5 * 60 * 1000) { // a fresh look every few minutes at most
        m_week_cache = readWeek();
        m_week_cached_at = now;
    }
    return m_week_cache.mid(0, count);
}

int LibraryStats::weekSeconds() const
{
    qint64 total = 0;
    for (const QVariant& v : weekBest(1000))
        total += v.toMap().value(QStringLiteral("seconds")).toLongLong();
    return int(std::min<qint64>(total, INT_MAX));
}

QVariantList LibraryStats::unplayed(int count) const
{
    std::vector<model::Game*> games;
    for (model::Game* g : m_api->allGames()->entries())
        if (g->playCount() == 0 && !g->lastPlayed().isValid() && has_any_art(g))
            games.push_back(g);
    // the ones with a wide picture first (their 16:9 cards look best), each group in today's order
    std::sort(games.begin(), games.end(), [](const model::Game* a, const model::Game* b) {
        const bool wa = has_wide_art(a), wb = has_wide_art(b);
        if (wa != wb) return wa;
        return daily_rank(a) < daily_rank(b);
    });
    QVariantList out;
    for (model::Game* g : games) {
        if (out.size() >= count) break;
        out.append(obj(g));
    }
    return out;
}

QVariantList LibraryStats::becauseYouPlayed(int count) const
{
    const QVariantList recent = recentlyPlayed(1);
    if (recent.isEmpty())
        return {};
    auto* last = qobject_cast<model::Game*>(recent.first().value<QObject*>());
    if (!last || last->collectionsModel()->entries().empty())
        return {};
    const model::Collection* system = last->collectionsModel()->entries().front();
    std::vector<model::Game*> games;
    for (model::Game* g : system->gameList()->entries())
        if (g != last && g->playCount() == 0 && has_any_art(g))
            games.push_back(g);
    std::sort(games.begin(), games.end(), [](const model::Game* a, const model::Game* b) { return daily_rank(a) < daily_rank(b); });
    QVariantList out;
    for (model::Game* g : games) {
        if (out.size() >= count) break;
        out.append(obj(g));
    }
    return out;
}

QVariantList LibraryStats::systems(int count) const
{
    std::vector<model::Collection*> list(m_api->collections()->entries().begin(), m_api->collections()->entries().end());
    std::sort(list.begin(), list.end(), [](const model::Collection* a, const model::Collection* b) {
        return a->gameList()->entries().size() > b->gameList()->entries().size();
    });
    QVariantList out;
    for (model::Collection* c : list) {
        if (out.size() >= count) break;
        const auto& games = c->gameList()->entries();
        if (games.empty())
            continue;
        // the picture: today's pick among its games with a wide picture, else any with art
        model::Game* pick = nullptr;
        quint32 best = UINT_MAX;
        for (model::Game* g : games) {
            const quint32 r = daily_rank(g) | (has_wide_art(g) ? 0u : 0x80000000u);
            if (has_any_art(g) && r < best) { best = r; pick = g; }
        }
        QVariantMap m;
        m.insert(QStringLiteral("name"), c->name());
        m.insert(QStringLiteral("shortName"), c->shortName());
        m.insert(QStringLiteral("count"), int(games.size()));
        m.insert(QStringLiteral("game"), pick ? obj(pick) : QVariant());
        m.insert(QStringLiteral("collection"), QVariant::fromValue(static_cast<QObject*>(c)));
        out.append(m);
    }
    return out;
}

} // namespace deckos
