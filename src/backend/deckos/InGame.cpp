// DeckOS
// See InGame.h

#include "InGame.h"

#include "RaMatcher.h"
#include "model/Api.h"
#include "model/gaming/Assets.h"
#include "model/gaming/Collection.h"
#include "model/gaming/Game.h"
#include "model/gaming/GameFile.h"
#include "model/memory/Memory.h"

#include <QGuiApplication>
#include <QJsonDocument>
#include <QJsonObject>
#include <QTimer>

#ifdef Q_OS_ANDROID
#include <QtAndroidExtras/QAndroidJniObject>
#endif


namespace {
#ifdef Q_OS_ANDROID
constexpr auto JNI_SESSION = "com/deckos/ingame/Session";
#endif

QString memory_string(model::ApiObject* api, const QString& key)
{
    return api->memory().get(key).toString();
}
} // namespace


namespace deckos {

InGame::InGame(model::ApiObject* api, RaMatcher* ra, QObject* parent)
    : QObject(parent)
    , m_api(api)
    , m_ra(ra)
    , m_no_show_timer(new QTimer(this))
{
    m_no_show_timer->setSingleShot(true);
    m_no_show_timer->setInterval(15000);
    connect(m_no_show_timer, &QTimer::timeout, this, [this]() {
        if (m_playing && !m_left_front)
            endSession();
    });
    connect(qApp, &QGuiApplication::applicationStateChanged, this, &InGame::onAppState);

    connect(m_ra, &RaMatcher::identified, this,
            [this](QObject* game, int gameId, const QString&, const QString&, const QString&) {
        if (!m_launched || game != m_launched)
            return;
        m_launched = nullptr;
#ifdef Q_OS_ANDROID
        if (gameId > 0)
            QAndroidJniObject::callStaticMethod<void>(JNI_SESSION, "setRaGame", "(I)V", static_cast<jint>(gameId));
#else
        Q_UNUSED(gameId);
#endif
    });
}

bool InGame::available() const
{
#ifdef Q_OS_ANDROID
    return true;
#else
    return false;
#endif
}

int InGame::hudLevel() const
{
#ifdef Q_OS_ANDROID
    return QAndroidJniObject::callStaticMethod<jint>(JNI_SESSION, "hudLevel", "()I");
#else
    return m_pc_hud;
#endif
}

void InGame::setHudLevel(int level)
{
    level = qBound(0, level, 4);
#ifdef Q_OS_ANDROID
    QAndroidJniObject::callStaticMethod<void>(JNI_SESSION, "setHudLevel", "(I)V", static_cast<jint>(level));
#else
    m_pc_hud = level;
#endif
    emit changed();
}

bool InGame::notification() const
{
#ifdef Q_OS_ANDROID
    return QAndroidJniObject::callStaticMethod<jboolean>(JNI_SESSION, "notificationEnabled", "()Z");
#else
    return m_pc_notification;
#endif
}

void InGame::setNotification(bool on)
{
#ifdef Q_OS_ANDROID
    QAndroidJniObject::callStaticMethod<void>(JNI_SESSION, "setNotificationEnabled", "(Z)V", static_cast<jboolean>(on));
#else
    m_pc_notification = on;
#endif
    emit changed();
}

bool InGame::overlayAllowed() const
{
#ifdef Q_OS_ANDROID
    return QAndroidJniObject::callStaticMethod<jboolean>(JNI_SESSION, "overlayAllowed", "()Z");
#else
    return false;
#endif
}

bool InGame::keepLoaded() const
{
#ifdef Q_OS_ANDROID
    return QAndroidJniObject::callStaticMethod<jboolean>(JNI_SESSION, "keepLoaded", "()Z");
#else
    return m_pc_keep_loaded;
#endif
}

void InGame::setKeepLoaded(bool on)
{
#ifdef Q_OS_ANDROID
    QAndroidJniObject::callStaticMethod<void>(JNI_SESSION, "setKeepLoaded", "(Z)V", static_cast<jboolean>(on));
#else
    m_pc_keep_loaded = on;
#endif
    emit changed();
}

void InGame::beginSession()
{
    m_left_front = QGuiApplication::applicationState() != Qt::ApplicationActive;
    m_playing = true;
    emit playingChanged();
    if (!m_left_front)
        m_no_show_timer->start();
}

void InGame::onAppState(Qt::ApplicationState state)
{
    if (!m_playing)
        return;
    if (state != Qt::ApplicationActive) {
        m_left_front = true;
        m_no_show_timer->stop();
        return;
    }
    if (m_left_front)
        endSession();
}

void InGame::endSession()
{
    m_no_show_timer->stop();
    m_playing = false;
    m_left_front = false;
    emit sessionEnded();
    emit playingChanged();
}

void InGame::requestOverlayPermission()
{
#ifdef Q_OS_ANDROID
    QAndroidJniObject::callStaticMethod<void>(JNI_SESSION, "requestOverlayPermission", "()V");
#endif
}

void InGame::onGameLaunching(const model::GameFile* file)
{
    if (!file || !file->parentGame())
        return;
    model::Game* game = file->parentGame();

    QJsonObject info;
    info.insert(QStringLiteral("title"), game->title());
    const auto& collections = game->collectionsModel()->entries();
    if (!collections.empty())
        info.insert(QStringLiteral("system"), collections.front()->name());
    info.insert(QStringLiteral("cover"), game->assets().boxFront());
    const QString ra_user = memory_string(m_api, QStringLiteral("ra_api_user"));
    const QString ra_key = memory_string(m_api, QStringLiteral("ra_api_key"));
    info.insert(QStringLiteral("raUser"), ra_user);
    info.insert(QStringLiteral("raKey"), ra_key);
    info.insert(QStringLiteral("profileName"), memory_string(m_api, QStringLiteral("profileName")));
    info.insert(QStringLiteral("profilePicture"), memory_string(m_api, QStringLiteral("profilePicture")));

#ifdef Q_OS_ANDROID
    const QString json = QString::fromUtf8(QJsonDocument(info).toJson(QJsonDocument::Compact));
    QAndroidJniObject::callStaticMethod<void>(JNI_SESSION, "setNowPlaying", "(Ljava/lang/String;)V",
                                              QAndroidJniObject::fromString(json).object<jstring>());
#endif

    // the overlay's Achievements tab needs the RA game: found by ROM hash (cached after the first time)
    if (!ra_user.isEmpty() && !ra_key.isEmpty()) {
        m_launched = game;
        m_ra->identify(game, ra_key);
    }
}

} // namespace deckos
