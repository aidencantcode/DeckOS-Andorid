# ClusterTune in DeckOS

DeckOS has ClusterTune's tuner built in as **Settings › Underclocking**, plus the underclock slider in Quick Access.

- **Upstream:** [AurelioB/ClusterTune](https://github.com/AurelioB/ClusterTune), MIT License, © 2026 Aurelio Bernal.
- **License text:** [`src/backend/deckos/ClusterTune-LICENSE.txt`](../src/backend/deckos/ClusterTune-LICENSE.txt).
- **Ported from:** `main` at `f2bcccadd10d9daebb38d0900b185b8265cb4779` (2026-10-25, the 1.3.0 release line). Ported 2026-11-25.

## Why a port and not the app itself

ClusterTune is about 25,000 lines of Kotlin and Jetpack Compose. DeckOS's Android build is Qt 5.15's Gradle template with Java 8, `compileSdk` 30 and no Kotlin. Hosting Compose would mean replacing that build, and its UI is touch-first besides.

So DeckOS ports the logic:
- to C++, shared by PC and Android and unit-tested;
- plus a little Java, so Quick Access and boot work without Qt.

The UI is rebuilt as a controller page in the Steam style. ClusterTune's file format is kept exactly, so profiles move between the two apps.

## What came from where

| ClusterTune (`app/src/main/…`) | DeckOS | Notes |
|---|---|---|
| `data/CpuPolicyDetector.kt` | `src/backend/deckos/UnderclockCore.cpp` `parse_policy` | Same rules: `scaling_available_frequencies`, the fallback table, `affected_cpus`/`related_cpus`, minimum candidates (never `scaling_min_freq`). |
| `data/GpuPolicyDetector.kt` | `UnderclockCore.cpp` `detect_kgsl`, `detect_devfreq` | KGSL first, then devfreq. The first ceiling seen is kept as Stock (`gpuStockSeen`). |
| `data/SocDetector.kt` | `Underclock.cpp` `soc_model` | The same property order, read with `__system_property_get`. |
| `data/ProfileJsonCodec.kt` | `UnderclockCore.cpp` `parseShare` / `encodeShare` | Share file schema 2. Policy keys are strings; a value of 0 is dropped. |
| `assets/bundled_profiles/*.json` | `src/backend/deckos/ClusterTunePresets.h` | Verbatim. |
| `data/BundledProfileProvider.kt` | `UnderclockCore.cpp` `bundledFor` | A preset is offered only if every one of its values exists on the device. |
| `PerformanceRepository.kt` `importProfilesJson` / `mergeImportedProfiles` | `Underclock.cpp` `importFile` | Same id = that profile updated; a preset stays a preset. |
| `root/host/HostFilesystem.kt` `applyInternal`, `reconcileMinimum`, `protectionMode`, `restoreNode` | `UnderclockCore.cpp` `script` | One shell script for PServer. Each cap is written, then any minimum above it is lowered, then the cap is written again. Caps are made read-only (`mode & 0555`); Stock makes them writable again. |
| `boot/BootCompletedReceiver.kt`, `BootRestoreRetry.kt` | `src/app/platform/android/.../UnderclockBootReceiver.java` | Re-applies the profile after a restart, with a few retries while PServer comes up. |
| Profile list, create, edit, duplicate, delete, reorder, export | `Underclock.cpp` + `src/themes/deckos/screens/settings/underclock.qml` | Presets are editable and deletable, as upstream; *Restore ClusterTune presets* brings them back. |

**Not ported yet** (see the roadmap):
- App and game automation: `apps/*`, `AppProfileCoordinator`. DeckOS will apply a profile per **game** instead, since it knows what it launches.
- Auto Tune: `autotune/*`, `root/host/HostAutoSession`, `HostTelemetry`.
- The sleep profile: `sleep/*`.
- Switch history: `logging/*`.
- The Quick Settings tile and the edge gesture: DeckOS has Quick Access instead.
- Root (`su`) as a second way to write: DeckOS only targets AYN and Retroid handhelds, which have PServer.
- The privileged host process and its journaled rollback: DeckOS writes with one script per apply and reads the result back.

## Bringing in upstream changes

1. Update the local clone, which lives outside the repo and is never committed:
   ```sh
   git -C third_party_refs/ClusterTune pull
   ```
2. See what changed since the port, in the files listed above:
   ```sh
   git -C third_party_refs/ClusterTune log --oneline f2bccca..HEAD -- \
     app/src/main/assets/bundled_profiles app/src/main/java/com/aure/clustertune/data/CpuPolicyDetector.kt \
     app/src/main/java/com/aure/clustertune/data/GpuPolicyDetector.kt app/src/main/java/com/aure/clustertune/data/ProfileJsonCodec.kt \
     app/src/main/java/com/aure/clustertune/data/BundledProfileProvider.kt app/src/main/java/com/aure/clustertune/data/SocDetector.kt \
     app/src/main/java/com/aure/clustertune/root/host/HostFilesystem.kt
   git -C third_party_refs/ClusterTune diff f2bccca..HEAD -- <one of those paths>
   ```
3. **New or changed presets** (a new chip is the most common update): paste each upstream `bundled_profiles/<SOC>.json` into `ClusterTunePresets.h`, one entry per chip.
4. **Other changes:** apply them to the DeckOS file in the table and extend `tests/backend/deckos/underclock/test_Underclock.cpp`.
5. Put the new commit hash in this file, in the "Ported from" line above, and in the header of `ClusterTunePresets.h`.
