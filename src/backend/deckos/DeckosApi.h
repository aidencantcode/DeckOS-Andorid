// DeckOS
// The `deckos` object themes see: editing a game's name/description and the scraper.

#pragma once

#include <QObject>
#include <QVariantMap>

namespace model { class ApiObject; }


namespace deckos {

class Scraper;
class RomLibrary;

class DeckosApi : public QObject {
    Q_OBJECT
    Q_PROPERTY(QObject* scraper READ scraperObj CONSTANT)
    Q_PROPERTY(QObject* library READ libraryObj CONSTANT)

public:
    explicit DeckosApi(model::ApiObject* api, QObject* parent = nullptr);

    /// New name / description for a game (empty = back to what the game's metadata says).
    /// Saved at once and shown everywhere; kept across library reloads and restarts.
    Q_INVOKABLE void setGameTitle(QObject* game, const QString& title);
    Q_INVOKABLE void setGameDescription(QObject* game, const QString& text);
    /// Forgets every DeckOS change to this game (edits and scraped info/artwork).
    Q_INVOKABLE void resetGame(QObject* game);
    /// { edited: bool, titleEdited, descriptionEdited, scraped: ISO date or "", sources: "TheGamesDB, ..." }
    Q_INVOKABLE QVariantMap gameChanges(QObject* game) const;

    /// Reloads the library: from the game index cache if no game folder or metadata file changed
    /// (seconds), otherwise a full scan. Settings > Library > "Reload all games" forces a full scan.
    Q_INVOKABLE void refreshLibrary();

    Scraper* scraper() const { return m_scraper; }
    QObject* scraperObj() const;
    QObject* libraryObj() const;

    void onLibraryReady();

signals:
    void libraryRefreshRequested();

private:
    Scraper* const m_scraper;
    RomLibrary* const m_library;
    bool m_started = false;
};

} // namespace deckos
