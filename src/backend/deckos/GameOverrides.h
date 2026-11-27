// DeckOS
// Per-game changes made inside DeckOS - names and descriptions edited in Properties, everything the
// scraper found (description, release date, artwork files...) and the artwork the user picked. They are
// applied over whatever the metadata sources (metadata.pegasus.txt etc.) say, every time the library
// loads, and live when they change. Stored in <config>/deckos/game_overrides.json, keyed by the game's
// first file. In an entry, "assets" is what the scraper saved and "custom" what the user picked
// (Properties > Customization): custom wins, and a scrape never touches it.
//
// Artwork files live in <media>/<system>/<rom name>/, named after what they are (fileStem): hero.png,
// logo.png, capsule.png, wide-capsule.png, boxart.jpg, screenshot-01.png..., and custom-hero.png etc.
// for the user's own. <media> is <DeckOS folder>/media once one is picked (MediaLibrary).

#pragma once

#include <QHash>
#include <QJsonObject>
#include <QMutex>
#include <QSet>
#include <QString>
#include <QStringList>

#include <vector>

namespace model { class Game; }


namespace deckos {

class GameOverrides {
public:
    static GameOverrides& instance();
    /// a store backed by another file (tests); the app uses instance()
    explicit GameOverrides(QString path);

    /// "file:<absolute path>" or "uri:<uri>" of the game's first file; empty if the game has no file
    static QString keyFor(const model::Game&);
    /// where artwork is saved: <DeckOS folder>/media once one is picked, else legacyMediaDir()
    static QString mediaDir();
    /// MediaLibrary, at start and when the DeckOS folder changes (empty: legacyMediaDir())
    static void setMediaDir(const QString& dir);
    /// <config>/deckos/media - where scraped artwork went before the DeckOS folder
    static QString legacyMediaDir();
    /// a file DeckOS saved itself (scraped or picked by the user), in either media folder
    static bool isOwnMedia(const QString& uri);
    /// <media>/<system>/<name>/ ("other" without a system; `name` is the ROM file's name without
    /// its extension, else the title)
    static QString gameMediaDir(const QString& system, const QString& name);
    static QString gameMediaDir(const model::Game&);
    /// a file's name for an asset: "background" -> "hero", "poster" -> "capsule", "steam" ->
    /// "wide-capsule", "boxFront" -> "boxart", "video" -> "trailer"; others keep their name
    static QString fileStem(const QString& asset);
    /// only characters that are safe in a folder name on every file system
    static QString safeName(QString name);

    QJsonObject entry(const QString& key) const;
    QStringList keys() const;
    /// merges `fields` into the entry (a null value removes that field) and saves
    void update(const QString& key, const QJsonObject& fields);
    /// update() for many games at once, saved once (key -> fields)
    void updateAll(const QHash<QString, QJsonObject>& changes);
    /// forgets every change made to this game and saves
    void remove(const QString& key);
    /// re-reads the file (done by the provider before every library load)
    void reload();
    /// DECKOS: the keys changed since the last reload() - a scrape or pick that finished while the library
    /// was loading reached the old game objects only; DeckosApi applies them to the new ones (and clears)
    QStringList takeChangedSinceReload();

    /// DECKOS: each game's record next to its artwork, <media>/<system>/<rom>/game.txt, Pegasus-style
    /// "key: value" text: its scraped and edited info and its artwork's file names (relative to that
    /// folder). Written whenever an entry with DeckOS artwork changes; read back (readRecord) when a game
    /// has no entry - DeckOS's own list was lost, or the game's path changed (another form of the same
    /// folder, a folder added again) - so its artwork and info are never lost with the list.
    static QString recordName() { return QStringLiteral("game.txt"); }
    /// an entry from a record (artwork as file URIs in the record's folder); `file` gets the game file
    /// path it was written for. Empty if there is no readable record.
    static QJsonObject readRecord(const QString& record_path, QString* file = nullptr);
    /// writes the records of every entry that has artwork; once per media folder (marker file), so
    /// libraries scraped before records existed get theirs
    void writeAllRecords();
    /// key -> game for a list of games (keyFor each)
    static QHash<QString, model::Game*> gamesByKey(const std::vector<model::Game*>& games);

    /// Applies an entry to a game. With `live`, change signals are emitted so the UI updates.
    /// The values the game had before the first override are kept in game.extra (deckos_original_*),
    /// so restore() can put them back without reloading the library.
    static void apply(model::Game&, const QJsonObject& entry, bool live);
    static void restore(model::Game&);
    /// takes every file of DeckOS's (isOwnMedia) off the game's artwork; the entry puts back what's
    /// current. A library restored from the game index cache otherwise keeps addresses of files that
    /// were moved into the DeckOS folder or renamed since (0.1.1)
    static void dropOwnMedia(model::Game&);

    /// asset names used in entries ("boxFront", "logo", ...) - the same names themes use
    static QStringList assetNames();
    /// one of assetNames() as the asset type (AssetType::UNKNOWN for others)
    static int assetType(const QString& name);

private:
    void load_locked();
    void save_locked() const;
    void merge_locked(const QString& key, const QJsonObject& fields);
    /// the folder holding the entry's own artwork, "" if it has none
    static QString recordDir(const QJsonObject& entry);
    void writeRecord_locked(const QString& key) const;

    mutable QMutex m_lock;
    QString m_path;
    QJsonObject m_data;
    QSet<QString> m_changed;
};

} // namespace deckos
