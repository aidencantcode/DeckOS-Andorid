// Pegasus Frontend
// Copyright (C) 2017-2021  Mátyás Mustoha
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program. If not, see <http://www.gnu.org/licenses/>.


package org.pegasus_frontend.android;

import android.content.ComponentName;
import android.content.Intent;
import android.content.pm.PackageManager;
import android.content.pm.ResolveInfo;


final class App {
    private final String m_package_name;
    private final String m_app_name;
    private final String m_launch_action;
    private final String m_launch_component;

    public App(PackageManager pm, ResolveInfo info) {
        m_package_name = info.activityInfo.packageName;
        m_app_name = info.loadLabel(pm).toString();

        // DECKOS: the launcher activity this entry was found by - the one the home screen opens.
        // getLaunchIntentForPackage prefers an INFO activity when the app has one, a different screen.
        m_launch_action = Intent.ACTION_MAIN;
        m_launch_component = new ComponentName(m_package_name, info.activityInfo.name).flattenToShortString();
    }

    public String packageName() { return m_package_name; }
    public String appName() { return m_app_name; }
    public String launchAction() { return m_launch_action; }
    public String launchComponent() { return m_launch_component; }
}
