.pragma library

function fetchAllSections(topModel, freeModel, salesModel, statusText) {
    var xhr = new XMLHttpRequest();
    xhr.open("GET", "https://store.steampowered.com/api/featuredcategories/?cc=us&l=english", true);

    xhr.onreadystatechange = function() {
        if (xhr.readyState !== XMLHttpRequest.DONE) return;

        if (xhr.status === 200) {
            try {
                var data = JSON.parse(xhr.responseText);

                // --- Top Sellers ---
                var topItems = data.top_sellers ? data.top_sellers.items : [];
                var topCount = 0;
                for (var i = 0; i < topItems.length && topCount < 5; i++) {
                    var g = topItems[i];
                    if (g.type !== 0) continue; // пропускаем бандлы и DLC
                    topModel.append({
                        "title":    g.name,
                        "imageUrl": g.header_image,
                        "price":    g.final_price === 0 ? "Free" : "$" + (g.final_price / 100).toFixed(2),
                        "discount": g.discount_percent > 0 ? "-" + g.discount_percent + "%" : ""
                    });
                    topCount++;
                }

                // --- Specials / Sales ---
                var salesItems = data.specials ? data.specials.items : [];
                var salesCount = 0;
                for (var j = 0; j < salesItems.length && salesCount < 5; j++) {
                    var s = salesItems[j];
                    if (s.type !== 0 || !s.discounted) continue;
                    salesModel.append({
                        "title":    s.name,
                        "imageUrl": s.header_image,
                        "price":    "$" + (s.final_price / 100).toFixed(2),
                        "discount": "-" + s.discount_percent + "%"
                    });
                    salesCount++;
                }

                // --- Popular Free ---
                // Бесплатные берём отдельным запросом
                fetchFreeGames(freeModel, statusText);

            } catch (e) {
                statusText.text = "Parse error: " + e.message;
            }
        } else if (xhr.status === 0) {
            statusText.text = "Network error.\nCheck your internet connection.";
        } else {
            statusText.text = "Steam error. Code: " + xhr.status;
        }
    };

    xhr.onerror = function() { statusText.text = "Request failed."; };
    xhr.send();
}

function fetchFreeGames(freeModel, statusText) {
    var xhr = new XMLHttpRequest();
    xhr.open("GET", "https://store.steampowered.com/search/results/?filter=topsellers&json=1&cc=us&maxprice=free", true);

    xhr.onreadystatechange = function() {
        if (xhr.readyState !== XMLHttpRequest.DONE) return;

        if (xhr.status === 200) {
            try {
                var response = JSON.parse(xhr.responseText);
                var items = response.items;

                if (!items || items.length === 0) return;

                var re = /\/apps\/(\d+)\//;
                var appIds = [];
                for (var i = 0; i < items.length && appIds.length < 5; i++) {
                    var match = re.exec(items[i].logo);
                    if (match) appIds.push(match[1]);
                }

                fetchFreeDetails(appIds, 0, freeModel);

            } catch (e) { /* тихо */ }
        }
    };

    xhr.onerror = function() {};
    xhr.send();
}

function fetchFreeDetails(appIds, index, freeModel) {
    if (index >= appIds.length) return;

    var appId = appIds[index];
    var xhr = new XMLHttpRequest();
    xhr.open("GET", "https://store.steampowered.com/api/appdetails/?appids=" + appId + "&cc=us&l=english", true);

    xhr.onreadystatechange = function() {
        if (xhr.readyState !== XMLHttpRequest.DONE) return;

        if (xhr.status === 200) {
            try {
                var response = JSON.parse(xhr.responseText);
                var entry = response[appId];
                if (entry && entry.success && entry.data) {
                    var d = entry.data;
                    freeModel.append({
                        "title":    d.name,
                        "imageUrl": d.header_image || "",
                        "price":    "Free",
                        "discount": ""
                    });
                }
            } catch (e) {}
        }

        fetchFreeDetails(appIds, index + 1, freeModel);
    };

    xhr.onerror = function() { fetchFreeDetails(appIds, index + 1, freeModel); };
    xhr.send();
}