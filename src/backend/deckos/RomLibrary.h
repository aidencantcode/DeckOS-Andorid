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

#include <QMutex>
#include <QTimer>

#include <atomic>
#include <map>
#include <memory>
#include <vector>


namespace deckos {

class Catalog;
struct CatalogSystem;

struct ScannedSystem {
    QString id;
    QStringList folders;   // where its games were found
    QStringList files;     // absolute paths, sorted
    QSet<QString> folderGames; // DECKOS: those of `files` that are game folders (CatalogSystem::gameFolders)
};

/// DECKOS: how far a running scan got, written by the scan's thread and read by the UI thread
/// (the loading screen); `cancel` stops it, and nothing it found is used then
struct ScanProgress {
    std::atomic<int> systemsTotal { 0 };
    std::atomic<int> systemsDone { 0 };
    std::atomic<int> files { 0 };
    std::atomic<bool> cancel { false };
    QMutex lock;
    QString currentSystem; // a system's name, under `lock`
};

/// The scan itself (no Qt event loop needed): exposed for tests.
std::vector<ScannedSystem> scan_rom_folders(const QStringList& rom_roots, const QSet<QString>& only_systems);
std::vector<ScannedSystem> scan_rom_folders(const Catalog&, const QStringList& rom_roots, const QSet<QString>& only_systems);
/// DECKOS: `links` (system id -> folder) replace the folders found by name for those systems
std::vector<ScannedSystem> scan_rom_folders(const Catalog&, const QStringList& rom_roots, const QSet<QString>& only_systems,
                                            const std::map<QString, QString>& links, ScanProgress* progress = nullptr);
/// "Chrono Trigger (USA) [!].sfc" -> "Chrono Trigger"; keeps the tags when two games would get the same name.
/// Game folders ("Demon's Souls [BLUS30443]") keep their whole folder name before the clean-up (no extension).
QStringList game_titles(const QStringList& files, const QSet<QString>& folder_games = {});


class RomLibrary : public QObject {
    Q_OBJECT
    Q_PROPERTY(QStringList romFolders READ romFolders NOTIFY romFoldersChanged)
    Q_PROPERTY(bool scanning READ scanning NOTIFY scanStateChanged)
    Q_PROPERTY(QString status READ status NOTIFY scanStateChanged)
    /// systems found by the last scans: [{ id, name, games, folders, emulatorId, emulatorName, installed,
    ///  command, customCommand, link }]
    Q_PROPERTY(QVariantList systems READ systemsList NOTIFY systemsChanged)
    Q_PROPERTY(bool scanOnStart READ scanOnStart WRITE setScanOnStart NOTIFY settingsChanged)
    /// DECKOS: the running scan was asked for by the user (a folder added, "Scan ROM folders"...), so the
    /// interface shows the loading screen; the quick check after start-up runs unseen
    Q_PROPERTY(bool scanForeground READ scanForeground NOTIFY scanStateChanged)
    /// games found so far, how far along (0..1) and the system being read, while scanning
    Q_PROPERTY(int scanFound READ scanFound NOTIFY scanProgressChanged)
    Q_PROPERTY(qreal scanProgress READ scanProgress NOTIFY scanProgressChanged)
    Q_PROPERTY(QString scanSystem READ scanSystem NOTIFY scanProgressChanged)

public:
    explicit RomLibrary(QObject* parent = nullptr);
    ~RomLibrary() override;

    Q_INVOKABLE void addRomFolder(const QString& path);
    Q_INVOKABLE void removeRomFolder(const QString& path);
    /// Scans all systems (empty list) or only the given system ids.
    Q_INVOKABLE void scan(const QStringList& systemIds = {});
    /// the quick look for new ROMs after start-up: no loading screen
    void scanInBackground();
    /// stops the running scan; nothing changes (no system file is written)
    Q_INVOKABLE void cancelScan();

    /// [{ id, name, installed, isDefault, achievements }] for a system, installed emulators first
    Q_INVOKABLE QVariantList emulatorsFor(const QString& systemId) const;
    Q_INVOKABLE void setEmulator(const QString& systemId, const QString& emulatorId);
    /// a hand-written launch command for the whole system; empty = back to the emulator's
    Q_INVOKABLE void setCustomCommand(const QString& systemId, const QString& command);
    /// Settings > Collections: the system's games come from this folder only (empty = the folders found
    /// by name in the ROM folders again). Rescans that system.
    Q_INVOKABLE void linkFolder(const QString& systemId, const QString& folder);
    /// Settings > Emulators > Scan installed emulators: the catalog's emulators installed on the device,
    /// found without any ROM folder: [{ name, package, systems: [system names] }], by name
    Q_INVOKABLE QVariantList installedEmulators();

    QStringList romFolders() const { return m_rom_folders; }
    bool scanning() const { return m_scanning; }
    const QString& status() const { return m_status; }
    QVariantList systemsList() const;
    bool scanOnStart() const { return m_scan_on_start; }
    void setScanOnStart(bool);
    bool scanForeground() const { return m_scanning && m_foreground; }
    int scanFound() const { return m_found; }
    qreal scanProgress() const { return m_progress_value; }
    const QString& scanSystem() const { return m_scan_system; }

    /// re-reads which emulator apps are installed (Android)
    void refreshEmulators() { refreshInstalled(); emit systemsChanged(); }

    /// <config>/deckos/library - added to the game folders Pegasus reads
    static QString libraryDir();

signals:
    void romFoldersChanged();
    void scanStateChanged();
    void scanProgressChanged();
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
        QString link;       // the folder picked for it (linkFolder), empty = found by name
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
    bool m_foreground = false;
    bool m_pending_foreground = false;
    std::shared_ptr<ScanProgress> m_scan_progress; // shared with the scan's thread
    QTimer m_progress_timer;
    int m_found = 0;
    qreal m_progress_value = 0.0;
    QString m_scan_system;

    void startScan(const QStringList& systemIds, bool foreground);
    void pollProgress();
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
