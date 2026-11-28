// DeckOS
// See ImageCache.h

#include "ImageCache.h"

#include "Log.h"
#include "model/Api.h"
#include "model/gaming/Assets.h"
#include "model/gaming/Game.h"

#include <QCache>
#include <QCryptographicHash>
#include <QDir>
#include <QDirIterator>
#include <QFileInfo>
#include <QImage>
#include <QImageReader>
#include <QImageWriter>
#include <QMutex>
#include <QMutexLocker>
#include <QPointer>
#include <QQuickTextureFactory>
#include <QRunnable>
#include <QStandardPaths>
#include <QThread>
#include <QThreadPool>
#include <QTimer>
#include <QUrl>
#include <QtConcurrent/QtConcurrentRun>

#include <atomic>
#include <cmath>


namespace {
std::atomic<int> g_pending{0};
std::atomic<int> g_warming{0};
std::atomic<int> g_generation{0}; // clear() bumps it: warm jobs from before stop

QMutex g_mem_mutex;
QCache<QString, QImage>& mem_cache()
{
    static QCache<QString, QImage> cache(160 * 1024); // cost in KB
    return cache;
}

QThreadPool* view_pool()
{
    static QThreadPool* pool = []() {
        auto* p = new QThreadPool;
        p->setMaxThreadCount(qBound(2, QThread::idealThreadCount() / 2, 4));
        p->setExpiryTimeout(30000);
        return p;
    }();
    return pool;
}

QThreadPool* warm_pool()
{
    static QThreadPool* pool = []() {
        auto* p = new QThreadPool;
        p->setMaxThreadCount(1); // in the background, never in the way of what's on screen
        p->setExpiryTimeout(10000);
        return p;
    }();
    return pool;
}

/// a requested dimension, rounded up to one of a few sizes (one thumbnail serves similar layouts)
int bucket(int v)
{
    static const int sizes[] = { 64, 96, 128, 192, 256, 320, 384, 448, 512, 640, 768, 1024, 1280, 1600, 1920, 2560 };
    if (v <= 0)
        return 0;
    for (int s : sizes)
        if (s >= v)
            return s;
    return v;
}

/// "file:///storage/.../poster.png?v=123", "/storage/...", "qrc:/..." -> a path QImageReader opens; "" if
/// it isn't on the device (web images keep their own loading)
QString local_path(const QString& id)
{
    QString s = QUrl::fromPercentEncoding(id.toUtf8());
    const int v = s.lastIndexOf(QLatin1String("?v="));
    if (v > 0)
        s.truncate(v);
    if (s.startsWith(QLatin1String("file://"))) {
        s = s.mid(7);
#ifdef Q_OS_WIN
        if (s.size() > 2 && s.at(0) == QLatin1Char('/') && s.at(2) == QLatin1Char(':'))
            s = s.mid(1);
#endif
        return s;
    }
    if (s.startsWith(QLatin1String("qrc:/")))
        return s.mid(3);
    if (s.startsWith(QLatin1String(":/")) || s.startsWith(QLatin1Char('/')))
        return s;
#ifdef Q_OS_WIN
    if (s.size() > 2 && s.at(1) == QLatin1Char(':'))
        return s;
#endif
    return QString();
}

QString cache_key(const QFileInfo& fi, const QSize& req)
{
    const QString raw = fi.absoluteFilePath() + QLatin1Char('|') + QString::number(fi.size()) + QLatin1Char('|')
                      + QString::number(fi.lastModified().toMSecsSinceEpoch()) + QLatin1Char('|')
                      + QString::number(req.width()) + QLatin1Char('x') + QString::number(req.height());
    return QString::fromLatin1(QCryptographicHash::hash(raw.toUtf8(), QCryptographicHash::Sha1).toHex());
}

QString cache_file(const QString& key)
{
    return deckos::ImageCache::cacheDir() + QLatin1Char('/') + key.left(2) + QLatin1Char('/') + key + QLatin1String(".thumb");
}

/// the size the thumbnail is made at: covers the requested box (tiles crop to fill), never larger than
/// the original. Invalid: keep the original size.
QSize target_size(const QSize& orig, const QSize& req)
{
    if (!orig.isValid() || (req.width() <= 0 && req.height() <= 0))
        return QSize();
    const double sx = req.width() > 0 ? double(req.width()) / orig.width() : 0.0;
    const double sy = req.height() > 0 ? double(req.height()) / orig.height() : 0.0;
    const double s = std::max(sx, sy);
    if (s <= 0.0 || s >= 0.95)
        return QSize(); // about its own size already
    return QSize(std::max(1, int(std::ceil(orig.width() * s))), std::max(1, int(std::ceil(orig.height() * s))));
}

void remember(const QString& key, const QImage& img)
{
    QMutexLocker lock(&g_mem_mutex);
    mem_cache().insert(key, new QImage(img), std::max<qsizetype>(1, img.sizeInBytes() / 1024));
}

/// reads the thumbnail (memory, then disk), else makes it from the original and keeps it.
/// `forScreen`: false while warming (only the disk copy is made, the memory cache is left alone)
QImage load_thumbnail(const QString& path, const QSize& requested, bool forScreen, QString* error)
{
    const QFileInfo fi(path);
    if (!fi.exists()) {
        if (error) *error = QStringLiteral("no such file");
        return QImage();
    }
    const QSize req(bucket(requested.width()), bucket(requested.height()));
    const QString key = cache_key(fi, req);
    if (forScreen) {
        QMutexLocker lock(&g_mem_mutex);
        if (QImage* hit = mem_cache().object(key))
            return *hit;
    }
    const QString file = cache_file(key);
    if (QFileInfo::exists(file)) {
        if (!forScreen)
            return QImage(1, 1, QImage::Format_RGB32); // there already
        QImageReader cached(file);
        cached.setDecideFormatFromContent(true);
        const QImage img = cached.read();
        if (!img.isNull()) {
            remember(key, img);
            return img;
        }
        QFile::remove(file); // broken: made again
    }

    QImageReader reader(path);
    reader.setAutoTransform(true);
    const QSize orig = reader.size();
    const QSize out = target_size(orig, req);
    if (out.isValid() && reader.supportsOption(QImageIOHandler::ScaledSize))
        reader.setScaledSize(out); // JPEG decodes straight at the smaller size
    QImage img = reader.read();
    if (img.isNull()) {
        if (error) *error = reader.errorString();
        return QImage();
    }
    if (out.isValid() && img.size() != out)
        img = img.scaled(out, Qt::IgnoreAspectRatio, Qt::SmoothTransformation);

    if (out.isValid()) { // smaller than the original: worth keeping (a small original is read as it is)
        const bool alpha = img.hasAlphaChannel();
        if (!alpha && img.format() != QImage::Format_RGB32)
            img = img.convertToFormat(QImage::Format_RGB32);
        QDir().mkpath(QFileInfo(file).absolutePath());
        const QString tmp = file + QLatin1String(".part");
        bool written = false;
        {
            // closed before the rename (the writer keeps its file open; Windows can't rename an open file)
            QImageWriter writer(tmp, alpha ? QByteArrayLiteral("png") : QByteArrayLiteral("jpg"));
            if (!alpha)
                writer.setQuality(88);
            written = writer.write(img);
        }
        if (written) {
            QFile::remove(file);
            QFile::rename(tmp, file);
        }
        else {
            QFile::remove(tmp);
        }
    }
    if (forScreen)
        remember(key, img);
    return img;
}


class ThumbResponse : public QQuickImageResponse, public QRunnable {
public:
    ThumbResponse(const QString& id, const QSize& requested)
        : m_id(id)
        , m_requested(requested)
    {
        setAutoDelete(false);
        ++g_pending;
    }

