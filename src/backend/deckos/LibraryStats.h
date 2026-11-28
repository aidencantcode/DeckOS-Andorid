// DeckOS
// The library's own shelves for Home's What's New and Recommended tabs (`deckos.stats` in QML):
// recently played, most played, the best game of the week (play time in the last 7 days, from Pegasus's
// play history - every session is kept with its start time in stats.db), games never played (picked
// fresh each day), and systems with their game counts. Lists of Game objects, ready for the theme.
// Recomputed when the library reloads and after each game session (changed()).

#pragma once

#include <QObject>
#include <QVariantList>

namespace model { class ApiObject; class Game; }
class QTimer;


namespace deckos {

class LibraryStats : public QObject {
    Q_OBJECT
    /// bumps on every change: bind to it (e.g. `deckos.stats.revision >= 0 && deckos.stats.mostPlayed(10)`)
    Q_PROPERTY(int revision READ revision NOTIFY changed)

public:
    explicit LibraryStats(model::ApiObject* api, QObject* parent = nullptr);

    int revision() const { return m_revision; }

    /// played games, newest first (Game objects)
    Q_INVOKABLE QVariantList recentlyPlayed(int count) const;
    /// by total play time
    Q_INVOKABLE QVariantList mostPlayed(int count) const;
    /// the last 7 days: { game, seconds, sessions }, most played first
    Q_INVOKABLE QVariantList weekBest(int count) const;
    /// never played, with artwork, a different pick every day (Game objects)
    Q_INVOKABLE QVariantList unplayed(int count) const;
    /// games of the same systems as the most recently played one, never played (Game objects)
    Q_INVOKABLE QVariantList becauseYouPlayed(int count) const;
    /// { name, shortName, count, game (a Game with artwork, for the picture) } per system, biggest first
    Q_INVOKABLE QVariantList systems(int count) const;
    /// total play time this week, seconds
    Q_INVOKABLE int weekSeconds() const;

    /// the library was (re)loaded / a session ended
    void invalidate();

signals:
    void changed();

private:
    model::ApiObject* const m_api;
    QTimer* const m_delay;
    int m_revision = 0;
    mutable qint64 m_week_cached_at = 0;
    mutable QVariantList m_week_cache;

    QVariantList readWeek() const;
};

} // namespace deckos
