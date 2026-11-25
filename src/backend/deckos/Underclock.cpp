// DeckOS - underclocking. See Underclock.h; ported from ClusterTune (MIT), docs/clustertune-port.md.

#include "Underclock.h"

#include "Paths.h"

#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QGuiApplication>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QSaveFile>
#include <QStandardPaths>
#include <QTimer>
#include <QUuid>

#ifdef Q_OS_ANDROID
#include <QtAndroidExtras/QAndroidJniObject>
#include <sys/system_properties.h>
#endif


namespace {
constexpr auto STOCK = "stock";

#ifdef Q_OS_ANDROID
constexpr auto JNI_SESSION = "com/deckos/ingame/Session";

QString system_property(const char* name)
{
    char value[PROP_VALUE_MAX] = {};
    __system_property_get(name, value);
    return QString::fromLatin1(value).trimmed();
}

/// SocDetector: the first of these that is set
QString soc_model()
{
    for (const char* p : { "ro.soc.model", "ro.vendor.qti.soc_model", "ro.fota.platform", "ro.hardware", "ro.product.board" }) {
        const QString v = system_property(p);
        if (!v.isEmpty())
            return v;
    }
    return {};
}
#else
void write_file(const QString& path, const QString& text)
{
    QDir().mkpath(QFileInfo(path).path());
    QFile f(path);
    if (f.open(QIODevice::WriteOnly | QIODevice::Truncate))
        f.write(text.toLatin1());
}

/// PC: a Snapdragon 8 Elite's cpufreq and KGSL nodes (Odin 3 layout: cores 0-5 and 6-7), with every
/// frequency ClusterTune's CQ8725S presets use
void make_simulated_tree(const QString& root)
{
    const QString cpufreq = root + QStringLiteral("/sys/devices/system/cpu/cpufreq");
    struct Pol { int id; const char* cpus; const char* freqs; int max; int min; };
    const Pol pols[] = {
        { 0, "0 1 2 3 4 5", "384000 556800 748800 960000 1152000 1363200 1555200 1785600 1996800 2227200 2400000 2745600 2918400 3072000 3321600 3532800", 3532800, 384000 },
        { 6, "6 7", "1017600 1209600 1401600 1689600 1958400 2246400 2438400 2649600 2841600 3072000 3283200 3513600 3840000 4089600 4320000", 4320000, 1017600 },
    };
    for (const Pol& p : pols) {
        const QString d = cpufreq + QStringLiteral("/policy%1/").arg(p.id);
        write_file(d + QStringLiteral("affected_cpus"), QString::fromLatin1(p.cpus));
        write_file(d + QStringLiteral("related_cpus"), QString::fromLatin1(p.cpus));
        write_file(d + QStringLiteral("scaling_available_frequencies"), QString::fromLatin1(p.freqs));
        write_file(d + QStringLiteral("cpuinfo_max_freq"), QString::number(p.max));
        write_file(d + QStringLiteral("cpuinfo_min_freq"), QString::number(p.min));
        write_file(d + QStringLiteral("scaling_max_freq"), QString::number(p.max));
        write_file(d + QStringLiteral("scaling_min_freq"), QString::number(p.min));
    }
    const QString kgsl = root + QStringLiteral("/sys/class/kgsl/kgsl-3d0/");
    write_file(kgsl + QStringLiteral("gpu_available_frequencies"),
               QStringLiteral("1100000000 1050000000 967000000 900000000 832000000 734000000 660000000 607000000 525000000 443000000 389000000 342000000 222000000 160000000"));
    write_file(kgsl + QStringLiteral("max_gpuclk"), QStringLiteral("1100000000"));
    write_file(kgsl + QStringLiteral("min_gpuclk"), QStringLiteral("160000000"));
}
#endif

QString core_range(const QVector<int>& cpus)
{
    if (cpus.isEmpty())
        return {};
    bool contiguous = true;
    for (int i = 1; i < cpus.size(); i++)
        contiguous = contiguous && cpus[i] == cpus[i - 1] + 1;
    if (cpus.size() == 1)
        return QStringLiteral("Core %1").arg(cpus.first());
    if (contiguous)
        return QStringLiteral("Cores %1-%2").arg(cpus.first()).arg(cpus.last());
    QStringList parts;
    for (int c : cpus) parts << QString::number(c);
    return QStringLiteral("Cores ") + parts.join(QLatin1Char(','));
}

QJsonObject profile_json(const deckos::uc::Profile& p)
{
    QJsonObject freqs;
    for (auto it = p.cpu.cbegin(); it != p.cpu.cend(); ++it)
        freqs.insert(QString::number(it.key()), it.value());
    return QJsonObject {
        { QStringLiteral("id"), p.id },
        { QStringLiteral("name"), p.name },
        { QStringLiteral("bundled"), p.bundled },
        { QStringLiteral("maxFrequencies"), freqs },
        { QStringLiteral("gpuMaxFrequencyHz"), p.gpu },
    };
}
} // namespace


