// The buddy's optional senses, each off until its setting turns it on:
//
//   desktop  Hyprland events: a workspace-hopping spree, a burst of new
//            windows, and whether the focused window is fullscreen
//   devices  the default speaker muted or turned all the way up, the network
//            dropping or coming back, a Bluetooth device connecting
//   music    the playing MPRIS track's title and artist
//
// Every sense reads from models Quickshell already keeps for the shell
// (Hyprland, Pipewire, NetworkManager, BlueZ, MPRIS over D-Bus); nothing here
// spawns a process or opens a file. What leaves this file is a mood name, a
// boolean, and (music only) two strings clipped to 64 characters. A sense
// that is off reads nothing: its bindings fall back to constants and its
// handlers are disabled.
//
// One thing is always on because it reads nothing new: UPower telling us the
// cable went in or out, which only makes the probe run now instead of later.
import QtQuick
import Quickshell
import Quickshell.Bluetooth
import Quickshell.Hyprland
import Quickshell.Networking
import Quickshell.Services.Mpris
import Quickshell.Services.Pipewire
import Quickshell.Services.UPower
import Quickshell.Wayland

Item {
  id: senses

  property bool desktop: false
  property bool devices: false
  property bool music: false

  // A mood worth a reaction, and a request to run the probe now.
  signal sensed(string name)
  signal kick()

  readonly property int clipLength: 64

  // Rolling timestamps for burst detection, capped so a flood stays small.
  function burst(list, now, windowMs) {
    const out = list.filter(function(t) { return now - t < windowMs })
    out.push(now)
    return out.slice(-32)
  }

  // A sense that has just been switched on (or the shell that just started)
  // reports its current state as a change. Wait a moment before believing it.
  property bool devicesArmed: false
  property bool musicArmed: false
  onDevicesChanged: devicesArmed = false
  onMusicChanged: musicArmed = false
  Timer { running: senses.devices && !senses.devicesArmed; interval: 3000; onTriggered: senses.devicesArmed = true }
  Timer { running: senses.music && !senses.musicArmed; interval: 3000; onTriggered: senses.musicArmed = true }

  // ----------------------------------------------------------------- desktop
  // The focused window's own fullscreen flag: Hyprland's workspace
  // hasFullscreen is also true for a merely maximized window.
  readonly property bool fullscreen: desktop && !!ToplevelManager.activeToplevel && ToplevelManager.activeToplevel.fullscreen === true
  property var switches: []
  property var opens: []
  Connections {
    target: Hyprland
    enabled: senses.desktop
    // bounded: only the event's name is compared, against constants; its
    // data (window titles, workspace names) is never read or copied.
    function onRawEvent(event) {
      const name = event ? event.name : ""
      const now = Date.now()
      if (name === "workspacev2") {
        senses.switches = senses.burst(senses.switches, now, 30000)
        if (senses.switches.length >= 8) { senses.switches = []; senses.sensed("restless") }
      } else if (name === "openwindow") {
        senses.opens = senses.burst(senses.opens, now, 20000)
        if (senses.opens.length >= 6) { senses.opens = []; senses.sensed("overwhelmed") }
      }
    }
  }

  // ----------------------------------------------------------------- devices
  readonly property var sink: devices ? Pipewire.defaultAudioSink : null
  // A node's audio properties stay empty until something tracks it.
  PwObjectTracker { objects: senses.sink ? [senses.sink] : [] }
  readonly property bool sinkMuted: !!(sink && sink.audio && sink.audio.muted)
  readonly property real sinkVolume: sink && sink.audio ? (Number(sink.audio.volume) || 0) : 0
  property bool loudLatched: false
  onSinkMutedChanged: if (sinkMuted && devicesArmed) sensed("speakerMuted")
  onSinkVolumeChanged: {
    if (sinkVolume >= 1.0 && !loudLatched) { loudLatched = true; if (devicesArmed) sensed("loud") }
    else if (sinkVolume < 0.9) loudLatched = false
  }

  readonly property int connectivity: devices ? Networking.connectivity : NetworkConnectivity.Unknown
  property int lastConnectivity: NetworkConnectivity.Unknown
  onConnectivityChanged: {
    const was = lastConnectivity
    lastConnectivity = connectivity
    if (!devicesArmed) return
    // Only a real loss counts: "Limited" is often just NetworkManager's
    // connectivity check failing for a moment while the network works.
    if (was !== NetworkConnectivity.None && connectivity === NetworkConnectivity.None) sensed("offline")
    else if (was === NetworkConnectivity.None && connectivity === NetworkConnectivity.Full) sensed("online")
  }

  // Only how many are connected; names are never read.
  readonly property int btConnected: {
    if (!devices || !Bluetooth.devices) return 0
    const list = Bluetooth.devices.values
    let n = 0
    for (let i = 0; i < list.length && i < 64; i++) if (list[i] && list[i].connected) n++
    return n
  }
  property int lastBtConnected: 0
  onBtConnectedChanged: {
    const more = btConnected > lastBtConnected
    lastBtConnected = btConnected
    if (more && devicesArmed) sensed("bluetooth")
  }

  // ------------------------------------------------------------------- music
  readonly property var player: {
    if (!music || !Mpris.players) return null
    const list = Mpris.players.values
    for (let i = 0; i < list.length && i < 16; i++) if (list[i] && list[i].isPlaying) return list[i]
    return null
  }
  // bounded: the metadata lives in Quickshell's MPRIS model; these clipped
  // copies are all that reach the bubble or the Ollama context.
  readonly property string track: player ? String(player.trackTitle || "").slice(0, clipLength) : ""
  readonly property string artist: player ? String(player.trackArtist || "").slice(0, clipLength) : ""

  property string lastTrack: ""
  property int repeats: 0
  property double lastNoteAt: 0
  property double lastMusicLineAt: 0
  function noteTrack() {
    if (!track) return
    const now = Date.now()
    // A new track can arrive as both a track signal and a title change.
    if (track === lastTrack && now - lastNoteAt < 2000) return
    lastNoteAt = now
    repeats = track === lastTrack ? repeats + 1 : 1
    lastTrack = track
    if (!musicArmed) return
    if (repeats === 3) sensed("onRepeat")
    else if (repeats === 1 && now - lastMusicLineAt > 5 * 60 * 1000) { lastMusicLineAt = now; sensed("music") }
  }
  // Pausing and resuming blanks and restores the title; only a different
  // title counts here. Repeats come from the player's track signal below.
  onTrackChanged: if (track && track !== lastTrack) noteTrack()
  Connections {
    target: senses.player
    enabled: senses.music
    // The same song played again keeps its title, so the track signal is
    // what counts a repeat.
    function onPostTrackChanged() { senses.noteTrack() }
  }

  // ------------------------------------------------------------------- power
  Connections {
    target: UPower
    function onOnBatteryChanged() { senses.kick() }
  }
}
