// DeckOS
// The Downloads page's "On this device" list (`deckos.deviceDownloads`): other apps' notifications with a
// progress bar - Play Store installs, browser downloads, an emulator fetching its files - from DeckOS's
// notification listener (com.deckos.media.NotificationWatcher). Read once a second while the page is
// shown. Needs Android's "Notification access" for DeckOS: allow() gives it through PServer / root, else
// opens Android's settings. On PC the lists stay empty.

#pragma once

#include <QObject>
#include <QVariantList>

class QTimer;


namespace deckos {

class DeviceDownloads : public QObject {
    Q_OBJECT
    /// running: { key, package, app, title, text, sub, progress (0-1, -1 unknown), time }
    Q_PROPERTY(QVariantList active READ active NOTIFY changed)
    /// finished while DeckOS was running, newest first: the same plus state
    Q_PROPERTY(QVariantList recent READ recent NOTIFY changed)
    /// "Notification access" is given
    Q_PROPERTY(bool allowed READ allowed NOTIFY changed)
    /// it can be read on this platform at all (Android)
    Q_PROPERTY(bool available READ available CONSTANT)

public:
    explicit DeviceDownloads(QObject* parent = nullptr);

    QVariantList active() const { return m_active; }
    QVariantList recent() const { return m_recent; }
    bool allowed() const { return m_allowed; }
    bool available() const;

    /// the Downloads page is on screen: read every second
    Q_INVOKABLE void watch(bool on);
    /// asks for "Notification access" (PServer / root, else Android's settings)
    Q_INVOKABLE void allow();
    Q_INVOKABLE void clearRecent();
    Q_INVOKABLE void poll();

signals:
    void changed();

private:
    QTimer* const m_timer;
    QVariantList m_active, m_recent;
    bool m_allowed = false;
};

} // namespace deckos
