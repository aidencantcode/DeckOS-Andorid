// RetroAchievementsApi.js
.pragma library

var BASE_URL = "https://retroachievements.org/API/";

function getUserSummary(user, key, callback) {
    if (!user || !key) {
        console.warn("Отсутствуют учетные данные пользователя или ключ API.");
        return;
    }

    var xhr = new XMLHttpRequest();
    xhr.open("GET", BASE_URL + "API_GetUserSummary.php?z=" + user + "&y=" + key + "&u=" + user, true);
    
    xhr.onreadystatechange = function() {
        if (xhr.readyState === XMLHttpRequest.DONE && xhr.status === 200) {
            var response = JSON.parse(xhr.responseText);
            callback({
                userName: response.User || user, 
                userPic: response.UserPic ? "https://media.retroachievements.org" + response.UserPic : "",
                userLevel: response.TotalPoints ? response.TotalPoints : "0"
            });
        }
    };
    xhr.send();
}

function getUserGameProgress(user, key, gameId, callback) {
    if (!user || !key) return;

    var xhr = new XMLHttpRequest();
    xhr.open("GET", BASE_URL + "API_GetGameInfoAndUserProgress.php?z=" + user + "&y=" + key + "&u=" + user + "&g=" + gameId, true);
    
    xhr.onreadystatechange = function() {
        if (xhr.readyState === XMLHttpRequest.DONE && xhr.status === 200) {
            var response = JSON.parse(xhr.responseText);
            var achievementsArray = [];
            
            if (response.Achievements) {
                for (var key_name in response.Achievements) {
                    if (response.Achievements.hasOwnProperty(key_name)) {
                        var ach = response.Achievements[key_name];
                        achievementsArray.push({
                            title: ach.Title,
                            description: ach.Description,
                            points: ach.Points,
                            badgeName: ach.BadgeName,
                            isUnlocked: ach.DateEarned !== undefined && ach.DateEarned !== null
                        });
                    }
                }
            }
            callback({
                gameIcon: response.ImageIcon ? "https://media.retroachievements.org/ImageIcon/" + response.ImageIcon : "",
                achievements: achievementsArray
            });
        }
    };
    xhr.send();
}

function getGameAchievements(user, key, gameId, callback) {
    if (!user || !key) return;

    var xhr = new XMLHttpRequest();
    xhr.open("GET", BASE_URL + "API_GetGameExtended.php?z=" + user + "&y=" + key + "&i=" + gameId, true);
    
    xhr.onreadystatechange = function() {
        if (xhr.readyState === XMLHttpRequest.DONE && xhr.status === 200) {
            var response = JSON.parse(xhr.responseText);
            var achievementsArray = [];
            
            if (response.Achievements) {
                for (var key_name in response.Achievements) {
                    if (response.Achievements.hasOwnProperty(key_name)) {
                        achievementsArray.push(response.Achievements[key_name]);
                    }
                }
            }
            callback(achievementsArray);
        }
    };
    xhr.send();
}

function findGameIdByTitle(user, key, targetTitle, callback) {
    if (!user || !key) {
        console.warn("Отсутствуют учетные данные RetroAchievements.");
        return;
    }

    var xhrConsoles = new XMLHttpRequest();
    xhrConsoles.open("GET", BASE_URL + "API_GetConsoleIDs.php?z=" + user + "&y=" + key, true);
    
    xhrConsoles.onreadystatechange = function() {
        if (xhrConsoles.readyState === XMLHttpRequest.DONE && xhrConsoles.status === 200) {
            var consoles = JSON.parse(xhrConsoles.responseText);
            var currentIndex = 0;
            
            function searchNextConsole() {
                if (currentIndex >= consoles.length) {
                    callback(null); 
                    return;
                }
                
                var consoleId = consoles[currentIndex].ID;
                var xhrGames = new XMLHttpRequest();
                xhrGames.open("GET", BASE_URL + "API_GetGameList.php?z=" + user + "&y=" + key + "&i=" + consoleId, true);
                
                xhrGames.onreadystatechange = function() {
                    if (xhrGames.readyState === XMLHttpRequest.DONE) {
                        if (xhrGames.status === 200) {
                            var games = JSON.parse(xhrGames.responseText);
                            for (var i = 0; i < games.length; i++) {
                                if (games[i].Title.toLowerCase() === targetTitle.toLowerCase()) {
                                    callback(games[i].ID);
                                    return; 
                                }
                            }
                        }
                        currentIndex++;
                        searchNextConsole(); 
                    }
                };
                xhrGames.send();
            }
            
            searchNextConsole();
        }
    };
    xhrConsoles.send();
}
