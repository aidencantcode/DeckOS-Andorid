// DeckOS
// Artwork thumbnails for the grids and rows (Library, Home, Search, collections): `image://deckthumb/<url>`
// in QML (theme.thumb(url)). Cover art from SteamGridDB / ScreenScraper is often 600x900 to 1200x1800
// pixels; every tile used to decode the whole file on the interface thread (AnimatedImage doesn't share
// Qt's image cache) - scrolling fast through a big library stuttered badly.
//
// Here a tile asks for the size it shows (Image.sourceSize, rounded up to a few fixed sizes so one
// thumbnail serves many layouts). The first time, a worker thread scales the original down and keeps
// it as a small JPEG (PNG when it has transparency) in DeckOS's cache folder; after that, and after a
// restart, only that small file is read. Recently shown thumbnails also stay in memory (an LRU of about
// 160 MB), so scrolling back is instant. warm() makes the thumbnails of a whole library ahead of time,
// one at a time in the background.
//
// The cache key holds the original's path, size and modification time: new artwork (scraped, picked or
// edited) gets a new thumbnail by itself.

#pragma once

#include <QObject>
#include <QQuickAsyncImageProvider>
#include <QSet>
#include <QStringList>

class QThreadPool;
namespace model { class ApiObject; }
class QTimer;


namespace deckos {

class ImageCache : public QObject {
    Q_OBJECT
    /// thumbnails being made or read right now (the Library shows a loading bar meanwhile)
    Q_PROPERTY(int pending READ pending NOTIFY pendingChanged)
    /// warm(): thumbnails still to make, and how many it was asked for
    Q_PROPERTY(int warming READ warming NOTIFY pendingChanged)
    Q_PROPERTY(int warmTotal READ warmTotal NOTIFY pendingChanged)
    /// the cache folder's size on disk, MB (Settings)
    Q_PROPERTY(qreal diskMegabytes READ diskMegabytes NOTIFY diskChanged)

public:
    explicit ImageCache(model::ApiObject* api, QObject* parent = nullptr);
    ~ImageCache() override;

    int pending() const;
    int warming() const;
    int warmTotal() const { return m_warm_total; }
    qreal diskMegabytes() const { return m_disk_mb; }

    /// makes the thumbnails of these images (file paths or file: URLs) at the size a tile would ask for,
    /// in the background, so the grids open and scroll without loading anything
    Q_INVOKABLE void warm(const QStringList& urls, int width, int height);
    /// ...for every game's artwork of one kind ("poster": poster or box front, as theme.getAssetSource;
    /// "steam": the wide capsule)
    Q_INVOKABLE void warmLibrary(const QString& kind, int width, int height);
    /// empties the cache (memory and disk); thumbnails are made again as they're shown
    Q_INVOKABLE void clear();
    /// re-reads diskMegabytes
    Q_INVOKABLE void measure();

    /// the provider QML's engine uses (one per engine; the caches are shared)
    static QQuickAsyncImageProvider* createProvider();
    static QString cacheDir();

signals:
    void pendingChanged();
    void diskChanged();

private:
    model::ApiObject* const m_api;
    QTimer* const m_poll;
    int m_last_pending = 0;
    int m_last_warming = 0;
    int m_warm_total = 0;
    qreal m_disk_mb = 0.0;
    QSet<QString> m_warmed; // warmLibrary calls already made (kind, size, library size)
};

} // namespace deckos
