// DeckOS - underclocking core. See UnderclockCore.h; ported from ClusterTune (MIT), docs/clustertune-port.md.

#include "UnderclockCore.h"

#include "ClusterTunePresets.h"

#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QRegularExpression>

#include <algorithm>


namespace deckos {
namespace uc {

namespace {
QString read_text(const QString& path)
{
    QFile f(path);
    if (!f.open(QIODevice::ReadOnly))
        return {};
    return QString::fromLatin1(f.read(65536)).trimmed();
}

int read_int(const QString& path)
{
    bool ok = false;
    const int v = read_text(path).toInt(&ok);
    return ok ? v : 0;
}

QVector<int> parse_ints(const QString& raw, bool positive_only)
{
    QVector<int> out;
    for (const QString& part : raw.split(QRegularExpression(QStringLiteral("\\s+")), Qt::SkipEmptyParts)) {
        bool ok = false;
        const int v = part.toInt(&ok);
        if (ok && (!positive_only || v > 0) && !out.contains(v))
            out.append(v);
    }
    std::sort(out.begin(), out.end());
    return out;
}

/// first column of stats/time_in_state; with `used`, only frequencies the core has spent time at
QVector<int> time_in_state(const QString& path, bool used)
{
    QVector<int> out;
    for (const QString& line : read_text(path).split(QLatin1Char('\n'))) {
        const QStringList f = line.trimmed().split(QRegularExpression(QStringLiteral("\\s+")), Qt::SkipEmptyParts);
        if (f.isEmpty())
            continue;
        bool ok = false;
        const int freq = f[0].toInt(&ok);
        if (!ok || freq <= 0)
            continue;
        if (used && (f.size() < 2 || f[1].toLongLong() <= 0))
            continue;
        out.append(freq);
    }
    return out;
}

// CpuPolicyDetector.parsePolicy
bool parse_policy(const QString& path, Cluster& c)
{
    const QString name = QFileInfo(path).fileName();
    bool ok = false;
    c.policy = name.mid(6).toInt(&ok);
    if (!ok)
        return false;
    c.maxPath = path + QStringLiteral("/scaling_max_freq");
    c.minPath = path + QStringLiteral("/scaling_min_freq");

    const QVector<int> raw = parse_ints(read_text(path + QStringLiteral("/scaling_available_frequencies")), false);
    c.cpus = parse_ints(read_text(path + QStringLiteral("/affected_cpus")), false);
    if (c.cpus.isEmpty())
        c.cpus = parse_ints(read_text(path + QStringLiteral("/related_cpus")), false);
    if (c.cpus.isEmpty())
        c.cpus = { c.policy };

    const int info_max = read_int(path + QStringLiteral("/cpuinfo_max_freq"));
    const int info_min = read_int(path + QStringLiteral("/cpuinfo_min_freq"));
    const int scaling_max = read_int(c.maxPath);
    const QString tis = path + QStringLiteral("/stats/time_in_state");

    // scaling_min_freq may have been left high by an OEM service: never the repair floor
    QVector<int> min_candidates;
    if (info_min > 0) min_candidates.append(info_min);
    for (int f : raw) if (f > 0) min_candidates.append(f);
    for (int f : time_in_state(tis, true)) min_candidates.append(f);
    if (min_candidates.isEmpty())
        return false;
    c.hwMin = *std::min_element(min_candidates.cbegin(), min_candidates.cend());
    const int scaling_min = read_int(c.minPath);
    const int min_freq = scaling_min > 0 ? scaling_min : c.hwMin;

    c.freqs = raw;
    if (c.freqs.isEmpty()) {
        for (int f : { min_freq, scaling_max > 0 ? scaling_max : info_max, std::max(info_max, scaling_max) })
            if (f > 0 && !c.freqs.contains(f)) c.freqs.append(f);
        std::sort(c.freqs.begin(), c.freqs.end());
    }
    if (c.freqs.isEmpty())
        return false;
    c.stock = c.freqs.last();
    c.current = scaling_max > 0 ? scaling_max : c.stock;
    return true;
}

// GpuPolicyDetector
bool detect_kgsl(const QString& root, Gpu& g)
{
    const QString path = root + QStringLiteral("/sys/class/kgsl/kgsl-3d0");
    g.maxPath = path + QStringLiteral("/max_gpuclk");
    g.current = read_int(g.maxPath);
    if (g.current <= 0)
        return false;
    g.freqs = parse_ints(read_text(path + QStringLiteral("/gpu_available_frequencies")), true);
    const int min = read_int(path + QStringLiteral("/min_gpuclk"));
    g.minPath = min > 0 ? path + QStringLiteral("/min_gpuclk") : QString();
    g.hwMin = min > 0 ? min : (g.freqs.isEmpty() ? 0 : g.freqs.first());
    return true;
}

bool detect_devfreq(const QString& root, Gpu& g)
{
    QStringList dirs = QDir(root + QStringLiteral("/sys/class/devfreq")).entryList(QDir::Dirs | QDir::NoDotAndDotDot);
    QStringList picked;
    for (const QString& d : dirs) {
        const QString n = d.toLower();
        const bool gpu = n.contains(QLatin1String("kgsl-3d")) || n.contains(QLatin1String("gpu")) || n.contains(QLatin1String("mali"));
        const bool excluded = n.contains(QLatin1String("bus")) || n.contains(QLatin1String("bw")) || n.contains(QLatin1String("memlat"));
        if (gpu && !excluded)
            picked.append(d);
    }
    std::sort(picked.begin(), picked.end(), [](const QString& a, const QString& b) {
        const auto score = [](const QString& s) { return s.contains(QLatin1String("kgsl-3d")) ? 0 : s.contains(QLatin1String("gpu")) ? 1 : 2; };
        return score(a) != score(b) ? score(a) < score(b) : a < b;
    });
    for (const QString& d : picked) {
        const QString path = root + QStringLiteral("/sys/class/devfreq/") + d;
        const int max = read_int(path + QStringLiteral("/max_freq"));
        if (max <= 0)
            continue;
        g.maxPath = path + QStringLiteral("/max_freq");
        g.current = max;
        g.freqs = parse_ints(read_text(path + QStringLiteral("/available_frequencies")), true);
        const int min = read_int(path + QStringLiteral("/min_freq"));
        g.minPath = QFile::exists(path + QStringLiteral("/min_freq")) ? path + QStringLiteral("/min_freq") : QString();
        g.hwMin = min > 0 ? min : (g.freqs.isEmpty() ? 0 : g.freqs.first());
        return true;
    }
    return false;
}

QString quoted(const QString& s)
{
    QString q = s;
    q.replace(QLatin1Char('\''), QLatin1String("'\"'\"'"));
    return QLatin1Char('\'') + q + QLatin1Char('\'');
}

int snap_down(const QVector<int>& table, int value)
{
    int pick = 0;
    for (int f : table)
        if (f <= value) pick = f;
    return pick > 0 ? pick : (table.isEmpty() ? value : table.first());
}

bool write_int(const QString& path, int v)
{
    QFile f(path);
    if (!f.open(QIODevice::WriteOnly | QIODevice::Truncate))
        return false;
    f.write(QByteArray::number(v));
    return true;
}
} // namespace


const Cluster* Device::cluster(int policy) const
{
    for (const Cluster& c : clusters)
        if (c.policy == policy) return &c;
    return nullptr;
}

Device detect(const QString& root, int gpuStockSeen)
{
    Device d;
    QDir dir(root + QStringLiteral("/sys/devices/system/cpu/cpufreq"));
    for (const QString& name : dir.entryList({ QStringLiteral("policy*") }, QDir::Dirs | QDir::NoDotAndDotDot)) {
        Cluster c;
        if (parse_policy(dir.filePath(name), c))
            d.clusters.append(c);
    }
    std::sort(d.clusters.begin(), d.clusters.end(), [](const Cluster& a, const Cluster& b) { return a.policy < b.policy; });

    Gpu& g = d.gpu;
    g.present = detect_kgsl(root, g) || detect_devfreq(root, g);
    if (g.present) {
        // the first ceiling seen stays Stock, so a capped value isn't mistaken for it later
        const int top = g.freqs.isEmpty() ? 0 : g.freqs.last();
        g.stock = std::max({ top, g.current, gpuStockSeen });
    }
    else {
        g = Gpu();
    }
    return d;
}

QVector<Profile> parseShare(const QByteArray& json)
{
    QVector<Profile> out;
    const QJsonDocument doc = QJsonDocument::fromJson(json);
    if (!doc.isObject())
        return out;
    for (const QJsonValue& v : doc.object().value(QLatin1String("profiles")).toArray()) {
        const QJsonObject o = v.toObject();
        Profile p;
        p.id = o.value(QLatin1String("id")).toString();
        p.name = o.value(QLatin1String("name")).toString();
        if (p.id.isEmpty() || p.name.isEmpty())
            continue;
        const QJsonObject freqs = o.value(QLatin1String("maxFrequencies")).toObject();
        for (auto it = freqs.begin(); it != freqs.end(); ++it) {
            bool ok = false;
            const int policy = it.key().toInt(&ok);
            const int khz = it.value().toInt();
            if (ok && khz > 0)
                p.cpu.insert(policy, khz);
        }
        p.gpu = std::max(0, o.value(QLatin1String("gpuMaxFrequencyHz")).toInt());
        out.append(p);
    }
    return out;
}

QByteArray encodeShare(const QVector<Profile>& profiles, const QString& soc)
{
    QJsonArray list;
    for (const Profile& p : profiles) {
        QJsonObject freqs;
        for (auto it = p.cpu.cbegin(); it != p.cpu.cend(); ++it)
            freqs.insert(QString::number(it.key()), it.value());
        QJsonObject o {
            { QStringLiteral("id"), p.id },
            { QStringLiteral("name"), p.name },
            { QStringLiteral("maxFrequencies"), freqs },
        };
        o.insert(QStringLiteral("gpuMaxFrequencyHz"), p.gpu > 0 ? QJsonValue(p.gpu) : QJsonValue());
        list.append(o);
    }
    QJsonObject root {
        { QStringLiteral("schemaVersion"), 2 },
        { QStringLiteral("profiles"), list },
    };
    root.insert(QStringLiteral("socModel"), soc.isEmpty() ? QJsonValue() : QJsonValue(soc));
    return QJsonDocument(root).toJson(QJsonDocument::Indented);
}

QVector<Profile> bundledFor(const Device& device)
{
    QVector<Profile> out;
    for (const clustertune::BundledPresets& b : clustertune::BUNDLED_PRESETS) {
        if (device.soc.compare(QLatin1String(b.socModel), Qt::CaseInsensitive) != 0)
            continue;
        for (Profile p : parseShare(QByteArray(b.json))) {
            p.bundled = true;
            if (!p.cpu.isEmpty() && fits(p, device))
                out.append(p);
        }
    }
    if (out.isEmpty() && device.valid()) {
        // DeckOS: ClusterTune has presets for two chips only (Odin 3, Odin 2 / Thor). Anywhere else
        // (Retroid Pocket Classic...) three steps of each cluster's own table: ~85 / 70 / 55 % of its top
        struct Step { const char* id; const char* name; double share; };
        for (const Step& s : { Step { "deckos_small", "Small Underclock", 0.85 },
                               Step { "deckos_medium", "Medium Underclock", 0.70 },
                               Step { "deckos_large", "Large Underclock", 0.55 } }) {
            Profile p;
            p.id = QString::fromLatin1(s.id);
            p.name = QString::fromLatin1(s.name);
            p.bundled = true;
            for (const Cluster& c : device.clusters) {
                const int f = snap_down(c.freqs, static_cast<int>(c.stock * s.share));
                if (f > 0 && f < c.stock)
                    p.cpu.insert(c.policy, f);
            }
            if (!p.cpu.isEmpty() && (out.isEmpty() || p.cpu != out.last().cpu))
                out.append(p);
        }
    }
    return out;
}

bool isDeckosPreset(const Profile& p)
{
    return p.bundled && p.id.startsWith(QLatin1String("deckos_"));
}

bool fits(const Profile& profile, const Device& device)
{
    for (auto it = profile.cpu.cbegin(); it != profile.cpu.cend(); ++it) {
        const Cluster* c = device.cluster(it.key());
        if (!c || !c->freqs.contains(it.value()))
            return false;
    }
    if (profile.gpu > 0) {
        if (!device.gpu.present)
            return false;
        if (!device.gpu.freqs.isEmpty() && !device.gpu.freqs.contains(profile.gpu) && profile.gpu != device.gpu.stock)
            return false;
    }
    return true;
}

int cpuTarget(const Profile* profile, const Cluster& c)
{
    if (!profile || !profile->cpu.contains(c.policy))
        return c.stock;
    return std::min(c.stock, snap_down(c.freqs, profile->cpu.value(c.policy)));
}

int gpuTarget(const Profile* profile, const Gpu& g)
{
    if (!profile || profile->gpu <= 0)
        return g.stock;
    return std::min(g.stock, g.freqs.isEmpty() ? profile->gpu : snap_down(g.freqs, profile->gpu));
}

QString script(const Device& device, const Profile* profile, const QString& label)
{
    QString s;
    s += QStringLiteral("# DeckOS underclock: %1 (ClusterTune's way, docs/clustertune-port.md)\n").arg(QString(label).remove(QLatin1Char('\n')));
    // cap NODE VALUE lock|open - write a maximum; lock = read-only after, so vendor services keep off it
    s += QStringLiteral("cap() { [ -e \"$1\" ] || return 0; chmod u+w \"$1\" 2>/dev/null; echo \"$2\" > \"$1\" 2>/dev/null;"
                        " [ \"$3\" = lock ] && chmod a-w \"$1\" 2>/dev/null; return 0; }\n");
    // floor NODE CEILING VALUE - a minimum above the new cap would hold the clock up: lower it
    s += QStringLiteral("floor() { m=$(cat \"$1\" 2>/dev/null); [ -n \"$m\" ] && [ \"$m\" -gt \"$2\" ] 2>/dev/null || return 0;"
                        " chmod u+w \"$1\" 2>/dev/null; echo \"$3\" > \"$1\" 2>/dev/null; return 0; }\n");
    for (const Cluster& c : device.clusters) {
        const int target = cpuTarget(profile, c);
        const bool stock = target >= c.stock;
        const QString mode = stock ? QStringLiteral("open") : QStringLiteral("lock");
        s += QStringLiteral("cap %1 %2 %3\n").arg(quoted(c.maxPath)).arg(target).arg(mode);
        if (!stock && c.hwMin > 0) {
            s += QStringLiteral("floor %1 %2 %3\n").arg(quoted(c.minPath)).arg(target).arg(c.hwMin);
            s += QStringLiteral("cap %1 %2 %3\n").arg(quoted(c.maxPath)).arg(target).arg(mode);
        }
    }
    const Gpu& g = device.gpu;
    if (g.present && g.stock > 0) {
        const int target = gpuTarget(profile, g);
        const bool stock = target >= g.stock;
        const QString mode = stock ? QStringLiteral("open") : QStringLiteral("lock");
        s += QStringLiteral("cap %1 %2 %3\n").arg(quoted(g.maxPath)).arg(target).arg(mode);
        if (!stock && !g.minPath.isEmpty() && g.hwMin > 0) {
            s += QStringLiteral("floor %1 %2 %3\n").arg(quoted(g.minPath)).arg(target).arg(g.hwMin);
            s += QStringLiteral("cap %1 %2 %3\n").arg(quoted(g.maxPath)).arg(target).arg(mode);
        }
    }
    return s;
}

bool applyToTree(const Device& device, const Profile* profile)
{
    bool ok = true;
    for (const Cluster& c : device.clusters) {
        const int target = cpuTarget(profile, c);
        ok = write_int(c.maxPath, target) && ok;
        if (read_int(c.minPath) > target)
            ok = write_int(c.minPath, c.hwMin) && ok;
    }
    if (device.gpu.present && device.gpu.stock > 0) {
        const int target = gpuTarget(profile, device.gpu);
        ok = write_int(device.gpu.maxPath, target) && ok;
        if (!device.gpu.minPath.isEmpty() && read_int(device.gpu.minPath) > target)
            ok = write_int(device.gpu.minPath, device.gpu.hwMin) && ok;
    }
    return ok;
}

QString formatKHz(int kHz)
{
    if (kHz <= 0)
        return QStringLiteral("-");
    if (kHz >= 1000000)
        return QStringLiteral("%1 GHz").arg(kHz / 1000000.0, 0, 'f', 2);
    return QStringLiteral("%1 MHz").arg(qRound(kHz / 1000.0));
}

QString formatHz(int hz)
{
    return hz <= 0 ? QStringLiteral("-") : QStringLiteral("%1 MHz").arg(qRound(hz / 1000000.0));
}

QString chipName(const QString& soc)
{
    static const QMap<QString, QString> names {
        { QStringLiteral("CQ8725S"), QStringLiteral("Snapdragon 8 Elite") },
        { QStringLiteral("SM8750"), QStringLiteral("Snapdragon 8 Elite") },
        { QStringLiteral("QCS8550"), QStringLiteral("Snapdragon 8 Gen 2") },
        { QStringLiteral("SM8550"), QStringLiteral("Snapdragon 8 Gen 2") },
        { QStringLiteral("SM8650"), QStringLiteral("Snapdragon 8 Gen 3") },
        { QStringLiteral("SM8475"), QStringLiteral("Snapdragon 8+ Gen 1") },
        { QStringLiteral("SM8450"), QStringLiteral("Snapdragon 8 Gen 1") },
        { QStringLiteral("SM8350"), QStringLiteral("Snapdragon 888") },
        { QStringLiteral("SM8250"), QStringLiteral("Snapdragon 865") },
    };
    return names.value(soc.toUpper());
}

} // namespace uc
} // namespace deckos
