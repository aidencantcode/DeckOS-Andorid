// DeckOS
// The built-in system/emulator catalog (catalog/systems.json, converted from NeoStation's GPL-3.0
// catalog by tools/import-neostation-catalog.ps1): which folder names mean which system, which file
// extensions are games, and the Android `am start` arguments of every known emulator.

#pragma once

#include <QHash>
#include <QJsonObject>
#include <QString>
#include <QStringList>
#include <QVector>


namespace deckos {

struct CatalogEmulator {
    QString id;
    QString name;
    QString package;
    QString args;          // `am start` arguments with Pegasus placeholders ({file.path}, {file.uri}...)
    bool isDefault = false;
    bool retroArch = false;
    bool achievements = false;
};

struct CatalogSystem {
    QString id;
    QString name;
    QString shortName;
    QStringList folders;
    QStringList extensions; // lower case, no dot
    /// DECKOS: games that are folders (PS3/PS4/PS5 dumps, Xbox 360 "games on demand"): a folder holding
    /// any of these paths (e.g. "PS3_GAME/USRDIR/EBOOT.BIN") is one game, listed by its folder path
    QStringList gameFolders;
    bool multidisc = false;
    int raConsoleId = 0;
    QVector<CatalogEmulator> emulators;

    const CatalogEmulator* emulator(const QString& emu_id) const;
};

class Catalog {
public:
    static const Catalog& instance();
    /// a catalog read from another file (tests)
    explicit Catalog(const QString& json_path);

    const QVector<CatalogSystem>& systems() const { return m_systems; }
    const CatalogSystem* byId(const QString&) const;
    /// matches a folder name against every system's aliases ("SNES", "Super Nintendo", "snes"...)
    const CatalogSystem* byFolderName(const QString& folder_name) const;

    /// lower case, letters and digits only - how folder names are compared
    static QString normalized(const QString&);

    /// DECKOS: merges another catalog file on top (catalog/deckos-systems.json, written by hand): new
    /// systems are added; for a known id, the fields it has replace (name, shortName, raConsoleId,
    /// multidisc), lists are extended (folders, extensions, gameFolders) and emulators with the same id
    /// replace the catalog's, others are added (an isDefault one becomes the only default)
    void merge(const QString& json_path);

private:
    void addSystem(const QJsonObject&);
    QVector<CatalogSystem> m_systems;
    QHash<QString, int> m_by_id;
    QHash<QString, int> m_by_folder;
};


/// The full `am start ...` command for an emulator. RetroArch core names ("snes9x") become the core's
/// path inside that RetroArch package, as RetroArch needs it.
QString launch_command(const CatalogEmulator&);

} // namespace deckos
