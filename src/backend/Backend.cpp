// Pegasus Frontend
// Copyright (C) 2018  Mátyás Mustoha
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


#include "Backend.h"

#include "AppSettings.h"
#include "Log.h"
#include "FrontendLayer.h"
#include "ProcessLauncher.h"
#include "ScriptRunner.h"
#include "Paths.h"
#include "platform/PowerCommands.h"
#include "types/AppCloseType.h"

// For type registration
#include "model/Api.h"
#include "model/keys/Key.h"
#include "model/gaming/Assets.h"
#include "model/gaming/GameFile.h"
#include "model/internal/Internal.h"
#include "deckos/DeckosApi.h" // DECKOS
#include "deckos/InGame.h" // DECKOS
#include "deckos/UserCollections.h" // DECKOS
#include "providers/pegasus_playtime/PlaytimeStats.h" // DECKOS: in-game play time
#include "utils/FolderListModel.h"
#include "SortFilterProxyModel/qqmlsortfilterproxymodel.h"
#include "SortFilterProxyModel/filters/filtersqmltypes.h"
#include "SortFilterProxyModel/proxyroles/proxyrolesqmltypes.h"
#include "SortFilterProxyModel/sorters/sortersqmltypes.h"

#include <QGuiApplication>
#include <algorithm>
#include <QQmlEngine>
#include <QTimer>

#if defined(WITH_SDL_GAMEPAD) || defined(WITH_SDL_POWER)
#include <SDL.h>
#endif

namespace model { class Key; }
namespace model { class Keys; }
class FolderListModel;


namespace {
void print_metainfo()
{
    Log::info(LOGMSG("DeckOS " GIT_REVISION " (" GIT_DATE ")"));  // DECKOS
    Log::info(LOGMSG("Running on %1 (%2, %3)").arg(
        QSysInfo::prettyProductName(),
        QSysInfo::currentCpuArchitecture(),
        QGuiApplication::platformName()));
    Log::info(LOGMSG("Qt version %1").arg(qVersion()));
}

void create_config_dirs()
{
    QDir configDir(paths::writableConfigDir());
    if (!configDir.mkpath(QStringLiteral("themes/")))
        Log::warning(LOGMSG("Failed to automatically create the `themes` directory"));
}

// On some platforms only one program can draw to the screen at a time,
// so Pegasus must hide its frontend as soon as the game has started.
bool platform_requires_hiding()
{
#ifdef Q_OS_ANDROID
    return true;
#else
    const QString platform = QGuiApplication::platformName();
    return platform == QLatin1String("eglfs")
        || platform == QLatin1String("linuxfb")
        || platform == QLatin1String("vkkhrdisplay")
        || platform.startsWith(QLatin1String("minimal"));
#endif
}

void register_api_classes()
{
    // register API classes:
    //   this should come before the ApiObject constructor,
    //   as that may produce language change signals

    constexpr auto API_URI = "Pegasus.Model";
    const QString error_msg = LOGMSG("Sorry, you cannot create this type in QML.");

    qmlRegisterUncreatableType<model::Collection>(API_URI, 0, 7, "Collection", error_msg);
    qmlRegisterUncreatableType<model::Game>(API_URI, 0, 2, "Game", error_msg);
    qmlRegisterUncreatableType<model::Assets>(API_URI, 0, 2, "GameAssets", error_msg);
    qmlRegisterUncreatableType<model::Locales>(API_URI, 0, 11, "Locales", error_msg);
    qmlRegisterUncreatableType<model::Themes>(API_URI, 0, 11, "Themes", error_msg);
    qmlRegisterUncreatableType<model::Providers>(API_URI, 0, 11, "Providers", error_msg);
    qmlRegisterUncreatableType<model::Key>(API_URI, 0, 10, "Key", error_msg);
    qmlRegisterUncreatableType<model::Keys>(API_URI, 0, 10, "Keys", error_msg);
    qmlRegisterUncreatableType<model::GamepadManager>(API_URI, 0, 12, "GamepadManager", error_msg);
    qmlRegisterUncreatableType<model::DeviceInfo>(API_URI, 0, 13, "Device", error_msg);

    // QML utilities
    qmlRegisterType<FolderListModel>("Pegasus.FolderListModel", 1, 0, "FolderListModel");

    // third-party
    qqsfpm::registerSorterTypes();
    qqsfpm::registerFiltersTypes();
    qqsfpm::registerProxyRoleTypes();
    qqsfpm::registerQQmlSortFilterProxyModelTypes();
}

void on_app_close(AppCloseType type)
{
    if (type == AppCloseType::SUSPEND) {
        return platform::power::suspend();
    }
    ScriptRunner::run(ScriptEvent::QUIT);
    switch (type) {
        case AppCloseType::REBOOT:
            ScriptRunner::run(ScriptEvent::REBOOT);
            break;
        case AppCloseType::SHUTDOWN:
            ScriptRunner::run(ScriptEvent::SHUTDOWN);
            break;
        default: break;
    }

    Log::info(LOGMSG("Closing Pegasus, goodbye!"));
    Log::close();

    QCoreApplication::quit();
    switch (type) {
        case AppCloseType::REBOOT:
            platform::power::reboot();
            break;
        case AppCloseType::SHUTDOWN:
            platform::power::shutdown();
            break;
        default: break;
    }
}
} // namespace


