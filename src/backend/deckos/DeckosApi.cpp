// DeckOS
// See DeckosApi.h

#include "DeckosApi.h"

#include "GameOverrides.h"
#include "InGame.h"
#include "Underclock.h"
#include "RaMatcher.h"
#include "RomLibrary.h"
#include "Scraper.h"
#include "Catalog.h"
#include "model/gaming/Game.h"
#include "model/gaming/Collection.h"
#include "model/gaming/GameFile.h"
#include "Paths.h"

#include <QDateTime>
#include <QDir>
#include <QFileInfo>
#include <QJsonObject>
#include <QUrl>
#include <algorithm>


namespace deckos {

DeckosApi::DeckosApi(model::ApiObject* api, QObject* parent)
    : QObject(parent)
    , m_scraper(new Scraper(api, this))
    , m_library(new RomLibrary(this))
    , m_ra(new RaMatcher(this))
    , m_ingame(new InGame(api, m_ra, this))
    , m_underclock(new Underclock(this))
{
    // a scan that changed system files reloads the library (from the cache for everything else)
    connect(m_library, &RomLibrary::scanFinished, this, [this](int, int changed) {
        if (changed > 0)
            emit libraryRefreshRequested();
    });
}

QObject* DeckosApi::libraryObj() const
{
    return m_library;
}

QObject* DeckosApi::raObj() const
{
    return m_ra;
}

QObject* DeckosApi::ingameObj() const
{
    return m_ingame;
}

QObject* DeckosApi::underclockObj() const
{
    return m_underclock;
}

QVariantList DeckosApi::gameScreenshots(QObject* obj, int limit) const
{
    QVariantList out;
    auto game = qobject_cast<model::Game*>(obj);
    if (!game || limit <= 0)
        return out;
    const auto& files = game->filesModel()->entries();
    if (files.empty())
        return out;
    const QFileInfo rom = files.front()->fileinfo();
    const QString base = rom.completeBaseName();
    if (base.isEmpty())
        return out;

    // RetroArch names screenshots "<content name>-YYMMDD-HHMMSS.png" and saves them next to the content
    // by default, or in its screenshots folder (checked 2026-11-25 against RetroArch's task_screenshot.c)
    const QStringList filters {
        base + QStringLiteral("-*.png"), base + QStringLiteral("-*.jpg"),
    };
    QStringList dirs { rom.absolutePath() };
#ifdef Q_OS_ANDROID
    dirs << QStringLiteral("/storage/emulated/0/RetroArch/screenshots");
#endif
    QVector<QFileInfo> found;
    for (const QString& path : qAsConst(dirs)) {
        const QDir dir(path);
        if (dir.exists())
            found += dir.entryInfoList(filters, QDir::Files | QDir::Readable).toVector();
    }
    const QDir own(paths::writableConfigDir() + QStringLiteral("/deckos/screenshots/") + base);
    if (own.exists())
        found += own.entryInfoList({ QStringLiteral("*.png"), QStringLiteral("*.jpg") }, QDir::Files | QDir::Readable).toVector();

    std::sort(found.begin(), found.end(), [](const QFileInfo& a, const QFileInfo& b) {
        return a.lastModified() > b.lastModified();
    });
    for (const QFileInfo& fi : qAsConst(found)) {
        if (out.size() >= limit)
            break;
        QVariantMap entry;
        entry.insert(QStringLiteral("url"), QUrl::fromLocalFile(fi.absoluteFilePath()).toString());
        entry.insert(QStringLiteral("time"), fi.lastModified().toMSecsSinceEpoch());
        out.append(entry);
    }
    return out;
}

void DeckosApi::onGameLaunching(const model::GameFile* file)
{
    m_ingame->onGameLaunching(file);
}

QObject* DeckosApi::scraperObj() const
{
    return m_scraper;
}

void DeckosApi::refreshLibrary()
{
    emit libraryRefreshRequested();
}

void DeckosApi::onLibraryReady()
{
    if (!m_started) {
        // first load of this run: look for new or removed ROMs in the background
        m_started = true;
        m_library->refreshEmulators();
        if (m_library->scanOnStart())
            m_library->scan();
    }
    m_scraper->onLibraryReady();
}

void DeckosApi::setGameTitle(QObject* obj, const QString& title)
{
    auto game = qobject_cast<model::Game*>(obj);
    if (!game)
        return;
    const QString key = GameOverrides::keyFor(*game);
    const QString clean = title.trimmed();

    if (clean.isEmpty()) {
        // back to the original name; keep any other change
        GameOverrides::instance().update(key, { { QStringLiteral("title"), QJsonValue::Null } });
        const QString original = game->extraMap().value(QStringLiteral("deckos_original_title")).toString();
        if (!original.isEmpty()) {
            game->setTitle(original);
            game->setSortBy(game->extraMap().value(QStringLiteral("deckos_original_sortBy"), original).toString());
            emit game->metadataChanged();
        }
        return;
    }
    GameOverrides::instance().update(key, { { QStringLiteral("title"), clean } });
    GameOverrides::apply(*game, { { QStringLiteral("title"), clean } }, true);
}

void DeckosApi::setGameDescription(QObject* obj, const QString& text)
{
    auto game = qobject_cast<model::Game*>(obj);
    if (!game)
        return;
    const QString key = GameOverrides::keyFor(*game);
    const QString clean = text.trimmed();

    if (clean.isEmpty()) {
        GameOverrides::instance().update(key, {
            { QStringLiteral("description"), QJsonValue::Null },
            { QStringLiteral("edited_description"), QJsonValue::Null },
        });
        const QVariantMap& extra = game->extraMap();
        if (extra.contains(QStringLiteral("deckos_original_description"))) {
            game->setDescription(extra.value(QStringLiteral("deckos_original_description")).toString());
            game->setSummary(extra.value(QStringLiteral("deckos_original_summary")).toString());
            emit game->metadataChanged();
        }
        return;
    }
    GameOverrides::instance().update(key, {
        { QStringLiteral("description"), clean },
        { QStringLiteral("edited_description"), true },
    });
    GameOverrides::apply(*game, { { QStringLiteral("description"), clean } }, true);
}

void DeckosApi::resetGame(QObject* obj)
{
    auto game = qobject_cast<model::Game*>(obj);
    if (!game)
        return;
    GameOverrides::instance().remove(GameOverrides::keyFor(*game));
    GameOverrides::restore(*game);
}

QVariantMap DeckosApi::gameChanges(QObject* obj) const
{
    auto game = qobject_cast<model::Game*>(obj);
    if (!game)
        return {};
    const QJsonObject entry = GameOverrides::instance().entry(GameOverrides::keyFor(*game));
    return {
        { QStringLiteral("edited"), !entry.isEmpty() },
        { QStringLiteral("titleEdited"), entry.contains(QStringLiteral("title")) },
        { QStringLiteral("descriptionEdited"), entry.value(QStringLiteral("edited_description")).toBool() },
        { QStringLiteral("launchEdited"), entry.contains(QStringLiteral("launch")) },
        { QStringLiteral("scraped"), entry.value(QStringLiteral("scraped")).toString() },
        { QStringLiteral("sources"), entry.value(QStringLiteral("sources")).toString() },
    };
}

} // namespace deckos

