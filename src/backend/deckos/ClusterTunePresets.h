// DeckOS - underclocking (Underclock.h)
// ClusterTune's bundled presets, verbatim from app/src/main/assets/bundled_profiles/ (ClusterTune 1.3.0,
// github.com/AurelioB/ClusterTune @ f2bccca, MIT License - Copyright (c) 2026 Aurelio Bernal; see docs/clustertune-port.md).
// To update: paste each upstream file between its R"CTJSON( and )CTJSON" markers, one entry per chip.

#pragma once

namespace deckos {
namespace clustertune {

struct BundledPresets { const char* socModel; const char* json; };

static const BundledPresets BUNDLED_PRESETS[] = {
    { "CQ8725S", R"CTJSON({
  "schemaVersion": 1,
  "socModel": "CQ8725S",
  "profiles": [
    {
      "id": "bundled_cq8725s_small",
      "name": "Small Underclock",
      "maxFrequencies": {
        "0": 2745600,
        "6": 3072000
      }
    },
    {
      "id": "bundled_cq8725s_medium",
      "name": "Medium Underclock",
      "maxFrequencies": {
        "0": 2227200,
        "6": 2246400
      }
    },
    {
      "id": "bundled_cq8725s_large",
      "name": "Large Underclock",
      "maxFrequencies": {
        "0": 1785600,
        "6": 1958400
      }
    }
  ]
}
)CTJSON" },
    { "QCS8550", R"CTJSON({
    "schemaVersion": 1,
    "socModel": "QCS8550",
    "profiles": [
        {
            "id": "bundled_qcs8550_small",
            "name": "Small Underclock",
            "maxFrequencies": {
                "0": 1785600,
                "3": 2323200,
                "7": 2476800
            }
        },
        {
            "id": "bundled_qcs8550_moderate",
            "name": "Medium Underclock",
            "maxFrequencies": {
                "0": 1555200,
                "3": 2054400,
                "7": 2092800
            }
        },
        {
            "id": "bundled_qcs8550_aggressive",
            "name": "Large Underclock",
            "maxFrequencies": {
                "0": 1459200,
                "3": 1785600,
                "7": 1843200
            }
        }
    ]
}
)CTJSON" },
};

} // namespace clustertune
} // namespace deckos
