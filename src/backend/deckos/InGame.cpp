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
#include <QDir>
#include <QElapsedTimer>
#include <QImage>
#include <QQuickItem>
#include <QQuickWindow>
#include <QRegularExpression>
#include <QStandardPaths>
#include <QTimer>

#ifdef Q_OS_ANDROID
#include <QtAndroidExtras/QAndroidJniEnvironment>
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
    connect(m_api, &model::ApiObject::eventLaunchError, this, &InGame::hideLaunchCover); // DeckOS shows the error

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
bool InGame::shortcutRunning() const { DECKOS_GET(jni_bool("shortcutServiceRunning"), false); }
int InGame::hudPosition() const { DECKOS_GET(jni_int("hudPosition"), m_pc_hud_pos); }
bool InGame::showFps() const { DECKOS_GET(jni_bool("showFps"), m_pc_fps); }
bool InGame::privileged() const { DECKOS_GET(jni_bool("privilegedAvailable"), false); }
bool InGame::notificationBlocked() const { DECKOS_GET(jni_bool("notificationsBlocked"), false); }
bool InGame::launchCover() const { DECKOS_GET(jni_bool("launchCover"), m_pc_cover); }
int InGame::launchCoverSeconds() const { DECKOS_GET(jni_int("launchCoverSeconds"), m_pc_cover_seconds); }
bool InGame::launchCoverPossible() const { DECKOS_GET(jni_bool("launchCoverPossible"), qEnvironmentVariableIsSet("DECKOS_COVER_DUMP")); }

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

void InGame::setLaunchCover(bool on)
{
#ifdef Q_OS_ANDROID
    jni_set_bool("setLaunchCover", on);
#else
    m_pc_cover = on;
#endif
    emit changed();
}

void InGame::setLaunchCoverSeconds(int seconds)
{
    seconds = qBound(1, seconds, 30);
#ifdef Q_OS_ANDROID
    jni_set_int("setLaunchCoverSeconds", seconds);
#else
    m_pc_cover_seconds = seconds;
#endif
    emit changed();
}

void InGame::enableShortcut()
{
#ifdef Q_OS_ANDROID
    if (!jni_bool("enableShortcutService"))
        openAccessibilitySettings();
    QTimer::singleShot(1500, this, &InGame::changed); // the service starts a moment later
#endif
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
#ifdef Q_OS_ANDROID
    const bool home = QAndroidJniObject::callStaticMethod<jboolean>(JNI_SESSION, "takeExitToHome", "()Z");
#else
    const bool home = false;
#endif
    emit sessionEnded();
    emit playingChanged();
    if (home)
        emit exitedToHome();
}

QString InGame::packageFromCommand(const QString& command)
{
    // -n / --component take package/activity, -p / --package just the package
    static const QRegularExpression rx(QStringLiteral(
        "(?:^|\\s)(?:-n|--component|-p|--package)\\s+[\"']?([A-Za-z][A-Za-z0-9_]*(?:\\.[A-Za-z0-9_]+)+)"));
    const QRegularExpressionMatch m = rx.match(command);
    return m.hasMatch() ? m.captured(1) : QString();
}

qint64 InGame::playedSeconds() const
{
#ifdef Q_OS_ANDROID
    return QAndroidJniObject::callStaticMethod<jlong>(JNI_SESSION, "playedSeconds", "()J");
#else
    return -1;
#endif
}

