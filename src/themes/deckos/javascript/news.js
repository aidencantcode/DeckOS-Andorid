// news.js

function fetchNews(callback) {
    var xhr = new XMLHttpRequest();
    var url = "https://api.rss2json.com/v1/api.json?rss_url=https%3A%2F%2Fwww.gamespot.com%2Ffeeds%2Fnews";

    xhr.onreadystatechange = function() {
        if (xhr.readyState === XMLHttpRequest.DONE) {
            if (xhr.status === 200) {
                var response = JSON.parse(xhr.responseText);
                var items = [];

                if (response.items) {
                    for (var i = 0; i < response.items.length; i++) {
                        var item = response.items[i];

                        // --- МАКСИМАЛЬНО ГЛУБОКИЙ ПОИСК КАРТИНКИ (ДЛЯ ПРЕВЬЮ) ---
                        var img = item.thumbnail;
                        
                        if (!img && item.enclosure && item.enclosure.link) {
                            img = item.enclosure.link;
                        }
                        
                        if (!img) {
                            var htmlSearch = (item.description || "") + " " + (item.content || "");
                            var imgMatch = htmlSearch.match(/<img[^>]+src="([^">]+)"/);
                            if (imgMatch) {
                                img = imgMatch[1];
                            }
                        }
                        // -------------------------------------------

                        var cleanDesc = item.description.replace(/<[^>]*>?/gm, ' ').replace(/\s+/g, ' ').trim();
                        if (cleanDesc.length > 150) {
                            cleanDesc = cleanDesc.substring(0, 150) + "...";
                        }

                        // --- БЕЗОПАСНОЕ ФОРМАТИРОВАНИЕ ДАТЫ ---
                        var formattedDate = "";
                        try {
                            var dateObj = new Date(item.pubDate);
                            if (!isNaN(dateObj.getTime())) {
                                var day = dateObj.getDate();
                                var month = dateObj.getMonth() + 1;
                                var year = dateObj.getFullYear();
                                var hours = dateObj.getHours();
                                var minutes = dateObj.getMinutes();
                                
                                if (day < 10) day = "0" + day;
                                if (month < 10) month = "0" + month;
                                if (hours < 10) hours = "0" + hours;
                                if (minutes < 10) minutes = "0" + minutes;
                                
                                formattedDate = day + "." + month + "." + year + " " + hours + ":" + minutes;
                            } else {
                                formattedDate = item.pubDate || "";
                            }
                        } catch(e) {
                            formattedDate = item.pubDate || "";
                        }
                        // --------------------------------------

                        items.push({
                            title: item.title || "",
                            image: img || "",
                            pubDate: formattedDate,
                            link: item.link || "",
                            desc: cleanDesc,
                            fullContent: item.content || item.description || ""
                        });
                    }
                }
                callback(items);
            } else {
                callback([]);
            }
        }
    }

    xhr.open("GET", url, true);
    xhr.send();
}

function cleanHtml(html) {
    var text = html;
    text = text.replace(/<(script|style)[^>]*>[\s\S]*?<\/\1>/gi, '');
    text = text.replace(/<a[^>]*>[\s\S]*?<\/a>/gi, ''); 
    text = text.replace(/<\/\s*(p|div|h1|h2|h3|h4|h5|h6|ul|ol|li)[^>]*>/gi, '\n\n');
    text = text.replace(/<\s*br\s*\/?>/gi, '\n');
    text = text.replace(/<\s*(p|div|h1|h2|h3|h4|h5|h6|li)[^>]*>/gi, '');
    text = text.replace(/<[^>]*>?/gm, '');
    text = text.replace(/&nbsp;/g, ' ')
               .replace(/&quot;/g, '"')
               .replace(/&amp;/g, '&')
               .replace(/&lt;/g, '<')
               .replace(/&gt;/g, '>');
    text = text.replace(/[ \t]+/g, ' ');
    text = text.replace(/\n[ \t]+/g, '\n');
    text = text.replace(/\n{3,}/g, '\n\n');
    return text.trim();
}