    QQuickTextureFactory* textureFactory() const override
    {
        return QQuickTextureFactory::textureFactoryForImage(m_image);
    }
    QString errorString() const override { return m_error; }
    void cancel() override { m_cancelled = true; }

    void run() override
    {
        if (!m_cancelled) {
            const QString path = local_path(m_id);
            if (path.isEmpty())
                m_error = QStringLiteral("not a file on this device: ") + m_id;
            else
                m_image = load_thumbnail(path, m_requested, true, &m_error);
            if (m_image.isNull() && m_error.isEmpty())
                m_error = QStringLiteral("can't read ") + path;
        }
        --g_pending;
        emit finished();
    }

private:
    const QString m_id;
    const QSize m_requested;
    QImage m_image;
    QString m_error;
    std::atomic<bool> m_cancelled{false};
};

class ThumbProvider : public QQuickAsyncImageProvider {
public:
    QQuickImageResponse* requestImageResponse(const QString& id, const QSize& requestedSize) override
    {
        auto* response = new ThumbResponse(id, requestedSize);
        view_pool()->start(response);
        return response;
    }
};


class WarmJob : public QRunnable {
public:
    WarmJob(QStringList paths, QSize size, int generation)
        : m_paths(std::move(paths)), m_size(size), m_generation(generation) {}

