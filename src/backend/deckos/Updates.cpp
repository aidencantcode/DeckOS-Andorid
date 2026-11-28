// DeckOS
// See Updates.h

#include "Updates.h"

#include "Log.h"
#include "Paths.h"

#include <QCoreApplication>
#include <QDateTime>
#include <QDesktopServices>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QJsonDocument>
#include <QJsonObject>
#include <QNetworkAccessManager>
#include <QNetworkReply>
#include <QNetworkRequest>
#include <QRegularExpression>
#include <QSaveFile>
#include <QStandardPaths>
#include <QTimer>
#include <QUrl>

#ifdef Q_OS_ANDROID
#include <QtAndroidExtras/QtAndroid>
#include <QtAndroidExtras/QAndroidJniObject>
#endif

#include <algorithm>


namespace {
constexpr qint64 MINUTE = 60 * 1000;
constexpr qint64 AUTO_EVERY = 12 * 60 * MINUTE;
constexpr qint64 FORCE_EVERY = 10 * MINUTE;
const QString APP_ID = QStringLiteral("app");
const QString REPO = QStringLiteral("aidencantcode/DeckOS-Andorid");
#ifdef Q_OS_ANDROID
constexpr auto JNI_PACKAGES = "com/deckos/media/Packages";
#endif

qint64 now_ms() { return QDateTime::currentMSecsSinceEpoch(); }

QString state_path() { return paths::writableConfigDir() + QStringLiteral("/deckos/updates.json"); }

QString download_dir()
{
    return QStandardPaths::writableLocation(QStandardPaths::CacheLocation) + QStringLiteral("/updates");
}

QString version_of(const QString& tag)
{
    static const QRegularExpression rx(QStringLiteral("(\\d+(?:\\.\\d+)*)"));
    const QRegularExpressionMatch m = rx.match(tag);
    return m.hasMatch() ? m.captured(1) : tag;
}

qint64 iso_ms(const QString& s)
{
    const QDateTime t = QDateTime::fromString(s, Qt::ISODate);
    return t.isValid() ? t.toMSecsSinceEpoch() : 0;
}

int device_sdk()
{
#ifdef Q_OS_ANDROID
    return QtAndroid::androidSdkVersion();
#else
    return 99;
#endif
}

#ifdef Q_OS_ANDROID
QString own_package()
{
#ifdef Q_OS_ANDROID
    return QtAndroid::androidContext().callObjectMethod("getPackageName", "()Ljava/lang/String;").toString();
#else
    return QString();
#endif
}
#endif

QString human_size(qint64 bytes)
{
    if (bytes <= 0) return QString();
    return QString::number(bytes / (1024.0 * 1024.0), 'f', 1) + QStringLiteral(" MB");
}
} // namespace