namespace backend {

Backend::Backend()
    : Backend(CliArgs {})
{}

Backend::~Backend()
{
    delete m_hide_timer;
    delete m_launcher;
    delete m_frontend;
    delete m_deckos; // DECKOS
    delete m_providerman;
    delete m_api_private;
    delete m_api_public;

#if defined(WITH_SDL_GAMEPAD) || defined(WITH_SDL_POWER)
    SDL_Quit();
#endif
}

Backend::Backend(const CliArgs& args)
    : m_args(args)
{
    // Make sure this comes before any file related operations
    AppSettings::general.portable = args.portable;

    Log::init(args.silent);
    print_metainfo();
    create_config_dirs();
    register_api_classes();

    AppSettings::load_providers();
    AppSettings::load_config();

    m_api_public = new model::ApiObject(args);
    m_api_private = new model::Internal(args);
    m_frontend = new FrontendLayer(m_api_public, m_api_private);
    m_deckos = new deckos::DeckosApi(m_api_public); // DECKOS
    m_frontend->setDeckosApi(m_deckos);
    m_launcher = new ProcessLauncher();
    m_providerman = new ProviderManager();

    m_hide_timer = new QTimer();
    m_hide_timer->setSingleShot(true);
    QObject::connect(m_hide_timer, &QTimer::timeout, [this](){
        Log::info(LOGMSG("Hiding the frontend after the configured delay"));
        m_frontend->teardown();
    });

    // the following communication is required because process handling
    // and destroying/rebuilding the frontend stack are asynchronous tasks;
    // see the relevant classes. Depending on the settings and the platform,
    // the frontend may also be kept alive while the game runs.

    // DECKOS: the in-game layer learns about the game first (connected before the launcher, so it runs
    // before Android switches to the emulator)
    QObject::connect(m_api_public, &model::ApiObject::launchGameFile,
                     m_deckos, &deckos::DeckosApi::onGameLaunching);

    // the Api asks the Launcher to start the game
    QObject::connect(m_api_public, &model::ApiObject::launchGameFile,
                     m_launcher, &ProcessLauncher::onLaunchRequested);

    // the Launcher tries to start the game, ask the Frontend
    // to tear down the UI, then report back to the Api
    QObject::connect(m_launcher, &ProcessLauncher::processLaunchOk,
                     m_api_public, &model::ApiObject::onGameLaunchOk);

    QObject::connect(m_api_public, &model::ApiObject::gameFileLaunched,
                     m_providerman, &ProviderManager::onGameLaunched);

    QObject::connect(m_launcher, &ProcessLauncher::processLaunchError,
                     m_api_public, &model::ApiObject::onGameLaunchError);

    QObject::connect(m_launcher, &ProcessLauncher::processLaunchOk,
                     [this](){ onProcessLaunched(); });

    QObject::connect(m_frontend, &FrontendLayer::teardownComplete,
                     m_launcher, &ProcessLauncher::onTeardownComplete);

    // when the game ends, the Launcher wakes up the Api and the Frontend
    QObject::connect(m_launcher, &ProcessLauncher::processFinished,
                     m_api_public, &model::ApiObject::onGameProcessFinished);
    QObject::connect(m_api_public, &model::ApiObject::gameFileFinished,
                     m_providerman, &ProviderManager::onGameFinished);

    QObject::connect(m_launcher, &ProcessLauncher::processFinished,
                     [this](){ onProcessFinished(); });

    // DECKOS: Android with the interface kept loaded: the game "finishes" when DeckOS is back in front
    QObject::connect(m_deckos->ingame(), &deckos::InGame::sessionEnded, [this](){
        Log::info(LOGMSG("Back in DeckOS after the game"));
        // only the time the game was in front counts (Java tracks which app is in front)
        const qint64 played = m_deckos->ingame()->playedSeconds();
        if (played >= 0) {
            Log::info(LOGMSG("Played for %1 s").arg(played));
            providers::playtime::PlaytimeStats::setNextDuration(played);
        }
        if (m_api_public->launchInProgress()) // (never without one; PC's DECKOS_FAKE_RUNNING has none)
            m_api_public->onGameProcessFinished();
        onProcessFinished();
    });
    // DECKOS: back in DeckOS while the game still runs behind it (PServer / root): the session goes on
    // (the game page offers Resume / Stop), but the controller works in DeckOS again
    QObject::connect(m_deckos->ingame(), &deckos::InGame::returnedToFront, [this](){
        m_hide_timer->stop();
        startGamepad();
    });
    // DECKOS: a launch while the last session is open. A game still running behind DeckOS is never
    // left running under another: the launch is dropped and the theme asks to close it first
    // (InGame::launchBlocked). Otherwise the old session ends (its play time is saved) and the launch
    // goes on - Pegasus allowed one launch at a time.
    QObject::connect(m_api_public, &model::ApiObject::launchWhileRunning, [this](model::GameFile* file){
        m_deckos->ingame()->onLaunchWhileRunning(file);
    });
    QObject::connect(m_launcher, &ProcessLauncher::processLaunchError, [this](){ runPendingScan(); });

    // Setting changes
    QObject::connect(m_api_private->settings().localesPtr(), &model::Locales::localeChanged,
                     m_api_public, &model::ApiObject::onLocaleChanged);
    QObject::connect(m_api_private->settings().themesPtr(), &model::Themes::themeChanged,
                     m_api_public, &model::ApiObject::onThemeChanged);
    QObject::connect(m_api_private->settings().keyEditorPtr(), &model::KeyEditor::keysChanged,
                     m_api_public->keysPtr(), &model::Keys::refresh_keys);
    QObject::connect(m_api_private->settingsPtr(), &model::Settings::providerReloadingRequested,
                     [this](){ onScanRequested(true); });

    QObject::connect(m_api_public, &model::ApiObject::favoritesChanged,
                     [this](){ onFavoritesChanged(); });

    // Loading progress
    QObject::connect(m_providerman, &ProviderManager::scanStarted,
                     m_api_private->scannerPtr(), &model::ScannerState::onScanStarted);
    QObject::connect(m_providerman, &ProviderManager::scanFinished,
                     m_api_private->scannerPtr(), &model::ScannerState::onScanFinished);
    QObject::connect(m_providerman, &ProviderManager::scanProgressChanged,
                     m_api_private->scannerPtr(), &model::ScannerState::onScanProgressChanged);
    QObject::connect(m_providerman, &ProviderManager::scanFinished,
                     [this](){ onScanFinished(); });
    QObject::connect(m_api_public, &model::ApiObject::gamedataReady,
                     m_api_private->scannerPtr(), &model::ScannerState::onUiReady);
    QObject::connect(m_api_public, &model::ApiObject::gamedataReady, // DECKOS: auto-scrape
                     m_deckos, &deckos::DeckosApi::onLibraryReady);
    QObject::connect(m_deckos, &deckos::DeckosApi::libraryRefreshRequested, // DECKOS: cache-aware reload
                     [this](){ onScanRequested(false); });

    // partial QML reload
    QObject::connect(&m_api_private->meta(), &model::Meta::qmlClearCacheRequested,
                     m_frontend, &FrontendLayer::clearCache);

    // quit/reboot/shutdown request
    // DECKOS: a game still running behind DeckOS: its play time is saved first
    QObject::connect(&m_api_private->system(), &model::System::appCloseRequested, [this](AppCloseType type){
        if (type != AppCloseType::SUSPEND)
            m_deckos->ingame()->finishSession();
        on_app_close(type);
    });
}

void Backend::start()
{
    m_api_private->settings().postInit();
    onProcessFinished();
    onScanRequested(AppSettings::general.scan_on_launch);
}

void Backend::onScanRequested(const bool force_refresh)
{
    // DECKOS: not while a launched game's session is open (on Android it can last as long as the game
    // runs behind DeckOS): the reload would delete the game file it ends with. It runs right after.
    if (m_api_public->launchInProgress()) {
        Log::info(LOGMSG("Library reload postponed until the game ends"));
        m_pending_scan = std::max(m_pending_scan, force_refresh ? 1 : 0);
        return;
    }
    m_api_public->clearGameData();
    m_providerman->run(force_refresh);
}

void Backend::runPendingScan()
{
    if (m_pending_scan < 0)
        return;
    // after the current call chain: a new launch may be on its way (launchWhileRunning)
    QTimer::singleShot(0, m_api_public, [this](){
        if (m_pending_scan < 0 || m_api_public->launchInProgress())
            return;
        const bool force = m_pending_scan == 1;
        m_pending_scan = -1;
        onScanRequested(force);
    });
}

void Backend::startGamepad()
{
    if (m_gamepad_on)
        return;
    m_gamepad_on = true;
    m_api_private->gamepad().start(m_args);
}

void Backend::onScanFinished()
{
    std::vector<model::Collection*> colls;
    std::swap(m_providerman->foundCollections(), colls);

    std::vector<model::Game*> games;
    std::swap(m_providerman->foundGames(), games);

    // DECKOS: the user's collections join in here, after the game index cache was saved (never in it)
    m_deckos->collections()->apply(colls, games);

    m_api_public->setGameData(std::move(colls), std::move(games));
}

void Backend::onFavoritesChanged()
{
    m_providerman->onFavoritesChanged(m_api_public->allGames()->entries());
}

void Backend::onProcessLaunched()
{
#ifdef Q_OS_ANDROID
    // DECKOS: Pegasus destroyed the whole interface at every launch and rebuilt it straight away, while
    // the emulator was starting, and Android's launcher returns at once, so every session was saved
    // as ~0 s of play time. DeckOS stays loaded instead (Android doesn't draw it in the background) and
    // the session ends when DeckOS is back in front: same page as before, real play time.
    if (m_deckos->ingame()->keepLoaded()) {
        Log::info(LOGMSG("Keeping DeckOS loaded while the game runs"));
        m_api_private->gamepad().stop();
        m_gamepad_on = false;
        m_deckos->ingame()->beginSession();
        return;
    }
#endif

    int delay_sec = AppSettings::general.hide_delay_after_launch;
    if (delay_sec != 0 && platform_requires_hiding()) {
        Log::info(LOGMSG("This platform allows only one program on the screen, hiding Pegasus immediately"));
        delay_sec = 0;
    }

    if (delay_sec == 0) {
        m_frontend->teardown();
    }
    else if (delay_sec > 0) {
        Log::info(LOGMSG("Keeping the frontend visible for %1 seconds").arg(delay_sec));
        m_hide_timer->start(delay_sec * 1000);
    }
    else {
        Log::info(LOGMSG("Keeping the frontend visible while the program runs"));
    }

    m_api_private->gamepad().stop();
    m_gamepad_on = false;
}

void Backend::onProcessFinished()
{
    m_hide_timer->stop();

    if (m_frontend->isLoaded())
        m_frontend->bringToFront();
    else
        m_frontend->rebuild();

    startGamepad(); // DECKOS: once (returnedToFront may have started it)
    runPendingScan(); // DECKOS: a library reload asked for while the game ran
}

} // namespace backend
