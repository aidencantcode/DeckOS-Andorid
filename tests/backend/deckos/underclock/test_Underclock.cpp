// DeckOS
// Tests for the ClusterTune port (deckos/UnderclockCore): reading cpufreq / KGSL nodes, ClusterTune's
// file format, its presets, and the script that applies a profile.

#include <QtTest/QtTest>

#include "Log.h"
#include "deckos/UnderclockCore.h"

#include <QDir>
#include <QFile>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QTemporaryDir>

using namespace deckos;


namespace {
void put(const QString& path, const QString& text)
{
    QDir().mkpath(QFileInfo(path).path());
    QFile f(path);
    QVERIFY(f.open(QIODevice::WriteOnly | QIODevice::Truncate));
    f.write(text.toLatin1());
}

QString get(const QString& path)
{
    QFile f(path);
    return f.open(QIODevice::ReadOnly) ? QString::fromLatin1(f.readAll()).trimmed() : QString();
}

/// an Odin 3 like tree: policy0 (cores 0-5), policy6 (6-7), KGSL with a frequency list
void make_tree(const QString& root, bool with_min_raised = false)
{
    const QString c = root + QStringLiteral("/sys/devices/system/cpu/cpufreq/");
    put(c + QStringLiteral("policy0/affected_cpus"), QStringLiteral("0 1 2 3 4 5"));
    put(c + QStringLiteral("policy0/scaling_available_frequencies"), QStringLiteral("384000 1785600 2227200 2745600 3532800"));
    put(c + QStringLiteral("policy0/cpuinfo_min_freq"), QStringLiteral("384000"));
    put(c + QStringLiteral("policy0/cpuinfo_max_freq"), QStringLiteral("3532800"));
    put(c + QStringLiteral("policy0/scaling_max_freq"), QStringLiteral("3532800"));
    put(c + QStringLiteral("policy0/scaling_min_freq"), with_min_raised ? QStringLiteral("2745600") : QStringLiteral("384000"));
    put(c + QStringLiteral("policy6/related_cpus"), QStringLiteral("6 7")); // no affected_cpus: falls back
    put(c + QStringLiteral("policy6/scaling_available_frequencies"), QStringLiteral("4320000 1017600 1958400 2246400 3072000")); // unsorted
    put(c + QStringLiteral("policy6/cpuinfo_min_freq"), QStringLiteral("1017600"));
    put(c + QStringLiteral("policy6/cpuinfo_max_freq"), QStringLiteral("4320000"));
    put(c + QStringLiteral("policy6/scaling_max_freq"), QStringLiteral("3072000")); // already capped
    put(c + QStringLiteral("policy6/scaling_min_freq"), QStringLiteral("1017600"));
    const QString g = root + QStringLiteral("/sys/class/kgsl/kgsl-3d0/");
    put(g + QStringLiteral("gpu_available_frequencies"), QStringLiteral("1100000000 734000000 160000000"));
    put(g + QStringLiteral("max_gpuclk"), QStringLiteral("1100000000"));
    put(g + QStringLiteral("min_gpuclk"), QStringLiteral("160000000"));
}
} // namespace


class test_Underclock : public QObject {
    Q_OBJECT

private slots:
    void initTestCase() { Log::init_qttest(); }

    void detects_clusters_and_gpu();
    void cpu_table_fallback_without_list();
    void share_file_round_trip();
    void share_file_rejects_garbage();
    void bundled_presets_fit_the_chip();
    void fits_and_targets();
    void script_caps_floors_and_unlocks();
    void apply_to_tree_writes_limits();
    void formats();
};

