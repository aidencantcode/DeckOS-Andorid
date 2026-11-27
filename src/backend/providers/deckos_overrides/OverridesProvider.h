// DeckOS
// Applies the changes made inside DeckOS (edited names/descriptions, scraped info and artwork,
// deckos/GameOverrides) to the games the other providers found. Runs last, also after a cache restore.

#pragma once

#include "providers/Provider.h"

#include <QSet>

namespace model { class Game; }


namespace providers {
namespace deckos_overrides {

class OverridesProvider : public Provider {
    Q_OBJECT

public:
    explicit OverridesProvider(QObject* parent = nullptr);
    Provider& run(SearchContext&) final;

private:
    int recover_from_records(SearchContext&, const QSet<model::Game*>& done);
};

} // namespace deckos_overrides
} // namespace providers
