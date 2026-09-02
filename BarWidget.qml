import QtQuick
import Quickshell.Services.Mpris
import qs.Commons
import qs.Ui

BarWidget {
  id: root
  moduleName: "io.github.inxeo.plexamp"

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
  property real maxLabelWidth: 180

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
        acceptedButtons: Qt.NoButton
        onEntered: if (root.bar && root.trackTooltip) root.bar.showTooltip(scrollClip, root.trackTooltip)
        onExited: if (root.bar) root.bar.hideTooltip(scrollClip)
      }
    }
  }
}
