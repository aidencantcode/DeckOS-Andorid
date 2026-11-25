import QtQuick 2.15
import QtMultimedia 5.15
import QtQuick.Layouts 1.15
import QtGraphicalEffects 1.15
import QtQuick.Window 2.15
import "javascript/RetroAchievementsApi.js" as RAApi



FocusScope {
    id: root
    anchors.fill: parent
    focus: true

    property int currentPage: 0
    property var currentGame: null
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
        case 2: return "screens/store.qml"
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

// Дергаем API при первом запуске темы
Component.onCompleted: {
    updateProfileData();
}


// В файле theme.qml ИЗМЕНИТЕ функцию toggleLeftBar:
function toggleLeftBar(component) {
    if (component.isOpen) {
        // ЗАКРЫТИЕ
        sLeftClose.play();
        component.isOpen = false;
        component.focus = false;
        
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
        component.updateFocus();
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

    // Основной Loader
Loader {
    id: pageLoader
    
    // 1. Фиксируем логическую высоту
height: root.canvasHeight // DECKOS: was 1080, see uiScale

// 2. Рассчитываем ширину на основе реального соотношения сторон родителя (экрана)
// Формула: (Реальная Ширина / Реальная Высота) * Логическая Высота
width: (parent.width / parent.height) * height
//width: height * (16/9)

// 3. Масштабируем Loader так, чтобы его логические 1080px 
// визуально заполнили всю высоту экрана
scale: parent.height / height

// 4. Центрируем
anchors.centerIn: parent

    
    focus: true
    enabled: !welcome.visible // DECKOS: the first-start card keeps the keys
    source: getPageSource(currentPage)
    asynchronous: api.memory.has("asyncLoading") ? api.memory.get("asyncLoading") : false


    onLoaded: {
    if (item) {
        item.theme = root
        item.forceActiveFocus()
    }
}
}

    function finalizeNavigation(index) {
    // DECKOS: clear the source before changing currentPage; the other order re-ran the source binding and
    // created the next page twice on the first navigation (one copy destroyed right away)
    pageLoader.source = "";
    root.currentPage = index;
    pageLoader.source = getPageSource(index);
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
    currentPage = 10;
    pageLoader.source = "";
    pageLoader.setSource(getPageSource(10), {
        "theme": root,
        "gameToLaunch": currentGame
    });
    isTransitioning = false;
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
    // Сохраняем текущую страницу, если это не LaunchScreen (10)
    if (currentPage !== 10) {
        api.memory.previousPage = currentPage;
    }
}else if (index === 9) {
        sLeftOpen.play();
    }else if (index === 11) {
        sLeftClose.play();
    } else if (currentPage === 8 && index === 0) {   // возврат из gamemenu на home
        sBack.play();
    }

    isTransitioning = true;

if (pageLoader.item && typeof pageLoader.item.startExitAnimation === "function" && index !== 11) {
    pageLoader.item.startExitAnimation(index);
    } else {
        finalizeNavigation(index);
    }
}

// DECKOS: first start without any game folder: point to where games are added (A), or dismiss for good (B)
FocusScope {
    id: welcome
    anchors.fill: parent
    z: 5000
    property bool dismissed: api.memory.has("welcomeDismissed")
    readonly property bool noFolders: Internal.settings.gameDirs.filter(function (d) { return d !== "" && d !== "." }).length === 0
        && (typeof deckos === "undefined" || !deckos || deckos.library.romFolders.length === 0)
    visible: noFolders && !dismissed && root.currentPage === 0
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
}
