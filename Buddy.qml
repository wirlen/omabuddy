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
//   Scroll       grow / shrink it
//   Right-click  mute / unmute the speech bubble
//
//   omarchy-shell omabuddy say "hello"     make it say something
//   omarchy-shell omabuddy mood proud      force a mood for a while
//   omarchy-shell omabuddy poke
//   omarchy-shell omabuddy set tone polite (see README for settings)
//   omarchy-shell omabuddy state

import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import QtQuick.Effects
import qs.Commons
import "Mood.js" as Mood
import "Quips.js" as Quips

Item {
  id: root

  // Injected by the panel loader.
  property var shell: null
  property var manifest: null

  readonly property string pluginId: String((manifest && manifest.id) || "wirlen.omabuddy")
  readonly property string home: Quickshell.env("HOME")
  readonly property string scriptsDir: home + "/.config/omarchy/plugins/" + pluginId + "/scripts"

  // ---------------------------------------------------------------- settings
  // The shell API hands panel plugins no view of shell.json, so read our own
  // plugins[] entry straight from the file and follow it as it changes (the
  // shell rewrites it whenever updateEntryInline() persists a setting).
  readonly property string shellConfigPath: home + "/.config/omarchy/shell.json"
  property var shellConfig: null
  FileView {
    id: shellConfigFile
    path: root.shellConfigPath
    watchChanges: true
    printErrors: false
    onLoaded: root.readShellConfig(text())
    onLoadFailed: root.readShellConfig("")
    onFileChanged: reload()
  }
  function readShellConfig(raw) {
    try {
      const parsed = JSON.parse(String(raw || "").trim() || "{}")
      root.shellConfig = parsed && typeof parsed === "object" ? parsed : null
    } catch (e) { root.shellConfig = null }
  }
  readonly property var pluginEntry: {
    const config = root.shellConfig || (shell ? shell.shellConfig : null)
    const plugins = config && Array.isArray(config.plugins) ? config.plugins : []
    for (let i = 0; i < plugins.length; i++)
      if (plugins[i] && plugins[i].id === root.pluginId) return plugins[i]
    return ({})
  }
  readonly property string corner: String(pluginEntry.corner || "bottom-right")
  readonly property int minSize: 8
  readonly property int maxSize: 48
  readonly property int size: Math.min(maxSize, Math.max(minSize, Number(pluginEntry.size) || 14)) // face font size in px
  // Wheel resizing previews instantly and persists once the wheel goes quiet.
  property int pendingSize: -1
  Timer {
    id: sizeCommit
    interval: 400
    onTriggered: { if (root.pendingSize > 0 && root.pendingSize !== root.size) root.updateSetting("size", root.pendingSize); root.pendingSize = -1 }
  }
  function nudgeSize(delta) {
    const from = root.pendingSize > 0 ? root.pendingSize : root.size
    root.pendingSize = Math.min(root.maxSize, Math.max(root.minSize, from + delta))
    sizeCommit.restart()
  }
  readonly property string tone: String(pluginEntry.tone || "snarky")
  readonly property int chattiness: Math.max(1, Number(pluginEntry.chattiness) || 12) // minutes between unprompted lines
  readonly property bool muted: pluginEntry.muted === true
  readonly property string llm: String(pluginEntry.llm || "off")
  readonly property string ollamaUrl: String(pluginEntry.ollamaUrl || "http://localhost:11434")
  readonly property string ollamaModel: String(pluginEntry.ollamaModel || "llama3.2")
  readonly property bool allowRemoteLlm: pluginEntry.allowRemoteLlm === true
  readonly property int probeSeconds: Math.max(5, Number(pluginEntry.probeSeconds) || 20)

  function updateSetting(name, value) {
    if (!shell || typeof shell.updateEntryInline !== "function") return false
    const next = ({})
    for (const key in root.pluginEntry) if (key !== "id") next[key] = root.pluginEntry[key]
    next[name] = value
    shell.updateEntryInline(root.pluginId, next)
    return true
  }

  // ----------------------------------------------------------------- palette
  // The shell exposes accent/urgent/muted; the design also wants green,
  // yellow and cyan, so read them straight from the active theme's colors.toml.
  property var themeColors: ({})
  FileView {
    path: root.home + "/.local/state/omarchy/current/theme/colors.toml"
    watchChanges: true
    printErrors: false
    onLoaded: root.themeColors = root.parseToml(text())
    onFileChanged: reload()
  }
  function parseToml(text) {
    const out = ({})
    const re = /^\s*([a-z_]+)\s*=\s*"(#[0-9a-fA-F]{6,8})"/gm
    let m
    while ((m = re.exec(String(text || ""))) !== null) out[m[1]] = m[2]
    return out
  }
  function roleColor(role) {
    const t = root.themeColors
    switch (role) {
      case "red":    return t.red    || Color.urgent
      case "green":  return t.green  || Color.accent
      case "yellow": return t.yellow || Color.accent
      case "cyan":   return t.cyan   || Color.accent
      case "muted":  return t.muted  || Color.muted
      default:       return t.accent || Color.accent
    }
  }

  // ------------------------------------------------------------------- state
  property var sensors: null
  property string mood: "idle"
  property string moodReason: "booting"
  property string forcedMood: ""
  property string line: ""
  property bool bubbleOpen: false
  property real streakMin: 0
  property real ignoredMin: 0
  property bool userIdle: false
  property double lastLineAt: 0

  readonly property var faceSpec: Mood.face(root.mood)
  readonly property var quipContext: ({
    repo: sensors ? sensors.repo : "", branch: sensors ? sensors.branch : "",
    dirty: sensors ? sensors.dirty : 0, hour: sensors ? sensors.hour : new Date().getHours(),
    streak: Math.round(streakMin), battery: sensors ? sensors.battery : -1,
    windows: sensors ? sensors.windows : 0,
    event: sensors && sensors.calendar ? sensors.calendar.title : "",
    eta: sensors && sensors.calendar ? sensors.calendar.eta : "",
    agent: Mood.busiestAgent(sensors) ? Mood.busiestAgent(sensors).name : "the agent",
    prompts: Mood.busiestAgent(sensors) ? Mood.busiestAgent(sensors).prompts : 0,
    limit: Mood.tightestAgent(sensors) ? Math.round(Mood.tightestAgent(sensors).limit * 100) : 0
  })

  function recompute() {
    const decided = Mood.decide(root.sensors, { streakMin: root.streakMin, ignoredMin: root.ignoredMin })
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
      ollama.command = [root.scriptsDir + "/ollama.sh", root.ollamaUrl, root.ollamaModel, mood + " (" + root.tone + ")",
                        JSON.stringify(root.quipContext), root.allowRemoteLlm ? "remote-ok" : ""]
      ollama.running = true
      return
    }
    root.say(Quips.pick(mood, root.quipContext, root.tone))
  }

  readonly property int maxLineLength: 280

  function say(text) {
    let clean = String(text || "").trim()
    if (!clean) return
    if (clean.length > root.maxLineLength) clean = clean.slice(0, root.maxLineLength - 1) + "…"
    root.line = clean
    root.bubbleOpen = true
    bubbleTimer.interval = Math.min(14000, 3500 + clean.length * 60)
    bubbleTimer.restart()
    talkTimer.interval = Math.min(2600, 600 + clean.length * 35)
    talkTimer.restart()
    face.talking = true
  }

  function poke() {
    root.ignoredMin = 0
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
  Timer { id: talkTimer; onTriggered: face.talking = false }

  // --------------------------------------------------------------- sensors
  Process {
    id: probe
    // A stalled mount under the focused directory must not wedge the probe for good.
    command: ["timeout", "15", root.scriptsDir + "/probe.sh"]
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
    onTriggered: {
      if (!root.userIdle) root.streakMin += 1
      root.ignoredMin += 1
      root.recompute()
    }
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
        root.say(got ? got : Quips.pick(ollama.moodForLine, root.quipContext, root.tone))
      }
    }
    onExited: function(code) { if (code !== 0) root.say(Quips.pick(ollama.moodForLine, root.quipContext, root.tone)) }
  }

  // ------------------------------------------------------------------- ipc
  IpcHandler {
    target: "omabuddy"
    function say(text: string): string { root.say(text); return "ok" }
    function poke(): string { root.poke(); return "ok" }
    function mood(name: string): string { root.forceMood(name, 20000); root.speak(name, true); return root.mood }
    function state(): string {
      return JSON.stringify({ mood: root.mood, reason: root.moodReason, tone: root.tone, streakMin: root.streakMin, muted: root.muted, sensors: root.sensors })
    }
    function set(name: string, value: string): string {
      const known = ["corner", "size", "tone", "chattiness", "muted", "llm", "ollamaUrl", "ollamaModel", "allowRemoteLlm", "probeSeconds"]
      if (known.indexOf(name) === -1) return "unknown setting: " + name + " (" + known.join(", ") + ")"
      let v = value
      if (name === "muted" || name === "allowRemoteLlm") v = value === "true"
      else if (name === "ollamaUrl" && !/^https?:\/\//.test(value)) return "ollamaUrl must start with http:// or https://"
      else if (name === "size") { v = Number(value); if (!(v >= root.minSize && v <= root.maxSize)) return "size must be " + root.minSize + " to " + root.maxSize }
      else if (name === "chattiness" || name === "probeSeconds") v = Number(value)
      else if (name === "tone" && value !== "snarky" && value !== "polite") return "tone must be snarky or polite"
      return root.updateSetting(name, v) ? "ok" : "unavailable"
    }
  }

  Component.onCompleted: {
    root.recompute()
    Qt.callLater(function() { root.say(Quips.pick("greeting", root.quipContext, root.tone)) })
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
      width: face.implicitWidth
      height: face.implicitHeight

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
      onWidthChanged: if (!drag.active) park()
      onHeightChanged: if (!drag.active) park()

      Behavior on x { enabled: !drag.active; NumberAnimation { duration: 320; easing.type: Easing.OutBack } }
      Behavior on y { enabled: !drag.active; NumberAnimation { duration: 320; easing.type: Easing.OutBack } }

      Face {
        id: face
        anchors.fill: parent
        pixelSize: root.pendingSize > 0 ? root.pendingSize : root.size
        eyes: root.faceSpec.eyes
        mouth: root.faceSpec.mouth
        extra: root.faceSpec.extra
        color: root.roleColor(root.faceSpec.role)
        bob: root.faceSpec.bob
        scale: drag.active ? 1.06 : (hover.hovered ? 1.03 : 1.0)
        Behavior on scale { NumberAnimation { duration: 120 } }
      }

      HoverHandler { id: hover; cursorShape: Qt.OpenHandCursor }

      WheelHandler {
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        onWheel: function(event) { root.nudgeSize(event.angleDelta.y > 0 ? 1 : -1) }
      }

      DragHandler {
        id: drag
        target: buddy
        cursorShape: Qt.ClosedHandCursor
        xAxis.minimum: 0; xAxis.maximum: panel.width - buddy.width
        yAxis.minimum: 0; yAxis.maximum: panel.height - buddy.height
        property bool grabbed: false
        onActiveChanged: {
          // The handler flips active once while the window is being set up;
          // only a real press counts as a grab, and only a grab counts as a drop.
          if (active) {
            if (!centroid.pressed) return
            grabbed = true
            root.ignoredMin = 0
            root.forceMood("grabbed", 60000)
            root.speak("grabbed", true)
            return
          }
          if (!grabbed) return
          grabbed = false
          const cx = buddy.x + buddy.width / 2, cy = buddy.y + buddy.height / 2
          const next = (cy < panel.height / 2 ? "top" : "bottom") + "-" + (cx < panel.width / 2 ? "left" : "right")
          if (next === root.corner) buddy.park(); else root.updateSetting("corner", next)
          root.forceMood("dropped", 3500)
          root.speak("dropped", true)
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
          root.say(root.muted ? "okay, talking again." : "zipping it. right-click to unzip.")
        }
      }
    }

    // Speech bubble: foreground on background, one sharp corner pointing at
    // the buddy. Above the face at the bottom corners, below it at the top.
    Rectangle {
      id: bubble
      visible: opacity > 0
      opacity: root.bubbleOpen ? 1 : 0
      Behavior on opacity { NumberAnimation { duration: 180 } }

      readonly property int maxWidth: Style.space(250)
      readonly property int tail: Math.max(1, Style.space(2))
      readonly property int round: Style.space(8)
      width: bubbleText.width + Style.space(12) * 2
      height: bubbleText.height + Style.space(9) * 2
      color: Color.foreground
      topLeftRadius: (!buddy.atBottom && !buddy.atRight) ? tail : round
      topRightRadius: (!buddy.atBottom && buddy.atRight) ? tail : round
      bottomLeftRadius: (buddy.atBottom && !buddy.atRight) ? tail : round
      bottomRightRadius: (buddy.atBottom && buddy.atRight) ? tail : round

      // Sit over the head, flush with the face's outer edge, following the bob.
      x: buddy.atRight ? buddy.x + buddy.width - width - root.size : buddy.x + root.size
      y: buddy.atBottom ? buddy.y - height + root.size * 0.1 : buddy.y + buddy.height + Style.space(4)

      Text {
        id: bubbleText
        anchors.centerIn: parent
        width: Math.min(implicitWidth, bubble.maxWidth)
        wrapMode: Text.WordWrap
        // Lines carry branch names, calendar titles and model output: never markup.
        textFormat: Text.PlainText
        text: root.line
        color: Color.background
        font.family: Style.font.family
        font.pixelSize: Style.font.body
        font.weight: Font.Medium
        lineHeight: 1.4
      }
    }
    MultiEffect {
      source: bubble
      anchors.fill: bubble
      visible: bubble.visible
      opacity: bubble.opacity
      z: bubble.z - 1
      shadowEnabled: true
      shadowBlur: 1.0
      shadowOpacity: 0.45
      shadowVerticalOffset: Style.space(8)
    }
  }
}
