// DeckOS
// ROM folders without any metadata files: the user picks a folder (e.g. /sdcard/ROMs), DeckOS recognises
// its system folders (snes, "Super Nintendo", psx...) with the catalog, lists the games in them and writes
// one Pegasus metadata file per system into <config>/deckos/library/, with a launch command for the
// emulator chosen for that system (auto-picked from the installed ones, changeable, editable).
// Pegasus then loads those files like any other metadata - nothing is written into the ROM folders.
//
// Scans run in the background. Only systems whose game list or command changed get their file rewritten,
// so the game index cache stays valid when nothing changed. Scanning some systems only ("Rescan SNES")
// leaves the other systems' files untouched.

#pragma once

#include <QFutureWatcher>
#include <QHash>
#include <QObject>
#include <QSet>
#include <QStringList>
#include <QVariantList>

#include <map>
#include <vector>


namespace deckos {

class Catalog;
struct CatalogSystem;

struct ScannedSystem {
    QString id;
    QStringList folders;   // where its games were found
    QStringList files;     // absolute paths, sorted
};

/// The scan itself (no Qt event loop needed): exposed for tests.
std::vector<ScannedSystem> scan_rom_folders(const QStringList& rom_roots, const QSet<QString>& only_systems);
std::vector<ScannedSystem> scan_rom_folders(const Catalog&, const QStringList& rom_roots, const QSet<QString>& only_systems);
/// "Chrono Trigger (USA) [!].sfc" -> "Chrono Trigger"; keeps the tags when two games would get the same name
QStringList game_titles(const QStringList& files);


class RomLibrary : public QObject {
    Q_OBJECT
    Q_PROPERTY(QStringList romFolders READ romFolders NOTIFY romFoldersChanged)
    Q_PROPERTY(bool scanning READ scanning NOTIFY scanStateChanged)
    Q_PROPERTY(QString status READ status NOTIFY scanStateChanged)
    /// systems found by the last scans: [{ id, name, games, folders, emulatorId, emulatorName, installed,
    ///  command, customCommand }]
    Q_PROPERTY(QVariantList systems READ systemsList NOTIFY systemsChanged)
    Q_PROPERTY(bool scanOnStart READ scanOnStart WRITE setScanOnStart NOTIFY settingsChanged)

public:
    explicit RomLibrary(QObject* parent = nullptr);
    ~RomLibrary() override;

    Q_INVOKABLE void addRomFolder(const QString& path);
    Q_INVOKABLE void removeRomFolder(const QString& path);
    /// Scans all systems (empty list) or only the given system ids.
    Q_INVOKABLE void scan(const QStringList& systemIds = {});

    /// [{ id, name, installed, isDefault, achievements }] for a system, installed emulators first
    Q_INVOKABLE QVariantList emulatorsFor(const QString& systemId) const;
    Q_INVOKABLE void setEmulator(const QString& systemId, const QString& emulatorId);
    /// a hand-written launch command for the whole system; empty = back to the emulator's
    Q_INVOKABLE void setCustomCommand(const QString& systemId, const QString& command);

    QStringList romFolders() const { return m_rom_folders; }
    bool scanning() const { return m_scanning; }
    const QString& status() const { return m_status; }
    QVariantList systemsList() const;
    bool scanOnStart() const { return m_scan_on_start; }
    void setScanOnStart(bool);

    /// re-reads which emulator apps are installed (Android)
    void refreshEmulators() { refreshInstalled(); emit systemsChanged(); }

    /// <config>/deckos/library - added to the game folders Pegasus reads
    static QString libraryDir();

signals:
    void romFoldersChanged();
    void scanStateChanged();
    void systemsChanged();
    void settingsChanged();
    /// emitted after a scan; `changed` = number of system files written or removed
    void scanFinished(int games, int changed);

private:
    struct SystemState {
        QString emulator;   // chosen emulator id, empty = automatic
        QString command;    // custom command, empty = the emulator's
        int games = 0;
        QStringList folders;
    };

    QStringList m_rom_folders;
    std::map<QString, SystemState> m_systems;
    QSet<QString> m_installed;
    bool m_scan_on_start = true;
    bool m_scanning = false;
    QString m_status;
    QSet<QString> m_pending_scope; // scan requested while one was running
    bool m_pending = false;
    QFutureWatcher<std::vector<ScannedSystem>> m_watcher;
    QSet<QString> m_running_scope;

    void load();
    void save() const;
    void refreshInstalled();
    QString chosenEmulator(const CatalogSystem&) const;
    QString commandFor(const CatalogSystem&) const;
    bool writeSystemFile(const CatalogSystem&, const ScannedSystem&) const;
    void onScanDone();
    void setStatus(const QString&);
};

} // namespace deckos