void test_Underclock::detects_clusters_and_gpu()
{
    QTemporaryDir dir;
    make_tree(dir.path());
    const uc::Device d = uc::detect(dir.path());
    QCOMPARE(d.clusters.size(), 2);
    QCOMPARE(d.clusters[0].policy, 0);
    QCOMPARE(d.clusters[0].cpus, QVector<int>({ 0, 1, 2, 3, 4, 5 }));
    QCOMPARE(d.clusters[0].stock, 3532800);
    QCOMPARE(d.clusters[0].hwMin, 384000);
    QCOMPARE(d.clusters[1].policy, 6);
    QCOMPARE(d.clusters[1].cpus, QVector<int>({ 6, 7 }));
    QCOMPARE(d.clusters[1].freqs.first(), 1017600); // sorted
    QCOMPARE(d.clusters[1].stock, 4320000);         // the table's top, not the capped current value
    QCOMPARE(d.clusters[1].current, 3072000);
    QVERIFY(d.gpu.present);
    QCOMPARE(d.gpu.freqs, QVector<int>({ 160000000, 734000000, 1100000000 }));
    QCOMPARE(d.gpu.stock, 1100000000);
    QVERIFY(d.gpu.minPath.endsWith(QLatin1String("min_gpuclk")));

    // a GPU capped before DeckOS saw it, without a list: the remembered ceiling stays Stock
    put(dir.filePath(QStringLiteral("sys/class/kgsl/kgsl-3d0/gpu_available_frequencies")), QString());
    put(dir.filePath(QStringLiteral("sys/class/kgsl/kgsl-3d0/max_gpuclk")), QStringLiteral("734000000"));
    QCOMPARE(uc::detect(dir.path(), 1100000000).gpu.stock, 1100000000);
}

void test_Underclock::cpu_table_fallback_without_list()
{
    QTemporaryDir dir;
    const QString p = dir.path() + QStringLiteral("/sys/devices/system/cpu/cpufreq/policy0/");
    put(p + QStringLiteral("cpuinfo_min_freq"), QStringLiteral("300000"));
    put(p + QStringLiteral("cpuinfo_max_freq"), QStringLiteral("2000000"));
    put(p + QStringLiteral("scaling_max_freq"), QStringLiteral("1500000"));
    put(p + QStringLiteral("scaling_min_freq"), QStringLiteral("300000"));
    const uc::Device d = uc::detect(dir.path());
    QCOMPARE(d.clusters.size(), 1);
    QCOMPARE(d.clusters[0].freqs, QVector<int>({ 300000, 1500000, 2000000 })); // ClusterTune's buildFallbackFrequencies
    QCOMPARE(d.clusters[0].stock, 2000000);
    QVERIFY(!d.gpu.present);
}

void test_Underclock::share_file_round_trip()
{
    uc::Profile a;
    a.id = QStringLiteral("user_1");
    a.name = QStringLiteral("Quiet");
    a.cpu = { { 0, 2227200 }, { 6, 2246400 } };
    a.gpu = 734000000;
    uc::Profile b;
    b.id = QStringLiteral("user_2");
    b.name = QStringLiteral("CPU only");
    b.cpu = { { 0, 1785600 } };

    const QByteArray json = uc::encodeShare({ a, b }, QStringLiteral("CQ8725S"));
    const QJsonObject root = QJsonDocument::fromJson(json).object();
    QCOMPARE(root.value(QLatin1String("schemaVersion")).toInt(), 2);
    QCOMPARE(root.value(QLatin1String("socModel")).toString(), QStringLiteral("CQ8725S"));
    QVERIFY(root.value(QLatin1String("profiles")).toArray()[1].toObject().value(QLatin1String("gpuMaxFrequencyHz")).isNull());

    const QVector<uc::Profile> back = uc::parseShare(json);
    QCOMPARE(back.size(), 2);
    QCOMPARE(back[0].id, a.id);
    QCOMPARE(back[0].name, a.name);
    QCOMPARE(back[0].cpu, a.cpu);
    QCOMPARE(back[0].gpu, a.gpu);
    QCOMPARE(back[1].gpu, 0);
}

void test_Underclock::share_file_rejects_garbage()
{
    QVERIFY(uc::parseShare("not json").isEmpty());
    QVERIFY(uc::parseShare("{\"profiles\": [{\"name\": \"no id\", \"maxFrequencies\": {\"0\": 1}}]}").isEmpty());
    // a policy that isn't a number and a 0 kHz value are dropped, as ClusterTune does
    const QVector<uc::Profile> p = uc::parseShare(
        "{\"profiles\": [{\"id\": \"x\", \"name\": \"X\", \"maxFrequencies\": {\"0\": 1785600, \"big\": 5, \"6\": 0}}]}");
    QCOMPARE(p.size(), 1);
    QCOMPARE(p[0].cpu.size(), 1);
}

void test_Underclock::bundled_presets_fit_the_chip()
{
    QTemporaryDir dir;
    make_tree(dir.path());
    uc::Device d = uc::detect(dir.path());
    d.soc = QStringLiteral("CQ8725S");
    // the test tree has every value the three CQ8725S presets use
    const QVector<uc::Profile> presets = uc::bundledFor(d);
    QVERIFY(!presets.isEmpty());
    for (const uc::Profile& p : presets) {
        QVERIFY(p.bundled);
        QVERIFY(p.id.startsWith(QLatin1String("bundled_cq8725s_")));
        QVERIFY(uc::fits(p, d));
    }
    QCOMPARE(presets.size(), 3);
    QCOMPARE(presets.first().name, QStringLiteral("Small Underclock"));

    d.soc = QStringLiteral("SM9999");
    QVERIFY(uc::bundledFor(d).isEmpty());
}