namespace {
// the catalog system a game belongs to: its collection's short name (DeckOS ROM-folder collections use
// the catalog id), or any of its collections that matches a catalog folder alias
const deckos::CatalogSystem* system_of(const model::Game& game)
{
    const deckos::Catalog& catalog = deckos::Catalog::instance();
    for (const model::Collection* coll : game.collectionsModel()->entries()) {
        if (const deckos::CatalogSystem* sys = catalog.byId(coll->shortName()))
            return sys;
        if (const deckos::CatalogSystem* sys = catalog.byFolderName(coll->shortName()))
            return sys;
        if (const deckos::CatalogSystem* sys = catalog.byFolderName(coll->name()))
            return sys;
    }
    return nullptr;
}
} // namespace

namespace deckos {

QString DeckosApi::gameLaunchCommand(QObject* obj) const
{
    auto game = qobject_cast<model::Game*>(obj);
    return game ? game->launchCmd() : QString();
}

void DeckosApi::setGameLaunchCommand(QObject* obj, const QString& command)
{
    auto game = qobject_cast<model::Game*>(obj);
    if (!game)
        return;
    const QString key = GameOverrides::keyFor(*game);
    const QString clean = command.trimmed();
    if (clean.isEmpty()) {
        GameOverrides::instance().update(key, { { QStringLiteral("launch"), QJsonValue::Null } });
        const QVariantMap& extra = game->extraMap();
        if (extra.contains(QStringLiteral("deckos_original_launch")))
            game->setLaunchCmd(extra.value(QStringLiteral("deckos_original_launch")).toString());
        return;
    }
    GameOverrides::instance().update(key, { { QStringLiteral("launch"), clean } });
    GameOverrides::apply(*game, { { QStringLiteral("launch"), clean } }, true);
}

QVariantList DeckosApi::gameEmulators(QObject* obj) const
{
    auto game = qobject_cast<model::Game*>(obj);
    const CatalogSystem* sys = game ? system_of(*game) : nullptr;
    return sys ? m_library->emulatorsFor(sys->id) : QVariantList();
}

void DeckosApi::setGameEmulator(QObject* obj, const QString& emulator_id)
{
    auto game = qobject_cast<model::Game*>(obj);
    const CatalogSystem* sys = game ? system_of(*game) : nullptr;
    const CatalogEmulator* emu = sys ? sys->emulator(emulator_id) : nullptr;
    if (emu)
        setGameLaunchCommand(game, launch_command(*emu));
}

} // namespace deckos
