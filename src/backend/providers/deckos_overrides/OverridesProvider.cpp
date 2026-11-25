// DeckOS
// See OverridesProvider.h

#include "OverridesProvider.h"

#include "Log.h"
#include "deckos/GameOverrides.h"
#include "model/gaming/Game.h"
#include "providers/SearchContext.h"


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
    for (const QString& key : store.keys()) {
        model::Game* game = nullptr;
        if (key.startsWith(QLatin1String("file:")))
            game = sctx.game_by_filepath(key.mid(5));
        else if (key.startsWith(QLatin1String("uri:")))
            game = sctx.game_by_uri(key.mid(4));

        if (game) {
            deckos::GameOverrides::apply(*game, store.entry(key), false);
            applied++;
        }
    }

    if (applied > 0)
        Log::info(display_name(), LOGMSG("Applied to %1 games").arg(applied));
    return *this;
}

} // namespace deckos_overrides
} // namespace providers
