// DeckOS
// Per-game changes made inside DeckOS - names and descriptions edited in Properties, and everything the
// scraper found (description, release date, artwork files...). They are applied over whatever the
// metadata sources (metadata.pegasus.txt etc.) say, every time the library loads, and live when they
// change. Stored in <config>/deckos/game_overrides.json, keyed by the game's first file.

#pragma once

#include <QJsonObject>
#include <QMutex>
#include <QString>
#include <QStringList>

namespace model { class Game; }


namespace deckos {

class GameOverrides {
public:
    static GameOverrides& instance();
    /// a store backed by another file (tests); the app uses instance()
    explicit GameOverrides(QString path);

    /// "file:<absolute path>" or "uri:<uri>" of the game's first file; empty if the game has no file
    static QString keyFor(const model::Game&);
    /// <config>/deckos/media - where scraped artwork is saved
    static QString mediaDir();

    QJsonObject entry(const QString& key) const;
    QStringList keys() const;
    /// merges `fields` into the entry (a null value removes that field) and saves
    void update(const QString& key, const QJsonObject& fields);
    /// forgets every change made to this game and saves
    void remove(const QString& key);
    /// re-reads the file (done by the provider before every library load)
    void reload();

    /// Applies an entry to a game. With `live`, change signals are emitted so the UI updates.
    /// The values the game had before the first override are kept in game.extra (deckos_original_*),
    /// so restore() can put them back without reloading the library.
    static void apply(model::Game&, const QJsonObject& entry, bool live);
    static void restore(model::Game&);

    /// asset names used in entries ("boxFront", "logo", ...) - the same names themes use
    static QStringList assetNames();

private:
    void load_locked();
    void save_locked() const;

    mutable QMutex m_lock;
    QString m_path;
    QJsonObject m_data;
};

} // namespace deckos
