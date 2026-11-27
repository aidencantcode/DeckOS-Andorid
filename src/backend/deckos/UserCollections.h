// DeckOS
// The user's collections (`deckos.collections`): games put into a collection from the game page
// (options > Add to collection...), into one the library already has (a system, a metadata file's
// collection, Android) or a new one named there. Like Pegasus's favorites, a list next to the library,
// not in it: <config>/deckos/collections.json, one entry per collection with the games' keys
// (GameOverrides::keyFor). Games not found right now (SD card out) stay in the file.
//
// After every scan or cache restore, apply() adds them before the games reach the theme - after the
// game index cache is saved, so it never holds them. A game's own collections stay first: DeckOS takes
// the first one as the game's system (artwork folder, scraper, RetroAchievements, the play-time card).
// While DeckOS runs, add()/remove() change the models in place - no library reload.

#pragma once

#include <QMap>
#include <QMutex>
#include <QObject>
#include <QPointer>
#include <QSet>
#include <QString>
#include <QStringList>
#include <QVariantList>
#include <vector>

namespace model { class ApiObject; class Collection; class Game; }


namespace deckos {

class UserCollections : public QObject {
    Q_OBJECT
    /// DECKOS: collection icons (Library > Collections > X > Properties): a picture of the user's shown
    /// instead of the dynamic collage of the games' covers. By collection name in lower case:
    /// { source: file URL, fit: shown whole (an icon or logo) rather than filling the tile, custom: in use }.
    /// Switching back to the dynamic icon keeps the picture, so it can be switched on again.
    Q_PROPERTY(QVariantMap icons READ icons NOTIFY iconsChanged)

public:
    explicit UserCollections(model::ApiObject* api, QObject* parent = nullptr);
    UserCollections(model::ApiObject* api, QString path, QObject* parent = nullptr);

    static QString defaultPath();

    /// after a scan, before ApiObject::setGameData: the user's collections joined in (new ones made,
    /// existing ones extended), renamed ones renamed, hidden ones taken out of `collections` (their games
    /// keep them), `collections` kept sorted
    void apply(std::vector<model::Collection*>& collections, const std::vector<model::Game*>& games);

    /// Settings > Collections: every collection, hidden ones too, by name: { name, count, hidden,
    /// shortName (a ROM-folder collection's system id), user (made in DeckOS, not by the library) }
    Q_INVOKABLE QVariantList allCollections() const;
    /// hides a collection from the Library and the pickers (its games stay where they are), or shows it again
    Q_INVOKABLE bool setHidden(const QString& name, bool hidden);
    /// a new name, kept across scans; "" when done, else what's wrong. A ROM-folder collection keeps its
    /// system (the short name doesn't change)
    Q_INVOKABLE QString rename(const QString& name, const QString& newName);

    /// every collection for the picker, by name: { name, member (the game is in it), mine (put there by
    /// the user, so it can be taken out), count (games in it) }
    Q_INVOKABLE QVariantList forGame(QObject* game) const;
    /// puts the game into the collection called so: an existing one (any case) or a new one.
    /// "" when done, else what's wrong, to show
    Q_INVOKABLE QString add(QObject* game, const QString& name);
    /// takes it out again, if the user put it there; an emptied collection goes away
    Q_INVOKABLE bool remove(QObject* game, const QString& name);
    /// the collection already called so (any case), "" if none - for "New collection" as it's typed
    Q_INVOKABLE QString existingName(const QString& name) const;

    /// the collection's custom icon is this picture (a file path or file URL; copied into iconsDir() unless
    /// it is there already) and is used. "" when done, else what's wrong
    Q_INVOKABLE QString setIcon(const QString& name, const QString& path, bool fit);
    /// custom picture (if it has one) or the dynamic collage
    Q_INVOKABLE void setCustomIcon(const QString& name, bool custom);
    QVariantMap icons() const;
    /// <config>/deckos/collection-icons
    static QString iconsDir();

    static constexpr int MAX_NAME = 60;

signals:
    /// a game's collections changed (picker rows, game page)
    void changed(QObject* game);
    /// a collection was hidden, shown or renamed (Settings > Collections)
    void listChanged();
    void iconsChanged();

private:
    struct Entry {
        QString name;
        QStringList keys;
    };
    struct Icon {
        QString file;     // absolute path
        bool fit = false;
        bool custom = true;
        Icon() = default;
        Icon(QString f, bool fi, bool c) : file(std::move(f)), fit(fi), custom(c) {}
    };
    QMap<QString, Icon> m_icons; // by collection name, lower case

    model::ApiObject* const m_api;
    const QString m_path;
    std::vector<Entry> m_entries;
    QStringList m_hidden_names;                         // saved
    QMap<QString, QString> m_renames;                   // a library collection's own name -> the user's
    std::vector<QPointer<model::Collection>> m_hidden;  // the hidden ones since the last apply()
    QSet<QString> m_library_names;                      // the library's own names (lower case), last apply()
    /// apply() runs on the scan's thread (Backend::onScanFinished), the rest on the UI thread
    mutable QMutex m_lock;

    void load();
    bool save() const;
    Entry* entry(const QString& name);
    const Entry* entry(const QString& name) const;
    model::Collection* collection(const QString& name) const;
    model::Collection* hiddenCollection(const QString& name) const; // takes m_lock
    QString originalName(const QString& name) const;                // m_lock held; "" = made in DeckOS
};

} // namespace deckos
