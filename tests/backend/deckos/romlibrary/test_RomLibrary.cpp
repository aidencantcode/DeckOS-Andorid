// DeckOS
// Tests for the ROM folder scanner and the system catalog (deckos/RomLibrary, deckos/Catalog).

#include <QtTest/QtTest>

#include "Log.h"
#include "deckos/Catalog.h"
#include "deckos/RomLibrary.h"

#include <QDir>
#include <QFile>
#include <QTemporaryDir>


namespace {
const char CATALOG_JSON[] =
    "{\"systems\": ["
    " {\"id\": \"snes\", \"name\": \"Super Nintendo Entertainment System\", \"shortName\": \"SNES\","
    "  \"folders\": [\"snes\", \"Super Nintendo\"], \"extensions\": [\"sfc\", \"smc\"],"
    "  \"emulators\": [{\"id\": \"snes.ra64.snes9x\", \"name\": \"RetroArch64 Snes9x\", \"package\": \"com.retroarch.aarch64\","
    "   \"isDefault\": true, \"retroArch\": true,"
    "   \"args\": \"-n com.retroarch.aarch64/com.retroarch.browser.retroactivity.RetroActivityFuture --es ROM \\\"{file.path}\\\" --es LIBRETRO \\\"snes9x\\\"\"}]},"
    " {\"id\": \"ps1\", \"name\": \"Sony PlayStation\", \"shortName\": \"PS1\","
    "  \"folders\": [\"psx\", \"PlayStation\"], \"extensions\": [\"cue\", \"bin\", \"chd\", \"m3u\"], \"emulators\": []},"
    " {\"id\": \"gba\", \"name\": \"Game Boy Advance\", \"shortName\": \"GBA\","
    "  \"folders\": [\"gba\", \"Game Boy Advance\"], \"extensions\": [\"gba\"], \"emulators\": []}"
    "]}";

void touch(const QString& path, const QByteArray& content = {})
{
    QDir().mkpath(QFileInfo(path).absolutePath());
    QFile file(path);
    QVERIFY(file.open(QIODevice::WriteOnly));
    file.write(content);
}

const deckos::ScannedSystem* find(const std::vector<deckos::ScannedSystem>& list, const QString& id)
{
    for (const auto& sys : list)
        if (sys.id == id) return &sys;
    return nullptr;
}

QStringList names(const QStringList& paths)
{
    QStringList out;
    for (const QString& p : paths)
        out << QFileInfo(p).fileName();
    return out;
}
} // namespace


class test_RomLibrary : public QObject {
    Q_OBJECT

private slots:
    void initTestCase();

    void folder_aliases();
    void launch_command_expands_cores();
    void scan_finds_systems_and_games();
    void scan_hides_playlist_and_cue_parts();
    void scan_picked_system_folder();
    void scan_only_some_systems();
    void titles();

private:
    QTemporaryDir m_dir;
    QString m_catalog_path;
};

void test_RomLibrary::initTestCase()
{
    Log::init_qttest();
    QVERIFY(m_dir.isValid());
    m_catalog_path = m_dir.filePath(QStringLiteral("systems.json"));
    touch(m_catalog_path, CATALOG_JSON);
}

void test_RomLibrary::folder_aliases()
{
    const deckos::Catalog catalog(m_catalog_path);
    QCOMPARE(catalog.systems().size(), 3);
    QVERIFY(catalog.byFolderName(QStringLiteral("SNES")));
    QCOMPARE(catalog.byFolderName(QStringLiteral("SNES"))->id, QStringLiteral("snes"));
    QCOMPARE(catalog.byFolderName(QStringLiteral("super nintendo"))->id, QStringLiteral("snes"));
    QCOMPARE(catalog.byFolderName(QStringLiteral("Game-Boy_Advance"))->id, QStringLiteral("gba"));
    QCOMPARE(catalog.byFolderName(QStringLiteral("PS1"))->id, QStringLiteral("ps1")); // short name counts
    QVERIFY(!catalog.byFolderName(QStringLiteral("music")));
}

void test_RomLibrary::launch_command_expands_cores()
{
    const deckos::Catalog catalog(m_catalog_path);
    const deckos::CatalogEmulator* emu = catalog.byId(QStringLiteral("snes"))->emulator(QStringLiteral("snes.ra64.snes9x"));
    QVERIFY(emu);
    const QString cmd = deckos::launch_command(*emu);
    QVERIFY(cmd.startsWith(QStringLiteral("am start -n com.retroarch.aarch64/")));
    QVERIFY(cmd.contains(QStringLiteral("--es LIBRETRO \"/data/data/com.retroarch.aarch64/cores/snes9x_libretro_android.so\"")));
    QVERIFY(cmd.contains(QStringLiteral("--es ROM \"{file.path}\"")));

    deckos::CatalogEmulator standalone;
    standalone.args = QStringLiteral("-n org.ppsspp.ppsspp/.PpssppActivity -d \"{file.uri}\"");
    QCOMPARE(deckos::launch_command(standalone), QStringLiteral("am start -n org.ppsspp.ppsspp/.PpssppActivity -d \"{file.uri}\""));
}

