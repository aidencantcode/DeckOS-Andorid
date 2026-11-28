// DeckOS
// See DeviceDownloads.h

#include "DeviceDownloads.h"

#include "Log.h"

#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QTimer>

#ifdef Q_OS_ANDROID
#include <QtAndroidExtras/QAndroidJniObject>
#include <QtAndroidExtras/QtAndroid>
#endif


namespace {
#ifdef Q_OS_ANDROID
constexpr auto JNI_WATCHER = "com/deckos/media/NotificationWatcher";
#endif
} // namespace


namespace deckos {

DeviceDownloads::DeviceDownloads(QObject* parent)
    : QObject(parent)
    , m_timer(new QTimer(this))
{
    m_timer->setInterval(1000);
    connect(m_timer, &QTimer::timeout, this, &DeviceDownloads::poll);
}

bool DeviceDownloads::available() const
{
#ifdef Q_OS_ANDROID
    return true;
#else
    return false;
#endif
}

void DeviceDownloads::watch(bool on)
{
    if (on) {
        poll();
        m_timer->start();
    }
    else {
        m_timer->stop();
    }
}

void DeviceDownloads::poll()
{
#ifdef Q_OS_ANDROID
    const QString json = QAndroidJniObject::callStaticObjectMethod(
        JNI_WATCHER, "snapshot", "(Landroid/content/Context;)Ljava/lang/String;", QtAndroid::androidContext().object()).toString();
    const QJsonObject o = QJsonDocument::fromJson(json.toUtf8()).object();
    const QVariantList active = o.value(QStringLiteral("active")).toArray().toVariantList();
    const QVariantList recent = o.value(QStringLiteral("recent")).toArray().toVariantList();
    const bool allowed = o.value(QStringLiteral("allowed")).toBool();
    if (active != m_active || recent != m_recent || allowed != m_allowed) {
        m_active = active;
        m_recent = recent;
        m_allowed = allowed;
        emit changed();
    }
#endif
}

void DeviceDownloads::allow()
{
#ifdef Q_OS_ANDROID
    const QAndroidJniObject ctx = QtAndroid::androidContext();
    if (QAndroidJniObject::callStaticMethod<jboolean>(JNI_WATCHER, "grant", "(Landroid/content/Context;)Z", ctx.object())) {
        Log::info(LOGMSG("Downloads: notification access given through PServer / root"));
        QTimer::singleShot(1500, this, &DeviceDownloads::poll);
        return;
    }
    QAndroidJniObject::callStaticMethod<void>(JNI_WATCHER, "openSettings", "(Landroid/content/Context;)V", ctx.object());
#endif
}

void DeviceDownloads::clearRecent()
{
#ifdef Q_OS_ANDROID
    QAndroidJniObject::callStaticMethod<void>(JNI_WATCHER, "clearRecent", "()V");
#endif
    m_recent.clear();
    emit changed();
}

} // namespace deckos
