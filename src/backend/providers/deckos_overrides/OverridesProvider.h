// DeckOS
// Applies the changes made inside DeckOS (edited names/descriptions, scraped info and artwork,
// deckos/GameOverrides) to the games the other providers found. Runs last, also after a cache restore.

#pragma once

#include "providers/Provider.h"


namespace providers {
namespace deckos_overrides {

class OverridesProvider : public Provider {
    Q_OBJECT

public:
    explicit OverridesProvider(QObject* parent = nullptr);
    Provider& run(SearchContext&) final;
};

} // namespace deckos_overrides
} // namespace providers