void test_RomLibrary::scan_finds_systems_and_games()
{
    QTemporaryDir roms;
    touch(roms.filePath(QStringLiteral("snes/Chrono Trigger (USA).sfc")));
    touch(roms.filePath(QStringLiteral("snes/Super Mario World (USA).smc")));
    touch(roms.filePath(QStringLiteral("snes/readme.txt")));                 // wrong extension
    touch(roms.filePath(QStringLiteral("snes/media/boxart.sfc")));           // artwork folder
    touch(roms.filePath(QStringLiteral("snes/.hidden.sfc")));                // hidden file
    touch(roms.filePath(QStringLiteral("snes/RPGs/Earthbound (USA).sfc")));  // subfolder
    touch(roms.filePath(QStringLiteral("Game Boy Advance/Metroid Fusion (USA).gba")));
    touch(roms.filePath(QStringLiteral("unknown/whatever.sfc")));            // not a system folder

    const deckos::Catalog catalog(m_catalog_path);
    const auto result = deckos::scan_rom_folders(catalog, { roms.path() }, {});
    QCOMPARE(static_cast<int>(result.size()), 2);

    const deckos::ScannedSystem* snes = find(result, QStringLiteral("snes"));
    QVERIFY(snes);
    QCOMPARE(names(snes->files), (QStringList {
        QStringLiteral("Chrono Trigger (USA).sfc"),
        QStringLiteral("Earthbound (USA).sfc"),
        QStringLiteral("Super Mario World (USA).smc"),
    }));
    const deckos::ScannedSystem* gba = find(result, QStringLiteral("gba"));
    QVERIFY(gba);
    QCOMPARE(gba->files.size(), 1);
}

void test_RomLibrary::scan_hides_playlist_and_cue_parts()
{
    QTemporaryDir roms;
    touch(roms.filePath(QStringLiteral("psx/FF7 (Disc 1).cue")), "FILE \"FF7 (Disc 1).bin\" BINARY\n  TRACK 01 MODE2/2352\n");
    touch(roms.filePath(QStringLiteral("psx/FF7 (Disc 1).bin")));
    touch(roms.filePath(QStringLiteral("psx/FF7 (Disc 2).cue")), "FILE \"FF7 (Disc 2).bin\" BINARY\n");
    touch(roms.filePath(QStringLiteral("psx/FF7 (Disc 2).bin")));
    touch(roms.filePath(QStringLiteral("psx/FF7.m3u")), "FF7 (Disc 1).cue\n# comment\nFF7 (Disc 2).cue\n");
    touch(roms.filePath(QStringLiteral("psx/Crash.cue")), "FILE \"Crash.bin\" BINARY\n");
    touch(roms.filePath(QStringLiteral("psx/Crash.bin")));

    const deckos::Catalog catalog(m_catalog_path);
    const auto result = deckos::scan_rom_folders(catalog, { roms.path() }, {});
    const deckos::ScannedSystem* ps1 = find(result, QStringLiteral("ps1"));
    QVERIFY(ps1);
    QCOMPARE(names(ps1->files), (QStringList { QStringLiteral("Crash.cue"), QStringLiteral("FF7.m3u") }));
}

void test_RomLibrary::scan_picked_system_folder()
{
    // the user picked ".../ROMs/snes" itself instead of ".../ROMs"
    QTemporaryDir roms;
    touch(roms.filePath(QStringLiteral("snes/Game (USA).sfc")));
    const deckos::Catalog catalog(m_catalog_path);
    const auto result = deckos::scan_rom_folders(catalog, { roms.filePath(QStringLiteral("snes")) }, {});
    QCOMPARE(static_cast<int>(result.size()), 1);
    QCOMPARE(result.front().id, QStringLiteral("snes"));
    QCOMPARE(result.front().files.size(), 1);
}

void test_RomLibrary::scan_only_some_systems()
{
    QTemporaryDir roms;
    touch(roms.filePath(QStringLiteral("snes/A.sfc")));
    touch(roms.filePath(QStringLiteral("gba/B.gba")));
    const deckos::Catalog catalog(m_catalog_path);
    const auto result = deckos::scan_rom_folders(catalog, { roms.path() }, { QStringLiteral("gba") });
    QCOMPARE(static_cast<int>(result.size()), 1);
    QCOMPARE(result.front().id, QStringLiteral("gba"));
}

void test_RomLibrary::titles()
{
    const QStringList titles = deckos::game_titles({
        QStringLiteral("/r/Chrono Trigger (USA) [!].sfc"),
        QStringLiteral("/r/Legend of Zelda, The - A Link to the Past (USA).sfc"),
        QStringLiteral("/r/Tetris (USA).gb"),
        QStringLiteral("/r/Tetris (Europe).gb"),
        QStringLiteral("/r/(Hack) .sfc"),
    });
    QCOMPARE(titles.at(0), QStringLiteral("Chrono Trigger"));
    QCOMPARE(titles.at(1), QStringLiteral("The Legend of Zelda - A Link to the Past"));
    QCOMPARE(titles.at(2), QStringLiteral("Tetris (USA)"));    // same clean name twice: tags stay
    QCOMPARE(titles.at(3), QStringLiteral("Tetris (Europe)"));
    QCOMPARE(titles.at(4), QStringLiteral("(Hack) "));          // nothing left after cleaning: file name
}


QTEST_MAIN(test_RomLibrary)
#include "test_RomLibrary.moc"
