// DeckOS - in-game layer
// Underclocking without Qt: Quick Access's slider (Stock, ClusterTune's presets, "Custom"), the HUD's
// profile name, and the profile applied again after a restart. DeckOS's Settings > Underclocking (C++
// deckos/Underclock, ClusterTune built in - docs/clustertune-port.md) owns the profiles and hands this
// side ready-made scripts: Session.setUnderclockSteps / setUnderclockBootScript. Every limit is written
// by one of those scripts through PServer (Privileged).

package com.deckos.ingame;

import android.content.Context;

import org.json.JSONArray;
import org.json.JSONObject;

import java.util.ArrayList;
import java.util.List;


final class Underclock {
    private Underclock() {}

    static final String STOCK = "stock";
    static final String PREF_STEPS = "uc_steps";            // {steps: [{id, label, name, script}], onBoot}
    static final String PREF_ACTIVE = "uc_active";          // profile id
    static final String PREF_ACTIVE_LABEL = "uc_active_label";
    static final String PREF_ACTIVE_SCRIPT = "uc_active_script";

    static final class Step {
        String id, label, name, script;
    }

    private static JSONObject state() {
        try {
            return new JSONObject(Session.prefs().getString(PREF_STEPS, "{}"));
        }
        catch (Exception e) {
            return new JSONObject();
        }
    }

    static List<Step> steps() {
        List<Step> out = new ArrayList<>();
        JSONArray a = state().optJSONArray("steps");
        if (a == null) return out;
        for (int i = 0; i < a.length(); i++) {
            JSONObject o = a.optJSONObject(i);
            if (o == null) continue;
            Step s = new Step();
            s.id = o.optString("id", "");
            s.label = o.optString("label", "");
            s.name = o.optString("name", s.label);
            s.script = o.optString("script", "");
            if (!s.id.isEmpty() && !s.script.isEmpty()) out.add(s);
        }
        return out;
    }

    /// the slider is worth showing: PServer is there and there is more than Stock to pick
    static boolean available() {
        return Privileged.available() && steps().size() > 1;
    }

    static String activeId() {
        return Session.prefs().getString(PREF_ACTIVE, STOCK);
    }

    /// the slider position of the applied profile; -1 when it's one Quick Access doesn't list
    static int index(List<Step> steps) {
        String id = activeId();
        for (int i = 0; i < steps.size(); i++)
            if (steps.get(i).id.equals(id)) return i;
        return -1;
    }

    static boolean apply(Context ctx, Step s) {
        return run(ctx, s.id, s.label, s.script);
    }

    /// runs a profile's script and remembers it (the HUD shows `label`; a restart runs `script` again)
    static boolean run(Context ctx, String id, String label, String script) {
        if (!Privileged.runScript(ctx, "underclock.sh", script))
            return false;
        Session.prefs().edit()
            .putString(PREF_ACTIVE, id)
            .putString(PREF_ACTIVE_LABEL, STOCK.equals(id) ? "" : label)
            .putString(PREF_ACTIVE_SCRIPT, STOCK.equals(id) ? "" : script)
            .apply();
        SessionService.refresh();
        return true;
    }

    /// for the HUD: "" at Stock
    static String activeLabel() {
        return Session.prefs().getString(PREF_ACTIVE_LABEL, "");
    }

    /// apply the profile again after a restart (Settings › Underclocking)
    static boolean onBoot() {
        return state().optBoolean("onBoot", true);
    }

    static String activeScript() {
        return Session.prefs().getString(PREF_ACTIVE_SCRIPT, "");
    }
}
