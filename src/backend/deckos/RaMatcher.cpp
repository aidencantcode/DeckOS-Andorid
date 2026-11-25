// DeckOS
// See RaMatcher.h

#include "RaMatcher.h"

#include "Catalog.h"
#include "Log.h"
#include "Paths.h"
#include "model/gaming/Collection.h"
#include "model/gaming/Game.h"
#include "model/gaming/GameFile.h"

#include "rc_consoles.h"
#include "rc_hash.h"

#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QNetworkAccessManager>
#include <QNetworkReply>
#include <QNetworkRequest>
#include <QRunnable>
#include <QSaveFile>
#include <QTimer>
#include <QUrl>
#include <QUrlQuery>

#include "miniz/miniz.h"

#include <climits>
#include <cstdio>
#include <memory>


namespace {
const QString LOGTAG = QStringLiteral("RetroAchievements");

constexpr int LIST_PAGE_SIZE = 500;                 // games per API_GetGameList page (PAGE_SIZE is a system macro on Android)
constexpr qint64 LIST_MAX_AGE_S = 7 * 24 * 3600;    // download a console's hash list again after a week
constexpr qint64 LIST_RETRY_AGE_S = 24 * 3600;      // ...or after a day, when a hash isn't in it
constexpr qint64 MAX_ZIPPED_ROM = 160 * 1024 * 1024; // the game inside a zip is unpacked in memory


// rcheevos reads files through these, so paths work the same everywhere (Unicode paths on Windows too)
void* RC_CCONV file_open(const char* path_utf8)
{
    auto file = new QFile(QString::fromUtf8(path_utf8));
    if (!file->open(QIODevice::ReadOnly)) {
        delete file;
        return nullptr;
    }
    return file;
}
void RC_CCONV file_seek(void* handle, int64_t offset, int origin)
{
    auto file = static_cast<QFile*>(handle);
    const qint64 base = origin == SEEK_CUR ? file->pos() : origin == SEEK_END ? file->size() : 0;
    file->seek(base + offset);
}
int64_t RC_CCONV file_tell(void* handle)
{
    return static_cast<QFile*>(handle)->pos();
}
size_t RC_CCONV file_read(void* handle, void* buffer, size_t requested)
{
    const qint64 got = static_cast<QFile*>(handle)->read(static_cast<char*>(buffer), static_cast<qint64>(requested));
    return got > 0 ? static_cast<size_t>(got) : 0;
}
void RC_CCONV file_close(void* handle)
{
    delete static_cast<QFile*>(handle);
}
void RC_CCONV hash_error(const char* message, const rc_hash_iterator_t* iterator)
{
    if (iterator && iterator->userdata)
        *static_cast<QString*>(iterator->userdata) = QString::fromUtf8(message);
}

int generate(char hash[33], int console_id, const QString& name, const QByteArray* data, QString* error)
{
    const QByteArray name_utf8 = name.toUtf8();
    rc_hash_iterator_t it;
    if (data)
        rc_hash_initialize_iterator(&it, name_utf8.constData(), reinterpret_cast<const uint8_t*>(data->constData()), static_cast<size_t>(data->size()));
    else
        rc_hash_initialize_iterator(&it, name_utf8.constData(), nullptr, 0);
    it.userdata = error;
    it.callbacks.error_message = hash_error;
    it.callbacks.filereader.open = file_open;
    it.callbacks.filereader.seek = file_seek;
    it.callbacks.filereader.tell = file_tell;
    it.callbacks.filereader.read = file_read;
    it.callbacks.filereader.close = file_close;
    const int ok = rc_hash_generate(hash, static_cast<uint32_t>(console_id), &it);
    rc_hash_destroy_iterator(&it);
    return ok;
}

// miniz reads zips through QFile (Unicode paths, same on every platform)
size_t zip_read(void* opaque, mz_uint64 offset, void* buffer, size_t requested)
{
    auto file = static_cast<QFile*>(opaque);
    if (!file->seek(static_cast<qint64>(offset)))
        return 0;
    const qint64 got = file->read(static_cast<char*>(buffer), static_cast<qint64>(requested));
    return got > 0 ? static_cast<size_t>(got) : 0;
}

// systems whose zip files are the game itself for RA (arcade sets are hashed by name, DOS/Arduboy
// read the zip themselves); for everything else the zip is just packing around one ROM
bool zip_is_the_game(int console_id)
{
    return console_id == RC_CONSOLE_ARCADE || console_id == RC_CONSOLE_MS_DOS || console_id == RC_CONSOLE_ARDUBOY;
}

QString list_path(const QString& dir, int console_id)
{
    return dir + QStringLiteral("/console_%1.json").arg(console_id);
}

bool write_json(const QString& path, const QJsonDocument& doc)
{
    QDir().mkpath(QFileInfo(path).absolutePath());
    QSaveFile file(path);
    if (!file.open(QIODevice::WriteOnly))
        return false;
    file.write(doc.toJson(QJsonDocument::Compact));
    return file.commit();
}
} // namespace