namespace deckos {

Updates::Updates(QObject* parent)
    : QObject(parent)
    , m_net(new QNetworkAccessManager(this))
    , m_timer(new QTimer(this))
    , m_save_timer(new QTimer(this))
{
    m_app.package = APP_ID;
    m_app.name = QStringLiteral("DeckOS");
    m_save_timer->setSingleShot(true);
    m_save_timer->setInterval(1000);
    connect(m_save_timer, &QTimer::timeout, this, &Updates::saveState);

    loadCatalog();
    loadState();
    refreshInstalled();

    // by itself: a while after start, then every hour whether 12 hours have passed
    m_timer->setInterval(60 * MINUTE);
    connect(m_timer, &QTimer::timeout, this, [this]() {
        if (m_auto && now_ms() - m_last_check > AUTO_EVERY)
            check(false);
    });
    m_timer->start();
    QTimer::singleShot(20000, this, [this]() {
        if (m_auto && now_ms() - m_last_check > AUTO_EVERY)
            check(false);
    });
}

Updates::~Updates()
{
    for (QFile* f : qAsConst(m_files)) {
        f->close();
        f->remove();
        delete f;
    }
    if (m_save_timer->isActive())
        saveState();
}

QString Updates::appVersion() const
{
    return version_of(QCoreApplication::applicationVersion());
}

QString Updates::repo() const { return REPO; }

bool Updates::privileged() const
{
#ifdef Q_OS_ANDROID
    return QAndroidJniObject::callStaticMethod<jboolean>("com/deckos/ingame/Session", "privilegedAvailable", "()Z");
#else
    return false;
#endif
}

bool Updates::canInstall() const
{
#ifdef Q_OS_ANDROID
    return QAndroidJniObject::callStaticMethod<jboolean>(JNI_PACKAGES, "canInstall", "(Landroid/content/Context;)Z",
                                                         QtAndroid::androidContext().object());
#else
    return false;
#endif
}

void Updates::setAutoCheck(bool on)
{
    if (on == m_auto) return;
    m_auto = on;
    emit settingsChanged();
    m_save_timer->start();
}

void Updates::setSilentInstall(bool on)
{
    if (on == m_silent) return;
    m_silent = on;
    emit settingsChanged();
    m_save_timer->start();
}

void Updates::openInstallSettings()
{
#ifdef Q_OS_ANDROID
    QAndroidJniObject::callStaticMethod<void>(JNI_PACKAGES, "openInstallSettings", "(Landroid/content/Context;)V",
                                              QtAndroid::androidContext().object());
#endif
    QTimer::singleShot(5000, this, &Updates::settingsChanged);
}


// --- catalog and saved state -------------------------------------------------------------------------

void Updates::loadCatalog()
{
    QFile f(QStringLiteral(":/deckos/catalog/emulator-sources.json"));
    if (!f.open(QIODevice::ReadOnly)) {
        Log::warning(LOGMSG("Updates: the emulator sources aren't there"));
        return;
    }
    for (const QJsonValue& v : QJsonDocument::fromJson(f.readAll()).object().value(QStringLiteral("emulators")).toArray()) {
        const QJsonObject o = v.toObject();
        Entry e;
        e.package = o.value(QStringLiteral("package")).toString();
        e.name = o.value(QStringLiteral("name")).toString(e.package);
        e.github = o.value(QStringLiteral("github")).toString();
        e.asset = o.value(QStringLiteral("asset")).toString();
        e.versionFrom = o.value(QStringLiteral("versionFrom")).toString();
        e.urlTemplate = o.value(QStringLiteral("url")).toString();
        e.page = o.value(QStringLiteral("page")).toString();
        if (e.page.isEmpty() && !e.github.isEmpty())
            e.page = QStringLiteral("https://github.com/") + e.github + QStringLiteral("/releases");
        if (!e.package.isEmpty())
            m_entries.append(e);
    }
}

void Updates::loadState()
{
    QFile f(state_path());
    if (!f.open(QIODevice::ReadOnly))
        return;
    const QJsonObject o = QJsonDocument::fromJson(f.readAll()).object();
    m_auto = o.value(QStringLiteral("autoCheck")).toBool(true);
    m_silent = o.value(QStringLiteral("silentInstall")).toBool(false);
    m_last_check = qint64(o.value(QStringLiteral("lastCheck")).toDouble());
    m_downloads = o.value(QStringLiteral("downloads")).toArray().toVariantList();
    const QJsonObject latest = o.value(QStringLiteral("latest")).toObject();
    auto restore = [&latest](Entry& e) {
        const QJsonObject l = latest.value(e.package).toObject();
        if (l.isEmpty()) return;
        e.latest = l.value(QStringLiteral("latest")).toString();
        e.downloadUrl = l.value(QStringLiteral("url")).toString();
        e.notes = l.value(QStringLiteral("notes")).toString();
        e.published = qint64(l.value(QStringLiteral("published")).toDouble());
        e.size = qint64(l.value(QStringLiteral("size")).toDouble());
    };
    restore(m_app);
    for (Entry& e : m_entries)
        restore(e);
    // a download that was still running when DeckOS closed didn't finish
    for (QVariant& d : m_downloads) {
        QVariantMap m = d.toMap();
        if (m.value(QStringLiteral("state")).toString() == QLatin1String("downloading")) {
            m.insert(QStringLiteral("state"), QStringLiteral("error"));
            m.insert(QStringLiteral("error"), QStringLiteral("Stopped when DeckOS closed"));
            d = m;
        }
    }
}

void Updates::saveState()
{
    QJsonObject latest;
    auto keep = [&latest](const Entry& e) {
        if (e.latest.isEmpty()) return;
        latest.insert(e.package, QJsonObject{
            { QStringLiteral("latest"), e.latest }, { QStringLiteral("url"), e.downloadUrl },
            { QStringLiteral("notes"), e.notes }, { QStringLiteral("published"), double(e.published) },
            { QStringLiteral("size"), double(e.size) } });
    };
    keep(m_app);
    for (const Entry& e : qAsConst(m_entries))
        keep(e);
    QJsonObject o;
    o.insert(QStringLiteral("autoCheck"), m_auto);
    o.insert(QStringLiteral("silentInstall"), m_silent);
    o.insert(QStringLiteral("lastCheck"), double(m_last_check));
    o.insert(QStringLiteral("downloads"), QJsonArray::fromVariantList(m_downloads.mid(0, 30)));
    o.insert(QStringLiteral("latest"), latest);
    QDir().mkpath(QFileInfo(state_path()).absolutePath());
    QSaveFile f(state_path());
    if (f.open(QIODevice::WriteOnly)) {
        f.write(QJsonDocument(o).toJson(QJsonDocument::Compact));
        f.commit();
    }
}

void Updates::refreshInstalled()
{
#ifdef Q_OS_ANDROID
    const QAndroidJniObject ctx = QtAndroid::androidContext();
    for (Entry& e : m_entries) {
        const QString json = QAndroidJniObject::callStaticObjectMethod(
            JNI_PACKAGES, "info", "(Landroid/content/Context;Ljava/lang/String;)Ljava/lang/String;",
            ctx.object(), QAndroidJniObject::fromString(e.package).object<jstring>()).toString();
        const QJsonObject o = QJsonDocument::fromJson(json.toUtf8()).object();
        e.installed = o.value(QStringLiteral("installed")).toBool();
        e.installedVersion = o.value(QStringLiteral("version")).toString();
        e.installer = o.value(QStringLiteral("installer")).toString();
        e.installedAt = qint64(o.value(QStringLiteral("updated")).toDouble());
    }
#endif
    m_app.installed = true;
    m_app.installedVersion = appVersion();
}

Updates::Entry* Updates::entry(const QString& id)
{
    if (id == APP_ID)
        return &m_app;
    for (Entry& e : m_entries)
        if (e.package == id)
            return &e;
    return nullptr;
}

int Updates::compareVersions(const QString& a, const QString& b)
{
    static const QRegularExpression num(QStringLiteral("\\d+"));
    QList<qint64> x, y;
    for (auto it = num.globalMatch(a); it.hasNext();) x.append(it.next().captured(0).toLongLong());
    for (auto it = num.globalMatch(b); it.hasNext();) y.append(it.next().captured(0).toLongLong());
    const int n = std::max(x.size(), y.size());
    for (int i = 0; i < n; ++i) {
        const qint64 p = i < x.size() ? x[i] : 0, q = i < y.size() ? y[i] : 0;
        if (p != q)
            return p < q ? -1 : 1;
    }
    return 0;
}

QVariantMap Updates::toMap(const Entry& e) const
{
    const bool store = e.installer == QLatin1String("com.android.vending");
    const bool downloadable = !e.downloadUrl.isEmpty();
    bool update = false;
    if (e.installed && !e.latest.isEmpty()) {
        const bool numbers = e.installedVersion.contains(QRegularExpression(QStringLiteral("\\d")));
        update = numbers ? compareVersions(e.installedVersion, e.latest) < 0
                         : (e.published > 0 && e.installedAt > 0 && e.published > e.installedAt + 24 * 3600 * 1000LL);
    }
    QVariantMap m;
    m.insert(QStringLiteral("package"), e.package);
    m.insert(QStringLiteral("name"), e.name);
    m.insert(QStringLiteral("installed"), e.installed);
    m.insert(QStringLiteral("installedVersion"), e.installedVersion);
    m.insert(QStringLiteral("latest"), e.latest);
    m.insert(QStringLiteral("update"), update);
    m.insert(QStringLiteral("fromStore"), store);
    m.insert(QStringLiteral("canInstall"), downloadable && !store);
    m.insert(QStringLiteral("page"), e.page);
    m.insert(QStringLiteral("notes"), e.notes);
    m.insert(QStringLiteral("size"), human_size(e.size));
    m.insert(QStringLiteral("date"), e.published);
    m.insert(QStringLiteral("state"), e.state);
    m.insert(QStringLiteral("progress"), e.progress);
    m.insert(QStringLiteral("error"), e.error);
    return m;
}

QVariantMap Updates::app() const
{
    QVariantMap m = toMap(m_app);
    m.insert(QStringLiteral("installedVersion"), appVersion());
    return m;
}

QVariantList Updates::emulators() const
{
    QVariantList out;
    for (const Entry& e : m_entries)
        out.append(toMap(e));
    // installed first, then by name
    std::stable_sort(out.begin(), out.end(), [](const QVariant& a, const QVariant& b) {
        const QVariantMap x = a.toMap(), y = b.toMap();
        if (x.value(QStringLiteral("installed")).toBool() != y.value(QStringLiteral("installed")).toBool())
            return x.value(QStringLiteral("installed")).toBool();
        return x.value(QStringLiteral("name")).toString().compare(y.value(QStringLiteral("name")).toString(), Qt::CaseInsensitive) < 0;
    });
    return out;
}

QVariantList Updates::emulatorUpdates() const
{
    QVariantList out;
    for (const Entry& e : m_entries) {
        const QVariantMap m = toMap(e);
        if (m.value(QStringLiteral("update")).toBool())
            out.append(m);
    }
    return out;
}

void Updates::emitFor(const QString& id)
{
    if (id == APP_ID) {
        emit appChanged();
    }
    else {
        emit emulatorsChanged();
        emit emulatorUpdatesChanged();
    }
}


// --- checking ----------------------------------------------------------------------------------------

QNetworkReply* Updates::githubGet(const QString& path)
{
    QNetworkRequest request(QUrl(QStringLiteral("https://api.github.com/") + path));
    request.setRawHeader("Accept", "application/vnd.github+json");
    request.setRawHeader("User-Agent", QByteArrayLiteral("DeckOS/") + appVersion().toUtf8());
    request.setAttribute(QNetworkRequest::RedirectPolicyAttribute, QNetworkRequest::NoLessSafeRedirectPolicy);
    request.setTransferTimeout(20000);
    if (m_pending++ == 0)
        emit checkingChanged();
    return m_net->get(request);
}

void Updates::done(QNetworkReply* reply, const QString& failure)
{
    if (reply) reply->deleteLater();
    if (!failure.isEmpty())
        m_error = failure;
    m_pending = std::max(0, m_pending - 1);
    if (m_pending == 0) {
        m_last_check = now_ms();
        m_save_timer->start();
        const int count = emulatorUpdates().size() + (app().value(QStringLiteral("update")).toBool() ? 1 : 0);
        if (count > 0 && !m_had_updates)
            emit notice(QStringLiteral("Updates available"),
                        count == 1 ? QStringLiteral("1 update in Settings › Updates") : QString::number(count) + QStringLiteral(" updates in Settings › Updates"));
        m_had_updates = count > 0;
    }
    emit checkingChanged();
}

void Updates::check(bool force)
{
    m_error.clear();
    refreshInstalled();
    emit emulatorsChanged();
    emit emulatorUpdatesChanged();
    fetchApp(force);
    for (Entry& e : m_entries)
        fetchEntry(e, force);
    if (m_pending == 0)
        emit checkingChanged();
}

void Updates::fetchApp(bool force)
{
    const QString key = QStringLiteral("app");
    if (!force && now_ms() - m_fetched.value(key, 0) < FORCE_EVERY)
        return;
    if (force && now_ms() - m_fetched.value(key, 0) < 15 * 1000)
        return; // pressed twice
    m_fetched.insert(key, now_ms());
    QNetworkReply* reply = githubGet(QStringLiteral("repos/") + REPO + QStringLiteral("/releases?per_page=10"));
    connect(reply, &QNetworkReply::finished, this, [this, reply]() {
        const int status = reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
        if (reply->error() != QNetworkReply::NoError) {
            done(reply, status == 404 ? QStringLiteral("DeckOS's repository can't be reached (it may be private now)")
                       : status == 403 ? QStringLiteral("GitHub's hourly limit for checks was reached: try again in a while")
                       : QStringLiteral("No connection to GitHub"));
            return;
        }
        // the newest release (DeckOS's are pre-releases) with an arm64 APK
        QString best, url, notes;
        qint64 published = 0, size = 0;
        for (const QJsonValue& v : QJsonDocument::fromJson(reply->readAll()).array()) {
            const QJsonObject r = v.toObject();
            if (r.value(QStringLiteral("draft")).toBool())
                continue;
            const QString version = version_of(r.value(QStringLiteral("tag_name")).toString());
            if (!best.isEmpty() && compareVersions(version, best) <= 0)
                continue;
            for (const QJsonValue& a : r.value(QStringLiteral("assets")).toArray()) {
                const QJsonObject asset = a.toObject();
                const QString name = asset.value(QStringLiteral("name")).toString();
                if (name.endsWith(QLatin1String("_arm64.apk"))) {
                    best = version;
                    url = asset.value(QStringLiteral("browser_download_url")).toString();
                    size = qint64(asset.value(QStringLiteral("size")).toDouble());
                    published = iso_ms(r.value(QStringLiteral("published_at")).toString());
                    notes = r.value(QStringLiteral("body")).toString().left(6000);
                    break;
                }
            }
        }
        if (!best.isEmpty()) {
            m_app.latest = best;
            m_app.downloadUrl = url;
            m_app.notes = notes;
            m_app.published = published;
            m_app.size = size;
            emit appChanged();
        }
        done(reply);
    });
}

void Updates::fetchEntry(Entry& e, bool force)
{
    const QString repo = !e.github.isEmpty() ? e.github : e.versionFrom;
    if (repo.isEmpty())
        return; // a page only
    const QString key = e.package;
    if (!force && now_ms() - m_fetched.value(key, 0) < FORCE_EVERY)
        return;
    if (force && now_ms() - m_fetched.value(key, 0) < 15 * 1000)
        return;
    m_fetched.insert(key, now_ms());
    const bool versioned = e.github.isEmpty();
    QNetworkReply* reply = githubGet(QStringLiteral("repos/") + repo + (versioned ? QStringLiteral("/releases/latest")
                                                                                  : QStringLiteral("/releases?per_page=8")));
    const QString id = e.package;
    connect(reply, &QNetworkReply::finished, this, [this, reply, id, versioned]() {
        const int status = reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
        if (reply->error() != QNetworkReply::NoError) {
            done(reply, status == 403 ? QStringLiteral("GitHub's hourly limit for checks was reached: try again in a while")
                                      : QString());
            return;
        }
        const QJsonDocument doc = QJsonDocument::fromJson(reply->readAll());
        if (versioned) {
            Entry* e = entry(id);
            const QJsonObject r = doc.object();
            const QString version = version_of(r.value(QStringLiteral("tag_name")).toString());
            if (e && !version.isEmpty()) {
                e->latest = version;
                e->downloadUrl = QString(e->urlTemplate).replace(QLatin1String("{version_}"), QString(version).replace(QLatin1Char('.'), QLatin1Char('_')))
                                                        .replace(QLatin1String("{version}"), version);
                e->published = iso_ms(r.value(QStringLiteral("published_at")).toString());
                e->notes = r.value(QStringLiteral("body")).toString().left(4000);
                e->size = 0;
                emitFor(id);
            }
        }
        else {
            applyRelease(id, doc.array());
        }
        done(reply);
    });
}

void Updates::applyRelease(const QString& id, const QJsonArray& releases)
{
    Entry* e = entry(id);
    if (!e)
        return;
    const QRegularExpression rx(e->asset, QRegularExpression::CaseInsensitiveOption);
    const int sdk = device_sdk();
    for (const QJsonValue& v : releases) {
        const QJsonObject r = v.toObject();
        if (r.value(QStringLiteral("draft")).toBool() || r.value(QStringLiteral("prerelease")).toBool())
            continue;
        // the matching APK; several (one per Android version, "sdk30"...): the newest the device can run
        QJsonObject pick;
        int pickSdk = -1;
        for (const QJsonValue& a : r.value(QStringLiteral("assets")).toArray()) {
            const QJsonObject asset = a.toObject();
            const QRegularExpressionMatch m = rx.match(asset.value(QStringLiteral("name")).toString());
            if (!m.hasMatch())
                continue;
            const int need = m.lastCapturedIndex() >= 1 ? m.captured(1).toInt() : 0;
            if (need > sdk)
                continue;
            if (need > pickSdk) {
                pick = asset;
                pickSdk = need;
            }
        }
        if (pick.isEmpty())
            continue;
        const QString tag = r.value(QStringLiteral("tag_name")).toString();
        e->latest = version_of(tag).isEmpty() ? tag : version_of(tag);
        e->downloadUrl = pick.value(QStringLiteral("browser_download_url")).toString();
        e->size = qint64(pick.value(QStringLiteral("size")).toDouble());
        e->published = iso_ms(r.value(QStringLiteral("published_at")).toString());
        e->notes = r.value(QStringLiteral("body")).toString().left(4000);
        emitFor(id);
        return;
    }
}

void Updates::onAppActive()
{
    refreshInstalled();
    bool changed = false;
    for (Entry& e : m_entries) {
        if (e.state == QLatin1String("installing") && e.installed && compareVersions(e.installedVersion, e.latest) >= 0) {
            e.state = QStringLiteral("installed");
            e.error.clear();
            if (!e.file.isEmpty()) QFile::remove(e.file);
            recordDownload(e.package, e.name, QStringLiteral("installed"), e.size, e.size, QString(), QString());
            emit notice(e.name + QStringLiteral(" updated"), QStringLiteral("Version ") + e.installedVersion + QStringLiteral(" is installed"));
            changed = true;
        }
    }
    if (changed) {
        emit emulatorsChanged();
        emit emulatorUpdatesChanged();
    }
    emit settingsChanged(); // "Install unknown apps" may have been allowed meanwhile
}


// --- downloading and installing ----------------------------------------------------------------------

void Updates::updateApp()
{
    if (m_app.latest.isEmpty() || compareVersions(appVersion(), m_app.latest) >= 0)
        return;
    if (m_app.state == QLatin1String("ready") && QFileInfo::exists(m_app.file)) {
        install(APP_ID);
        return;
    }
    startDownload(APP_ID);
}

void Updates::updateEmulator(const QString& package)
{
    Entry* e = entry(package);
    if (!e)
        return;
    const QVariantMap m = toMap(*e);
    if (!m.value(QStringLiteral("canInstall")).toBool()) {
        openPage(package);
        return;
    }
    if (e->state == QLatin1String("downloading"))
        return;
    if (e->state == QLatin1String("ready") && QFileInfo::exists(e->file)) {
        install(package);
        return;
    }
    startDownload(package);
}

void Updates::openPage(const QString& package)
{
    Entry* e = entry(package);
    if (!e)
        return;
#ifdef Q_OS_ANDROID
    if (e->installer == QLatin1String("com.android.vending") || e->page.contains(QLatin1String("play.google.com"))) {
        QAndroidJniObject::callStaticMethod<void>(JNI_PACKAGES, "openStorePage", "(Landroid/content/Context;Ljava/lang/String;)V",
                                                  QtAndroid::androidContext().object(),
                                                  QAndroidJniObject::fromString(package).object<jstring>());
        return;
    }
#endif
    if (!e->page.isEmpty())
        QDesktopServices::openUrl(QUrl(e->page));
}

void Updates::setState(const QString& id, const QString& state, const QString& error)
{
    Entry* e = entry(id);
    if (!e) return;
    e->state = state;
    e->error = error;
    emitFor(id);
}

void Updates::recordDownload(const QString& id, const QString& name, const QString& state, qint64 bytes, qint64 total,
                             const QString& file, const QString& error)
{
    QVariantMap m;
    m.insert(QStringLiteral("id"), id);
    m.insert(QStringLiteral("name"), name);
    m.insert(QStringLiteral("state"), state);
    m.insert(QStringLiteral("bytes"), bytes);
    m.insert(QStringLiteral("total"), total);
    m.insert(QStringLiteral("progress"), total > 0 ? qreal(bytes) / total : 0.0);
    m.insert(QStringLiteral("time"), now_ms());
    m.insert(QStringLiteral("file"), file);
    m.insert(QStringLiteral("error"), error);
    // one row per thing: the newest state replaces the running one
    for (int i = 0; i < m_downloads.size(); ++i) {
        const QVariantMap old = m_downloads[i].toMap();
        if (old.value(QStringLiteral("id")).toString() == id
            && (old.value(QStringLiteral("state")).toString() == QLatin1String("downloading")
                || old.value(QStringLiteral("state")).toString() == QLatin1String("ready")
                || state == QLatin1String("installed"))) {
            m_downloads.removeAt(i);
            break;
        }
    }
    m_downloads.prepend(m);
    while (m_downloads.size() > 30)
        m_downloads.removeLast();
    emit downloadsChanged();
    m_save_timer->start();
}

void Updates::startDownload(const QString& id)
{
    Entry* e = entry(id);
    if (!e || e->downloadUrl.isEmpty() || (m_active.contains(id) && m_active.value(id)))
        return;
    QDir().mkpath(download_dir());
    QString name = (id == APP_ID ? QStringLiteral("DeckOS") : e->package) + QLatin1Char('-') + e->latest + QStringLiteral(".apk");
    name.replace(QRegularExpression(QStringLiteral("[^A-Za-z0-9._-]")), QStringLiteral("_"));
    const QString path = download_dir() + QLatin1Char('/') + name;
    auto* file = new QFile(path + QStringLiteral(".part"));
    if (!file->open(QIODevice::WriteOnly)) {
        delete file;
        setState(id, QStringLiteral("error"), QStringLiteral("Can't save the download"));
        return;
    }
    QNetworkRequest request{QUrl(e->downloadUrl)};
    request.setRawHeader("User-Agent", QByteArrayLiteral("DeckOS/") + appVersion().toUtf8());
    request.setAttribute(QNetworkRequest::RedirectPolicyAttribute, QNetworkRequest::NoLessSafeRedirectPolicy);
    request.setTransferTimeout(60000); // nothing for a minute: stalled
    QNetworkReply* reply = m_net->get(request);
    m_active.insert(id, reply);
    m_files.insert(id, file);
    m_notified.insert(id, -10);
    e->progress = 0;
    e->file.clear();
    setState(id, QStringLiteral("downloading"));
    recordDownload(id, e->name + QLatin1Char(' ') + e->latest, QStringLiteral("downloading"), 0, e->size, QString(), QString());
    Log::info(LOGMSG("Updates: downloading %1 %2").arg(e->name, e->latest));
    const int notifyId = id == APP_ID ? 1 : 2 + int(std::distance(m_entries.begin(),
        std::find_if(m_entries.begin(), m_entries.end(), [&id](const Entry& x) { return x.package == id; })));
    const QString title = e->name + QLatin1Char(' ') + e->latest;

    connect(reply, &QNetworkReply::readyRead, this, [this, id, reply]() {
        if (QFile* f = m_files.value(id)) f->write(reply->readAll());
    });
    connect(reply, &QNetworkReply::downloadProgress, this, [this, id, title, notifyId](qint64 got, qint64 total) {
        Entry* e = entry(id);
        if (!e) return;
        if (total > 0) e->size = total;
        e->progress = total > 0 ? qreal(got) / total : 0;
        emitFor(id);
        // the running row of the Downloads page
        for (QVariant& d : m_downloads) {
            QVariantMap m = d.toMap();
            if (m.value(QStringLiteral("id")).toString() == id && m.value(QStringLiteral("state")).toString() == QLatin1String("downloading")) {
                m.insert(QStringLiteral("bytes"), got);
                m.insert(QStringLiteral("total"), total);
                m.insert(QStringLiteral("progress"), e->progress);
                d = m;
                break;
            }
        }
        emit downloadsChanged();
        const int pct = int(e->progress * 100);
        if (pct - m_notified.value(id) >= 3) {
            m_notified.insert(id, pct);
#ifdef Q_OS_ANDROID
            QAndroidJniObject::callStaticMethod<void>(JNI_PACKAGES, "notifyDownload", "(Landroid/content/Context;ILjava/lang/String;Ljava/lang/String;I)V",
                QtAndroid::androidContext().object(), jint(notifyId),
                QAndroidJniObject::fromString(title).object<jstring>(),
                QAndroidJniObject::fromString(human_size(got) + QStringLiteral(" of ") + human_size(total)).object<jstring>(), jint(pct));
#else
            Q_UNUSED(title); Q_UNUSED(notifyId);
#endif
        }
    });
    connect(reply, &QNetworkReply::finished, this, [this, id, reply, path, title, notifyId]() {
        QFile* f = m_files.take(id);
        m_active.remove(id);
        Entry* e = entry(id);
        if (f) {
            f->write(reply->readAll());
            f->close();
        }
        const bool ok = reply->error() == QNetworkReply::NoError && f && f->size() > 100 * 1024;
        reply->deleteLater();
        auto notify = [&](const QString& text, int progress) {
#ifdef Q_OS_ANDROID
            QAndroidJniObject::callStaticMethod<void>(JNI_PACKAGES, "notifyDownload", "(Landroid/content/Context;ILjava/lang/String;Ljava/lang/String;I)V",
                QtAndroid::androidContext().object(), jint(notifyId),
                QAndroidJniObject::fromString(title).object<jstring>(),
                QAndroidJniObject::fromString(text).object<jstring>(), jint(progress));
#else
            Q_UNUSED(text); Q_UNUSED(progress);
#endif
        };
        if (!ok || !e) {
            const QString why = reply->error() == QNetworkReply::OperationCanceledError ? QStringLiteral("Cancelled")
                              : reply->error() != QNetworkReply::NoError ? QStringLiteral("Download failed: ") + reply->errorString()
                              : QStringLiteral("The download was empty");
            if (f) f->remove();
            delete f;
            if (e) setState(id, QStringLiteral("error"), why);
            recordDownload(id, title, QStringLiteral("error"), 0, 0, QString(), why);
            notify(why, -2);
            if (reply->error() != QNetworkReply::OperationCanceledError)
                emit notice(title, why);
            return;
        }
        const qint64 size = f->size();
        QFile::remove(path);
        f->rename(path);
        delete f;
        e->file = path;
        e->progress = 1;
        setState(id, QStringLiteral("ready"));
        recordDownload(id, title, QStringLiteral("ready"), size, size, path, QString());
        notify(QStringLiteral("Downloaded - installing"), 101);
        Log::info(LOGMSG("Updates: %1 downloaded (%2)").arg(title, human_size(size)));
        install(id);
    });
}

void Updates::install(const QString& id)
{
    Entry* e = entry(id);
    if (!e || !QFileInfo::exists(e->file))
        return;
#ifdef Q_OS_ANDROID
    const QString thenStart = id == APP_ID ? own_package() + QStringLiteral("/org.pegasus_frontend.android.MainActivity") : QString();
    const int r = QAndroidJniObject::callStaticMethod<jint>(
        JNI_PACKAGES, "install", "(Landroid/content/Context;Ljava/lang/String;ZLjava/lang/String;)I",
        QtAndroid::androidContext().object(), QAndroidJniObject::fromString(e->file).object<jstring>(),
        jboolean(m_silent && privileged()), QAndroidJniObject::fromString(thenStart).object<jstring>());
    if (r == 0)
        setState(id, QStringLiteral("installing"));
    else if (r == 1)
        setState(id, QStringLiteral("ready"), QStringLiteral("Allow DeckOS to install apps (Android's setting is open), then press Install again"));
    else
        setState(id, QStringLiteral("error"), QStringLiteral("Android's installer couldn't be opened"));
#else
    setState(id, QStringLiteral("ready"), QStringLiteral("Downloaded. Installing works on the handheld."));
#endif
}

void Updates::cancel(const QString& id)
{
    if (QNetworkReply* r = m_active.value(id))
        r->abort();
}

void Updates::clearDownloads()
{
    QVariantList kept;
    for (const QVariant& d : qAsConst(m_downloads)) {
        const QVariantMap m = d.toMap();
        if (m.value(QStringLiteral("state")).toString() == QLatin1String("downloading")) {
            kept.append(d);
            continue;
        }
        const QString file = m.value(QStringLiteral("file")).toString();
        if (!file.isEmpty())
            QFile::remove(file);
    }
    m_downloads = kept;
    emit downloadsChanged();
    m_save_timer->start();
}

} // namespace deckos
