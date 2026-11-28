// DeckOS
// Tests for What's New's feed parsing (deckos/Feeds: RSS 2.0 as WordPress writes it, YouTube's Atom
// feeds), its HTML clean-up, and the version comparison of Updates.

#include <QtTest/QtTest>

#include "deckos/Feeds.h"
#include "deckos/Updates.h"

using namespace deckos;


class test_Feeds : public QObject {
    Q_OBJECT

private slots:
    void rss_wordpress();
    void atom_youtube();
    void plain_text();
    void versions();
};

void test_Feeds::rss_wordpress()
{
    // trimmed from retrohandhelds.gg/feed/ (2026-11-28)
    const QByteArray xml =
        "<?xml version=\"1.0\" encoding=\"UTF-8\"?><rss version=\"2.0\" xmlns:content=\"http://purl.org/rss/1.0/modules/content/\""
        " xmlns:dc=\"http://purl.org/dc/elements/1.1/\"><channel><title>Retro Handhelds</title>"
        "<item><title>Watermelon and SeedlessDS Get Their Latest Updates</title>"
        "<link>https://retrohandhelds.gg/watermelon/</link>"
        "<pubDate>Fri, 27 Nov 2026 22:02:35 +0000</pubDate>"
        "<description><![CDATA[<p>It may be out of season, but WatermelonDS isn&#8217;t done &amp; grows.</p>]]></description>"
        "<content:encoded><![CDATA[<p>First paragraph.</p><figure><img width=\"1024\" src=\"https://cdn.example/a.jpg\"/></figure><p>Second.</p>]]></content:encoded>"
        "</item>"
        "<item><title>No link here</title></item>"
        "</channel></rss>";
    const QVariantList items = Feeds::parseFeed(xml, QStringLiteral("Retro Handhelds"), false);
    QCOMPARE(items.size(), 1); // the item without a link is dropped
    const QVariantMap m = items.first().toMap();
    QCOMPARE(m.value(QStringLiteral("kind")).toString(), QStringLiteral("news"));
    QCOMPARE(m.value(QStringLiteral("source")).toString(), QStringLiteral("Retro Handhelds"));
    QCOMPARE(m.value(QStringLiteral("link")).toString(), QStringLiteral("https://retrohandhelds.gg/watermelon/"));
    QCOMPARE(m.value(QStringLiteral("image")).toString(), QStringLiteral("https://cdn.example/a.jpg"));
    QCOMPARE(m.value(QStringLiteral("summary")).toString(),
             QString::fromUtf8("It may be out of season, but WatermelonDS isn’t done & grows."));
    QCOMPARE(m.value(QStringLiteral("body")).toString(), QStringLiteral("First paragraph.\n\nSecond."));
    QCOMPARE(m.value(QStringLiteral("date")).toLongLong(),
             QDateTime(QDate(2026, 11, 27), QTime(22, 2, 35), Qt::UTC).toMSecsSinceEpoch());
}

void test_Feeds::atom_youtube()
{
    // trimmed from youtube.com/feeds/videos.xml?channel_id=... (2026-11-28)
    const QByteArray xml =
        "<?xml version=\"1.0\" encoding=\"UTF-8\"?><feed xmlns:yt=\"http://www.youtube.com/xml/schemas/2015\""
        " xmlns:media=\"http://search.yahoo.com/mrss/\" xmlns=\"http://www.w3.org/2005/Atom\">"
        "<title>Joey's Retro Handhelds</title>"
        "<entry><id>yt:video:aUhpfmPK-rE</id><yt:videoId>aUhpfmPK-rE</yt:videoId>"
        "<title>Anbernic RG47G1 &amp; Black Friday Sales</title>"
        "<link rel=\"alternate\" href=\"https://www.youtube.com/watch?v=aUhpfmPK-rE\"/>"
        "<published>2026-11-27T19:03:32+00:00</published><updated>2026-11-27T19:19:19+00:00</updated>"
        "<media:group><media:title>Anbernic RG47G1</media:title>"
        "<media:content url=\"https://www.youtube.com/v/aUhpfmPK-rE?version=3\" type=\"application/x-shockwave-flash\"/>"
        "<media:thumbnail url=\"https://i2.ytimg.com/vi/aUhpfmPK-rE/hqdefault.jpg\" width=\"480\" height=\"360\"/>"
        "<media:description>Links in the video</media:description></media:group></entry></feed>";
    const QVariantList items = Feeds::parseFeed(xml, QStringLiteral("Joey's Retro Handhelds"), true);
    QCOMPARE(items.size(), 1);
    const QVariantMap m = items.first().toMap();
    QCOMPARE(m.value(QStringLiteral("kind")).toString(), QStringLiteral("video"));
    QCOMPARE(m.value(QStringLiteral("videoId")).toString(), QStringLiteral("aUhpfmPK-rE"));
    QCOMPARE(m.value(QStringLiteral("title")).toString(), QStringLiteral("Anbernic RG47G1 & Black Friday Sales"));
    QCOMPARE(m.value(QStringLiteral("link")).toString(), QStringLiteral("https://www.youtube.com/watch?v=aUhpfmPK-rE"));
    QCOMPARE(m.value(QStringLiteral("image")).toString(), QStringLiteral("https://i.ytimg.com/vi/aUhpfmPK-rE/hqdefault.jpg"));
    QCOMPARE(m.value(QStringLiteral("summary")).toString(), QStringLiteral("Links in the video"));
    QCOMPARE(m.value(QStringLiteral("date")).toLongLong(),
             QDateTime(QDate(2026, 11, 27), QTime(19, 3, 32), Qt::UTC).toMSecsSinceEpoch());
}

void test_Feeds::plain_text()
{
    QCOMPARE(Feeds::plainText(QStringLiteral("<p>A&nbsp;<b>bold</b> &#x2019;move&#8217;</p><script>x()</script>"), 0),
             QString::fromUtf8("A bold ’move’"));
    const QString cut = Feeds::plainText(QStringLiteral("one two three four five six seven eight nine ten"), 20);
    QVERIFY(cut.endsWith(QString::fromUtf8("…")));
    QVERIFY(cut.size() <= 21);
    QCOMPARE(Feeds::firstImage(QStringLiteral("<img src='data:x'><img src=\"https://a/b.png\">")), QStringLiteral("https://a/b.png"));
}

void test_Feeds::versions()
{
    QCOMPARE(Updates::compareVersions(QStringLiteral("1.22.2"), QStringLiteral("v1.22.2")), 0);
    QCOMPARE(Updates::compareVersions(QStringLiteral("1.22.2"), QStringLiteral("1.22.10")), -1);
    QCOMPARE(Updates::compareVersions(QStringLiteral("11.2"), QStringLiteral("v11.2.0")), 0);
    QCOMPARE(Updates::compareVersions(QStringLiteral("13.1.1"), QStringLiteral("cmod_v13.1")), 1);
    QCOMPARE(Updates::compareVersions(QStringLiteral("0.1.6"), QStringLiteral("0.1.7")), -1);
    QCOMPARE(Updates::compareVersions(QStringLiteral("2127.0.1"), QStringLiteral("2127.1")), -1);
}


QTEST_MAIN(test_Feeds)
#include "test_Feeds.moc"
