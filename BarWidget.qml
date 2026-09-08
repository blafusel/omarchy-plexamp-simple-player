import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import qs.Commons
import qs.Ui

BarWidget {
  id: root
  moduleName: "io.github.inxeo.plexamp-simple-player"

  readonly property var players: Mpris.players ? Mpris.players.values : []
  readonly property var player: {
    var list = players
    for (var i = 0; i < list.length; i++) {
      if (isPlexamp(list[i]))
        return list[i]
    }
    return null
  }
  readonly property bool isPlaying: player ? !!player.isPlaying : false
  readonly property string playIcon: isPlaying ? "󰏤" : "󰐊"
  readonly property string title: player ? (player.trackTitle || "") : ""
  readonly property string artist: player ? (player.trackArtist || "") : ""
  readonly property string trackLabel: title + (artist ? "  ·  " + artist : "")
  readonly property string trackTooltip: title + (artist ? " — " + artist : "")
  readonly property string album: player ? (player.trackAlbum || "") : ""
  readonly property string artUrl: player ? (player.trackArtUrl || "") : ""
  property real maxLabelWidth: 180
  property bool infoPopupOpen: false

  visible: player !== null
  implicitWidth: visible ? (vertical ? barSize : row.implicitWidth + Style.space(8)) : 0
  implicitHeight: visible ? (vertical ? buttons.implicitHeight : barSize) : 0

  function isPlexamp(p) {
    if (!p)
      return false
    var dbus = String(p.dbusName || "").toLowerCase()
    var desktop = String(p.desktopEntry || "").toLowerCase()
    var identity = String(p.identity || "").toLowerCase()
    return dbus.indexOf("plexamp") !== -1
        || desktop.indexOf("plexamp") !== -1
        || identity.indexOf("plexamp") !== -1
  }

  function playPause() {
    var p = player
    if (!p)
      return
    if (p.isPlaying && p.canPause)
      p.pause()
    else if (!p.isPlaying && p.canPlay)
      p.play()
    else if (p.canTogglePlaying)
      p.togglePlaying()
  }

  function previous() {
    if (player)
      player.previous()
  }

  function next() {
    if (player)
      player.next()
  }

  Row {
    id: row
    anchors.centerIn: parent
    spacing: Style.space(6)

    Grid {
      id: buttons
      rows: root.vertical ? 3 : 1
      columns: root.vertical ? 1 : 3
      anchors.verticalCenter: parent.verticalCenter

      BarIconButton {
        bar: root.bar
        text: "󰒮"
        tooltipText: "Previous"
        onPressed: root.previous()
      }

      BarIconButton {
        bar: root.bar
        text: root.playIcon
        tooltipText: root.isPlaying ? "Pause" : "Play"
        onPressed: root.playPause()
      }

      BarIconButton {
        bar: root.bar
        text: "󰒭"
        tooltipText: "Next"
        onPressed: root.next()
      }
    }

    Item {
      id: ratingWidget
      visible: !root.vertical && root.player !== null
      anchors.verticalCenter: parent.verticalCenter

      readonly property string trackId: root.player && root.player.metadata
          ? String(root.player.metadata["mpris:trackid"] || "") : ""
      readonly property real ratingValue: root.player && root.player.metadata
          ? (root.player.metadata["xesam:userRating"] || 0) : 0
      // Plexamp's own MPRIS Metadata is read-only (confirmed via introspection:
      // no writable rating property or method exists there), so a rating set
      // here won't be reflected back by Plexamp until it independently
      // refreshes. Track our own optimistic value per-track until then.
      property string manualRatingTrackId: ""
      property real manualRatingValue: 0
      readonly property real effectiveRatingValue: manualRatingTrackId === trackId ? manualRatingValue : ratingValue
      readonly property int ratingStars: Math.max(0, Math.min(5, Math.round(effectiveRatingValue * 5)))
      // -1 means no hover in progress; otherwise the star index the mouse is over.
      property int hoverStars: -1
      readonly property int displayStars: hoverStars >= 0 ? hoverStars : ratingStars

      width: badge.implicitWidth
      height: badge.implicitHeight

      function starGlyph(filled) {
        // md-star / md-star_outline (Material Design Icons range) render
        // reliably in this font; the classic fa-star codepoints (0xF005/6)
        // silently fail to rasterize in this widget for unknown reasons.
        return filled ? "󰓎" : "󰓒"
      }

      // Ratings live on the Plex Media Server, not in Plexamp: Plexamp's MPRIS
      // Metadata is read-only and exposes no rating-write method, so setting a
      // rating means talking to the Plex server directly, then nudging
      // Plexamp's Companion API so it re-fetches metadata and its own UI
      // picks up the change. rate-track.sh already implements exactly that
      // (PUT /:/rate, then refreshPlayQueue or a seek nudge), so it's reused
      // here rather than reimplementing Companion discovery in QML. Override
      // PLEXAMP_RATER_SCRIPT if the script lives somewhere other than the
      // default dev checkout path below.
      readonly property string raterScript: Quickshell.env("PLEXAMP_RATER_SCRIPT")
          || ((Quickshell.env("HOME") || "") + "/dev/plexamp-controller/rate-track.sh")

      function setRating(stars) {
        if (!root.player)
          return
        setRatingProc.command = [raterScript, String(stars)]
        if (!setRatingProc.running)
          setRatingProc.running = true
        ratingWidget.manualRatingTrackId = ratingWidget.trackId
        ratingWidget.manualRatingValue = stars / 5
      }

      Process {
        id: setRatingProc
        onExited: function(exitCode) {
          if (exitCode !== 0)
            console.warn("plexamp-simple-player: rating write rejected (exit " + exitCode + ")")
        }
      }

      Row {
        id: badge
        anchors.verticalCenter: parent.verticalCenter
        spacing: 0

        Repeater {
          model: 5

          // Nerd Font icon glyphs report unreliable advance widths, so a
          // plain concatenated string collapses into an overlapping mess.
          // Each star gets its own fixed-size box instead.
          Text {
            readonly property int starIndex: index + 1
            width: Style.font.body
            textFormat: Text.PlainText
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            text: ratingWidget.starGlyph(starIndex <= ratingWidget.displayStars)
            color: ratingWidget.hoverStars >= 0 && starIndex <= ratingWidget.hoverStars
                ? Color.accent
                : (root.bar ? root.bar.barForeground : Color.foreground)
            font.family: root.bar ? root.bar.fontFamily : Style.font.family
            font.pixelSize: Style.font.body * 0.85

            MouseArea {
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onEntered: ratingWidget.hoverStars = starIndex
              onExited: if (ratingWidget.hoverStars === starIndex) ratingWidget.hoverStars = -1
              onClicked: ratingWidget.setRating(starIndex)
            }
          }
        }
      }
    }

    Item {
      id: scrollClip
      width: Math.min(root.maxLabelWidth, measure.implicitWidth)
      height: buttons.height
      clip: true
      visible: !root.vertical && root.trackLabel !== ""
      anchors.verticalCenter: parent.verticalCenter
      property bool tooltipHovered: labelMouse.containsMouse
      readonly property bool needsScroll: measure.implicitWidth > width
      readonly property string gapText: "    •    "
      readonly property real cycleWidth: cycleMeasure.implicitWidth

      function resetMarquee() {
        marquee.x = 0
        if (scrollAnim.running)
          scrollAnim.restart()
      }

      onNeedsScrollChanged: if (!needsScroll) marquee.x = 0
      onCycleWidthChanged: if (scrollClip.needsScroll) resetMarquee()

      // Hidden measurers so the ticker can loop by exactly one title+gap
      // without depending on a second Text item that may get clipped.
      Text {
        id: measure
        text: root.trackLabel
        textFormat: Text.PlainText
        font.family: root.bar ? root.bar.fontFamily : Style.font.family
        font.pixelSize: Style.font.body
        visible: false
      }

      Text {
        id: cycleMeasure
        text: root.trackLabel + scrollClip.gapText
        textFormat: Text.PlainText
        font.family: measure.font.family
        font.pixelSize: measure.font.pixelSize
        visible: false
      }

      Text {
        id: marquee
        text: scrollClip.needsScroll
              ? (root.trackLabel + scrollClip.gapText + root.trackLabel)
              : root.trackLabel
        textFormat: Text.PlainText
        wrapMode: Text.NoWrap
        elide: Text.ElideNone
        color: root.bar ? root.bar.barForeground : Color.foreground
        font.family: measure.font.family
        font.pixelSize: measure.font.pixelSize
        anchors.verticalCenter: parent.verticalCenter
        onTextChanged: scrollClip.resetMarquee()

        NumberAnimation on x {
          id: scrollAnim
          running: scrollClip.needsScroll && scrollClip.visible && scrollClip.cycleWidth > 1
          loops: Animation.Infinite
          duration: Math.max(6000, Math.round(scrollClip.cycleWidth * 25))
          from: 0
          to: -scrollClip.cycleWidth
          easing.type: Easing.Linear
        }
      }

      MouseArea {
        id: labelMouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onEntered: if (root.bar && root.trackTooltip) root.bar.showTooltip(scrollClip, root.trackTooltip)
        onExited: if (root.bar) root.bar.hideTooltip(scrollClip)
        onClicked: root.infoPopupOpen = !root.infoPopupOpen
      }

      QtObject {
        id: infoPopupOwner
        function close() { root.infoPopupOpen = false }
      }

      PopupCard {
        id: infoPopup
        anchorItem: scrollClip
        bar: root.bar
        owner: infoPopupOwner
        open: root.infoPopupOpen
        contentWidth: infoPopup.fittedContentWidth(Style.space(260))
        contentHeight: infoPopup.fittedContentHeight(infoColumn.implicitHeight)

        Column {
          id: infoColumn
          anchors.fill: parent
          spacing: Style.space(10)

          BorderSurface {
            width: parent.width
            height: width
            radius: Style.spacing.labelGap
            color: Style.normalFillFor(root.bar.foreground, Color.accent)
            borderSpec: Border.controlSpec("normal", root.bar.foreground, Color.accent)

            Image {
              anchors.fill: parent
              anchors.margins: Style.space(2)
              fillMode: Image.PreserveAspectCrop
              asynchronous: true
              source: root.artUrl
              visible: source !== ""
            }

            Text {
              anchors.centerIn: parent
              visible: root.artUrl === ""
              text: "󰝚"
              color: root.bar.foreground
              font.family: root.bar.fontFamily
              font.pixelSize: Style.font.displayLarge
            }
          }

          Text {
            textFormat: Text.PlainText
            text: root.title || "Nothing playing"
            color: root.bar.foreground
            font.family: root.bar.fontFamily
            font.pixelSize: Style.font.subtitle
            font.bold: true
            elide: Text.ElideRight
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
          }

          Text {
            textFormat: Text.PlainText
            text: root.artist
            color: Qt.darker(root.bar.foreground, 1.3)
            font.family: root.bar.fontFamily
            font.pixelSize: Style.font.bodySmall
            elide: Text.ElideRight
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            visible: text !== ""
          }

          Text {
            textFormat: Text.PlainText
            text: root.album
            color: Qt.darker(root.bar.foreground, 1.6)
            font.family: root.bar.fontFamily
            font.pixelSize: Style.font.caption
            elide: Text.ElideRight
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            visible: text !== ""
          }

          Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: Style.space(2)

            Repeater {
              model: 5

              Text {
                readonly property int starIndex: index + 1
                width: Style.font.body
                textFormat: Text.PlainText
                horizontalAlignment: Text.AlignHCenter
                text: ratingWidget.starGlyph(starIndex <= ratingWidget.ratingStars)
                color: root.bar.foreground
                font.family: root.bar.fontFamily
                font.pixelSize: Style.font.body * 0.85
              }
            }
          }

          Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: Style.space(6)

            Button {
              iconText: "󰒮"
              foreground: root.bar.foreground
              horizontalPadding: Style.spacing.controlPaddingX
              verticalPadding: Style.spacing.controlPaddingY
              onClicked: root.previous()
            }

            Button {
              iconText: root.playIcon
              foreground: root.bar.foreground
              horizontalPadding: Style.spacing.panelGap
              verticalPadding: Style.spacing.controlPaddingY
              iconSize: Style.font.iconLarge
              onClicked: root.playPause()
            }

            Button {
              iconText: "󰒭"
              foreground: root.bar.foreground
              horizontalPadding: Style.spacing.controlPaddingX
              verticalPadding: Style.spacing.controlPaddingY
              onClicked: root.next()
            }
          }
        }
      }
    }
  }
}
