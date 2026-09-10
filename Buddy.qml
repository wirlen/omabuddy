// Omabuddy: a small companion parked in a screen corner.
//
// A fullscreen transparent layer window on the Top layer, input-masked to the
// buddy itself so every other pixel passes clicks through to whatever is
// underneath. The buddy watches the world through scripts/probe.sh, decides a
// mood in Mood.js, and speaks lines from Quips.js (or, opted in, from a local
// Ollama).
//
//   Click        poke it
//   Drag         move it; it snaps to the nearest corner and remembers
//   Right-click  mute / unmute the speech bubble
//
//   omarchy-shell omabuddy say "hello"     make it say something
//   omarchy-shell omabuddy mood proud      force a mood for a while
//   omarchy-shell omabuddy poke
//   omarchy-shell omabuddy set llm ollama  (see README for settings)
//   omarchy-shell omabuddy state

import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import qs.Commons
import "Mood.js" as Mood
import "Quips.js" as Quips

Item {
  id: root

  // Injected by the panel loader.
  property var shell: null
  property var manifest: null

  readonly property string pluginId: String((manifest && manifest.id) || "roth.omabuddy")
  readonly property string pluginDir: String((manifest && manifest.__sourceDir) || "")
  readonly property string scriptsDir: Quickshell.env("HOME") + "/.config/omarchy/plugins/" + pluginId + "/scripts"

  // ---------------------------------------------------------------- settings
  readonly property var pluginEntry: {
    const config = shell ? shell.shellConfig : null
    const plugins = config && Array.isArray(config.plugins) ? config.plugins : []
    for (let i = 0; i < plugins.length; i++)
      if (plugins[i] && plugins[i].id === root.pluginId) return plugins[i]
    return ({})
  }
  readonly property string corner: String(pluginEntry.corner || "bottom-right")
  readonly property int size: Math.max(40, Number(pluginEntry.size) || 72)
  readonly property int chattiness: Math.max(1, Number(pluginEntry.chattiness) || 12) // minutes between unprompted lines
  readonly property bool muted: pluginEntry.muted === true
  readonly property string llm: String(pluginEntry.llm || "off")
  readonly property string ollamaUrl: String(pluginEntry.ollamaUrl || "http://localhost:11434")
  readonly property string ollamaModel: String(pluginEntry.ollamaModel || "llama3.2")
  readonly property int probeSeconds: Math.max(5, Number(pluginEntry.probeSeconds) || 20)

  function updateSetting(name, value) {
    if (!shell || typeof shell.updateEntryInline !== "function") return false
    const next = ({})
    for (const key in root.pluginEntry) if (key !== "id") next[key] = root.pluginEntry[key]
    next[name] = value
    shell.updateEntryInline(root.pluginId, next)
    return true
  }

  // ------------------------------------------------------------------- state
  property var sensors: null
  property string mood: "idle"
  property string moodReason: "booting"
  property string forcedMood: ""
  property string line: ""
  property bool bubbleOpen: false
  property real streakMin: 0
  property bool userIdle: false
  property double lastLineAt: 0

  readonly property var faceParams: Mood.face(root.mood)
  readonly property var quipContext: ({
    repo: sensors ? sensors.repo : "", branch: sensors ? sensors.branch : "",
    dirty: sensors ? sensors.dirty : 0, hour: sensors ? sensors.hour : new Date().getHours(),
    streak: Math.round(streakMin), battery: sensors ? sensors.battery : -1,
    event: sensors && sensors.calendar ? sensors.calendar.title : "",
    eta: sensors && sensors.calendar ? sensors.calendar.eta : "",
    agent: Mood.busiestAgent(sensors) ? Mood.busiestAgent(sensors).name : "the agent",
    prompts: Mood.busiestAgent(sensors) ? Mood.busiestAgent(sensors).prompts : 0,
    limit: Mood.tightestAgent(sensors) ? Math.round(Mood.tightestAgent(sensors).limit * 100) : 0
  })

  function recompute() {
    const decided = Mood.decide(root.sensors, { streakMin: root.streakMin })
    const next = root.forcedMood || decided.mood
    root.moodReason = root.forcedMood ? "forced" : decided.reason
    if (next !== root.mood) {
      root.mood = next
      // A mood swing is worth a word, but only if we've been quiet a while.
      if (Date.now() - root.lastLineAt > 60 * 1000) root.speak(next, false)
    }
  }

  function speak(mood, force) {
    if (root.muted && !force) return
    root.lastLineAt = Date.now()
    if (root.llm === "ollama" && !ollama.running) {
      ollama.moodForLine = mood
      ollama.command = [root.scriptsDir + "/ollama.sh", root.ollamaUrl, root.ollamaModel, mood, JSON.stringify(root.quipContext)]
      ollama.running = true
      return
    }
    root.say(Quips.pick(mood, root.quipContext))
  }

  function say(text) {
    const clean = String(text || "").trim()
    if (!clean) return
    root.line = clean
    root.bubbleOpen = true
    bubbleTimer.interval = Math.min(14000, 3500 + clean.length * 60)
    bubbleTimer.restart()
    talkTimer.restart()
    face.talking = true
  }

  function poke() {
    root.forceMood("poked", 4000)
    root.speak("poked", true)
  }

  function forceMood(name, ms) {
    root.forcedMood = name
    forcedTimer.interval = ms
    forcedTimer.restart()
    root.recompute()
  }

  Timer { id: forcedTimer; onTriggered: { root.forcedMood = ""; root.recompute() } }
  Timer { id: bubbleTimer; onTriggered: root.bubbleOpen = false }
  Timer { id: talkTimer; interval: 1400; onTriggered: face.talking = false }

  // --------------------------------------------------------------- sensors
  Process {
    id: probe
    command: [root.scriptsDir + "/probe.sh"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        let next
        try { next = JSON.parse(text) } catch (e) { console.warn("omabuddy: probe output unreadable:", e); return }
        const fired = Mood.events(root.sensors, next)
        root.sensors = next
        root.recompute()
        for (let i = 0; i < fired.length; i++) { root.forceMood(fired[i], 8000); root.speak(fired[i], false) }
      }
    }
    stderr: StdioCollector { waitForEnd: true; onStreamFinished: if (text.trim()) console.warn("omabuddy probe:", text.trim()) }
  }
  Timer {
    interval: root.probeSeconds * 1000
    running: true; repeat: true; triggeredOnStart: true
    onTriggered: if (!probe.running) probe.running = true
  }

  // Work streak: minutes of continuous activity, reset by four idle minutes.
  IdleMonitor {
    timeout: 240
    respectInhibitors: true
    onIsIdleChanged: {
      root.userIdle = isIdle
      if (isIdle) root.streakMin = 0
    }
  }
  Timer {
    interval: 60000; running: true; repeat: true
    onTriggered: { if (!root.userIdle) root.streakMin += 1; root.recompute() }
  }

  // Unprompted chatter on a slow clock.
  Timer {
    interval: root.chattiness * 60000
    running: !root.muted; repeat: true
    onTriggered: if (!root.userIdle) root.speak(root.mood, false)
  }

  // ------------------------------------------------------------------- llm
  Process {
    id: ollama
    property string moodForLine: "idle"
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        const got = String(text || "").trim()
        root.say(got ? got : Quips.pick(ollama.moodForLine, root.quipContext))
      }
    }
    onExited: function(code) { if (code !== 0) root.say(Quips.pick(ollama.moodForLine, root.quipContext)) }
  }

  // ------------------------------------------------------------------- ipc
  IpcHandler {
    target: "omabuddy"
    function say(text: string): string { root.say(text); return "ok" }
    function poke(): string { root.poke(); return "ok" }
    function mood(name: string): string { root.forceMood(name, 20000); root.speak(name, true); return root.mood }
    function state(): string {
      return JSON.stringify({ mood: root.mood, reason: root.moodReason, streakMin: root.streakMin, muted: root.muted, sensors: root.sensors })
    }
    function set(name: string, value: string): string {
      const known = ["corner", "size", "chattiness", "muted", "llm", "ollamaUrl", "ollamaModel", "probeSeconds"]
      if (known.indexOf(name) === -1) return "unknown setting: " + name + " (" + known.join(", ") + ")"
      let v = value
      if (name === "muted") v = value === "true"
      else if (name === "size" || name === "chattiness" || name === "probeSeconds") v = Number(value)
      return root.updateSetting(name, v) ? "ok" : "unavailable"
    }
  }

  Component.onCompleted: {
    root.recompute()
    Qt.callLater(function() { root.say(Quips.pick("greeting", root.quipContext)) })
  }

  // -------------------------------------------------------------------- ui
  PanelWindow {
    id: panel

    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    WlrLayershell.namespace: "omarchy-omabuddy"
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore
    // Only the buddy takes input; the rest of the screen is click-through.
    mask: Region { item: buddy }

    readonly property int margin: Style.gapsOut + Style.space(8)

    Item {
      id: buddy
      width: root.size
      height: root.size

      readonly property bool atRight: root.corner.indexOf("right") !== -1
      readonly property bool atBottom: root.corner.indexOf("top") === -1

      function park() {
        x = atRight ? panel.width - width - panel.margin : panel.margin
        y = atBottom ? panel.height - height - panel.margin : panel.margin
      }
      Component.onCompleted: park()
      Connections {
        target: panel
        function onWidthChanged() { if (!drag.active) buddy.park() }
        function onHeightChanged() { if (!drag.active) buddy.park() }
      }
      onAtRightChanged: if (!drag.active) park()
      onAtBottomChanged: if (!drag.active) park()

      Behavior on x { enabled: !drag.active; NumberAnimation { duration: 320; easing.type: Easing.OutBack } }
      Behavior on y { enabled: !drag.active; NumberAnimation { duration: 320; easing.type: Easing.OutBack } }

      Face {
        id: face
        anchors.fill: parent
        eye: root.faceParams.eye
        smile: root.faceParams.smile
        brow: root.faceParams.brow
        tint: root.faceParams.tint
        bob: root.faceParams.bob
        scale: drag.active ? 1.08 : (hover.hovered ? 1.04 : 1.0)
        Behavior on scale { NumberAnimation { duration: 120 } }
      }

      HoverHandler { id: hover; cursorShape: Qt.OpenHandCursor }

      DragHandler {
        id: drag
        target: buddy
        cursorShape: Qt.ClosedHandCursor
        xAxis.minimum: 0; xAxis.maximum: panel.width - buddy.width
        yAxis.minimum: 0; yAxis.maximum: panel.height - buddy.height
        onActiveChanged: if (!active) {
          const cx = buddy.x + buddy.width / 2, cy = buddy.y + buddy.height / 2
          const next = (cy < panel.height / 2 ? "top" : "bottom") + "-" + (cx < panel.width / 2 ? "left" : "right")
          if (next === root.corner) buddy.park(); else root.updateSetting("corner", next)
        }
      }

      TapHandler {
        acceptedButtons: Qt.LeftButton
        gesturePolicy: TapHandler.WithinBounds
        onTapped: root.poke()
      }
      TapHandler {
        acceptedButtons: Qt.RightButton
        onTapped: {
          root.updateSetting("muted", !root.muted)
          root.say(root.muted ? "Okay, talking again." : "Zipping it. Right-click to unzip.")
        }
      }
    }

    // Speech bubble, hanging off whichever side of the buddy has room.
    Rectangle {
      id: bubble
      visible: opacity > 0
      opacity: root.bubbleOpen ? 1 : 0
      Behavior on opacity { NumberAnimation { duration: 180 } }

      readonly property int maxWidth: Style.space(260)
      width: bubbleText.width + Style.spacing.md * 2
      height: bubbleText.height + Style.spacing.sm * 2
      radius: Style.cornerRadius
      color: Color.tooltip.background
      border.color: Color.tooltip.border
      border.width: Math.max(1, Style.space(1))

      x: buddy.atRight ? buddy.x - width - Style.spacing.sm : buddy.x + buddy.width + Style.spacing.sm
      y: buddy.atBottom ? buddy.y + buddy.height - height - Style.space(4) : buddy.y + Style.space(4)

      Text {
        id: bubbleText
        anchors.centerIn: parent
        width: Math.min(implicitWidth, bubble.maxWidth)
        wrapMode: Text.WordWrap
        text: root.line
        color: Color.tooltip.text
        font.family: Style.font.family
        font.pixelSize: Style.font.body
      }
    }
  }
}
