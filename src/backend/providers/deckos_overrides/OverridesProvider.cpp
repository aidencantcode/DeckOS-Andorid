// DeckOS
// See OverridesProvider.h

#include "OverridesProvider.h"

#include "Log.h"
#include "deckos/GameOverrides.h"
#include "model/gaming/Game.h"
#include "providers/SearchContext.h"
#include "model/gaming/GameFile.h"
#include "utils/PathTools.h"

#include <QDir>
#include <QFileInfo>
#include <QHash>
#include <QJsonObject>


namespace providers {
namespace deckos_overrides {

OverridesProvider::OverridesProvider(QObject* parent)
    : Provider(QLatin1String("deckos_overrides"), QStringLiteral("DeckOS game changes"),
               PROVIDER_FLAG_INTERNAL | PROVIDER_FLAG_HIDE_PROGRESS, parent)
{}

Provider& OverridesProvider::run(SearchContext& sctx)
{
    deckos::GameOverrides& store = deckos::GameOverrides::instance();
    store.reload();

    int applied = 0;
    QSet<model::Game*> done;
    for (const QString& key : store.keys()) {
        model::Game* game = nullptr;
        if (key.startsWith(QLatin1String("file:")))
            game = sctx.game_by_filepath(key.mid(5));
        else if (key.startsWith(QLatin1String("uri:")))
            game = sctx.game_by_uri(key.mid(4));

        if (game) {
            // DECKOS: the whole entry is applied, so DeckOS's files come only from it - not from the
            // game index cache, which can hold addresses of files moved or renamed since
            deckos::GameOverrides::dropOwnMedia(*game);
            deckos::GameOverrides::apply(*game, store.entry(key), false);
            done.insert(game);
            applied++;
        }
    }

    if (applied > 0)
        Log::info(display_name(), LOGMSG("Applied to %1 games").arg(applied));

    const int recovered = recover_from_records(sctx, done);
    if (recovered > 0)
        Log::info(display_name(), LOGMSG("Brought back %1 games from their game.txt").arg(recovered));
    return *this;
}

// DECKOS: a game without an entry may still have its record (game.txt) in <media>/<system>/<rom name>/:
// its path changed (/sdcard/... vs /storage/emulated/0/..., a ROM folder added again, the SD card got
// another name) or DeckOS's own list was lost. The media folder is listed once (one listing per system,
// no file checked per game); a record is used when the file name it was written for matches.
int OverridesProvider::recover_from_records(SearchContext& sctx, const QSet<model::Game*>& done)
{
    QHash<QString, QStringList> dirs_by_rom; // rom folder name -> <media>/<system>/<rom> folders
    bool listed = false;
    QHash<QString, QJsonObject> changes;
    QHash<QString, model::Game*> games;
    QSet<model::Game*> matched;

    const auto& files = sctx.current_filepath_to_entry_map();
    for (auto it = files.cbegin(); it != files.cend(); ++it) {
        // note: before SearchContext::finalize a game has no files model yet - only this map
        model::GameFile* const gamefile = it->second;
        model::Game* const game = gamefile ? gamefile->parentGame() : nullptr;
        if (!game || done.contains(game) || matched.contains(game))
            continue;

        if (!listed) {
            listed = true;
            const QString media = deckos::GameOverrides::mediaDir();
            for (const QFileInfo& sys : QDir(media).entryInfoList(QDir::Dirs | QDir::NoDotAndDotDot)) {
                for (const QString& rom : QDir(sys.absoluteFilePath()).entryList(QDir::Dirs | QDir::NoDotAndDotDot))
                    dirs_by_rom[rom].append(sys.absoluteFilePath() + QLatin1Char('/') + rom);
            }
            if (dirs_by_rom.isEmpty())
                return 0;
        }

        const QFileInfo rom_file(it->first);
        const QStringList candidates = dirs_by_rom.value(deckos::GameOverrides::safeName(rom_file.completeBaseName()));
        for (const QString& dir : candidates) {
            QString recorded;
            const QJsonObject entry = deckos::GameOverrides::readRecord(dir + QLatin1Char('/') + deckos::GameOverrides::recordName(), &recorded);
            if (entry.isEmpty())
                continue;
            const QFileInfo was(recorded);
            if (was.fileName() != rom_file.fileName())
                continue; // another game with that name (another system)
            if (candidates.size() > 1 && was.dir().dirName() != rom_file.dir().dirName())
                continue;
            // the key GameOverrides::keyFor gives once the library is loaded (the record's file is the
            // game's first file, the one keys are made of)
            const QString key = QStringLiteral("file:")
                + (rom_file.exists() ? ::clean_abs_path(rom_file) : it->first);
            changes.insert(key, entry);
            games.insert(key, game);
            matched.insert(game);
            break;
        }
    }
    if (changes.isEmpty())
        return 0;

    deckos::GameOverrides& store = deckos::GameOverrides::instance();
    store.updateAll(changes); // saved under the game's current path (and its record rewritten)
    for (auto it = games.cbegin(); it != games.cend(); ++it) {
        deckos::GameOverrides::dropOwnMedia(*it.value());
        deckos::GameOverrides::apply(*it.value(), store.entry(it.key()), false);
    }
    return changes.size();
}

} // namespace deckos_overrides
} // namespace providers