namespace deckos {

int ra_console_for(const QString& short_name, const QString& name)
{
    // common Pegasus / ES-DE short names the catalog doesn't know (RA console ids, rc_consoles.h)
    static const QHash<QString, int> fallback {
        { QStringLiteral("snes"), 3 }, { QStringLiteral("superfamicom"), 3 }, { QStringLiteral("sfc"), 3 },
        { QStringLiteral("nes"), 7 }, { QStringLiteral("famicom"), 7 }, { QStringLiteral("fds"), 81 },
        { QStringLiteral("n64"), 2 }, { QStringLiteral("gb"), 4 }, { QStringLiteral("gbc"), 6 },
        { QStringLiteral("gba"), 5 }, { QStringLiteral("nds"), 18 }, { QStringLiteral("ndsi"), 78 },
        { QStringLiteral("3ds"), 62 }, { QStringLiteral("gc"), 16 }, { QStringLiteral("gamecube"), 16 },
        { QStringLiteral("ngc"), 16 }, { QStringLiteral("wii"), 19 }, { QStringLiteral("wiiu"), 20 },
        { QStringLiteral("virtualboy"), 28 }, { QStringLiteral("pokemini"), 24 },
        { QStringLiteral("genesis"), 1 }, { QStringLiteral("megadrive"), 1 }, { QStringLiteral("md"), 1 },
        { QStringLiteral("mastersystem"), 11 }, { QStringLiteral("sms"), 11 },
        { QStringLiteral("gamegear"), 15 }, { QStringLiteral("gg"), 15 },
        { QStringLiteral("saturn"), 39 }, { QStringLiteral("dreamcast"), 40 }, { QStringLiteral("dc"), 40 },
        { QStringLiteral("segacd"), 9 }, { QStringLiteral("megacd"), 9 },
        { QStringLiteral("32x"), 10 }, { QStringLiteral("sega32x"), 10 }, { QStringLiteral("sg1000"), 33 },
        { QStringLiteral("psx"), 12 }, { QStringLiteral("ps1"), 12 }, { QStringLiteral("playstation"), 12 },
        { QStringLiteral("ps2"), 21 }, { QStringLiteral("playstation2"), 21 }, { QStringLiteral("psp"), 41 },
        { QStringLiteral("atari2600"), 25 }, { QStringLiteral("atari5200"), 50 }, { QStringLiteral("atari7800"), 51 },
        { QStringLiteral("lynx"), 13 }, { QStringLiteral("atarilynx"), 13 },
        { QStringLiteral("jaguar"), 17 }, { QStringLiteral("atarijaguar"), 17 }, { QStringLiteral("jaguarcd"), 77 },
        { QStringLiteral("atarist"), 36 },
        { QStringLiteral("pcengine"), 8 }, { QStringLiteral("turbografx"), 8 }, { QStringLiteral("tg16"), 8 },
        { QStringLiteral("pcenginecd"), 76 }, { QStringLiteral("turbografxcd"), 76 }, { QStringLiteral("tgcd"), 76 },
        { QStringLiteral("pcfx"), 49 }, { QStringLiteral("pc8800"), 47 }, { QStringLiteral("pc9800"), 48 },
        { QStringLiteral("ngp"), 14 }, { QStringLiteral("ngpc"), 14 }, { QStringLiteral("neogeocd"), 56 },
        { QStringLiteral("arcade"), 27 }, { QStringLiteral("mame"), 27 }, { QStringLiteral("fbneo"), 27 },
        { QStringLiteral("neogeo"), 27 }, { QStringLiteral("wonderswan"), 53 }, { QStringLiteral("wonderswancolor"), 53 },
        { QStringLiteral("msx"), 29 }, { QStringLiteral("msx2"), 29 }, { QStringLiteral("colecovision"), 44 },
        { QStringLiteral("intellivision"), 45 }, { QStringLiteral("vectrex"), 46 }, { QStringLiteral("3do"), 43 },
        { QStringLiteral("amiga"), 35 }, { QStringLiteral("amstradcpc"), 37 }, { QStringLiteral("appleii"), 38 },
        { QStringLiteral("c64"), 30 }, { QStringLiteral("dos"), 26 }, { QStringLiteral("vic20"), 34 },
        { QStringLiteral("zxspectrum"), 59 }, { QStringLiteral("zx81"), 31 }, { QStringLiteral("x68000"), 52 },
        { QStringLiteral("cdi"), 42 }, { QStringLiteral("oric"), 32 }, { QStringLiteral("ngage"), 61 },
        { QStringLiteral("gameandwatch"), 60 }, { QStringLiteral("uzebox"), 80 }, { QStringLiteral("arduboy"), 71 },
        { QStringLiteral("tic80"), 65 }, { QStringLiteral("wasm4"), 72 }, { QStringLiteral("supervision"), 63 },
        { QStringLiteral("megaduck"), 69 },
        { QStringLiteral("supernintendo"), 3 }, { QStringLiteral("nintendo64"), 2 }, { QStringLiteral("gameboy"), 4 },
        { QStringLiteral("gameboycolor"), 6 }, { QStringLiteral("gameboyadvance"), 5 }, { QStringLiteral("nintendods"), 18 },
        { QStringLiteral("nintendoentertainmentsystem"), 7 }, { QStringLiteral("segagenesis"), 1 },
        { QStringLiteral("segamegadrive"), 1 }, { QStringLiteral("segasaturn"), 39 }, { QStringLiteral("segadreamcast"), 40 },
        { QStringLiteral("sonyplaystation"), 12 }, { QStringLiteral("sonyplaystation2"), 21 },
        { QStringLiteral("playstationportable"), 41 }, { QStringLiteral("sonypsp"), 41 },
    };

    const Catalog& catalog = Catalog::instance();
    for (const QString& candidate : { short_name, name }) {
        if (candidate.trimmed().isEmpty())
            continue;
        const CatalogSystem* sys = catalog.byId(candidate.trimmed().toLower());
        if (!sys)
            sys = catalog.byFolderName(candidate);
        if (sys && sys->raConsoleId > 0)
            return sys->raConsoleId;
        const int known = fallback.value(Catalog::normalized(candidate));
        if (known > 0)
            return known;
    }
    return 0;
}

QString ra_hash_file(const QString& path, int console_id, QString* error)
{
    QString why;
    char hash[33] = {};
    int ok = 0;

    const QString ext = QFileInfo(path).suffix().toLower();
    if (ext == QLatin1String("7z")) {
        why = QStringLiteral("7z archives can't be checked yet - unpack the game or use .zip");
    }
    else if (ext == QLatin1String("zip") && !zip_is_the_game(console_id)) {
        QFile file(path);
        mz_zip_archive zip;
        mz_zip_zero_struct(&zip);
        zip.m_pRead = zip_read;
        zip.m_pIO_opaque = &file;
        if (!file.open(QIODevice::ReadOnly) || !mz_zip_reader_init(&zip, static_cast<mz_uint64>(file.size()), 0)) {
            why = QStringLiteral("the zip file can't be opened");
        }
        else {
            // the game is the biggest file in the zip (others are readmes and such)
            mz_uint best = UINT_MAX;
            mz_uint64 best_size = 0;
            QString best_name;
            const mz_uint count = mz_zip_reader_get_num_files(&zip);
            for (mz_uint i = 0; i < count; i++) {
                mz_zip_archive_file_stat stat;
                if (!mz_zip_reader_file_stat(&zip, i, &stat) || stat.m_is_directory)
                    continue;
                if (best == UINT_MAX || stat.m_uncomp_size > best_size) {
                    best = i;
                    best_size = stat.m_uncomp_size;
                    best_name = QString::fromUtf8(stat.m_filename);
                }
            }
            if (best == UINT_MAX)
                why = QStringLiteral("the zip file is empty");
            else if (best_size > static_cast<mz_uint64>(MAX_ZIPPED_ROM))
                why = QStringLiteral("the game inside the zip is too big to check - unpack it");
            else {
                size_t size = 0;
                void* raw = mz_zip_reader_extract_to_heap(&zip, best, &size, 0);
                if (!raw || size == 0) {
                    why = QStringLiteral("the game inside the zip can't be unpacked");
                }
                else {
                    const QByteArray data = QByteArray::fromRawData(static_cast<const char*>(raw), static_cast<int>(size));
                    ok = generate(hash, console_id, QFileInfo(best_name).fileName(), &data, &why);
                }
                mz_free(raw);
            }
            mz_zip_reader_end(&zip);
        }
    }
    else {
        ok = generate(hash, console_id, path, nullptr, &why);
    }

    if (!ok || hash[0] == '\0') {
        if (error)
            *error = why.isEmpty() ? QStringLiteral("this file can't be checked") : why;
        return {};
    }
    return QString::fromLatin1(hash).toLower();
}


RaMatcher::RaMatcher(QObject* parent)
    : RaMatcher(paths::writableConfigDir() + QStringLiteral("/deckos/ra"), parent)
{}

RaMatcher::RaMatcher(const QString& cache_dir, QObject* parent)
    : QObject(parent)
    , m_dir(cache_dir)
    , m_net(new QNetworkAccessManager(this))
    , m_save_timer(new QTimer(this))
{
    // one ROM at a time: gentler on the SD card and the battery than hashing a library in parallel
    m_pool.setMaxThreadCount(1);
    m_save_timer->setSingleShot(true);
    m_save_timer->setInterval(2000);
    connect(m_save_timer, &QTimer::timeout, this, &RaMatcher::saveRomHashes);
}

RaMatcher::~RaMatcher()
{
    // a hash still running posts its result to this object; let it end while the object is whole
    m_pool.clear();
    m_pool.waitForDone();
    if (m_save_timer->isActive())
        saveRomHashes();
}

int RaMatcher::consoleOf(QObject* obj) const
{
    auto game = qobject_cast<model::Game*>(obj);
    if (!game)
        return 0;
    const auto& collections = game->collectionsModel()->entries();
    for (const model::Collection* coll : collections) {
        const int id = ra_console_for(coll->shortName(), coll->name());
        if (id > 0)
            return id;
    }
    return 0;
}

void RaMatcher::identify(QObject* obj, const QString& api_key)
{
    auto game = qobject_cast<model::Game*>(obj);
    if (!game)
        return;

    Request req;
    req.game = obj;
    req.key = api_key.trimmed();
    req.console = consoleOf(obj);
    if (req.console <= 0) {
        emit identified(obj, 0, {}, QStringLiteral("unsupported"), tr("RetroAchievements doesn't cover this game's system"));
        return;
    }

    const auto& files = game->filesModel()->entries();
    const QFileInfo finfo = files.empty() ? QFileInfo() : files.front()->fileinfo();
    if (finfo.filePath().isEmpty() || !finfo.isFile()) {
        emit identified(obj, 0, {}, QStringLiteral("unsupported"), tr("There's no game file to check"));
        return;
    }
    const QString path = finfo.absoluteFilePath();
    const qint64 size = finfo.size();
    const qint64 mtime = finfo.lastModified().toMSecsSinceEpoch();

    loadRomHashes();
    const auto known = m_rom_hashes.constFind(path);
    if (known != m_rom_hashes.cend() && known->size == size && known->mtime == mtime && known->console == req.console) {
        req.hash = known->hash;
        lookup(req);
        return;
    }

    // hashing a disc image can take a few seconds: do it off the UI thread
    QVector<Request>& queue = m_hash_waiting[path];
    queue.append(req);
    if (queue.size() > 1)
        return; // already being hashed for another request

    const int console = req.console;
    m_pool.start(QRunnable::create([this, path, console, size, mtime]() {
        QString error;
        RomHash entry;
        entry.size = size;
        entry.mtime = mtime;
        entry.console = console;
        entry.hash = ra_hash_file(path, console, &error);
        QMetaObject::invokeMethod(this, [this, path, entry, error]() { onHashed(path, entry, error); }, Qt::QueuedConnection);
    }));
}

void RaMatcher::onHashed(const QString& path, const RomHash& entry, const QString& error)
{
    const QVector<Request> waiting = m_hash_waiting.take(path);
    if (entry.hash.isEmpty()) {
        Log::info(LOGTAG, LOGMSG("Can't hash `%1`: %2").arg(path, error));
        for (const Request& req : waiting) {
            if (req.game)
                emit identified(req.game, 0, {}, QStringLiteral("unsupported"), error);
        }
        return;
    }

    m_rom_hashes.insert(path, entry);
    m_save_timer->start();
    for (Request req : waiting) {
        req.hash = entry.hash;
        lookup(req);
    }
}

void RaMatcher::lookup(const Request& req)
{
    if (m_waiting.contains(req.console)) { // its list is being downloaded
        m_waiting[req.console].append(req);
        return;
    }

    const ConsoleList& known = list(req.console);
    const QDateTime now = QDateTime::currentDateTimeUtc();
    const qint64 age = known.fetched.isValid() ? known.fetched.secsTo(now) : -1;
    const bool stale = age < 0 || age > LIST_MAX_AGE_S;
    const bool worth_retry = !known.games.contains(req.hash) && age > LIST_RETRY_AGE_S; // a set added since?
    if ((stale || worth_retry) && !req.key.isEmpty() && !m_downloaded.contains(req.console)) {
        m_waiting[req.console].append(req);
        download(req.console, req.key);
        return;
    }
    finish(req);
}

void RaMatcher::finish(const Request& req)
{
    if (!req.game)
        return;
    const ConsoleList& known = list(req.console);
    const auto it = known.games.constFind(req.hash);
    if (it != known.games.cend())
        emit identified(req.game, it->first, it->second, QStringLiteral("hash"), req.hash);
    else if (!known.fetched.isValid())
        emit identified(req.game, 0, {}, QStringLiteral("offline"), tr("RetroAchievements' game list couldn't be loaded"));
    else
        emit identified(req.game, 0, {}, QStringLiteral("unknown"), req.hash);
}


// --- RA's hash lists --------------------------------------------------------------------------------

void RaMatcher::download(int console, const QString& key)
{
    m_downloaded.insert(console); // once per run, even if it fails: never hammer the API
    downloadPage(console, key, 0, std::make_shared<QHash<QString, QPair<int, QString>>>());
}

void RaMatcher::downloadPage(int console, const QString& key, int offset,
                             std::shared_ptr<QHash<QString, QPair<int, QString>>> games)
{
    QUrlQuery query;
    query.addQueryItem(QStringLiteral("i"), QString::number(console));
    query.addQueryItem(QStringLiteral("f"), QStringLiteral("1")); // only games that have achievements
    query.addQueryItem(QStringLiteral("h"), QStringLiteral("1")); // with the hashes of their dumps
    query.addQueryItem(QStringLiteral("o"), QString::number(offset));
    query.addQueryItem(QStringLiteral("c"), QString::number(LIST_PAGE_SIZE));
    query.addQueryItem(QStringLiteral("y"), key);
    QUrl url(QStringLiteral("https://retroachievements.org/API/API_GetGameList.php"));
    url.setQuery(query);

    QNetworkRequest request(url);
    request.setHeader(QNetworkRequest::UserAgentHeader, QStringLiteral("DeckOS (Pegasus Frontend fork)"));
    request.setAttribute(QNetworkRequest::RedirectPolicyAttribute, QNetworkRequest::NoLessSafeRedirectPolicy);
    request.setTransferTimeout(30000);
    QNetworkReply* reply = m_net->get(request);

    connect(reply, &QNetworkReply::finished, this, [this, reply, console, key, offset, games]() {
        reply->deleteLater();
        const int http = reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
        const QJsonDocument doc = QJsonDocument::fromJson(reply->readAll());
        if (reply->error() != QNetworkReply::NoError || !doc.isArray()) {
            // the URL holds the API key: never log it
            Log::warning(LOGTAG, LOGMSG("Couldn't load the game list of console %1 (HTTP %2)").arg(console).arg(http));
            listDownloaded(console, nullptr);
            return;
        }

        const QJsonArray page = doc.array();
        for (const QJsonValue& val : page) {
            const QJsonObject game = val.toObject();
            const int id = game.value(QStringLiteral("ID")).toInt();
            const QString title = game.value(QStringLiteral("Title")).toString();
            for (const QJsonValue& hash : game.value(QStringLiteral("Hashes")).toArray())
                games->insert(hash.toString().toLower(), { id, title });
        }
        if (page.size() >= LIST_PAGE_SIZE && offset < 100000) {
            downloadPage(console, key, offset + LIST_PAGE_SIZE, games);
            return;
        }
        listDownloaded(console, games.get());
    });
}

void RaMatcher::listDownloaded(int console, const QHash<QString, QPair<int, QString>>* games)
{
    if (games) {
        ConsoleList& known = list(console);
        known.games = *games;
        known.fetched = QDateTime::currentDateTimeUtc();
        saveList(console);
        Log::info(LOGTAG, LOGMSG("Game list of console %1: %2 known dumps").arg(console).arg(games->size()));
    }
    const QVector<Request> waiting = m_waiting.take(console);
    for (const Request& req : waiting)
        finish(req);
}

RaMatcher::ConsoleList& RaMatcher::list(int console)
{
    ConsoleList& known = m_lists[console];
    if (known.loaded)
        return known;
    known.loaded = true;

    QFile file(list_path(m_dir, console));
    if (!file.open(QIODevice::ReadOnly))
        return known;
    const QJsonObject root = QJsonDocument::fromJson(file.readAll()).object();
    known.fetched = QDateTime::fromString(root.value(QStringLiteral("fetched")).toString(), Qt::ISODate);
    const QJsonObject games = root.value(QStringLiteral("games")).toObject();
    for (auto it = games.begin(); it != games.end(); ++it) {
        const QJsonArray entry = it.value().toArray();
        known.games.insert(it.key(), { entry.at(0).toInt(), entry.at(1).toString() });
    }
    return known;
}

void RaMatcher::saveList(int console) const
{
    const auto known = m_lists.constFind(console);
    if (known == m_lists.cend())
        return;
    QJsonObject games;
    for (auto it = known->games.cbegin(); it != known->games.cend(); ++it)
        games.insert(it.key(), QJsonArray { it->first, it->second });
    QJsonObject root;
    root.insert(QStringLiteral("fetched"), known->fetched.toString(Qt::ISODate));
    root.insert(QStringLiteral("games"), games);
    if (!write_json(list_path(m_dir, console), QJsonDocument(root)))
        Log::warning(LOGTAG, LOGMSG("Couldn't save the game list of console %1").arg(console));
}


// --- ROM hash cache ---------------------------------------------------------------------------------

void RaMatcher::loadRomHashes()
{
    if (m_rom_hashes_loaded)
        return;
    m_rom_hashes_loaded = true;

    QFile file(m_dir + QStringLiteral("/rom_hashes.json"));
    if (!file.open(QIODevice::ReadOnly))
        return;
    const QJsonObject root = QJsonDocument::fromJson(file.readAll()).object();
    for (auto it = root.begin(); it != root.end(); ++it) {
        const QJsonArray val = it.value().toArray(); // [size, modified (ms), console, hash]
        RomHash entry;
        entry.size = static_cast<qint64>(val.at(0).toDouble());
        entry.mtime = static_cast<qint64>(val.at(1).toDouble());
        entry.console = val.at(2).toInt();
        entry.hash = val.at(3).toString();
        if (!entry.hash.isEmpty())
            m_rom_hashes.insert(it.key(), entry);
    }
}

void RaMatcher::saveRomHashes() const
{
    QJsonObject root;
    for (auto it = m_rom_hashes.cbegin(); it != m_rom_hashes.cend(); ++it) {
        root.insert(it.key(), QJsonArray {
            static_cast<double>(it->size), static_cast<double>(it->mtime), it->console, it->hash });
    }
    if (!write_json(m_dir + QStringLiteral("/rom_hashes.json"), QJsonDocument(root)))
        Log::warning(LOGTAG, LOGMSG("Couldn't save the ROM hash cache"));
}

} // namespace deckos
