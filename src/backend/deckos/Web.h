// DeckOS
// Web content opened from the theme (`deckos.web`): YouTube videos play inside DeckOS on Android
// (com.deckos.media.VideoActivity: YouTube's own embedded player, driven by the controller), or open in the
// YouTube app / the browser. On PC both open the browser.

#pragma once

#include <QObject>


namespace deckos {

class Web : public QObject {
    Q_OBJECT
    /// videos play inside DeckOS (Android); false: they open in the browser
    Q_PROPERTY(bool inAppVideo READ inAppVideo CONSTANT)

public:
    explicit Web(QObject* parent = nullptr);

    bool inAppVideo() const;

    /// plays a YouTube video (its id) in DeckOS's player; `link` is opened instead where that can't be
    Q_INVOKABLE void playVideo(const QString& videoId, const QString& title, const QString& link);
    /// the video in the YouTube app (Android) or the browser
    Q_INVOKABLE void openInYouTube(const QString& videoId, const QString& link);
};

} // namespace deckos
