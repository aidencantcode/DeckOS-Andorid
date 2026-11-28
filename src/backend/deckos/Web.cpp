// DeckOS
// See Web.h

#include "Web.h"

#include "Log.h"

#include <QDesktopServices>
#include <QUrl>

#ifdef Q_OS_ANDROID
#include <QtAndroidExtras/QtAndroid>
#include <QtAndroidExtras/QAndroidJniObject>
#endif


namespace deckos {

Web::Web(QObject* parent)
    : QObject(parent)
{}

bool Web::inAppVideo() const
{
#ifdef Q_OS_ANDROID
    return true;
#else
    return false;
#endif
}

void Web::playVideo(const QString& videoId, const QString& title, const QString& link)
{
#ifdef Q_OS_ANDROID
    if (!videoId.isEmpty()) {
        const jboolean ok = QAndroidJniObject::callStaticMethod<jboolean>(
            "com/deckos/media/VideoActivity", "start", "(Landroid/content/Context;Ljava/lang/String;Ljava/lang/String;)Z",
            QtAndroid::androidActivity().object(),
            QAndroidJniObject::fromString(videoId).object<jstring>(),
            QAndroidJniObject::fromString(title).object<jstring>());
        if (ok)
            return;
    }
#else
    Q_UNUSED(videoId);
    Q_UNUSED(title);
#endif
    if (!link.isEmpty())
        QDesktopServices::openUrl(QUrl(link));
}

void Web::openInYouTube(const QString& videoId, const QString& link)
{
#ifdef Q_OS_ANDROID
    if (!videoId.isEmpty() && QAndroidJniObject::callStaticMethod<jboolean>(
            "com/deckos/media/VideoActivity", "openInYouTube", "(Landroid/content/Context;Ljava/lang/String;)Z",
            QtAndroid::androidActivity().object(), QAndroidJniObject::fromString(videoId).object<jstring>()))
        return;
#else
    Q_UNUSED(videoId);
#endif
    if (!link.isEmpty())
        QDesktopServices::openUrl(QUrl(link));
}

} // namespace deckos
