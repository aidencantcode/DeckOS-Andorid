// DeckOS
// See DeckosApi.h

#include "DeckosApi.h"

#include "GameOverrides.h"
#include "RomLibrary.h"
#include "Scraper.h"
#include "model/gaming/Game.h"

#include <QJsonObject>


namespace deckos {

DeckosApi::DeckosApi(model::ApiObject* api, QObject* parent)
    : QObject(parent)
    , m_scraper(new Scraper(api, this))
    , m_library(new RomLibrary(this))
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
        { QStringLiteral("scraped"), entry.value(QStringLiteral("scraped")).toString() },
        { QStringLiteral("sources"), entry.value(QStringLiteral("sources")).toString() },
    };
}

} // namespace deckos
