// Omabuddy's face, after the Claude Design "Omarchy Companion" canvas: a
// block-character critter in the shell's monospace font, glowing in a theme
// colour, standing on a little shadow. The parent hands in a face spec from
// Mood.face(): eyes, mouth, an optional extra mark by the head, and a colour.
import QtQuick
import QtQuick.Effects
import qs.Commons

Item {
  id: face

  property string eyes: "◉    ◉"
  property string mouth: "▁▁"
  property string extra: ""
  property color color: Color.accent
  property int bob: 1800        // bounce period ms, 0 = still
  property bool talking: false
  property real pixelSize: 14

  implicitWidth: label.implicitWidth + pixelSize * 2
  implicitHeight: label.implicitHeight + pixelSize * 0.9

  function art(eyes, mouth, extra) {
    return "   ▄▄▄▄▄▄▄▄\n  █ " + eyes + " █" + (extra || "") + "\n  █        █\n  █   " + mouth + "   █\n   ▀▀▀▀▀▀▀▀\n    ▀▀  ▀▀"
  }

  // Blink: eyes flatten for a beat every few seconds.
  property bool blinking: false
  Timer {
    interval: 2400 + Math.random() * 3200
    running: true; repeat: true
    onTriggered: { blinkTimer.restart(); face.blinking = true; interval = 2400 + Math.random() * 3200 }
  }
  Timer { id: blinkTimer; interval: 110; onTriggered: face.blinking = false }

  // Talking: the mouth opens and closes.
  property bool mouthOpen: false
  Timer {
    interval: 130; running: face.talking; repeat: true
    onTriggered: face.mouthOpen = !face.mouthOpen
    onRunningChanged: if (!running) face.mouthOpen = false
  }

  readonly property string shownEyes: blinking ? "–    –" : eyes
  readonly property string shownMouth: mouthOpen ? "○ " : mouth
  readonly property string text: art(shownEyes, shownMouth, extra)

  Behavior on color { ColorAnimation { duration: 400 } }

  // Idle bob: gentle vertical breathing, faster when excited.
  property real bobY: 0
  SequentialAnimation on bobY {
    running: face.bob > 0
    loops: Animation.Infinite
    NumberAnimation { to: -face.pixelSize * 0.25; duration: Math.max(150, face.bob / 2); easing.type: Easing.InOutSine }
    NumberAnimation { to: 0; duration: Math.max(150, face.bob / 2); easing.type: Easing.InOutSine }
  }

  // Ground shadow: shrinks a touch as the body lifts.
  Rectangle {
    id: shadow
    width: face.pixelSize * 4.6
    height: face.pixelSize * 0.42
    radius: height / 2
    color: Qt.rgba(0, 0, 0, 0.6)
    anchors.horizontalCenter: label.horizontalCenter
    anchors.horizontalCenterOffset: face.pixelSize * 0.2
    y: label.y + label.height - face.pixelSize * 0.15
    scale: 1 + face.bobY / (face.pixelSize * 2)
  }

  // Glow: a blurred copy of the text behind the crisp one.
  Text {
    id: glowSource
    anchors.fill: label
    text: face.text
    color: face.color
    font.family: label.font.family
    font.pixelSize: label.font.pixelSize
    font.weight: label.font.weight
    font.letterSpacing: label.font.letterSpacing
    lineHeight: label.lineHeight
    font.hintingPreference: label.font.hintingPreference
    visible: false
  }
  MultiEffect {
    source: glowSource
    anchors.fill: label
    y: label.y
    blurEnabled: true
    blurMax: 48
    blur: 1.0
    brightness: 0.2
    opacity: 0.85
  }

  Text {
    id: label
    x: face.pixelSize
    y: face.bobY + face.pixelSize * 0.3
    text: face.text
    color: face.color
    font.family: Style.font.family
    font.pixelSize: face.pixelSize
    font.weight: Font.Bold
    font.hintingPreference: Font.PreferNoHinting
    font.letterSpacing: -face.pixelSize * 0.06
    lineHeight: 0.94
    textFormat: Text.PlainText
    renderType: Text.NativeRendering
  }
}
