// DeckOS
// Settings › Updates, the Store and Home's "Emulator Updates" shelf (`deckos.updates` in QML):
// - DeckOS itself: the newest release of DeckOS's GitHub repository (its arm64 APK) against this build;
// - emulators: every app in catalog/emulator-sources.json - its installed version (Android's package
//   manager) against the newest release of its GitHub repository, or a versioned download address
//   (RetroArch's buildbot, ppsspp.org) - with Update / Install buttons.
// "Update" downloads the APK (progress on screen and in an Android notification), then installs it with
// Android's installer, or without a screen through PServer / root when Settings › Updates says so. An app
// that came from the Play Store is sent to the Play Store instead: a GitHub build can't replace it (they
// are signed with different keys). A check reads GitHub's public API without an account (60 requests an
// hour per device), so it runs at most every 12 hours by itself and every 10 minutes when asked.
// The downloads (finished, running, failed) are listed for the Downloads page.

#pragma once

#include <QHash>
#include <QJsonArray>
#include <QObject>
#include <QPointer>
#include <QVariantList>
#include <QVariantMap>

class QNetworkAccessManager;
class QNetworkReply;
class QFile;
class QTimer;


namespace deckos {

class Updates : public QObject {
    Q_OBJECT
    /// this build's version ("0.1.6")
    Q_PROPERTY(QString appVersion READ appVersion CONSTANT)
    /// DeckOS's newest release: { latest, update (bool), date (ms), notes, size, state, progress, error }
    /// state: "", "downloading", "ready", "installing", "error"
    Q_PROPERTY(QVariantMap app READ app NOTIFY appChanged)
    /// every emulator of the catalog: { package, name, installed (bool), installedVersion, latest, update (bool),
    /// fromStore (bool: Play Store app), canInstall (bool: a download DeckOS can install), page, state,
    /// progress, error, date }
    Q_PROPERTY(QVariantList emulators READ emulators NOTIFY emulatorsChanged)
    /// ...only those installed with a newer version out (Home's shelf, the Updates badge)
    Q_PROPERTY(QVariantList emulatorUpdates READ emulatorUpdates NOTIFY emulatorUpdatesChanged)
    /// downloads, newest first: { id, name, state, progress, bytes, total, time, file, error }
    Q_PROPERTY(QVariantList downloads READ downloads NOTIFY downloadsChanged)
    Q_PROPERTY(bool checking READ checking NOTIFY checkingChanged)
    /// ms since epoch of the last finished check (0: never)
    Q_PROPERTY(qint64 lastCheck READ lastCheck NOTIFY checkingChanged)
    Q_PROPERTY(QString error READ error NOTIFY checkingChanged)
    /// looks for updates by itself (at start, every 12 h)
    Q_PROPERTY(bool autoCheck READ autoCheck WRITE setAutoCheck NOTIFY settingsChanged)
    /// installs without Android's installer screen (PServer / root)
    Q_PROPERTY(bool silentInstall READ silentInstall WRITE setSilentInstall NOTIFY settingsChanged)
    /// PServer or root is there (silentInstall can work)
    Q_PROPERTY(bool privileged READ privileged CONSTANT)
    /// Android lets DeckOS open its installer ("Install unknown apps")
    Q_PROPERTY(bool canInstall READ canInstall NOTIFY settingsChanged)
    /// where DeckOS's own releases come from ("owner/repo")
    Q_PROPERTY(QString repo READ repo CONSTANT)

public:
    explicit Updates(QObject* parent = nullptr);
    ~Updates() override;

    QString appVersion() const;
    QVariantMap app() const;
    QVariantList emulators() const;
    QVariantList emulatorUpdates() const;
    QVariantList downloads() const { return m_downloads; }
    bool checking() const { return m_pending > 0; }
    qint64 lastCheck() const { return m_last_check; }
    QString error() const { return m_error; }
    bool autoCheck() const { return m_auto; }
    void setAutoCheck(bool on);
    bool silentInstall() const { return m_silent; }
    void setSilentInstall(bool on);
    bool privileged() const;
    bool canInstall() const;
    QString repo() const;

    /// looks for new versions now (force: also what was looked at in the last 10 minutes)
    Q_INVOKABLE void check(bool force = true);
    /// downloads and installs DeckOS's newest release
    Q_INVOKABLE void updateApp();
    /// downloads and installs an emulator's newest version (update or first install); Play Store apps and
    /// those without a download open their page instead
    Q_INVOKABLE void updateEmulator(const QString& package);
    /// its web / Play Store page
    Q_INVOKABLE void openPage(const QString& package);
    /// stops a download ("app" or a package)
    Q_INVOKABLE void cancel(const QString& id);
    /// forgets finished and failed downloads, deletes their files
    Q_INVOKABLE void clearDownloads();
    /// Android's "Install unknown apps" switch for DeckOS
    Q_INVOKABLE void openInstallSettings();

    /// DeckOS is in front again: installed versions may have changed (an installer just finished)
    void onAppActive();

    /// "1.22.2" vs "v1.22.10": -1 / 0 / 1 by their numbers (public for the tests)
    static int compareVersions(const QString& a, const QString& b);

signals:
    void appChanged();
    void emulatorsChanged();
    void emulatorUpdatesChanged();
    void downloadsChanged();
    void checkingChanged();
    void settingsChanged();
    /// a download finished or failed (the theme shows a card)
    void notice(const QString& title, const QString& text);

private:
    struct Entry {
        QString package, name, github, asset, versionFrom, urlTemplate, page;
        // installed
        bool installed = false;
        QString installedVersion, installer;
        qint64 installedAt = 0;
        // newest release
        QString latest, downloadUrl, notes;
        qint64 published = 0, size = 0;
        // download / install
        QString state, error, file;
        qreal progress = 0;
        Entry() {}
    };

    QNetworkAccessManager* const m_net;
    QTimer* const m_timer;
    QTimer* const m_save_timer;
    QList<Entry> m_entries;
    Entry m_app;
    QVariantList m_downloads;
    QHash<QString, qint64> m_fetched;           // repo -> ms of the last request
    QHash<QString, QPointer<QNetworkReply>> m_active; // id -> running download
    QHash<QString, QFile*> m_files;
    QHash<QString, int> m_notified;             // id -> last notification percent
    int m_pending = 0;
    qint64 m_last_check = 0;
    QString m_error;
    bool m_auto = true;
    bool m_silent = false;
    bool m_had_updates = false;

    void loadCatalog();
    void loadState();
    void saveState();
    void refreshInstalled();
    Entry* entry(const QString& id);
    QVariantMap toMap(const Entry& e) const;

    QNetworkReply* githubGet(const QString& path);
    void fetchApp(bool force);
    void fetchEntry(Entry& e, bool force);
    void applyRelease(const QString& id, const QJsonArray& releases);
    void done(QNetworkReply* reply, const QString& failure = QString());

    void startDownload(const QString& id);
    void install(const QString& id);
    void setState(const QString& id, const QString& state, const QString& error = QString());
    void recordDownload(const QString& id, const QString& name, const QString& state, qint64 bytes, qint64 total,
                        const QString& file, const QString& error);
    void emitFor(const QString& id);
};

} // namespace deckos
