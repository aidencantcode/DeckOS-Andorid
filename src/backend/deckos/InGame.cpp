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

#include <QFile>
#include <QFileInfo>
#include <QGuiApplication>
#include <QJsonArray>
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

// --- overlay settings: the Java Session prefs on Android, members on PC -----------------------------

#ifdef Q_OS_ANDROID
namespace {
int jni_int(const char* method)
{
    return QAndroidJniObject::callStaticMethod<jint>(JNI_SESSION, method, "()I");
}
bool jni_bool(const char* method)
{
    return QAndroidJniObject::callStaticMethod<jboolean>(JNI_SESSION, method, "()Z");
}
QString jni_string(const char* method)
{
    return QAndroidJniObject::callStaticObjectMethod(JNI_SESSION, method, "()Ljava/lang/String;").toString();
}
void jni_set_int(const char* method, int value)
{
    QAndroidJniObject::callStaticMethod<void>(JNI_SESSION, method, "(I)V", static_cast<jint>(value));
}
void jni_set_bool(const char* method, bool value)
{
    QAndroidJniObject::callStaticMethod<void>(JNI_SESSION, method, "(Z)V", static_cast<jboolean>(value));
}
} // namespace
#define DECKOS_GET(android, pc) return android
#else
#define DECKOS_GET(android, pc) return pc
#endif

int InGame::overlayScale() const { DECKOS_GET(jni_int("overlayScale"), m_pc_scale); }
bool InGame::keepRunning() const { DECKOS_GET(jni_bool("keepRunning"), m_pc_keep_running); }
int InGame::shortcut() const { DECKOS_GET(jni_int("shortcut"), m_pc_shortcut); }
bool InGame::shortcutEnabled() const { DECKOS_GET(jni_bool("shortcutServiceEnabled"), false); }
int InGame::hudPosition() const { DECKOS_GET(jni_int("hudPosition"), m_pc_hud_pos); }
bool InGame::showFps() const { DECKOS_GET(jni_bool("showFps"), m_pc_fps); }
bool InGame::privileged() const { DECKOS_GET(jni_bool("privilegedAvailable"), false); }
QString InGame::customUnderclock() const { DECKOS_GET(jni_string("customUnderclockName"), QString()); }

#undef DECKOS_GET

void InGame::setOverlayScale(int percent)
{
    percent = qBound(75, percent, 200);
#ifdef Q_OS_ANDROID
    jni_set_int("setOverlayScale", percent);
#else
    m_pc_scale = percent;
#endif
    emit changed();
}

void InGame::setKeepRunning(bool on)
{
#ifdef Q_OS_ANDROID
    jni_set_bool("setKeepRunning", on);
#else
    m_pc_keep_running = on;
#endif
    emit changed();
}

void InGame::setShortcut(int combo)
{
    combo = qBound(0, combo, 3);
#ifdef Q_OS_ANDROID
    jni_set_int("setShortcut", combo);
#else
    m_pc_shortcut = combo;
#endif
    emit changed();
}

void InGame::setHudPosition(int pos)
{
    pos = qBound(0, pos, 3);
#ifdef Q_OS_ANDROID
    jni_set_int("setHudPosition", pos);
#else
    m_pc_hud_pos = pos;
#endif
    emit changed();
}

void InGame::setShowFps(bool on)
{
#ifdef Q_OS_ANDROID
    jni_set_bool("setShowFps", on);
#else
    m_pc_fps = on;
#endif
    emit changed();
}

void InGame::openAccessibilitySettings()
{
#ifdef Q_OS_ANDROID
    QAndroidJniObject::callStaticMethod<void>(JNI_SESSION, "openAccessibilitySettings", "()V");
#endif
}

QString InGame::deviceInfo() const
{
#ifdef Q_OS_ANDROID
    return jni_string("deviceInfo");
#else
    return QStringLiteral("DeckOS device info\nPC build: the in-game layer, PServer and vendor modes are Android only.\n");
#endif
}

QString InGame::importClusterTune(const QString& path)
{
    QFile file(path);
    if (!file.open(QIODevice::ReadOnly))
        return tr("Can't read %1").arg(QFileInfo(path).fileName());
    if (file.size() > 1024 * 1024)
        return tr("That file is too big to be a ClusterTune profile");
    const QString json = QString::fromUtf8(file.readAll());
#ifdef Q_OS_ANDROID
    const QString result = QAndroidJniObject::callStaticObjectMethod(JNI_SESSION, "importClusterTune",
        "(Ljava/lang/String;)Ljava/lang/String;", QAndroidJniObject::fromString(json).object<jstring>()).toString();
#else
    // PC: check the file the same way, nothing to store it for
    const QJsonArray profiles = QJsonDocument::fromJson(json.toUtf8()).object().value(QLatin1String("profiles")).toArray();
    const QString result = profiles.isEmpty() ? QStringLiteral("!No profiles in that file")
                                              : profiles.first().toObject().value(QLatin1String("name")).toString();
#endif
    emit changed();
    return result.startsWith(QLatin1Char('!')) ? result.mid(1) : QString();
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