namespace deckos {

Underclock::Underclock(QObject* parent)
    : QObject(parent)
    , m_store_path(paths::writableConfigDir() + QStringLiteral("/deckos/underclock.json"))
    , m_reapply(new QTimer(this))
    , m_verify(new QTimer(this))
{
#ifndef Q_OS_ANDROID
    m_root = paths::writableConfigDir() + QStringLiteral("/deckos/simulated-sysfs");
#endif
    m_reapply->setSingleShot(true);
    m_reapply->setInterval(600);
    connect(m_reapply, &QTimer::timeout, this, [this]() { apply(activeId()); });
    m_verify->setSingleShot(true);
    m_verify->setInterval(1500);
    connect(m_verify, &QTimer::timeout, this, &Underclock::verify);

    // Quick Access may have switched the profile while DeckOS was away
    connect(qApp, &QGuiApplication::applicationStateChanged, this, [this](Qt::ApplicationState s) {
        if (s == Qt::ApplicationActive && m_loaded)
            emit changed();
    });
    // a moment after start: the Java side (Quick Access, restart) gets the profiles
    QTimer::singleShot(2000, this, [this]() { ensureLoaded(); });
}

bool Underclock::simulated() const
{
#ifdef Q_OS_ANDROID
    return false;
#else
    return true;
#endif
}

void Underclock::ensureLoaded()
{
    if (m_loaded)
        return;
    m_loaded = true;
#ifndef Q_OS_ANDROID
    if (!QFileInfo::exists(m_root + QStringLiteral("/sys/devices/system/cpu/cpufreq")))
        make_simulated_tree(m_root);
#endif
    load();
    detectDevice();
    seedPresets();
    pushToJava();
}

void Underclock::detectDevice()
{
    m_device = uc::detect(m_root, m_gpu_seen);
#ifdef Q_OS_ANDROID
    m_device.soc = soc_model();
#else
    m_device.soc = QStringLiteral("CQ8725S");
#endif
    if (m_device.gpu.present && m_device.gpu.stock > m_gpu_seen) {
        m_gpu_seen = m_device.gpu.stock;
        save();
    }
}

void Underclock::seedPresets()
{
    // "#2": 0.0.14 added DeckOS's own presets for chips ClusterTune has none for - offered once more
    const QString key = m_device.soc + QStringLiteral("#2");
    if (m_device.soc.isEmpty() || m_seeded.contains(key, Qt::CaseInsensitive))
        return;
    const QVector<uc::Profile> presets = uc::bundledFor(m_device);
    int at = 0;
    for (const uc::Profile& p : presets)
        if (!find(p.id))
            m_profiles.insert(at++, p);
    m_seeded << key;
    save();
}

void Underclock::load()
{
    QFile f(m_store_path);
    if (!f.open(QIODevice::ReadOnly))
        return;
    const QJsonObject o = QJsonDocument::fromJson(f.readAll()).object();
    m_profiles.clear();
    const QVector<uc::Profile> parsed = uc::parseShare(QJsonDocument(o).toJson());
    const QJsonArray raw = o.value(QLatin1String("profiles")).toArray();
    for (int i = 0; i < parsed.size(); i++) {
        uc::Profile p = parsed[i];
        for (const QJsonValue& v : raw)
            if (v.toObject().value(QLatin1String("id")).toString() == p.id)
                p.bundled = v.toObject().value(QLatin1String("bundled")).toBool();
        m_profiles.append(p);
    }
    m_seeded.clear();
    for (const QJsonValue& v : o.value(QLatin1String("seededChips")).toArray())
        m_seeded << v.toString();
    m_active = o.value(QLatin1String("active")).toString(QLatin1String(STOCK));
    m_overlay_custom = o.value(QLatin1String("overlayCustom")).toString();
    m_on_boot = o.value(QLatin1String("applyOnBoot")).toBool(true);
    m_gpu_seen = o.value(QLatin1String("gpuStockSeen")).toInt();
}

void Underclock::save()
{
    QJsonArray list;
    for (const uc::Profile& p : m_profiles)
        list.append(profile_json(p));
    const QJsonObject o {
        { QStringLiteral("version"), 1 },
        { QStringLiteral("profiles"), list },
        { QStringLiteral("seededChips"), QJsonArray::fromStringList(m_seeded) },
        { QStringLiteral("active"), m_active },
        { QStringLiteral("overlayCustom"), m_overlay_custom },
        { QStringLiteral("applyOnBoot"), m_on_boot },
        { QStringLiteral("gpuStockSeen"), m_gpu_seen },
    };
    QDir().mkpath(QFileInfo(m_store_path).path());
    QSaveFile f(m_store_path);
    if (f.open(QIODevice::WriteOnly)) {
        f.write(QJsonDocument(o).toJson(QJsonDocument::Indented));
        f.commit();
    }
}

/// Quick Access's slider (Stock, the presets, Custom) and the profile to apply after a restart, as
/// ready-made scripts: Java runs them without Qt
void Underclock::pushToJava()
{
    QJsonArray steps;
    const auto step = [&](const uc::Profile* p, const QString& label) {
        steps.append(QJsonObject {
            { QStringLiteral("id"), p ? p->id : QString::fromLatin1(STOCK) },
            { QStringLiteral("label"), label },
            { QStringLiteral("name"), p ? p->name : QStringLiteral("Stock") },
            { QStringLiteral("script"), uc::script(m_device, p, p ? p->name : QStringLiteral("Stock")) },
        });
    };
    if (m_device.valid()) {
        step(nullptr, QStringLiteral("Stock"));
        for (const uc::Profile& p : m_profiles) {
            if (!p.bundled || steps.size() >= 5)
                continue;
            QString label = p.name;
            label.remove(QStringLiteral(" Underclock"), Qt::CaseInsensitive);
            step(&p, label.left(10));
        }
        if (const uc::Profile* custom = find(overlayCustomId()))
            step(custom, QStringLiteral("Custom"));
    }
    const QJsonObject o {
        { QStringLiteral("steps"), steps },
        { QStringLiteral("onBoot"), m_on_boot },
    };
#ifdef Q_OS_ANDROID
    const QAndroidJniObject json = QAndroidJniObject::fromString(QString::fromUtf8(QJsonDocument(o).toJson(QJsonDocument::Compact)));
    QAndroidJniObject::callStaticMethod<void>(JNI_SESSION, "setUnderclockSteps", "(Ljava/lang/String;)V", json.object<jstring>());
    // the applied profile's script changes with its values: keep the one used after a restart current
    const QString active = activeId();
    if (active != QLatin1String(STOCK)) {
        const uc::Profile* p = find(active);
        const QAndroidJniObject jid = QAndroidJniObject::fromString(active);
        const QAndroidJniObject jscript = QAndroidJniObject::fromString(p ? uc::script(m_device, p, p->name) : QString());
        QAndroidJniObject::callStaticMethod<void>(JNI_SESSION, "setUnderclockBootScript", "(Ljava/lang/String;Ljava/lang/String;)V",
                                                  jid.object<jstring>(), jscript.object<jstring>());
    }
#else
    Q_UNUSED(o);
#endif
}

uc::Profile* Underclock::find(const QString& id)
{
    for (uc::Profile& p : m_profiles)
        if (p.id == id) return &p;
    return nullptr;
}


// --- properties -------------------------------------------------------------------------------------

bool Underclock::available() { ensureLoaded(); return m_device.valid(); }

bool Underclock::canApply()
{
    ensureLoaded();
#ifdef Q_OS_ANDROID
    return m_device.valid() && QAndroidJniObject::callStaticMethod<jboolean>(JNI_SESSION, "privilegedAvailable", "()Z");
#else
    return m_device.valid();
#endif
}

QString Underclock::method()
{
#ifdef Q_OS_ANDROID
    return canApply() ? QStringLiteral("AYN / Retroid system service (PServer)") : QString();
#else
    return QStringLiteral("Simulated (PC)");
#endif
}

QString Underclock::chip()
{
    ensureLoaded();
    const QString name = uc::chipName(m_device.soc);
    if (m_device.soc.isEmpty())
        return QStringLiteral("Unknown");
    return name.isEmpty() ? m_device.soc : QStringLiteral("%1 (%2)").arg(name, m_device.soc);
}

QVariantList Underclock::clusters()
{
    ensureLoaded();
    QVariantList out;
    for (const uc::Cluster& c : m_device.clusters) {
        QVariantList freqs;
        for (int f : c.freqs) freqs << f;
        out << QVariantMap {
            { QStringLiteral("policy"), c.policy },
            { QStringLiteral("label"), core_range(c.cpus) },
            { QStringLiteral("freqs"), freqs },
            { QStringLiteral("stock"), c.stock },
            { QStringLiteral("current"), c.current },
        };
    }
    return out;
}

QVariantMap Underclock::gpu()
{
    ensureLoaded();
    QVariantList freqs;
    for (int f : m_device.gpu.freqs) freqs << f;
    return {
        { QStringLiteral("present"), m_device.gpu.present },
        { QStringLiteral("freqs"), freqs },
        { QStringLiteral("stock"), m_device.gpu.stock },
        { QStringLiteral("current"), m_device.gpu.current },
    };
}

QString Underclock::summary(const uc::Profile* p) const
{
    if (!p)
        return QStringLiteral("The chip's own limits");
    QStringList cpu;
    for (const uc::Cluster& c : m_device.clusters)
        cpu << (p->cpu.contains(c.policy) ? uc::formatKHz(p->cpu.value(c.policy)) : QStringLiteral("Stock"));
    QString s = QStringLiteral("CPU ") + cpu.join(QStringLiteral(" / "));
    if (m_device.gpu.present)
        s += QStringLiteral(" · GPU ") + (p->gpu > 0 ? uc::formatHz(p->gpu) : QStringLiteral("Stock"));
    return s;
}

QVariantMap Underclock::toMap(const uc::Profile* p)
{
    QVariantMap cpu;
    if (p)
        for (auto it = p->cpu.cbegin(); it != p->cpu.cend(); ++it)
            cpu.insert(QString::number(it.key()), it.value());
    return {
        { QStringLiteral("id"), p ? p->id : QString::fromLatin1(STOCK) },
        { QStringLiteral("name"), p ? p->name : QStringLiteral("Stock") },
        { QStringLiteral("stock"), !p },
        { QStringLiteral("bundled"), p && p->bundled },
        { QStringLiteral("deckosPreset"), p && uc::isDeckosPreset(*p) },
        { QStringLiteral("cpu"), cpu },
        { QStringLiteral("gpu"), p ? p->gpu : 0 },
        { QStringLiteral("summary"), summary(p) },
        { QStringLiteral("fits"), !p || uc::fits(*p, m_device) },
    };
}

QVariantList Underclock::profiles()
{
    ensureLoaded();
    QVariantList out { toMap(nullptr) };
    for (const uc::Profile& p : m_profiles)
        out << toMap(&p);
    return out;
}

QVariantMap Underclock::profile(const QString& id)
{
    ensureLoaded();
    if (id == QLatin1String(STOCK))
        return toMap(nullptr);
    const uc::Profile* p = find(id);
    return p ? toMap(p) : QVariantMap();
}

QString Underclock::activeId()
{
    ensureLoaded();
#ifdef Q_OS_ANDROID
    const QString id = QAndroidJniObject::callStaticObjectMethod(JNI_SESSION, "underclockActiveId", "()Ljava/lang/String;").toString();
    m_active = id.isEmpty() ? QString::fromLatin1(STOCK) : id;
#endif
    return m_active;
}

bool Underclock::applyOnBoot() { ensureLoaded(); return m_on_boot; }

void Underclock::setApplyOnBoot(bool on)
{
    ensureLoaded();
    m_on_boot = on;
    save();
    pushToJava();
    emit changed();
}

QString Underclock::overlayCustomId()
{
    ensureLoaded();
    if (find(m_overlay_custom))
        return m_overlay_custom;
    for (const uc::Profile& p : m_profiles) // none chosen: the first of the user's own
        if (!p.bundled) return p.id;
    return {};
}

void Underclock::setOverlayCustomId(const QString& id)
{
    ensureLoaded();
    m_overlay_custom = id;
    save();
    pushToJava();
    emit changed();
}


// --- actions ----------------------------------------------------------------------------------------

void Underclock::refresh()
{
    ensureLoaded();
    detectDevice();
    emit changed();
}

bool Underclock::apply(const QString& id)
{
    ensureLoaded();
    if (!m_device.valid())
        return false;
    const bool stock = id == QLatin1String(STOCK);
    const uc::Profile* p = stock ? nullptr : find(id);
    if (!stock && !p)
        return false;
    const QString name = p ? p->name : QStringLiteral("Stock");
    m_reapply->stop();
#ifdef Q_OS_ANDROID
    const QString label = p ? name : QStringLiteral("Stock");
    const QAndroidJniObject jid = QAndroidJniObject::fromString(stock ? QString::fromLatin1(STOCK) : id);
    const QAndroidJniObject jname = QAndroidJniObject::fromString(name);
    const QAndroidJniObject jlabel = QAndroidJniObject::fromString(label);
    const QAndroidJniObject jscript = QAndroidJniObject::fromString(uc::script(m_device, p, name));
    const bool sent = QAndroidJniObject::callStaticMethod<jboolean>(JNI_SESSION, "runUnderclock",
        "(Ljava/lang/String;Ljava/lang/String;Ljava/lang/String;Ljava/lang/String;)Z",
        jid.object<jstring>(), jname.object<jstring>(), jlabel.object<jstring>(), jscript.object<jstring>());
    if (!sent) {
        m_status = QStringLiteral("Couldn't reach the system service - nothing changed");
        emit changed();
        return false;
    }
    m_active = stock ? QString::fromLatin1(STOCK) : id;
    m_status = QStringLiteral("Applying %1…").arg(name);
    m_verify_name = name;
    m_verify->start();
#else
    uc::applyToTree(m_device, p);
    m_active = stock ? QString::fromLatin1(STOCK) : id;
    detectDevice();
    m_status = QStringLiteral("%1 applied (simulated)").arg(name);
#endif
    qInfo().noquote() << QStringLiteral("DeckOS: underclock %1").arg(name);
    save();
    pushToJava();
    emit changed();
    return true;
}

/// Android: read the limits back; a vendor service or the kernel may have refused one
void Underclock::verify()
{
    detectDevice();
    const QString id = activeId();
    const uc::Profile* p = id == QLatin1String(STOCK) ? nullptr : find(id);
    QStringList off;
    for (const uc::Cluster& c : m_device.clusters) {
        const int want = uc::cpuTarget(p, c);
        if (c.current != want)
            off << QStringLiteral("%1 is at %2 (wanted %3)").arg(core_range(c.cpus), uc::formatKHz(c.current), uc::formatKHz(want));
    }
    if (m_device.gpu.present && p && p->gpu > 0 && m_device.gpu.current != uc::gpuTarget(p, m_device.gpu))
        off << QStringLiteral("GPU is at %1").arg(uc::formatHz(m_device.gpu.current));
    m_status = off.isEmpty() ? QStringLiteral("%1 applied").arg(m_verify_name)
                             : QStringLiteral("%1 only partly applied: %2").arg(m_verify_name, off.join(QStringLiteral("; ")));
    emit changed();
}

QString Underclock::createProfile()
{
    ensureLoaded();
    uc::Profile p;
    p.id = QStringLiteral("user_") + QUuid::createUuid().toString(QUuid::WithoutBraces);
    int n = 1;
    const auto taken = [this](const QString& name) {
        for (const uc::Profile& q : m_profiles) if (q.name == name) return true;
        return false;
    };
    while (taken(QStringLiteral("My profile %1").arg(n))) n++;
    p.name = QStringLiteral("My profile %1").arg(n);
    // the limits in effect now (Stock clusters stay unset)
    for (const uc::Cluster& c : m_device.clusters)
        if (c.current > 0 && c.current < c.stock)
            p.cpu.insert(c.policy, c.current);
    if (m_device.gpu.present && m_device.gpu.current > 0 && m_device.gpu.current < m_device.gpu.stock)
        p.gpu = m_device.gpu.current;
    m_profiles.append(p);
    save();
    pushToJava();
    emit changed();
    return p.id;
}

QString Underclock::duplicateProfile(const QString& id)
{
    ensureLoaded();
    const uc::Profile* src = find(id);
    if (!src)
        return {};
    uc::Profile p = *src;
    p.id = QStringLiteral("user_") + QUuid::createUuid().toString(QUuid::WithoutBraces);
    p.name = src->name + QStringLiteral(" (copy)");
    p.bundled = false;
    m_profiles.append(p);
    save();
    pushToJava();
    emit changed();
    return p.id;
}

void Underclock::renameProfile(const QString& id, const QString& name)
{
    uc::Profile* p = find(id);
    const QString n = name.trimmed().left(40);
    if (!p || n.isEmpty())
        return;
    p->name = n;
    edited(id);
}

void Underclock::setCpuLimit(const QString& id, int policy, int kHz)
{
    uc::Profile* p = find(id);
    const uc::Cluster* c = m_device.cluster(policy);
    if (!p || !c)
        return;
    if (kHz <= 0 || kHz >= c->stock)
        p->cpu.remove(policy);
    else
        p->cpu.insert(policy, kHz);
    edited(id);
}

void Underclock::setGpuLimit(const QString& id, int hz)
{
    uc::Profile* p = find(id);
    if (!p)
        return;
    p->gpu = hz <= 0 || hz >= m_device.gpu.stock ? 0 : hz;
    edited(id);
}

void Underclock::edited(const QString& id)
{
    save();
    pushToJava();
    if (id == activeId())
        m_reapply->start(); // the applied profile changed: apply it again once the editing pauses
    emit changed();
}

void Underclock::deleteProfile(const QString& id)
{
    ensureLoaded();
    for (int i = 0; i < m_profiles.size(); i++) {
        if (m_profiles[i].id != id)
            continue;
        m_profiles.removeAt(i);
        if (m_overlay_custom == id)
            m_overlay_custom.clear();
        save();
        if (activeId() == id)
            apply(QString::fromLatin1(STOCK)); // its limits would stay with no profile to show for them
        pushToJava();
        emit changed();
        return;
    }
}

void Underclock::moveProfile(const QString& id, int delta)
{
    for (int i = 0; i < m_profiles.size(); i++) {
        if (m_profiles[i].id != id)
            continue;
        const int to = qBound(0, i + delta, m_profiles.size() - 1);
        if (to != i) {
            m_profiles.move(i, to);
            save();
            pushToJava();
            emit changed();
        }
        return;
    }
}

int Underclock::restorePresets()
{
    ensureLoaded();
    int count = 0;
    int at = 0;
    for (const uc::Profile& preset : uc::bundledFor(m_device)) {
        if (uc::Profile* p = find(preset.id)) {
            if (p->cpu != preset.cpu || p->gpu != preset.gpu || p->name != preset.name) {
                *p = preset;
                count++;
            }
        }
        else {
            m_profiles.insert(at, preset);
            count++;
        }
        at++;
    }
    if (count > 0) {
        save();
        pushToJava();
        emit changed();
    }
    return count;
}

QString Underclock::importFile(const QString& path)
{
    ensureLoaded();
    QFile f(path);
    if (!f.open(QIODevice::ReadOnly))
        return QStringLiteral("!Couldn't open that file");
    const QVector<uc::Profile> list = uc::parseShare(f.read(1024 * 1024));
    if (list.isEmpty())
        return QStringLiteral("!Not a ClusterTune profile file");
    int added = 0, skipped = 0;
    for (uc::Profile in : list) {
        if (!uc::fits(in, m_device)) {
            skipped++;
            continue;
        }
        // mergeImportedProfiles: same id = that profile updated (a preset stays a preset)
        if (uc::Profile* existing = find(in.id)) {
            in.bundled = existing->bundled;
            *existing = in;
        }
        else {
            m_profiles.append(in);
        }
        added++;
    }
    if (added > 0) {
        save();
        pushToJava();
        emit changed();
    }
    if (added == 0)
        return QStringLiteral("!None of its %1 profiles fit this chip").arg(list.size());
    QString msg = added == 1 ? QStringLiteral("Imported 1 profile") : QStringLiteral("Imported %1 profiles").arg(added);
    if (skipped > 0)
        msg += QStringLiteral(" (%1 made for another chip skipped)").arg(skipped);
    return msg;
}

QString Underclock::exportFile()
{
    ensureLoaded();
    if (m_profiles.isEmpty())
        return QStringLiteral("!No profiles to export");
    QString dir = QStandardPaths::writableLocation(QStandardPaths::DownloadLocation);
    if (dir.isEmpty())
        dir = paths::writableConfigDir();
    QDir().mkpath(dir);
    const QString path = dir + QStringLiteral("/deckos-underclock-profiles.json");
    QSaveFile f(path);
    if (!f.open(QIODevice::WriteOnly))
        return QStringLiteral("!Couldn't write to %1").arg(dir);
    f.write(uc::encodeShare(m_profiles, m_device.soc));
    if (!f.commit())
        return QStringLiteral("!Couldn't write to %1").arg(dir);
    return path;
}

} // namespace deckos
