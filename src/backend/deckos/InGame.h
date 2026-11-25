// DeckOS
// The Android in-game layer (Java: src/app/platform/android/src/com/deckos/ingame): its settings for
// QML (`deckos.ingame`), and the game it shows. At every launch the game's title and system, the
// RetroAchievements account and the DeckOS profile go to Java (Session.setNowPlaying); the RA game id
// follows as soon as RaMatcher has found the ROM by its hash. On PC nothing runs; the settings
// page still works (values are only kept until DeckOS closes).

#pragma once

#include <QObject>
#include <QPointer>

namespace model { class ApiObject; class GameFile; }


namespace deckos {

class RaMatcher;

class InGame : public QObject {
    Q_OBJECT
    /// false on PC: there's no in-game layer to drive
    Q_PROPERTY(bool available READ available CONSTANT)
    /// performance overlay over games: 0 = off, 1-4 = Steam Deck's levels
    Q_PROPERTY(int hudLevel READ hudLevel WRITE setHudLevel NOTIFY changed)
    /// the "Playing ..." notification while DeckOS is in the background (opens the overlay)
    Q_PROPERTY(bool notification READ notification WRITE setNotification NOTIFY changed)
    /// Android's "Display over other apps" permission, needed for the performance overlay
    Q_PROPERTY(bool overlayAllowed READ overlayAllowed NOTIFY changed)

public:
    InGame(model::ApiObject* api, RaMatcher* ra, QObject* parent = nullptr);

    bool available() const;
    int hudLevel() const;
    void setHudLevel(int level);
    bool notification() const;
    void setNotification(bool on);
    bool overlayAllowed() const;

    /// opens Android's "Display over other apps" screen for DeckOS
    Q_INVOKABLE void requestOverlayPermission();
    /// re-reads the values (the permission is granted outside DeckOS)
    Q_INVOKABLE void recheck() { emit changed(); }

    void onGameLaunching(const model::GameFile* file);

signals:
    void changed();

private:
    model::ApiObject* const m_api;
    RaMatcher* const m_ra;
    QPointer<QObject> m_launched; // the game whose RA id is being looked up
    int m_pc_hud = 0;
    bool m_pc_notification = true;
};

} // namespace deckos