function parseArticleContent(html) {
    if (!html) return [];

    var blocks = [];
    var mediaRegex = /(<img[^>]+(?:src|data-src)="([^">]+)"[^>]*>)|(<iframe[^>]*src="([^">]*youtube\.com\/embed\/([^">?& ]+))[^">]*>[\s\S]*?<\/iframe>)/gi;
    var lastIndex = 0;
    var match;

    mediaRegex.lastIndex = 0;

    while ((match = mediaRegex.exec(html)) !== null) {
        var textBefore = html.substring(lastIndex, match.index);
        if (textBefore.trim()) {
            var clean = cleanHtml(textBefore);
            if (clean.trim()) {
                blocks.push({ type: "text", content: clean });
            }
        }

        if (match[1]) { 
            var imgTag = match[1];
            
            // Если есть data-src, он важнее (там лежит реальная картинка)
            var dataSrcMatch = imgTag.match(/data-src="([^">]+)"/i);
            var imgSrc = dataSrcMatch ? dataSrcMatch[1] : match[2];
            
            imgSrc = imgSrc.trim();

            // Если путь начинается с "//", добавляем протокол
            if (imgSrc.indexOf('//') === 0) {
                imgSrc = 'https:' + imgSrc;
            }
            
            // Никакой жесткой фильтрации. Просто добавляем блок, если ссылка есть
            if (imgSrc) {
                blocks.push({ type: "image", content: imgSrc });
            }
        } else if (match[3]) { 
            var videoUrl = match[4].trim();
            var videoId = match[5].trim();
            var thumbUrl = "https://img.youtube.com/vi/" + videoId + "/hqdefault.jpg";
            
            blocks.push({ 
                type: "video", 
                content: videoUrl, 
                thumbnail: thumbUrl 
            });
        }

        lastIndex = mediaRegex.lastIndex;
    }

    var textAfter = html.substring(lastIndex);
    if (textAfter.trim()) {
        var cleanAfter = cleanHtml(textAfter);
        if (cleanAfter.trim()) {
            blocks.push({ type: "text", content: cleanAfter });
        }
    }

    if (blocks.length === 0 && html.trim()) {
        var fallback = cleanHtml(html);
        if (fallback.trim()) {
            blocks.push({ type: "text", content: fallback });
        }
    }

    return blocks;
}

function fetchFullArticle(link, callback) {
    if (!link) {
        callback("");
        return;
    }

    var domainMatch = link.match(/^(https?:\/\/[^\/]+)/i);
    var baseDomain = domainMatch ? domainMatch[1] : "";

    var xhr = new XMLHttpRequest();
    xhr.onreadystatechange = function() {
        if (xhr.readyState === XMLHttpRequest.DONE) {
            if (xhr.status === 200) {
                var html = xhr.responseText;
                
                // 1. ИЗВЛЕКАЕМ ГЛАВНУЮ КАРТИНКУ (ИЗ МЕТА-ТЕГОВ)
                var headerImg = "";
                var ogImageMatch = html.match(/<meta[^>]*property="og:image"[^>]*content="([^"]+)"/i);
                if (ogImageMatch && ogImageMatch[1]) {
                    headerImg = ogImageMatch[1];
                }
                
                // ЛЕЧИМ КАРТИНКИ ДО ПАРСИНГА
                if (baseDomain) {
                    html = html.replace(/(src|href|data-src)="(\/[^"]+)"/gi, '$1="' + baseDomain + '$2"');
                }

                // ВЫТАСКИВАЕМ ТЕКСТ СТАТЬИ
                var contentMatch = html.match(/<article[^>]*>([\s\S]*?)<\/article>/i) ||
                                   html.match(/<div[^>]*class="[^"]*(?:content|article__content|article-text|post-content|entry-content)[^"]*"[^>]*>([\s\S]*?)<\/div>/i);

                var articleHtml = contentMatch ? contentMatch[1] : html;

                // 2. БЕЗОПАСНЫЙ ФИЛЬТР МУСОРА
                // Отсекаем только блок комментариев и футер в самом низу страницы
                var endSplitRegex = /<(?:div|section|aside|ul)[^>]*class="[^"]*(?:comments|similar-articles|related-bottom|article-footer)[^"]*"[^>]*>/i;
                articleHtml = articleHtml.split(endSplitRegex)[0];

                // Выжигаем рекламные iframe внутри текста (оставляем только YouTube)
                articleHtml = articleHtml.replace(/<iframe(?![^>]*youtube\.com)[^>]*>[\s\S]*?<\/iframe>/gi, '');
                
                // Выжигаем скрытые скрипты рекламы
                articleHtml = articleHtml.replace(/<script[^>]*>[\s\S]*?<\/script>/gi, '');

                // 3. ВСТАВЛЯЕМ ГЛАВНУЮ КАРТИНКУ В НАЧАЛО СТАТЬИ
                if (headerImg) {
                    // Проверяем, нет ли её уже в тексте, чтобы не дублировать
                    if (articleHtml.indexOf(headerImg) === -1) {
                        articleHtml = '<img src="' + headerImg + '">' + articleHtml;
                    }
                }

                callback(articleHtml);
            } else {
                callback("");
            }
        }
    };

    xhr.open("GET", link, true);
    xhr.send();
}
