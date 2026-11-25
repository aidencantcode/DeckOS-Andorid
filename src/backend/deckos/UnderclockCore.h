// DeckOS - underclocking, the parts with no state (Underclock.h has the rest)
// A port of ClusterTune's core (github.com/AurelioB/ClusterTune, MIT, 1.3.0 @ f2bccca; file map in
// docs/clustertune-port.md):
//  - detect():      CpuPolicyDetector + GpuPolicyDetector - every cpufreq policy with its frequency table,
//                   and the GPU's max clock (KGSL first, then devfreq)
//  - parseShare() / encodeShare(): ProfileJsonCodec - ClusterTune's export file, so profiles move both ways
//  - script():      what HostFilesystem's apply does, as one shell script for PServer: each cap written,
//                   any minimum above it lowered, the cap written again; a cap is made read-only so vendor
//                   services can't raise it back, and Stock makes it writable again
// All frequencies: CPU in kHz (as cpufreq), GPU in Hz (as KGSL).

#pragma once

#include <QByteArray>
#include <QMap>
#include <QString>
#include <QVector>


namespace deckos {
namespace uc {

struct Cluster {
    int policy = 0;
    QVector<int> cpus;          // the cores in it
    QVector<int> freqs;         // selectable maximums, ascending
    int stock = 0;              // the highest one (Stock)
    int current = 0;            // scaling_max_freq now
    int hwMin = 0;              // the lowest safe minimum (to lower an OEM-raised scaling_min_freq)
    QString maxPath;
    QString minPath;
};

struct Gpu {
    bool present = false;
    QVector<int> freqs;         // ascending; may be empty (then any value up to stock)
    int stock = 0;
    int current = 0;
    int hwMin = 0;
    QString maxPath;
    QString minPath;            // empty if there is none
};

struct Device {
    QVector<Cluster> clusters;
    Gpu gpu;
    QString soc;                // ro.soc.model etc., e.g. CQ8725S (Snapdragon 8 Elite)
    bool valid() const { return !clusters.isEmpty(); }
    const Cluster* cluster(int policy) const;
};

struct Profile {
    QString id;
    QString name;
    bool bundled = false;       // came from ClusterTune's presets (still editable, like upstream)
    QMap<int, int> cpu;         // policy -> kHz; a policy that isn't there stays at Stock
    int gpu = 0;                // Hz; 0 = Stock
};

/// root: "" for the real /sys, or a folder holding a copy of its tree (PC simulation, tests).
/// gpuStockSeen: the highest GPU maximum seen before (kernels without a frequency list).
Device detect(const QString& root, int gpuStockSeen = 0);

/// ClusterTune's share/export file ({schemaVersion, socModel, profiles:[{id, name, maxFrequencies:
/// {"policy": kHz}, gpuMaxFrequencyHz}]}), also its bundled preset files. Bad input: empty list.
QVector<Profile> parseShare(const QByteArray& json);
QByteArray encodeShare(const QVector<Profile>& profiles, const QString& soc);

/// ClusterTune's presets for this chip that fit the device (BundledProfileProvider)
QVector<Profile> bundledFor(const Device& device);

/// every value is one this device has (ClusterTune's import check)
bool fits(const Profile& profile, const Device& device);

/// the value written for a cluster: the profile's, snapped down to the table; Stock if it has none
int cpuTarget(const Profile* profile, const Cluster& cluster);
int gpuTarget(const Profile* profile, const Gpu& gpu);

/// the shell script that applies `profile` (nullptr = Stock) - run by PServer as a privileged user
QString script(const Device& device, const Profile* profile, const QString& label);

/// what the script does, done directly to a simulated tree (PC); returns false if a file is missing
bool applyToTree(const Device& device, const Profile* profile);

/// "2.75 GHz", "806 MHz"
QString formatKHz(int kHz);
QString formatHz(int hz);
/// "Snapdragon 8 Elite" for CQ8725S etc., "" if unknown
QString chipName(const QString& soc);

} // namespace uc
} // namespace deckos