void test_Underclock::fits_and_targets()
{
    QTemporaryDir dir;
    make_tree(dir.path());
    const uc::Device d = uc::detect(dir.path());
    uc::Profile p;
    p.cpu = { { 0, 2227200 } };
    QVERIFY(uc::fits(p, d));
    p.cpu.insert(6, 2000000); // not in the table
    QVERIFY(!uc::fits(p, d));
    QCOMPARE(uc::cpuTarget(&p, d.clusters[1]), 1958400); // snapped down
    QCOMPARE(uc::cpuTarget(nullptr, d.clusters[1]), 4320000); // Stock
    p.cpu = { { 9, 1000 } }; // no such policy
    QVERIFY(!uc::fits(p, d));
    p.cpu.clear();
    p.gpu = 734000000;
    QVERIFY(uc::fits(p, d));
    QCOMPARE(uc::gpuTarget(&p, d.gpu), 734000000);
    QCOMPARE(uc::gpuTarget(nullptr, d.gpu), 1100000000);
}

void test_Underclock::script_caps_floors_and_unlocks()
{
    QTemporaryDir dir;
    make_tree(dir.path());
    const uc::Device d = uc::detect(dir.path());
    uc::Profile p;
    p.name = QStringLiteral("Medium");
    p.cpu = { { 0, 2227200 } };
    p.gpu = 734000000;

    const QString s = uc::script(d, &p, p.name);
    const QString max0 = QStringLiteral("'%1'").arg(d.clusters[0].maxPath);
    const QString min0 = QStringLiteral("'%1'").arg(d.clusters[0].minPath);
    QVERIFY(s.contains(QStringLiteral("cap %1 2227200 lock\nfloor %2 2227200 384000\ncap %1 2227200 lock\n").arg(max0, min0)));
    QVERIFY(s.contains(QStringLiteral("cap '%1' 4320000 open\n").arg(d.clusters[1].maxPath))); // not in the profile: Stock
    QVERIFY(s.contains(QStringLiteral("cap '%1' 734000000 lock").arg(d.gpu.maxPath)));
    QVERIFY(s.contains(QStringLiteral("floor '%1' 734000000 160000000").arg(d.gpu.minPath)));

    const QString stock = uc::script(d, nullptr, QStringLiteral("Stock"));
    QVERIFY(!stock.contains(QLatin1String(" lock\n")));
    QVERIFY(!stock.contains(QLatin1String("\nfloor ")));
    QVERIFY(stock.contains(QStringLiteral("cap %1 3532800 open\n").arg(max0)));
}

void test_Underclock::apply_to_tree_writes_limits()
{
    QTemporaryDir dir;
    make_tree(dir.path(), true); // an OEM left policy0's minimum at 2.75 GHz
    const uc::Device d = uc::detect(dir.path());
    uc::Profile p;
    p.cpu = { { 0, 1785600 } };
    p.gpu = 734000000;
    QVERIFY(uc::applyToTree(d, &p));
    QCOMPARE(get(d.clusters[0].maxPath), QStringLiteral("1785600"));
    QCOMPARE(get(d.clusters[0].minPath), QStringLiteral("384000")); // lowered below the new cap
    QCOMPARE(get(d.clusters[1].maxPath), QStringLiteral("4320000")); // back to Stock
    QCOMPARE(get(d.gpu.maxPath), QStringLiteral("734000000"));
    QCOMPARE(uc::detect(dir.path()).clusters[0].current, 1785600);
}

void test_Underclock::formats()
{
    QCOMPARE(uc::formatKHz(2745600), QStringLiteral("2.75 GHz"));
    QCOMPARE(uc::formatKHz(806400), QStringLiteral("806 MHz"));
    QCOMPARE(uc::formatHz(734000000), QStringLiteral("734 MHz"));
    QCOMPARE(uc::chipName(QStringLiteral("cq8725s")), QStringLiteral("Snapdragon 8 Elite"));
}


QTEST_MAIN(test_Underclock)
#include "test_Underclock.moc"
