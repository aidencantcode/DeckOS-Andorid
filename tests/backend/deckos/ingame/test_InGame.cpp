// DeckOS
// Tests for deckos::InGame's launch command parsing: the emulator package that play time tracking and
// Quick Access's "Exit game" use.

#include <QtTest/QtTest>

#include "Log.h"
#include "deckos/InGame.h"


class test_InGame : public QObject {
    Q_OBJECT

private slots:
    void initTestCase() { Log::init_qttest(); }

    void package_from_command_data();
    void package_from_command();
};

void test_InGame::package_from_command_data()
{
    QTest::addColumn<QString>("command");
    QTest::addColumn<QString>("package");

    QTest::newRow("retroarch -n") << QStringLiteral("am start -n com.retroarch.aarch64/com.retroarch.browser.retroactivity.RetroActivityFuture -e ROM {file.path} -e LIBRETRO {core.path}")
                                  << QStringLiteral("com.retroarch.aarch64");
    QTest::newRow("short activity") << QStringLiteral("am start -n org.ppsspp.ppsspp/.PpssppActivity -a android.intent.action.VIEW -d {file.uri}")
                                    << QStringLiteral("org.ppsspp.ppsspp");
    QTest::newRow("quoted") << QStringLiteral("am start -n \"com.winlator/com.winlator.XServerDisplayActivity\" --es shortcut_path {file.path}")
                            << QStringLiteral("com.winlator");
    QTest::newRow("--component") << QStringLiteral("am start --user 0 --component xyz.aethersx2.android/.EmulationActivity -d {file.uri}")
                                 << QStringLiteral("xyz.aethersx2.android");
    QTest::newRow("-p") << QStringLiteral("am start -a android.intent.action.VIEW -p com.github.stenzek.duckstation -d {file.uri}")
                        << QStringLiteral("com.github.stenzek.duckstation");
    QTest::newRow("none") << QStringLiteral("am start -a android.intent.action.VIEW -d {file.uri} -t application/octet-stream")
                          << QString();
    QTest::newRow("-n in a path is not it") << QStringLiteral("am start -d /storage/games-n/x.iso")
                                            << QString();
}

void test_InGame::package_from_command()
{
    QFETCH(QString, command);
    QFETCH(QString, package);
    QCOMPARE(deckos::InGame::packageFromCommand(command), package);
}


QTEST_MAIN(test_InGame)
#include "test_InGame.moc"
