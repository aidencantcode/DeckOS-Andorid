import QtQuick 2.15
import QtMultimedia 5.15
import QtQuick.Layouts 1.15
import QtGraphicalEffects 1.15
import QtQuick.Window 2.15
import "javascript/RetroAchievementsApi.js" as RAApi
import "screens/settings/parts" // DECKOS: FolderPicker, TextEntry (the DeckOS folder card)



FocusScope {
    id: root
    anchors.fill: parent
    focus: true
    readonly property var theme: root // DECKOS: the parts used here (SteamKeyboard) read `theme`

    property int currentPage: 0
    property var currentGame: null
    // DECKOS: the Library, Home and Search hand over a sorted model's row: a copy of the game's fields,
    // with the game itself in modelData. Keep the game: Properties' rename and description edits were
    // refused for the copy (deckos.setGameTitle needs the game), and its fields never updated anyway.
    onCurrentGameChanged: {
        if (currentGame && currentGame.modelData && currentGame.modelData !== currentGame)
            currentGame = currentGame.modelData
    }
        property bool isTransitioning: false
    property bool navTrigger: false
    // Добавить эту строку:
    property bool returnFromLaunch: false 
    
    property string mediaFilterGame: ""


    
    
    // SETTINGS
        // Читаем из JSON (через api.memory) при запуске. 
    // Если ключа еще нет в файле, ставим дефолт.
    property bool asyncLoading: api.memory.has("asyncLoading") ? api.memory.get("asyncLoading") : false
    property bool animatedCovers: api.memory.has("animatedCovers") ? api.memory.get("animatedCovers") : false
    property real interfaceScale: api.memory.has("interfaceScale") ? api.memory.get("interfaceScale") : 0.5

    // DECKOS: StMini draws every page on a logical canvas 1080 px tall whose width follows the screen's
    // aspect ratio (Odin 3 1920x1080 -> 1920x1080, Retroid Pocket Classic 1240x1080 -> 1240x1080).
    // The Accessibility "Interface scale" slider (0..1, 0.5 = default) was saved but never applied;
    // it now changes the canvas height: 0 -> UI x0.8, 0.5 -> x1.0, 1 -> x1.2.
    readonly property real uiScale: 0.8 + 0.4 * Math.max(0, Math.min(1, interfaceScale))
    readonly property real canvasHeight: Math.round(1080 / uiScale)

    // DECKOS: the BigScreenFE parts (ra/) size things with Pegasus's vpx(), designed for a 720 px tall
    // window. The canvas is 1080 logical px tall, so this matches Pegasus at 1080p without scaling twice
    // (Pegasus's own vpx() would multiply by the real window height on top of the canvas scale).
    function vpx(value) { return value * 1.5 }
    property bool animationInFocus: api.memory.has("animationInFocus") ? api.memory.get("animationInFocus") : false


    // Как только переменная меняется внутри темы, даем команду движку намертво записать это в JSON
    onAsyncLoadingChanged: api.memory.set("asyncLoading", asyncLoading)
    onAnimatedCoversChanged: api.memory.set("animatedCovers", animatedCovers)
    onInterfaceScaleChanged: api.memory.set("interfaceScale", interfaceScale)
    onAnimationInFocusChanged: api.memory.set("animationInFocus", animationInFocus)
    
        // Глобальные переменные звука
    property real interfaceVolume: api.memory.has("interfaceVolume") ? api.memory.get("interfaceVolume") : 1.0
    property bool interfaceSoundEnabled: api.memory.has("interfaceSoundEnabled") ? api.memory.get("interfaceSoundEnabled") : true
    
    onInterfaceVolumeChanged: api.memory.set("interfaceVolume", interfaceVolume)
    onInterfaceSoundEnabledChanged: api.memory.set("interfaceSoundEnabled", interfaceSoundEnabled)
    
        // Настройка отображения заряда (в theme.qml)
    property bool showBatteryPercent: api.memory.has("showBatteryPercent") ? api.memory.get("showBatteryPercent") : true
    onShowBatteryPercentChanged: api.memory.set("showBatteryPercent", showBatteryPercent)
    
        // Настройка формата времени (General)
    property bool use24HourFormat: api.memory.has("use24HourFormat") ? api.memory.get("use24HourFormat") : true
    onUse24HourFormatChanged: api.memory.set("use24HourFormat", use24HourFormat)
    
        // Настройки High Contrast
    property bool highContrastHome: api.memory.has("highContrastHome") ? api.memory.get("highContrastHome") : false
    property bool highContrastGameMenu: api.memory.has("highContrastGameMenu") ? api.memory.get("highContrastGameMenu") : false
    property bool highContrastLogo: api.memory.has("highContrastLogo") ? api.memory.get("highContrastLogo") : false // Новая переменная
    
    onHighContrastHomeChanged: api.memory.set("highContrastHome", highContrastHome)
    onHighContrastGameMenuChanged: api.memory.set("highContrastGameMenu", highContrastGameMenu)
    onHighContrastLogoChanged: api.memory.set("highContrastLogo", highContrastLogo) // Новая привязка
    
        // Настройки контроллера
    property bool nintendoLayout: api.memory.has("nintendoLayout") ? api.memory.get("nintendoLayout") : false
    property bool universalIcons: api.memory.has("universalIcons") ? api.memory.get("universalIcons") : false
    
    onNintendoLayoutChanged: api.memory.set("nintendoLayout", nintendoLayout)
    onUniversalIconsChanged: api.memory.set("universalIcons", universalIcons)
    
        // Настройки учетной записи (сохранение)
    // DECKOS: one RetroAchievements account for the whole app - StMini's sign-in page and the
    // ACHIEVEMENTS tab (ra/, keys ra_api_user / ra_api_key) now read and write the same values
    property string savedUsername: api.memory.has("ra_api_user") ? api.memory.get("ra_api_user")
                                 : api.memory.has("savedUsername") ? api.memory.get("savedUsername") : ""
    property string savedApiKey: api.memory.has("ra_api_key") ? api.memory.get("ra_api_key")
                               : api.memory.has("savedApiKey") ? api.memory.get("savedApiKey") : ""
    property bool rememberMe: api.memory.has("rememberMe") ? api.memory.get("rememberMe") : true

    onRememberMeChanged: api.memory.set("rememberMe", rememberMe)

    property string globalUserName: "" // DECKOS: was a Russian "no data" placeholder
property string globalUserPic: ""
property string globalUserLevel: "0"

    // DECKOS: the user's own profile (Settings > Profile), shown in the side menu and the top bar
    property string profileName: api.memory.has("profileName") ? api.memory.get("profileName") : ""
    property string profilePicture: api.memory.has("profilePicture") ? api.memory.get("profilePicture") : ""
    onProfileNameChanged: api.memory.set("profileName", profileName)
    onProfilePictureChanged: api.memory.set("profilePicture", profilePicture)
    readonly property string profileDisplayName: profileName !== "" ? profileName
                                               : globalUserName !== "" ? globalUserName : "Player"
    readonly property string profilePictureSource: profilePicture !== "" ? profilePicture : globalUserPic

    // DECKOS: where the RetroAchievements sign-in page (13) goes back to: 8 = the game page it was opened
    // from, 6 = Settings (with pendingSettingsPage), -1 = Home
    property int loginReturnPage: -1

    // DECKOS: open Settings on a given section (e.g. "settings/profile.qml"); settings.qml picks it up
    property string pendingSettingsPage: ""
    function openSettingsPage(source) {
        pendingSettingsPage = source
        if (currentPage === 6 && pageLoader.item && typeof pageLoader.item.selectSection === "function")
            pageLoader.item.selectSection(source)
        else
            openPage(6)
    }

onHighContrastBottomBarChanged: api.memory.set("highContrastBottomBar", highContrastBottomBar)

property bool highContrastBottomBar: api.memory.has("highContrastBottomBar") ? api.memory.get("highContrastBottomBar") : false


    property int libraryRows: api.memory.has("libraryRows") ? api.memory.get("libraryRows") : 3
    property int homeRows: api.memory.has("homeRows") ? api.memory.get("homeRows") : 3
    property int searchRows: api.memory.has("searchRows") ? api.memory.get("searchRows") : 3

    onLibraryRowsChanged: api.memory.set("libraryRows", libraryRows)
    onHomeRowsChanged: api.memory.set("homeRows", homeRows)
    onSearchRowsChanged: api.memory.set("searchRows", searchRows)
    
    property int gameListSize: api.memory.has("gameListSize") ? api.memory.get("gameListSize") : 2
    onGameListSizeChanged: api.memory.set("gameListSize", gameListSize)
    
    property bool alternativeHomeScreen: api.memory.has("alternativeHomeScreen") ? api.memory.get("alternativeHomeScreen") : false
    onAlternativeHomeScreenChanged: api.memory.set("alternativeHomeScreen", alternativeHomeScreen)

    property bool roundedCovers: api.memory.has("roundedCovers") ? api.memory.get("roundedCovers") : false
    onRoundedCoversChanged: api.memory.set("roundedCovers", roundedCovers)
    
    // DECKOS: game page trailer: 0 off, 1 muted, 2 with sound; seconds before it fades in
    property int trailerMode: api.memory.has("trailerMode") ? api.memory.get("trailerMode") : 1
    property int trailerDelay: api.memory.has("trailerDelay") ? api.memory.get("trailerDelay") : 2 // DECKOS: 2 s idle, then the trailer
    onTrailerModeChanged: api.memory.set("trailerMode", trailerMode)
    onTrailerDelayChanged: api.memory.set("trailerDelay", trailerDelay)

    property bool gameLaunchingAnimation: api.memory.has("gameLaunchingAnimation") ? api.memory.get("gameLaunchingAnimation") : true
onGameLaunchingAnimationChanged: api.memory.set("gameLaunchingAnimation", gameLaunchingAnimation)


// ================= NETWORK CHECK =================
    property bool isOnline: false

    function checkInternet() {
        var xhr = new XMLHttpRequest()
        xhr.timeout = 8000  // 8 секунд максимум

        xhr.onreadystatechange = function() {
            if (xhr.readyState === XMLHttpRequest.DONE) {
                isOnline = (xhr.status === 204 || xhr.status === 200)
                // DECKOS: no log line every 15 s
            }
        }

        xhr.onerror = function() {
            isOnline = false
            // DECKOS: no log line every 15 s
        }

        xhr.ontimeout = function() {
            isOnline = false
            // DECKOS: no log line every 15 s
        }

        xhr.open("HEAD", "https://www.google.com/generate_204", true)
        xhr.send()
    }

    Timer {
        interval: 15000      // проверяем каждые 15 секунд
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: checkInternet()
    }


    
    FontLoader { id: extrabold; source: "./assets/font/Gilroy-ExtraBold.otf" }
    FontLoader { id: bold; source: "./assets/font/ARIALBD.TTF" }
    FontLoader { id: icons; source: "./assets/font/settings_icon.ttf" }
    
    
    // Аудиоэффекты темы (множитель interfaceVolume автоматически заглушает звук при значении 0)
    SoundEffect { id: sNav; source: "./assets/audio/nav.wav"; volume: 0.8 * root.interfaceVolume }
    SoundEffect { id: sTab; source: "./assets/audio/tab.wav"; volume: 1.0 * root.interfaceVolume }
    SoundEffect { id: sAccept; source: "./assets/audio/accept.wav"; volume: 1.0 * root.interfaceVolume }
    SoundEffect { id: sBack; source: "./assets/audio/back.wav"; volume: 1.0 * root.interfaceVolume }
    SoundEffect { id: sLeftOpen; source: "./assets/audio/deck_ui_side_menu_fly_in.wav"; volume: 1.0 * root.interfaceVolume }
    SoundEffect { id: sLeftClose; source: "./assets/audio/deck_ui_side_menu_fly_out.wav"; volume: 1.0 * root.interfaceVolume }
    SoundEffect { id: sShowui; source: "./assets/audio/deck_ui_show_ui.wav"; volume: 1.0 * root.interfaceVolume }
    SoundEffect { id: sGame; source: "./assets/audio/game.wav"; volume: 1.0 * root.interfaceVolume }
    SoundEffect { id: sType; source: "./assets/audio/type.wav"; volume: 1.0 * root.interfaceVolume }
    SoundEffect { id: sFav; source: "./assets/audio/favorite.wav"; volume: 1.0 * root.interfaceVolume }


function getPageSource(index) {
    switch (index) {
        case 0: return "screens/home.qml" // Добавьте эту строку
        case 1: return "screens/library.qml"
        case 2: return "screens/nothing.qml" // DECKOS: the Emulator Store (pages/StoreContent.qml); StMini's mock store is unused
        case 3: return "screens/nothing.qml"
        case 4: return "screens/media.qml"
        case 5: return "screens/nothing.qml"
        case 6: return "screens/settings.qml"
        case 8: return "screens/gamemenu.qml"
        case 9: return "screens/search.qml"
        case 10: return "screens/webscreen/profile.qml" // Добавьте эту строку
        case 11: return "screens/exit.qml"
        case 12: return "screens/webscreen/steamgriddb.qml"
        case 13: return "screens/webscreen/signup.qml"
        case 14: return "screens/gamedata.qml"
        default: return "screens/home.qml"
    }
}


function loadGameAchievements(gameTitle, callback) {
    if (savedUsername !== "" && savedApiKey !== "") {
        RAApi.findGameIdByTitle(savedUsername, savedApiKey, gameTitle, function(foundId) {
            if (foundId) {
                RAApi.getUserGameProgress(savedUsername, savedApiKey, foundId, function(data) {
                    callback(data);
                });
            }
        });
    }
}




function updateProfileData() {
    if (savedUsername !== "" && savedApiKey !== "") {
        RAApi.getUserSummary(savedUsername, savedApiKey, function(data) {
            if (data) {
                root.globalUserName = data.userName; // DECKOS: root. - unqualified writes in an XHR callback fail
                root.globalUserPic = data.userPic;
                root.globalUserLevel = data.userLevel;
            }
        });
    } else {
        globalUserName = ""; // DECKOS
        globalUserPic = "";
        globalUserLevel = "0";
    }
}

// Перезаписываем данные в память И сразу обновляем профиль
onSavedUsernameChanged: Qt.callLater(saveRaAccount) // DECKOS: deferred - writing memory inside a binding update looped
onSavedApiKeyChanged: Qt.callLater(saveRaAccount)
// DECKOS: StMini keys + the ACHIEVEMENTS tab keys
function saveRaAccount() {
    api.memory.set("savedUsername", savedUsername); api.memory.set("ra_api_user", savedUsername)
    api.memory.set("savedApiKey", savedApiKey); api.memory.set("ra_api_key", savedApiKey)
    updateProfileData()
}

// DECKOS: keys.txt in the DeckOS folder (else <config>/api-keys.env): the scraper keys go to the
// scraper, the RetroAchievements account to the whole app. { found, path, error, raUser, raKey }
function importKeysFile() {
    if (typeof deckos === "undefined" || !deckos) return { found: 0, error: "" }
    var res = deckos.scraper.importKeys()
    if (!res.error && res.raUser && res.raKey) { savedUsername = res.raUser; savedApiKey = res.raKey }
    if (deckos.media) deckos.media.keysRead()
    return res
}
// read again whenever keys.txt changed: at start, and back from a file manager
function importKeysIfChanged() {
    if (typeof deckos === "undefined" || !deckos || !deckos.media || !deckos.media.keysChanged()) return
    var res = importKeysFile()
    console.info("DeckOS: keys.txt read: " + (res.error ? res.error : res.found + " keys")) // never the values
}

// Дергаем API при первом запуске темы
Component.onCompleted: {
    updateProfileData();
    pageLoader.show(-1, currentPage) // DECKOS: first page (the page host has no source binding)
    Qt.callLater(importKeysIfChanged) // DECKOS: keys.txt
    prebuildTimer.start()
}

// DECKOS: the game page is built ahead once the first page is up, so opening a game is instant
Timer {
    id: prebuildTimer
    interval: 1500
    onTriggered: {
        if (root.isTransitioning) { restart(); return }
        pageLoader.prebuild(8)
    }
}


// В файле theme.qml ИЗМЕНИТЕ функцию toggleLeftBar:
function toggleLeftBar(component) {
    if (component.isOpen) {
        // ЗАКРЫТИЕ
        sLeftClose.play();
        component.isOpen = false;
        component.focus = false;
        if (root.openLeftBar === component) root.openLeftBar = null; // DECKOS: see focusWatch
        
        // ЗАПУСКАЕМ ТАЙМЕР ЧЕРЕЗ 300мс
        var hideTimer = Qt.createQmlObject('import QtQuick 2.15; Timer { interval: 400; running: true }', component, "hideTimer");
        hideTimer.triggered.connect(function() {
            // DECKOS: reopened during the close animation (MENU pressed twice quickly): stay visible.
            // Hiding it anyway left the menu "open" but invisible, so the next press closed it again.
            if (!component.isOpen) component.visible = false;
            hideTimer.destroy();
        });
        
        if (component.focusTimer) component.focusTimer.start();
    } else {
        // ОТКРЫТИЕ
        sLeftOpen.play();
        component.visible = true;
        component.focus = true;
        component.isOpen = true;
        fixMenuIndex(component); // DECKOS: see menuIndex
        component.updateFocus();
        root.openLeftBar = component; // DECKOS: see focusWatch
        // DECKOS: a close just before (double press) leaves the page's focusTimer (50-100 ms) running,
        // which then pulls focus out of the open menu; take it back once that has fired
        var refocusTimer = Qt.createQmlObject('import QtQuick 2.15; Timer { interval: 150; running: true }', component, "refocusTimer");
        refocusTimer.triggered.connect(function() {
            if (component.isOpen && !component.activeFocus) {
                component.focus = true;
                component.updateFocus();
            }
            refocusTimer.destroy();
        });
    }
}

Rectangle {
    id: globalBackground
    anchors.fill: parent
    color: "#0F1318" // Тот самый цвет темы
    z: -100 // Всегда сзади всех
}

// DECKOS: the page host. StMini had one Loader that destroyed and rebuilt the page on every navigation.
// Home (3.8k lines of QML) and Library (3.3k) took long enough to build on Android that coming back from
// a game page stalled and redrew the whole library. Home and Library now stay alive (hidden) once built
// and come back as they were; opening Settings drops them (some options are read at build time). Every
// other page is still built on demand. The id and `.item` are kept because pages use pageLoader.item.
FocusScope {
    id: pageLoader

    // StMini's logical canvas: canvasHeight tall, as wide as the screen's aspect ratio, scaled to fit
    height: root.canvasHeight // DECKOS: was 1080, see uiScale
    width: (parent.width / parent.height) * height
    scale: parent.height / height
    anchors.centerIn: parent

    focus: true
    // DECKOS: the first-start cards keep the keys. Not for the power menu: disabling the page dropped its
    // focus chain, and Home came back on its search bar instead of the game row (the menu holds the
    // focus itself and its backdrop takes the taps)
    enabled: !welcome.visible && !folderSetup.visible

    property Item item: null
    signal loaded()

    // Home, Library and the game page, once built, stay alive (hidden) until Settings is opened - a few
    // of its options are only read when a page is built. The game page is also built ahead (prebuild),
    // in the background a moment after start, so even the first game opens at once.
    readonly property var keepable: [0, 1, 8]
    readonly property var dropCacheOn: [6]
    property var cached: ({}) // page index -> Item
    property var components: ({})
    property var pending: ({}) // page index -> incubator still building it ahead
    property int generation: 0 // dropCache() makes pages still being built ahead stale

    function prebuild(index) {
        if (cached[index] || pending[index] || keepable.indexOf(index) === -1) return
        var c = componentFor(index)
        if (c.status !== Component.Ready) return
        var started = Date.now()
        var gen = generation
        var inc = c.incubateObject(pageLoader, { theme: root, visible: false, enabled: false }, Qt.Asynchronous)
        if (!inc) return
        var done = function () {
            if (pending[index] === inc) delete pending[index]
            var obj = inc.object
            if (!obj) return
            if (gen !== generation || cached[index]) { obj.destroy(); return } // dropped or built meanwhile
            cached[index] = obj
            console.info("DeckOS: page " + index + " built ahead in " + (Date.now() - started) + " ms")
        }
        if (inc.status === Component.Ready) { done(); return }
        pending[index] = inc
        inc.onStatusChanged = function (status) {
            if (status === Component.Ready) done()
            else if (status === Component.Error) delete pending[index]
        }
    }

    function componentFor(index) {
        var url = getPageSource(index)
        var c = components[url]
        if (!c) {
            c = Qt.createComponent(url)
            components[url] = c
        }
        return c
    }

    function dropCache() {
        generation++
        pending = {}
        for (var k in cached) {
            if (cached[k] && cached[k] !== item) {
                cached[k].visible = false
                cached[k].destroy()
            }
        }
        cached = {}
    }

    // fromIndex: the page being left; props: initial properties for the new page
    function show(fromIndex, index, props) {
        var old = item
        item = null
        var started = Date.now()

        if (old) {
            if (cached[fromIndex] === old) { // Home / Library: hide, keep for next time
                old.visible = false
                old.enabled = false
                old.focus = false
            } else {
                old.visible = false
                old.destroy()
            }
        }
        if (dropCacheOn.indexOf(index) !== -1)
            dropCache()

        if (!cached[index] && pending[index]) { // still being built ahead: finish it now
            var inc = pending[index]
            inc.forceCompletion()
            if (inc.object && !cached[index]) {
                delete pending[index]
                cached[index] = inc.object
            }
        }
        var again = cached[index]
        if (again) { // shown before: no rebuild, as it was left (focus, tab, scroll position)
            item = again
            item.enabled = true
            item.visible = true
            item.focus = true
            item.forceActiveFocus()
            if (typeof item.resumePage === "function") item.resumePage()
            console.info("DeckOS: page " + index + " shown again in " + (Date.now() - started) + " ms")
            loaded()
            return
        }

        var c = componentFor(index)
        if (c.status !== Component.Ready) {
            console.warn("DeckOS: page " + index + " failed to load: " + c.errorString())
            return
        }
        var initial = props || {}
        initial.theme = root // at creation, so the page's bindings never see it undefined
        item = c.createObject(pageLoader, initial)
        if (!item) return
        if (keepable.indexOf(index) !== -1)
            cached[index] = item
        // note: StMini's Loader assigned `theme` after loading; as an initial property, the pages'
        // onThemeChanged handlers now run during creation, before Component.onCompleted
        item.forceActiveFocus()
        console.info("DeckOS: page " + index + " built in " + (Date.now() - started) + " ms")
        loaded()
    }
}

    function finalizeNavigation(index) {
    if (typeof index !== "number" || isNaN(index) || index < 0) index = 0 // DECKOS: a lost return page goes Home, never nowhere
    var from = root.currentPage
    root.currentPage = index;
    pageLoader.show(from, index)
    isTransitioning = false;
    
    // Если мы вернулись на предыдущую страницу (которая сохранена), очищаем контекст
    if (api.memory.previousPage !== undefined && index === api.memory.previousPage) {
        api.memory.previousPage = undefined;
    }
}

// Запуск игры


function launchGameWithScreen(game) {
    if (!game) return;
    
    // Сохраняем игру
    currentGame = game;
    
    // Проигрываем звук
    sGame.play();
    
    // Пропускаем стандартную анимацию перехода
    isTransitioning = true;
    var from = currentPage
    currentPage = 10;
    pageLoader.show(from, 10, { "gameToLaunch": currentGame }) // DECKOS: page host
    isTransitioning = false;
}


// DECKOS: artwork shown small (grid tiles, rows) goes through the thumbnail cache (ImageCache.h): decoded
// off the interface thread at the size shown, kept on disk and in memory. The Image needs a sourceSize.
// Web images and, with animated covers on, GIFs load as they are.
function thumb(url) {
    if (!url) return ""
    var s = url.toString()
    if (s === "" || s.indexOf("image://") === 0 || s.indexOf("http") === 0 || s.indexOf("data:") === 0) return s
    if (animatedCovers && /\.gif(\?|$)/i.test(s)) return s
    return "image://deckthumb/" + encodeURIComponent(s)
}
function isAnimated(url) {
    return animatedCovers && !!url && /\.gif(\?|$)/i.test(url.toString())
}

// Получение источника ассета: веб (SteamGridDB) > локальный (metadata) > пусто
function getAssetSource(assetType, game) {
    if (!game) return ""

    // Маппинг типов ассетов темы в ключи SteamGridDB
    var mapping = {
        "poster": "capsule",
        "steam": "wideCapsule",   // wide capsule (баннер)
        "logo": "logo",
        "background": "hero"
    }
    var steamKey = mapping[assetType]
    if (!steamKey) return ""

    // 1. Проверяем кастомный веб-ассет из SteamGridDB
    if (typeof api !== "undefined" && api.memory) {
        var customData = api.memory.get("custom_assets_" + game.title)
        if (customData && customData.assets) {
            var webUrl = customData.assets[steamKey] || ""
            if (webUrl !== "") {
                return webUrl
            }
        }
    }

    // 2. Если веб-ассета нет, используем локальный из metadata
    if (assetType === "poster") {
        return game.assets.poster || game.assets.boxFront || ""
    } else if (assetType === "steam") {
        return game.assets.steam || ""  // локальный wide capsule
    } else if (assetType === "logo") {
        return game.assets.logo || ""
    } else if (assetType === "background") {
        return game.assets.background || ""
    }

    // 3. Ничего не найдено
    return ""
}


    // --- ЛОГИКА ПЕРЕХОДА ---

        function openPage(index) {
    if (isTransitioning || currentPage === index) return;

    // Звуки
    if (index === 8) {
    sAccept.play();
    // DECKOS: remember where the game page was opened from - not its own sub-pages (launch screen,
    // artwork picker, RA sign-in, Properties), or B on the game page would go back into them
    if ([10, 12, 13, 14].indexOf(currentPage) === -1) {
        api.memory.previousPage = currentPage;
    }
}else if (index === 14 && [10, 12, 13, 14].indexOf(currentPage) === -1) {
        propertiesReturnPage = currentPage; // DECKOS: B in Properties goes back there
    }else if (index === 12) {
        // DECKOS: B in Change artwork goes back where it was opened from (the game page, Properties, Home,
        // Library, Search). It read a value pages left as null after one use: B led nowhere.
        artworkReturnPage = typeof currentPage === "number" && currentPage !== 12 ? currentPage : 8;
    }else if (index === 9) {
        sLeftOpen.play();
    }else if (index === 11) {
        sLeftClose.play();
    } else if (currentPage === 8 && index === 0) {   // возврат из gamemenu на home
        sBack.play();
    }

    isTransitioning = true;
    pendingPage = index;               // DECKOS: focusWatch finishes a change that never completes
    transitionStarted = Date.now();

if (pageLoader.item && typeof pageLoader.item.startExitAnimation === "function" && index !== 11) {
    pageLoader.item.startExitAnimation(index);
    } else {
        finalizeNavigation(index);
    }
}

// DECKOS: back in front (Android: after Home / another app): pages put their selection highlight and
// focus back - the highlight's animation could stay stuck after Android suspended DeckOS
Connections {
    target: Qt.application
    function onStateChanged() {
        if (Qt.application.state === Qt.ApplicationActive) Qt.callLater(root.importKeysIfChanged) // DECKOS: keys.txt edited meanwhile
        if (Qt.application.state === Qt.ApplicationActive && pageLoader.item && typeof pageLoader.item.resumeFocus === "function")
            Qt.callLater(pageLoader.item.resumeFocus)
    }
}

// DECKOS: the controller's focus can drift from what the screen shows (Android resuming DeckOS, an old
// page timer firing while the Steam menu opens): with the menu open the keys belong to it, and with no
// item focused at all the page takes the focus back. Checked a few times a second while DeckOS is in front.
property var openLeftBar: null // the page's Steam menu while it's open (toggleLeftBar)

// DECKOS: the Steam menu button for the current page. Pages set the menu's selection from currentPage,
// but only Home ... Settings (0-6) have a button: on the game page (8), Properties (14) and the others
// the selection was on no button - nothing highlighted, and the D-pad had nowhere to go.
function menuIndex() {
    return currentPage >= 0 && currentPage <= 6 ? currentPage : 0
}
function fixMenuIndex(bar) {
    var n = bar && bar.buttons ? bar.buttons.length : 0
    if (n > 0 && (bar.currentIndex < 0 || bar.currentIndex >= n))
        bar.currentIndex = Math.min(menuIndex(), n - 1)
}

function isInside(item, ancestor) {
    for (var it = item; it; it = it.parent)
        if (it === ancestor) return true
    return false
}

property int propertiesReturnPage: 8 // DECKOS: the page Properties (14) was opened from: Home, Library, Search, the game page
property int artworkReturnPage: 8 // DECKOS: ...and Change artwork (12)
property int pendingPage: -1          // the page openPage is changing to
property double transitionStarted: 0
property var hiddenFocus: null        // focusWatch: an invisible item seen holding the focus

Timer {
    id: focusWatch
    interval: 300
    repeat: true
    running: Qt.application.state === Qt.ApplicationActive
    onTriggered: {
        var win = root.Window.window
        // a page change whose exit animation never finished would leave every page change and this
        // check blocked for good: finish it (the animation takes 225 ms)
        if (root.isTransitioning && root.pendingPage >= 0 && Date.now() - root.transitionStarted > 2500) {
            console.warn("DeckOS: the change to page " + root.pendingPage + " got stuck, finishing it")
            root.finalizeNavigation(root.pendingPage)
            return
        }
        if (!win || welcome.visible || folderSetup.visible || powerMenu.visible || root.isTransitioning) return
        var f = win.activeFocusItem
        var bar = root.openLeftBar
        if (bar && bar.isOpen && bar.visible) {
            root.fixMenuIndex(bar)
            if (f === bar || !root.isInside(f, bar)) {
                console.info("DeckOS: focus back to the Steam menu")
                bar.forceActiveFocus()
                if (typeof bar.updateFocus === "function") bar.updateFocus()
            }
            return
        }
        var page = pageLoader.item
        if (page && page.visible && (!f || f === win.contentItem || f === root || f === pageLoader)) {
            console.info("DeckOS: focus back to the page")
            if (typeof page.resumeFocus === "function") page.resumeFocus()
            else page.forceActiveFocus()
            root.hiddenFocus = null
            return
        }
        // the keys going to something no longer on screen (a page kept alive behind this one, a closed
        // panel): nothing looks selected and the controller does nothing. Seen twice in a row (not an
        // item that is just fading out): the page on screen takes the focus back.
        if (page && page.visible && f && !f.visible) {
            if (root.hiddenFocus === f) {
                console.info("DeckOS: focus was on a hidden item (" + f + "), back to the page")
                root.hiddenFocus = null
                if (typeof page.resumeFocus === "function") page.resumeFocus()
                else if (typeof page.goToZone === "function" && page.focusZone !== undefined) page.goToZone(Math.min(page.focusZone, 2))
                else page.forceActiveFocus()
            } else {
                root.hiddenFocus = f
            }
            return
        }
        root.hiddenFocus = null
    }
}

// DECKOS: "Exit game" in Quick Access closed the emulator - DeckOS comes back on Home (after the game
// page has reset its launch screen)
Connections {
    target: (typeof deckos !== "undefined" && deckos) ? deckos.ingame : null
    function onExitedToHome() { Qt.callLater(function () { if (root.currentPage !== 0) root.openPage(0) }) }
}

// DECKOS: first start without any game folder: point to where games are added (A), or dismiss for good (B)
FocusScope {
    id: welcome
    anchors.fill: parent
    z: 5000
    property bool dismissed: api.memory.has("welcomeDismissed")
    readonly property bool noFolders: Internal.settings.gameDirs.filter(function (d) { return d !== "" && d !== "." }).length === 0
        && (typeof deckos === "undefined" || !deckos || deckos.library.romFolders.length === 0)
    visible: noFolders && !dismissed && root.currentPage === 0 && !folderSetup.visible // DECKOS: the folder card first
    onVisibleChanged: if (visible) forceActiveFocus()
    Component.onCompleted: if (visible) forceActiveFocus()
    Timer { // the page under it and main.qml move the focus while loading; take it back while shown
        interval: 250; repeat: true
        running: welcome.visible && !welcome.activeFocus
        onTriggered: welcome.forceActiveFocus()
    }

    function close(openSettings) {
        dismissed = true
        if (openSettings) {
            root.openSettingsPage("settings/library.qml")
        } else {
            api.memory.set("welcomeDismissed", true)
            Qt.callLater(function () { if (pageLoader.item) pageLoader.item.forceActiveFocus() }) // once the page is enabled again
        }
    }
    Keys.onPressed: {
        if (api.keys.isAccept(event)) { sAccept.play(); close(true) }
        else if (api.keys.isCancel(event)) { sBack.play(); close(false) }
        event.accepted = true
    }
    Connections { // a page that finishes loading takes the focus; give it back while the card is up
        target: pageLoader
        function onLoaded() { if (welcome.visible) welcome.forceActiveFocus() }
    }

    Rectangle { anchors.fill: parent; color: "#B0000000"; MouseArea { anchors.fill: parent } }

    Rectangle {
        id: welcomeCard
        width: Math.min(parent.width * 0.7, parent.height * 1.15)
        height: welcomeColumn.height + parent.height * 0.08
        anchors.centerIn: parent
        radius: 8
        color: "#23262B"

        Column {
            id: welcomeColumn
            width: parent.width * 0.86
            anchors.centerIn: parent
            spacing: welcome.height * 0.03

            Text {
                text: "Welcome to DeckOS"
                color: "white"
                font.family: extrabold.name
                font.pixelSize: welcome.height * 0.055
            }
            Text {
                width: parent.width
                wrapMode: Text.WordWrap
                text: "Add the folder with your games. DeckOS finds your systems by their folder names "
                    + "(snes, gba, psx, \"PlayStation 2\"…) and picks an installed emulator for each - "
                    + "nothing is written into your folders."
                color: "#c7d0d9"
                font.family: bold.name
                font.pixelSize: welcome.height * 0.028
                lineHeight: 1.2
            }
            Row {
                spacing: welcome.height * 0.025
                Rectangle {
                    width: addText.implicitWidth + welcome.height * 0.06
                    height: welcome.height * 0.075
                    radius: 4
                    color: "#1a9fff"
                    Text { id: addText; anchors.centerIn: parent; text: "Ⓐ  Add your ROM folder"; color: "white"; font.family: bold.name; font.pixelSize: welcome.height * 0.03 }
                    MouseArea { anchors.fill: parent; onClicked: welcome.close(true) }
                }
                Rectangle {
                    width: laterText.implicitWidth + welcome.height * 0.06
                    height: welcome.height * 0.075
                    radius: 4
                    color: "#3d4450"
                    Text { id: laterText; anchors.centerIn: parent; text: "Ⓑ  Not now"; color: "white"; font.family: bold.name; font.pixelSize: welcome.height * 0.03 }
                    MouseArea { anchors.fill: parent; onClicked: welcome.close(false) }
                }
            }
        }
    }
}

// DECKOS: the DeckOS folder (MediaLibrary): scraped artwork, trailers, the user's own pictures, keys.txt and
// the log, in one folder any file manager can open. Asked at the first start - and once after updating, so
// the media saved so far moves in. A: a new folder in the shared storage, named on the keyboard; X: pick
// one (or make one anywhere); B: later (asked again next start; also in Settings > Library).
FocusScope {
    id: folderSetup
    anchors.fill: parent
    z: 5001
    readonly property var media: (typeof deckos !== "undefined" && deckos) ? deckos.media : null
    property bool later: false
    property string message: ""
    visible: !!media && !media.folderSet && !later && root.currentPage === 0
    onVisibleChanged: if (visible) forceActiveFocus()
    Component.onCompleted: if (visible) forceActiveFocus()
    Timer { // the page under it moves the focus while loading; take it back while the card is up
        interval: 250; repeat: true
        running: folderSetup.visible && !folderSetup.activeFocus && !setupPicker.visible && !setupName.visible
        onTriggered: folderSetup.forceActiveFocus()
    }

    function use(path) {
        var err = media.setFolder(path)
        setupPicker.visible = false
        if (err !== "") { message = err; forceActiveFocus(); return }
        message = ""
        root.importKeysIfChanged() // keys.txt may be there already
        Qt.callLater(function () { if (pageLoader.item) pageLoader.item.forceActiveFocus() })
    }
    function create(parentPath, name) {
        if (name.trim() === "") { // emptied: back to where it was asked
            if (setupPicker.visible) setupPicker.forceActiveFocus(); else forceActiveFocus()
            return
        }
        var path = media.makeFolder(parentPath, name)
        if (path === "") { message = "Couldn't create \"" + name + "\" in " + parentPath; setupPicker.visible = false; forceActiveFocus(); return }
        use(path)
    }
    function askName(parentPath) {
        setupName.parentPath = parentPath
        setupName.open("DeckOS")
    }

    Keys.onPressed: {
        event.accepted = true
        if (event.isAutoRepeat) return
        if (api.keys.isAccept(event)) { sAccept.play(); askName(media.defaultParent) }
        else if (api.keys.isDetails(event)) { sAccept.play(); setupPicker.open() }
        else if (api.keys.isCancel(event)) {
            sBack.play()
            later = true
            Qt.callLater(function () { if (pageLoader.item) pageLoader.item.forceActiveFocus() })
        }
    }

    Rectangle { anchors.fill: parent; color: "#B0000000"; MouseArea { anchors.fill: parent } }

    Rectangle {
        width: Math.min(parent.width * 0.74, parent.height * 1.2)
        height: setupColumn.height + parent.height * 0.08
        anchors.centerIn: parent
        radius: 8
        color: "#23262B"

        Column {
            id: setupColumn
            width: parent.width * 0.88
            anchors.centerIn: parent
            spacing: folderSetup.height * 0.028

            Text {
                text: "Your DeckOS folder"
                color: "white"
                font.family: extrabold.name
                font.pixelSize: folderSetup.height * 0.052
            }
            Text {
                width: parent.width
                wrapMode: Text.WordWrap
                text: "DeckOS keeps everything of yours in one folder you can open from any file manager: "
                    + "scraped artwork and trailers, your own pictures (Properties › Customization), "
                    + "keys.txt for your API keys, and its log. Inside, media is sorted by system and game."
                color: "#c7d0d9"
                font.family: bold.name
                font.pixelSize: folderSetup.height * 0.026
                lineHeight: 1.2
            }
            Text {
                width: parent.width
                text: folderSetup.media ? folderSetup.media.defaultParent + "/DeckOS" : ""
                elide: Text.ElideMiddle
                color: "#8b929a"
                font.family: bold.name
                font.pixelSize: folderSetup.height * 0.024
            }
            Text {
                width: parent.width
                visible: folderSetup.message !== ""
                wrapMode: Text.WordWrap
                text: folderSetup.message
                color: "#ff6b5b"
                font.family: bold.name
                font.pixelSize: folderSetup.height * 0.024
            }
            Flow {
                width: parent.width
                spacing: folderSetup.height * 0.02
                Repeater {
                    model: [
                        { text: "Ⓐ  Create a folder", color: "#1a9fff", act: "create" },
                        { text: "Ⓧ  Choose a folder", color: "#3d4450", act: "choose" },
                        { text: "Ⓑ  Later", color: "#3d4450", act: "later" }
                    ]
                    Rectangle {
                        width: setupButtonText.implicitWidth + folderSetup.height * 0.06
                        height: folderSetup.height * 0.072
                        radius: 4
                        color: modelData.color
                        Text {
                            id: setupButtonText
                            anchors.centerIn: parent
                            text: modelData.text
                            color: "white"
                            font.family: bold.name
                            font.pixelSize: folderSetup.height * 0.028
                        }
                        MouseArea {
                            anchors.fill: parent
                            onClicked: {
                                if (modelData.act === "create") folderSetup.askName(folderSetup.media.defaultParent)
                                else if (modelData.act === "choose") setupPicker.open()
                                else { folderSetup.later = true; if (pageLoader.item) pageLoader.item.forceActiveFocus() }
                            }
                        }
                    }
                }
            }
        }
    }

    FolderPicker {
        id: setupPicker
        title: "Choose your DeckOS folder"
        hint: "Open folders with A, go back with B. \"Use this folder\" keeps everything in the folder shown; \"New folder here\" makes one in it."
        allowNewFolder: true
        startFolder: folderSetup.media ? folderSetup.media.defaultParent : ""
        onPicked: folderSetup.use(path)
        onNewFolderRequested: folderSetup.askName(parentPath)
        onClosed: folderSetup.forceActiveFocus()
    }

    TextEntry {
        id: setupName
        property string parentPath: ""
        title: "Name your DeckOS folder"
        hint: "It's made in " + parentPath + ". Done, B or Start creates it."
        maxLength: 60
        onAccepted: folderSetup.create(parentPath, text)
    }
}

// DECKOS: Steam-style notifications, top-left over every page (SteamToasts.qml). theme.notify({ id, title,
// text, icon, progress, timeout }); the same id updates its card. Scraping and ROM scans report here.
function notify(n) {
    return toasts.notify(n)
}

SteamToasts {
    id: toasts
    anchors.fill: parent
    z: 5000
}

// DECKOS: every Play goes through here - one game at a time (LaunchGuard.qml). `launch` defaults to
// game.launch(); the game page passes its launch animation instead.
function playGame(game, launch) {
    if (!game) return
    if (game.modelData && game.modelData !== game && typeof game.launch !== "function") game = game.modelData // a sorted model's row
    launchGuard.play(game, launch || function () { game.launch() })
}

LaunchGuard {
    id: launchGuard
}

// DECKOS: what a shelf card does (ShelfView.qml on Home and the Friends & Chat page). `page` may offer
// openNews(shelf, index) for its own reader; otherwise articles open in the browser.
function openShelfItem(shelf, item, index, page) {
    if (!item) return
    var d = (typeof deckos !== "undefined" && deckos) ? deckos : null
    if (item.game) {
        try { sAccept.play() } catch (e) {}
        currentGame = item.game
        openPage(8)
        return
    }
    var kind = shelf.kind
    if (kind === "news") {
        if (page && typeof page.openNews === "function") page.openNews(shelf, index)
        else Qt.openUrlExternally(item.link)
    } else if (kind === "video") {
        if (d && d.web) d.web.playVideo(item.videoId || "", item.title || "", item.link || "")
        else Qt.openUrlExternally(item.link)
    } else if (kind === "action") {
        if (item.action === "ra-signin") { loginReturnPage = -1; openPage(13) }
        else if (item.action === "ra-site") Qt.openUrlExternally("https://retroachievements.org/")
        else if (item.action === "discord-add") discordEntry.open("")
        else if (item.action === "discord-help") Qt.openUrlExternally("https://github.com/Phineas/lanyard")
    } else if (kind === "discord") {
        if (item.id) Qt.openUrlExternally("https://discord.com/users/" + item.id)
    } else if (kind === "system") {
        openPage(1)
    } else if (kind === "update") {
        if (d && d.updates) d.updates.updateEmulator(item.package)
    } else if (item.link) {
        Qt.openUrlExternally(item.link)
    }
}

// X on a card: a video in the YouTube app, an article in the browser, a Discord friend removed
function shelfSecondary(shelf, item, index) {
    if (!item) return
    var d = (typeof deckos !== "undefined" && deckos) ? deckos : null
    if (shelf.kind === "video") {
        if (d && d.web) d.web.openInYouTube(item.videoId || "", item.link || "")
        else Qt.openUrlExternally(item.link)
    } else if (shelf.kind === "news") {
        Qt.openUrlExternally(item.link)
    } else if (shelf.kind === "discord" && item.id && d && d.feeds) {
        d.feeds.removeDiscordId(item.id)
        notify({ id: "discord", icon: "-", title: "Removed from Discord friends", text: item.name || item.id, timeout: 3000 })
    } else if (shelf.kind === "update" && d && d.updates) {
        d.updates.openPage(item.package)
    }
}

TextEntry {
    id: discordEntry
    z: 6000
    title: "Add a Discord friend"
    hint: "Their Discord user id (17-20 digits). In Discord: Settings › Advanced › Developer Mode on, then long-press their name › Copy User ID. They also join discord.gg/lanyard once, so Lanyard can share their status."
    maxLength: 22
    onAccepted: {
        var f = (typeof deckos !== "undefined" && deckos) ? deckos.feeds : null
        if (f && text.trim() !== "" && !f.addDiscordId(text))
            root.notify({ id: "discord", icon: "!", title: "That isn't a Discord user id", text: "It's a number of 17 to 20 digits.", timeout: 4000 })
        Qt.callLater(function () { // the focus back to the page under it
            var page = pageLoader.item
            if (page && typeof page.resumeFocus === "function") page.resumeFocus()
            else if (page) page.forceActiveFocus()
        })
    }
}

// DECKOS: updates found, downloaded, installed or failed (deckos.updates): a card top-left
Connections {
    target: (typeof deckos !== "undefined" && deckos) ? deckos.updates : null
    function onNotice(title, text) { toasts.notify({ id: "updates", icon: "↓", title: title, text: text, timeout: 6000 }) }
}

property bool scrapeToastShown: false
Connections {
    target: (typeof deckos !== "undefined" && deckos) ? deckos.scraper : null
    function onProgressChanged() {
        var s = deckos.scraper
        if (s.running) {
            root.scrapeToastShown = true
            toasts.notify({ id: "scrape", icon: "♠︎", title: "Scraping artwork",
                            text: (s.currentTitle !== "" ? s.currentTitle + "  ·  " : "") + s.done + " of " + s.total,
                            progress: s.total > 0 ? s.done / s.total : 0, timeout: 0 })
        } else if (root.scrapeToastShown) {
            root.scrapeToastShown = false
            // the scraper says "stopped" just before it sets the closing status ("Finished 2 of 2"): read it after
            Qt.callLater(function () {
                toasts.notify({ id: "scrape", icon: "♠︎", title: "Scraping finished", text: deckos.scraper.status,
                                progress: 1, timeout: 5000 })
            })
        }
    }
}

property bool scanToastShown: false
Connections {
    target: (typeof deckos !== "undefined" && deckos) ? deckos.library : null
    function onScanStateChanged() {
        var lib = deckos.library
        // DECKOS: a scan the user started has the full-screen loading screen (frontend/LibraryLoading.qml)
        // instead; only the quiet check after start-up gets a card
        if (lib.scanning && lib.scanForeground) {
            if (root.scanToastShown) toasts.dismiss("romscan")
            root.scanToastShown = false
        } else if (lib.scanning) {
            root.scanToastShown = true
            toasts.notify({ id: "romscan", icon: "L", title: "Scanning your ROM folders", text: lib.status, timeout: 0 })
        } else if (root.scanToastShown) {
            root.scanToastShown = false
            toasts.notify({ id: "romscan", icon: "L", title: "ROM folders scanned", text: lib.status, timeout: 4000 })
        }
    }
}

// DECKOS: the Steam menu's Close, one menu for every page (each StMini page had its own Exit/Cancel copy).
// Exit DeckOS, Restart DeckOS, Restart / Shut down the device (Android: PServer or root; PC: Pegasus's
// power commands, hidden by --disable-menu-reboot / --disable-menu-shutdown), Cancel.
function openPowerMenu() {
    powerMenu.open()
}

FocusScope {
    id: powerMenu
    anchors.fill: parent
    z: 5002
    visible: false
    property int current: 0
    property string message: ""

    readonly property var ingame: (typeof deckos !== "undefined" && deckos) ? deckos.ingame : null
    readonly property bool android: !!ingame && ingame.available
    // on Android the device's power needs PServer / root
    readonly property bool devicePower: !android || ingame.privileged
    readonly property var items: {
        var list = [
            { id: "exit", label: "Exit DeckOS" },
            { id: "restart", label: "Restart DeckOS" }
        ]
        if (Internal.meta.allowReboot) list.push({ id: "reboot", label: "Restart device", device: true })
        if (Internal.meta.allowShutdown) list.push({ id: "shutdown", label: "Shut down device", device: true })
        list.push({ id: "cancel", label: "Cancel" })
        return list
    }

    function open() {
        current = 0
        message = ""
        visible = true
        forceActiveFocus()
        try { sShowui.play() } catch (e) {}
    }
    function close() {
        visible = false
        Qt.callLater(function () {
            var page = pageLoader.item
            if (!page) return
            if (typeof page.resumeFocus === "function") page.resumeFocus()
            else page.forceActiveFocus()
        })
    }
    function run(i) {
        var it = items[i]
        if (!it) return
        if (it.device && !devicePower) {
            message = "Restarting or shutting down the device needs PServer or root."
            return
        }
        if (it.id === "exit") {
            Internal.system.quit()
        } else if (it.id === "restart") {
            if (ingame) ingame.restartAfterQuit()
            Internal.system.quit()
        } else if (it.id === "reboot") {
            if (android) { if (!ingame.rebootDevice()) message = "The device didn't accept the restart." }
            else Internal.system.reboot()
        } else if (it.id === "shutdown") {
            if (android) { if (!ingame.shutdownDevice()) message = "The device didn't accept the shut down." }
            else Internal.system.shutdown()
        } else {
            try { sBack.play() } catch (e) {}
            close()
        }
    }

    // the page under it moves the focus while it opens (the Steam menu closing, its focus timers): take
    // it straight back while the menu is up, with a timer as a backstop
    onActiveFocusChanged: if (visible && !activeFocus) Qt.callLater(function () { if (powerMenu.visible) powerMenu.forceActiveFocus() })
    Timer {
        interval: 250; repeat: true
        running: powerMenu.visible && !powerMenu.activeFocus && Qt.application.state === Qt.ApplicationActive
        onTriggered: powerMenu.forceActiveFocus()
    }

    Keys.onPressed: {
        event.accepted = true
        if (event.isAutoRepeat && (api.keys.isAccept(event) || api.keys.isCancel(event))) return
        if (event.key === Qt.Key_Up) {
            if (current > 0) { current--; try { sNav.stop(); sNav.play() } catch (e) {} }
        } else if (event.key === Qt.Key_Down) {
            if (current < items.length - 1) { current++; try { sNav.stop(); sNav.play() } catch (e) {} }
        } else if (api.keys.isAccept(event) || event.key === Qt.Key_Return) {
            run(current)
        } else if (api.keys.isCancel(event) || event.key === Qt.Key_Escape) {
            try { sBack.play() } catch (e) {}
            close()
        }
    }

    Rectangle {
        anchors.fill: parent
        color: "#B3000000"
        MouseArea { anchors.fill: parent; onClicked: powerMenu.close() }
    }

    Rectangle {
        id: powerPanel
        width: Math.min(parent.width * 0.6, parent.height * 0.62)
        height: powerColumn.height
        anchors.centerIn: parent
        color: "#181B20"
        MouseArea { anchors.fill: parent } // taps on the panel don't close it

        Text {
            anchors.bottom: parent.top
            anchors.bottomMargin: powerMenu.height * 0.025
            anchors.horizontalCenter: parent.horizontalCenter
            text: "Power"
            color: "white"
            font.family: bold.name
            font.pixelSize: powerMenu.height * 0.042
        }

        Column {
            id: powerColumn
            width: parent.width
            Repeater {
                model: powerMenu.items
                Rectangle {
                    readonly property bool active: powerMenu.current === index
                    readonly property bool off: !!modelData.device && !powerMenu.devicePower
                    width: powerColumn.width
                    height: powerMenu.height * 0.1
                    color: active ? "white" : "transparent"
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.left: parent.left
                        anchors.leftMargin: powerMenu.height * 0.03
                        text: modelData.label
                        color: active ? "black" : "white"
                        opacity: off ? 0.45 : 1
                        font.family: bold.name
                        font.pixelSize: powerMenu.height * 0.034
                    }
                    MouseArea {
                        anchors.fill: parent
                        onClicked: { if (powerMenu.current === index) powerMenu.run(index); else powerMenu.current = index }
                    }
                }
            }
        }

        Text {
            anchors.top: parent.bottom
            anchors.topMargin: powerMenu.height * 0.02
            width: parent.width
            visible: powerMenu.message !== ""
            wrapMode: Text.WordWrap
            horizontalAlignment: Text.AlignHCenter
            text: powerMenu.message
            color: "#F2A73B"
            font.family: bold.name
            font.pixelSize: powerMenu.height * 0.024
        }
    }
}
}
