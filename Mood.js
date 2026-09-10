// The buddy's tiny brain. Pure functions from a sensor snapshot (see
// scripts/probe.sh) plus a few bits of local memory to a mood name, and from
// a mood name to a face.
.pragma library

// Highest wins. Returns { mood, reason }.
function decide(s, mem) {
  if (!s) return { mood: "idle", reason: "no sensors yet" }
  var perCore = s.cores > 0 ? s.load / s.cores : 0
  var sinceCommitMin = s.lastCommit > 0 ? (s.now - s.lastCommit) / 60 : 1e9

  if (s.battery >= 0 && !s.charging && s.battery < 15)
    return { mood: "panic", reason: "battery " + s.battery + "%" }
  if (s.calendar && s.calendar.has && s.calendar.eta <= 10 && s.calendar.eta > -5)
    return { mood: "meeting", reason: s.calendar.title + " in " + s.calendar.eta + " min" }
  if (perCore > 0.9)
    return { mood: "sweaty", reason: "load " + s.load.toFixed(1) }
  var tight = tightestAgent(s)
  if (tight && tight.limit >= 0.9)
    return { mood: "rationed", reason: tight.name + " at " + Math.round(tight.limit * 100) + "%" }
  if (s.agentBusy > 0)
    return { mood: "cooking", reason: s.agentBusy + " agent(s) working" }
  if (s.inRepo && (s.dirty > 400 || (s.dirty > 40 && sinceCommitMin > 180)))
    return { mood: "worried", reason: s.dirty + " dirty lines" }
  if (mem.streakMin >= 90)
    return { mood: "stretch", reason: Math.round(mem.streakMin) + " min streak" }
  if (s.hour < 8 || s.hour >= 23 || (s.hour >= 20 && mem.ignoredMin >= 20))
    return { mood: "sleepy", reason: "hour " + s.hour }
  if (s.hour >= 20)
    return { mood: "zen", reason: "evening" }
  if (s.hour >= 13 && s.hour < 15)
    return { mood: "hyped", reason: "afternoon" }
  return { mood: "idle", reason: "nothing special" }
}

function tightestAgent(s) {
  if (!s || !Array.isArray(s.agents) || s.agents.length === 0) return null
  var best = null
  for (var i = 0; i < s.agents.length; i++)
    if (!best || s.agents[i].limit > best.limit) best = s.agents[i]
  return best
}

function busiestAgent(s) {
  if (!s || !Array.isArray(s.agents) || s.agents.length === 0) return null
  var best = null
  for (var i = 0; i < s.agents.length; i++)
    if (!best || s.agents[i].prompts > best.prompts) best = s.agents[i]
  return best
}

// One-shot events worth interrupting for, from a previous snapshot to a new one.
function events(prev, next) {
  var out = []
  if (!prev || !next) return out
  if (next.inRepo) {
    var sameRepo = prev.inRepo && prev.repo === next.repo
    if (sameRepo && next.lastCommit > prev.lastCommit) out.push("proud")
    if (sameRepo && prev.ahead > 0 && next.ahead === 0 && next.lastCommit === prev.lastCommit) out.push("shipped")
  }
  // An agent went from working to waiting: it wants you back.
  if (prev.agentBusy > 0 && next.agentBusy < prev.agentBusy && next.agentWindows > 0) out.push("agentDone")
  return out
}

// Face per mood, straight from the design canvas. `role` names a theme
// colour: accent, red, yellow, green, cyan, muted. `bob` is the idle bounce
// period in ms (0 = still).
function face(mood) {
  switch (mood) {
    case "worried":   return { eyes: "◉    ◉", mouth: "▂▂", extra: "",   role: "red",    bob: 1400 }
    case "meeting":   return { eyes: "◉    ◦", mouth: "○ ", extra: "",   role: "yellow", bob: 500 }
    case "proud":
    case "shipped":   return { eyes: "◠    ◠", mouth: "▽ ", extra: "",   role: "green",  bob: 500 }
    case "cooking":   return { eyes: "◦    ◉", mouth: "~ ", extra: " …", role: "cyan",   bob: 2200 }
    case "grabbed":   return { eyes: "◉    ◉", mouth: "▂▂", extra: " !", role: "red",    bob: 0 }
    case "poked":     return { eyes: ">    <", mouth: "▂▂", extra: " !", role: "yellow", bob: 300 }
    case "dropped":   return { eyes: "–    –", mouth: "‿‿", extra: "",   role: "green",  bob: 1200 }
    case "sleepy":
    case "zen":       return { eyes: "–    –", mouth: "‿ ", extra: " ᶻ", role: "muted",  bob: 3000 }
    case "panic":     return { eyes: "◉    ◉", mouth: "▂▂", extra: " ▪", role: "red",    bob: 250 }
    case "hyped":     return { eyes: "◠    ◠", mouth: "▽ ", extra: " !", role: "yellow", bob: 600 }
    case "stretch":   return { eyes: "–    –", mouth: "▁▁", extra: "",   role: "yellow", bob: 1600 }
    case "sweaty":    return { eyes: "◉    ◉", mouth: "~ ", extra: " ▪", role: "red",    bob: 350 }
    case "rationed":  return { eyes: "◉    ◦", mouth: "▂▂", extra: "",   role: "red",    bob: 1400 }
    case "agentDone": return { eyes: "◉    ◉", mouth: "▽ ", extra: " !", role: "cyan",   bob: 500 }
    case "greeting":  return { eyes: "◠    ◠", mouth: "▁▁", extra: "",   role: "accent", bob: 900 }
    default:          return { eyes: "◉    ◉", mouth: "▁▁", extra: "",   role: "accent", bob: 1800 }
  }
}