void InGame::openNotificationSettings()
{
#ifdef Q_OS_ANDROID
    QAndroidJniObject::callStaticMethod<void>(JNI_SESSION, "openNotificationSettings", "()V");
#endif
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
    info.insert(QStringLiteral("package"), packageFromCommand(game->launchCmd())); // play time, Exit game

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


// --- launch cover ------------------------------------------------------------------------------------

namespace {
/// the logo GIF as a file Java can read: it's in the theme's resources (or on disk on PC)
QString logo_file(const QUrl& url)
{
    const QString src = url.isLocalFile() ? url.toLocalFile()
                      : url.scheme() == QLatin1String("qrc") ? QLatin1Char(':') + url.path()
                      : QString();
    if (src.isEmpty() || !QFileInfo::exists(src))
        return {};
    if (!src.startsWith(QLatin1Char(':')))
        return src;
    const QString dir = QStandardPaths::writableLocation(QStandardPaths::CacheLocation);
    QDir().mkpath(dir);
    const QString out = dir + QStringLiteral("/launch-logo.gif");
    const QFileInfo have(out);
    if (!have.exists() || have.size() != QFileInfo(src).size()) {
        QFile::remove(out);
        if (!QFile::copy(src, out))
            return {};
        QFile::setPermissions(out, QFileDevice::ReadOwner | QFileDevice::WriteOwner);
    }
    return out;
}

QRectF scaled(const QRectF& r, qreal k)
{
    return QRectF(r.x() * k, r.y() * k, r.width() * k, r.height() * k);
}
} // namespace

bool InGame::showLaunchCover(QObject* spinnerObj, int spinnerStep, QObject* logoObj, int holdMs)
{
    auto* const spinner = qobject_cast<QQuickItem*>(spinnerObj);
    auto* const logo = qobject_cast<QQuickItem*>(logoObj);
    QQuickWindow* const win = spinner ? spinner->window() : logo ? logo->window() : nullptr;
    if (!win || win->width() <= 0)
        return false;
#ifdef Q_OS_ANDROID
    if (!launchCover() || !launchCoverPossible())
        return false;
#else
    // PC: nothing to show it with; DECKOS_COVER_DUMP=<file.png> saves the snapshot to check it
    const QString dump = qEnvironmentVariable("DECKOS_COVER_DUMP");
    if (dump.isEmpty())
        return false;
#endif
    QElapsedTimer timer;
    timer.start();

    // the snapshot, without the two animated parts (Java draws them, moving); made transparent rather
    // than hidden, so a row they are in doesn't close up
    const bool spinner_shown = spinner && spinner->isVisible() && spinner->opacity() > 0;
    const bool logo_shown = logo && logo->isVisible() && logo->opacity() > 0;
    const qreal spinner_opacity = spinner_shown ? spinner->opacity() : 0;
    const qreal logo_opacity = logo_shown ? logo->opacity() : 0;
    if (spinner_shown) spinner->setOpacity(0);
    if (logo_shown) logo->setOpacity(0);
    const QImage img = win->grabWindow();
    if (spinner_shown) spinner->setOpacity(spinner_opacity);
    if (logo_shown) logo->setOpacity(logo_opacity);
    if (img.isNull())
        return false;

    const qreal k = qreal(img.width()) / win->width(); // window units -> snapshot pixels
    const QPoint origin = win->mapToGlobal(QPoint(0, 0));
    const QPoint pos(qRound(origin.x() * k), qRound(origin.y() * k));

    QRectF spinner_rect;
    if (spinner_shown)
        spinner_rect = scaled(spinner->mapRectToScene(QRectF(0, 0, spinner->width(), spinner->height())), k);

    QRectF logo_rect;
    QString gif;
    float progress = 0.f;
    if (logo_shown) {
        // the picture inside the item (PreserveAspectFit), not the item
        QRectF r(0, 0, logo->width(), logo->height());
        const qreal pw = logo->property("paintedWidth").toReal();
        const qreal ph = logo->property("paintedHeight").toReal();
        if (pw > 0 && ph > 0)
            r = QRectF(r.center().x() - pw / 2, r.center().y() - ph / 2, pw, ph);
        logo_rect = scaled(logo->mapRectToScene(r), k);
        gif = logo_file(logo->property("source").toUrl());
        const int frames = logo->property("frameCount").toInt();
        if (frames > 0)
            progress = float(logo->property("currentFrame").toInt()) / frames;
    }

#ifdef Q_OS_ANDROID
    const QImage argb = img.convertToFormat(QImage::Format_ARGB32); // = Java's ARGB ints
    const int w = argb.width();
    const int h = argb.height();
    QAndroidJniEnvironment env;
    jintArray pixels = env->NewIntArray(w * h);
    if (!pixels) {
        if (env->ExceptionCheck())
            env->ExceptionClear();
        return false;
    }
    for (int y = 0; y < h; y++)
        env->SetIntArrayRegion(pixels, y * w, w, reinterpret_cast<const jint*>(argb.constScanLine(y)));
    const auto float_rect = [&env](const QRectF& r) {
        jfloatArray a = env->NewFloatArray(4);
        const jfloat v[4] = { jfloat(r.left()), jfloat(r.top()), jfloat(r.right()), jfloat(r.bottom()) };
        if (a)
            env->SetFloatArrayRegion(a, 0, 4, v);
        return a;
    };
    jfloatArray spinner_arr = float_rect(spinner_rect);
    jfloatArray logo_arr = float_rect(logo_rect);
    const QAndroidJniObject gif_path = QAndroidJniObject::fromString(gif);
    const bool ok = QAndroidJniObject::callStaticMethod<jboolean>(JNI_SESSION, "showLaunchCover",
        "([IIIII[FI[FLjava/lang/String;FI)Z",
        pixels, jint(w), jint(h), jint(pos.x()), jint(pos.y()), spinner_arr, jint(spinnerStep), logo_arr,
        gif_path.object<jstring>(), jfloat(progress), jint(holdMs));
    if (env->ExceptionCheck()) {
        env->ExceptionDescribe();
        env->ExceptionClear();
    }
    env->DeleteLocalRef(pixels);
    if (spinner_arr) env->DeleteLocalRef(spinner_arr);
    if (logo_arr) env->DeleteLocalRef(logo_arr);
    qInfo().noquote() << QStringLiteral("launch cover: %1 in %2 ms").arg(ok ? "shown" : "not shown").arg(timer.elapsed());
    return ok;
#else
    const bool saved = img.save(dump);
    qInfo().noquote() << QStringLiteral("launch cover (PC dump): %1 %2x%3 at %4,%5, spinner %6,%7 %8x%9 step %10, "
                                        "logo %11,%12 %13x%14 at %15 of the loop, gif '%16', hold %17 ms, %18 ms")
        .arg(saved ? dump : QStringLiteral("NOT SAVED")).arg(img.width()).arg(img.height()).arg(pos.x()).arg(pos.y())
        .arg(spinner_rect.x()).arg(spinner_rect.y()).arg(spinner_rect.width()).arg(spinner_rect.height()).arg(spinnerStep)
        .arg(logo_rect.x()).arg(logo_rect.y()).arg(logo_rect.width()).arg(logo_rect.height()).arg(progress)
        .arg(gif).arg(holdMs).arg(timer.elapsed());
    return false;
#endif
}

void InGame::hideLaunchCover()
{
#ifdef Q_OS_ANDROID
    QAndroidJniObject::callStaticMethod<void>(JNI_SESSION, "hideLaunchCover", "()V");
#endif
}

} // namespace deckos
