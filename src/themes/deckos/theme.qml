import QtQuick 2.15
import QtMultimedia 5.9
import QtQuick.Layouts 1.15
import QtGraphicalEffects 1.15
import QtQuick.Window 2.15

FocusScope {
    id: root
    anchors.fill: parent
    focus: true

    property int currentPage: 0
    property var currentGame: null
    property bool isTransitioning: false 
        // Добавить в корень FocusScope в theme.qml
    property bool navTrigger: false

    
    FontLoader { id: extrabold; source: "./assets/font/Gilroy-ExtraBold.otf" }
    FontLoader { id: bold; source: "./assets/font/ARIALBD.TTF" }
    FontLoader { id: icons; source: "./assets/font/settings_icon.ttf" }
    
    
     
    SoundEffect { id: sNav; source: "./assets/audio/nav.wav"; volume: 1.0 }
    SoundEffect { id: sAccept; source: "./assets/audio/accept.wav"; volume: 1.0 }
    SoundEffect { id: sBack; source: "./assets/audio/back.wav"; volume: 1.0 }
SoundEffect { id: sLeftOpen; source: "./assets/audio/deck_ui_side_menu_fly_in.wav"; volume: 1.0 }
SoundEffect { id: sLeftClose; source: "./assets/audio/deck_ui_side_menu_fly_out.wav"; volume: 1.0 }
SoundEffect { id: sShowui; source: "./assets/audio/deck_ui_show_ui.wav"; volume: 1.0 }

// В файле theme.qml ИЗМЕНИТЕ функцию toggleLeftBar:
function toggleLeftBar(component) {
    if (component.isOpen) {
        // ЗАКРЫТИЕ
        //sLeftClose.play();
        component.isOpen = false;
        component.focus = false;
        
        // ЗАПУСКАЕМ ТАЙМЕР ЧЕРЕЗ 300мс
        var hideTimer = Qt.createQmlObject('import QtQuick 2.15; Timer { interval: 400; running: true }', component, "hideTimer");
        hideTimer.triggered.connect(function() {
            component.visible = false;
            hideTimer.destroy();
        });
        
        if (component.focusTimer) component.focusTimer.start();
    } else {
        // ОТКРЫТИЕ
        //sLeftOpen.play();
        component.visible = true;
        component.focus = true;
        component.isOpen = true;
        component.updateFocus();
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
        anchors.fill: parent
        focus: true
        source: getPageSource(currentPage)

        onLoaded: {
            if (item) {
                item.theme = root
                item.forceActiveFocus()
            }
        }
    }

    function finalizeNavigation(index) {
    root.currentPage = index; // Сначала обновляем индекс
    pageLoader.source = ""; 
    pageLoader.source = getPageSource(index); // Затем загружаем файл
    isTransitioning = false;
}

function getPageSource(index) {
    switch (index) {
        case 0: return "screens/home.qml"
        case 1: return "screens/library.qml"
        case 2: return "screens/nothing.qml"
        case 3: return "screens/nothing.qml"
        case 4: return "screens/media.qml"
        case 5: return "screens/nothing.qml"
        case 6: return "screens/nothing.qml"
        case 8: return "screens/gamemenu.qml"
        case 9: return "screens/search.qml"
        default: return "screens/home.qml"
    }
}


    // --- ЛОГИКА ПЕРЕХОДА ---

        function openPage(index) {
        if (isTransitioning || currentPage === index) return;
        
        // ЗАПУСК ЗВУКА: Если идем на страницу 8
        if (index === 8) {
            //sAccept.play();
        }
        else if (index === 9) {
            //sLeftOpen.play()
        }
        else if (currentPage === 8 && index === 0) {
            //sBack.play();        
        }
        
        isTransitioning = true;

        if (pageLoader.item && typeof pageLoader.item.startExitAnimation === "function") {
            pageLoader.item.startExitAnimation(index);
        } else {
            finalizeNavigation(index);
        }
    }
}
