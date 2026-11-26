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

    mutable QMutex m_lock;
    QString m_path;
    QJsonObject m_data;
};

} // namespace deckos
