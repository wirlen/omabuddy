// Omabuddy's face. Entirely procedural: a soft blob, two eyes, two brows and
// a mouth, all drawn from theme colours so it looks native in every Omarchy
// theme. Animated properties tween between moods; the parent sets them from
// Mood.face().
import QtQuick
import qs.Commons

Item {
  id: face

  property real eye: 0.9      // 0 closed .. 1 wide open
  property real smile: 0.3    // -1 frown .. 1 grin
  property real brow: 0.0     // -1 furrowed .. 1 raised
  property string tint: "normal"
  property int bob: 1800      // bounce period ms, 0 = still
  property bool talking: false

  property color bodyColor: {
    if (tint === "accent") return Color.accent
    if (tint === "urgent") return Color.urgent
    if (tint === "muted") return Qt.darker(Color.popups.background, 1.15)
    return Color.popups.background
  }
  readonly property color inkColor: (tint === "accent" || tint === "urgent") ? Color.background : Color.foreground
  readonly property color edgeColor: (tint === "accent" || tint === "urgent") ? Qt.darker(bodyColor, 1.3) : Color.popups.border

  // Blink: eyelids drop for a moment every few seconds.
  property real blink: 1.0
  Timer {
    interval: 2400 + Math.random() * 3200
    running: true
    repeat: true
    onTriggered: { blinkAnim.restart(); interval = 2400 + Math.random() * 3200 }
  }
  SequentialAnimation {
    id: blinkAnim
    NumberAnimation { target: face; property: "blink"; to: 0.05; duration: 70 }
    NumberAnimation { target: face; property: "blink"; to: 1.0; duration: 110 }
  }

  Behavior on eye   { NumberAnimation { duration: 350; easing.type: Easing.OutCubic } }
  Behavior on smile { NumberAnimation { duration: 450; easing.type: Easing.OutBack } }
  Behavior on brow  { NumberAnimation { duration: 350; easing.type: Easing.OutCubic } }
  Behavior on bodyColor { ColorAnimation { duration: 500 } }

  // Idle bob: a gentle vertical breathing motion, faster when excited.
  property real bobY: 0
  SequentialAnimation on bobY {
    running: face.bob > 0
    loops: Animation.Infinite
    NumberAnimation { to: -face.height * 0.05; duration: Math.max(150, face.bob / 2); easing.type: Easing.InOutSine }
    NumberAnimation { to: 0; duration: Math.max(150, face.bob / 2); easing.type: Easing.InOutSine }
  }

  // Mouth wobble while "talking".
  property real talk: 0
  SequentialAnimation on talk {
    running: face.talking
    loops: Animation.Infinite
    NumberAnimation { to: 1; duration: 120 }
    NumberAnimation { to: 0; duration: 140 }
  }
  onTalkingChanged: if (!talking) talk = 0

  Canvas {
    id: canvas
    anchors.fill: parent
    y: face.bobY
    antialiasing: true

    Connections {
      target: face
      function onEyeChanged() { canvas.requestPaint() }
      function onSmileChanged() { canvas.requestPaint() }
      function onBrowChanged() { canvas.requestPaint() }
      function onBlinkChanged() { canvas.requestPaint() }
      function onBodyColorChanged() { canvas.requestPaint() }
      function onTalkChanged() { canvas.requestPaint() }
      function onBobYChanged() { canvas.requestPaint() }
    }

    onPaint: {
      var ctx = getContext("2d")
      var w = width, h = height
      ctx.clearRect(0, 0, w, h)

      // Body: squashed superellipse-ish blob.
      var pad = w * 0.06
      var bw = w - pad * 2, bh = h - pad * 2
      var r = Math.min(bw, bh) * 0.42
      ctx.beginPath()
      ctx.moveTo(pad + r, pad)
      ctx.lineTo(pad + bw - r, pad)
      ctx.quadraticCurveTo(pad + bw, pad, pad + bw, pad + r)
      ctx.lineTo(pad + bw, pad + bh - r)
      ctx.quadraticCurveTo(pad + bw, pad + bh, pad + bw - r, pad + bh)
      ctx.lineTo(pad + r, pad + bh)
      ctx.quadraticCurveTo(pad, pad + bh, pad, pad + bh - r)
      ctx.lineTo(pad, pad + r)
      ctx.quadraticCurveTo(pad, pad, pad + r, pad)
      ctx.closePath()
      ctx.fillStyle = face.bodyColor
      ctx.fill()
      ctx.lineWidth = Math.max(1.5, w * 0.03)
      ctx.strokeStyle = face.edgeColor
      ctx.stroke()

      // Eyes.
      var open = Math.max(0.04, face.eye * face.blink)
      var ex = [w * 0.34, w * 0.66]
      var ey = h * 0.42
      var er = w * 0.085
      ctx.fillStyle = face.inkColor
      for (var i = 0; i < 2; i++) {
        ctx.beginPath()
        ctx.ellipse(ex[i] - er, ey - er * open, er * 2, er * 2 * open)
        ctx.fill()
      }

      // Brows: a short stroke above each eye, tilted by `brow`.
      ctx.strokeStyle = face.inkColor
      ctx.lineWidth = Math.max(1.5, w * 0.035)
      ctx.lineCap = "round"
      var by = ey - er * 2.2 - face.brow * er * 0.9
      var tilt = -face.brow * er * 0.6
      // left brow: outer end goes down when furrowed (brow < 0 -> inner up)
      ctx.beginPath(); ctx.moveTo(ex[0] - er, by - tilt * 0.3); ctx.lineTo(ex[0] + er, by + tilt); ctx.stroke()
      ctx.beginPath(); ctx.moveTo(ex[1] - er, by + tilt); ctx.lineTo(ex[1] + er, by - tilt * 0.3); ctx.stroke()

      // Mouth: a curve whose bend follows `smile`; opens slightly when talking.
      var mx = w * 0.5, my = h * 0.68
      var mw = w * (0.22 + Math.abs(face.smile) * 0.1)
      var bend = face.smile * h * 0.12
      var gap = face.talk * h * 0.05
      ctx.beginPath()
      ctx.moveTo(mx - mw, my)
      ctx.quadraticCurveTo(mx, my + bend + gap, mx + mw, my)
      if (gap > 0.5) { ctx.quadraticCurveTo(mx, my + bend - gap * 0.4, mx - mw, my); ctx.fill() }
      ctx.stroke()
    }
    Component.onCompleted: requestPaint()
  }
}