    void run() override
    {
        QThread::currentThread()->setPriority(QThread::LowPriority);
        for (const QString& p : qAsConst(m_paths)) {
            if (m_generation != g_generation) {
                g_warming = 0;
                return;
            }
            load_thumbnail(p, m_size, false, nullptr);
            if (g_warming > 0)
                --g_warming;
        }
    }

private:
    const QStringList m_paths;
    const QSize m_size;
    const int m_generation;
};

qint64 folder_bytes(const QString& dir)
{
    qint64 total = 0;
    QDirIterator it(dir, QDir::Files, QDirIterator::Subdirectories);
    while (it.hasNext()) {
        it.next();
        total += it.fileInfo().size();
    }
    return total;
}
} // namespace


namespace deckos {

ImageCache::ImageCache(model::ApiObject* api, QObject* parent)
    : QObject(parent)
    , m_api(api)
    , m_poll(new QTimer(this))
{
    m_poll->setInterval(150);
    connect(m_poll, &QTimer::timeout, this, [this]() {
        const int p = g_pending, w = g_warming;
        if (p != m_last_pending || w != m_last_warming) {
            m_last_pending = p;
            if (w == 0 && m_last_warming > 0) {
                m_warm_total = 0;
                measure();
            }
            m_last_warming = w;
            emit pendingChanged();
        }
    });
    m_poll->start();
    QTimer::singleShot(4000, this, &ImageCache::measure);
}

ImageCache::~ImageCache() = default;

int ImageCache::pending() const { return m_last_pending; }
int ImageCache::warming() const { return m_last_warming; }

QString ImageCache::cacheDir()
{
    static const QString dir = QStandardPaths::writableLocation(QStandardPaths::CacheLocation) + QStringLiteral("/thumbs");
    return dir;
}

QQuickAsyncImageProvider* ImageCache::createProvider()
{
    return new ThumbProvider;
}

void ImageCache::warm(const QStringList& urls, int width, int height)
{
    QStringList paths;
    paths.reserve(urls.size());
    for (const QString& u : urls) {
        if (u.isEmpty())
            continue;
        QString id = u;
        if (id.startsWith(QLatin1String("image://deckthumb/")))
            id = id.mid(18);
        const QString p = local_path(id);
        if (!p.isEmpty())
            paths.append(p);
    }
    paths.removeDuplicates();
    if (paths.isEmpty())
        return;
    g_warming += paths.size();
    m_warm_total += paths.size();
    // in slices, so a clear() or a newer warm-up isn't stuck behind thousands of files
    constexpr int SLICE = 50;
    for (int i = 0; i < paths.size(); i += SLICE)
        warm_pool()->start(new WarmJob(paths.mid(i, SLICE), QSize(width, height), g_generation), -1);
    Log::info(LOGMSG("Making artwork thumbnails for %1 images in the background").arg(paths.size()));
    emit pendingChanged();
}

void ImageCache::warmLibrary(const QString& kind, int width, int height)
{
    if (!m_api || width <= 0 || height <= 0)
        return;
    // every Library tab asks: once per size and library
    const QString done = kind + QLatin1Char('|') + QString::number(width) + QLatin1Char('x') + QString::number(height)
                       + QLatin1Char('|') + QString::number(m_api->allGames()->entries().size());
    if (m_warmed.contains(done))
        return;
    m_warmed.insert(done);
    QStringList urls;
    for (const model::Game* game : m_api->allGames()->entries()) {
        const model::Assets& a = game->assets();
        if (kind == QLatin1String("steam"))
            urls.append(a.steam());
        else if (kind == QLatin1String("background"))
            urls.append(a.background());
        else
            urls.append(a.poster().isEmpty() ? a.boxFront() : a.poster());
    }
    warm(urls, width, height);
}

void ImageCache::clear()
{
    ++g_generation;
    warm_pool()->clear();
    g_warming = 0;
    m_warm_total = 0;
    m_warmed.clear();
    {
        QMutexLocker lock(&g_mem_mutex);
        mem_cache().clear();
    }
    QPointer<ImageCache> self(this);
    QtConcurrent::run([self]() {
        QDir(ImageCache::cacheDir()).removeRecursively();
        if (self)
            QMetaObject::invokeMethod(self, "measure", Qt::QueuedConnection);
    });
    emit pendingChanged();
}

void ImageCache::measure()
{
    QPointer<ImageCache> self(this);
    QtConcurrent::run([self]() {
        const qreal mb = folder_bytes(ImageCache::cacheDir()) / (1024.0 * 1024.0);
        if (!self)
            return;
        QMetaObject::invokeMethod(self, [self, mb]() {
            if (!self) return;
            self->m_disk_mb = mb;
            emit self->diskChanged();
        }, Qt::QueuedConnection);
    });
}

} // namespace deckos
