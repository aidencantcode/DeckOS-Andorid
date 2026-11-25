// DeckOS - underclocking: ClusterTune built into DeckOS (Settings > Underclocking, `deckos.underclock`)
// Caps each CPU cluster's and the GPU's maximum clock, with profiles: ClusterTune's presets for the
// chip, the user's own, and ClusterTune export files in and out. A port of ClusterTune's core
// (github.com/AurelioB/ClusterTune, MIT, 1.3.0 @ f2bccca); what came from where and how to bring in
// later upstream changes: docs/clustertune-port.md. The stateless parts are in UnderclockCore.h.
//
// Android: the limits are written by AYN / Retroid's PServer (Java Privileged) as one script; the
// Quick Access menu's underclock slider (Stock, the presets, "Custom") and re-applying after a restart
// work from a copy of the profiles kept by Java (Session.setUnderclockSteps), so they need no Qt.
// PC: a simulated Snapdragon 8 Elite (a fake /sys tree in the config folder), so the page can be used
// and tested.
// Profiles: <config>/deckos/underclock.json.

#pragma once

#include "UnderclockCore.h"

#include <QObject>
#include <QVariantList>
#include <QVariantMap>

class QTimer;


namespace deckos {

class Underclock : public QObject {
    Q_OBJECT
    /// CPU limits were found (cpufreq policies)
    Q_PROPERTY(bool available READ available NOTIFY changed)
    /// they can be written: AYN / Retroid's system service (always on PC, simulated)
    Q_PROPERTY(bool canApply READ canApply NOTIFY changed)
    Q_PROPERTY(bool simulated READ simulated CONSTANT)
    /// "AYN / Retroid system service (PServer)", "" if none
    Q_PROPERTY(QString method READ method NOTIFY changed)
    /// "Snapdragon 8 Elite (CQ8725S)"
    Q_PROPERTY(QString chip READ chip NOTIFY changed)
    /// [{ policy, label ("Cores 0-5"), freqs: [kHz], stock, current }]
    Q_PROPERTY(QVariantList clusters READ clusters NOTIFY changed)
    /// { present, freqs: [Hz], stock, current }
    Q_PROPERTY(QVariantMap gpu READ gpu NOTIFY changed)
    /// Stock first, then the profiles in order: { id, name, stock, bundled, cpu: {"policy": kHz}, gpu, summary, fits }
    Q_PROPERTY(QVariantList profiles READ profiles NOTIFY changed)
    /// the applied profile ("stock" = the chip's own limits); Quick Access can change it too
    Q_PROPERTY(QString activeId READ activeId NOTIFY changed)
    /// the applied profile again after a restart (limits reset at boot)
    Q_PROPERTY(bool applyOnBoot READ applyOnBoot WRITE setApplyOnBoot NOTIFY changed)
    /// the profile Quick Access calls "Custom" (its slider: Stock, the presets, Custom)
    Q_PROPERTY(QString overlayCustomId READ overlayCustomId WRITE setOverlayCustomId NOTIFY changed)
    /// what the last apply did, for the page
    Q_PROPERTY(QString status READ status NOTIFY changed)

public:
    explicit Underclock(QObject* parent = nullptr);

    bool available();
    bool canApply();
    bool simulated() const;
    QString method();
    QString chip();
    QVariantList clusters();
    QVariantMap gpu();
    QVariantList profiles();
    QString activeId();
    bool applyOnBoot();
    void setApplyOnBoot(bool on);
    QString overlayCustomId();
    void setOverlayCustomId(const QString& id);
    QString status() const { return m_status; }

    /// reads the device again (the page opens, DeckOS comes back)
    Q_INVOKABLE void refresh();
    /// applies a profile ("stock" too); false if it can't be written
    Q_INVOKABLE bool apply(const QString& id);
    /// a new profile with the limits in effect now; returns its id
    Q_INVOKABLE QString createProfile();
    Q_INVOKABLE QString duplicateProfile(const QString& id);
    Q_INVOKABLE void renameProfile(const QString& id, const QString& name);
    /// kHz / Hz, 0 = Stock for that cluster or the GPU; the active profile is applied again a moment later
    Q_INVOKABLE void setCpuLimit(const QString& id, int policy, int kHz);
    Q_INVOKABLE void setGpuLimit(const QString& id, int hz);
    Q_INVOKABLE void deleteProfile(const QString& id);
    Q_INVOKABLE void moveProfile(const QString& id, int delta);
    /// puts back ClusterTune's presets that were deleted or changed; returns how many
    Q_INVOKABLE int restorePresets();
    /// a ClusterTune export file: "Imported 2 profiles" or an error starting with "!"
    Q_INVOKABLE QString importFile(const QString& path);
    /// every profile to a ClusterTune-compatible file in Downloads: its path, or an error starting with "!"
    Q_INVOKABLE QString exportFile();
    Q_INVOKABLE QVariantMap profile(const QString& id);
    Q_INVOKABLE QString formatCpu(int kHz) const { return uc::formatKHz(kHz); }
    Q_INVOKABLE QString formatGpu(int hz) const { return uc::formatHz(hz); }

signals:
    void changed();

private:
    QString m_root;             // "" on Android; the simulated tree on PC
    QString m_store_path;
    uc::Device m_device;
    QVector<uc::Profile> m_profiles;
    QStringList m_seeded;       // chips whose presets were added once (deleting one keeps it deleted)
    QString m_active = QStringLiteral("stock");      // PC; Android keeps it in Java (Quick Access sets it)
    QString m_overlay_custom;
    bool m_on_boot = true;
    int m_gpu_seen = 0;
    QString m_status;
    bool m_loaded = false;
    QTimer* const m_reapply;    // edits to the applied profile apply after a pause
    QTimer* const m_verify;     // Android: reads the limits back after an apply
    QString m_verify_name;

    void ensureLoaded();
    void load();
    void save();
    void detectDevice();
    void seedPresets();
    void pushToJava();
    void verify();
    uc::Profile* find(const QString& id);
    QVariantMap toMap(const uc::Profile* p);
    QString summary(const uc::Profile* p) const;
    void edited(const QString& id);
};

} // namespace deckos
