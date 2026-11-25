// DeckOS
// Tests for RetroAchievements ROM hashing (deckos/RaMatcher): the hash must be the one rcheevos /
// RetroArch send to RetroAchievements, also for zipped ROMs.

#include <QtTest/QtTest>

#include "deckos/RaMatcher.h"

#include <QCryptographicHash>
#include <QFile>
#include <QTemporaryDir>

#include "miniz/miniz.h"


namespace {
QByteArray payload()
{
    QByteArray data;
    for (int i = 0; i < 32 * 1024; i++)
        data.append(static_cast<char>((i * 7 + 3) & 0xFF));
    return data;
}

QByteArray ines_rom()
{
    QByteArray header("NES\x1a", 4);
    header.append(QByteArray(12, '\0'));
    header[4] = 2; // 2 x 16 KB PRG
    return header + payload();
}

QString md5(const QByteArray& data)
{
    return QString::fromLatin1(QCryptographicHash::hash(data, QCryptographicHash::Md5).toHex());
}

void write(const QString& path, const QByteArray& data)
{
    QFile file(path);
    QVERIFY(file.open(QIODevice::WriteOnly));
    file.write(data);
}
} // namespace


class test_RaMatcher : public QObject {
    Q_OBJECT

private slots:
    void nes_header_is_skipped();
    void zipped_rom_hashes_like_the_rom();
    void whole_file_systems();
    void seven_zip_is_refused();
    void console_names();
};

void test_RaMatcher::nes_header_is_skipped()
{
    QTemporaryDir dir;
    const QString path = dir.filePath(QStringLiteral("Game (USA).nes"));
    write(path, ines_rom());

    QString error;
    QCOMPARE(deckos::ra_hash_file(path, 7, &error), md5(payload())); // RC_CONSOLE_NINTENDO
    QVERIFY(error.isEmpty());
}

void test_RaMatcher::zipped_rom_hashes_like_the_rom()
{
    QTemporaryDir dir;
    const QString path = dir.filePath(QStringLiteral("Game (USA).zip"));
    {
        const QByteArray readme("hello");
        const QByteArray rom = ines_rom();
        mz_zip_archive zip;
        mz_zip_zero_struct(&zip);
        QVERIFY(mz_zip_writer_init_heap(&zip, 0, 0));
        QVERIFY(mz_zip_writer_add_mem(&zip, "readme.txt", readme.constData(), static_cast<size_t>(readme.size()), MZ_DEFAULT_COMPRESSION));
        QVERIFY(mz_zip_writer_add_mem(&zip, "Game (USA).nes", rom.constData(), static_cast<size_t>(rom.size()), MZ_DEFAULT_COMPRESSION));
        void* buffer = nullptr;
        size_t size = 0;
        QVERIFY(mz_zip_writer_finalize_heap_archive(&zip, &buffer, &size));
        write(path, QByteArray(static_cast<const char*>(buffer), static_cast<int>(size)));
        mz_free(buffer); // finalize_heap_archive hands the buffer over
        mz_zip_writer_end(&zip);
    }
    QCOMPARE(deckos::ra_hash_file(path, 7), md5(payload()));
}

void test_RaMatcher::whole_file_systems()
{
    QTemporaryDir dir;
    const QString path = dir.filePath(QStringLiteral("game.gb"));
    write(path, payload());
    QCOMPARE(deckos::ra_hash_file(path, 4), md5(payload())); // RC_CONSOLE_GAMEBOY
}

void test_RaMatcher::seven_zip_is_refused()
{
    QTemporaryDir dir;
    const QString path = dir.filePath(QStringLiteral("game.7z"));
    write(path, payload());

    QString error;
    QVERIFY(deckos::ra_hash_file(path, 4, &error).isEmpty());
    QVERIFY(error.contains(QLatin1String("7z")));
}

void test_RaMatcher::console_names()
{
    QCOMPARE(deckos::ra_console_for(QStringLiteral("snes")), 3);
    QCOMPARE(deckos::ra_console_for(QStringLiteral("megadrive")), 1);
    QCOMPARE(deckos::ra_console_for(QStringLiteral(""), QStringLiteral("PSX")), 12);
    QCOMPARE(deckos::ra_console_for(QStringLiteral("Game Boy Advance")), 5);
    QCOMPARE(deckos::ra_console_for(QStringLiteral("not a system")), 0);
}


QTEST_MAIN(test_RaMatcher)
#include "test_RaMatcher.moc"
