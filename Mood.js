// The buddy's tiny brain. Pure functions from a sensor snapshot (see
// scripts/probe.sh) plus a few bits of local memory to a mood name, and from
// a mood name to how the face should look.
.pragma library

// Highest wins. Returns { mood, reason }.
function decide(s, mem) {
  if (!s) return { mood: "idle", reason: "no sensors yet" }
  var perCore = s.cores > 0 ? s.load / s.cores : 0
  var sinceCommitMin = s.lastCommit > 0 ? (s.now - s.lastCommit) / 60 : 1e9

  if (s.battery >= 0 && !s.charging && s.battery <= 10)
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
  if (s.hour < 8 || s.hour >= 23)
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

// Face parameters per mood. eye: 0..1 openness, smile: -1..1, brow: -1..1
// (positive = raised/surprised, negative = furrowed), tint: which theme colour
// the body leans towards, bob: idle bounce period in ms (0 = still).
function face(mood) {
  switch (mood) {
    case "sleepy":  return { eye: 0.35, smile: 0.1,  brow: -0.2, tint: "muted",  bob: 2600 }
    case "hyped":   return { eye: 1.0,  smile: 0.9,  brow: 0.6,  tint: "accent", bob: 700 }
    case "stretch": return { eye: 0.8,  smile: 0.0,  brow: 0.3,  tint: "muted",  bob: 1600 }
    case "worried": return { eye: 0.9,  smile: -0.5, brow: -0.6, tint: "urgent", bob: 1200 }
    case "proud":   return { eye: 0.6,  smile: 1.0,  brow: 0.4,  tint: "accent", bob: 500 }
    case "shipped": return { eye: 1.0,  smile: 1.0,  brow: 0.8,  tint: "accent", bob: 450 }
    case "sweaty":  return { eye: 0.7,  smile: -0.3, brow: -0.3, tint: "urgent", bob: 350 }
    case "panic":   return { eye: 1.0,  smile: -0.9, brow: 0.9,  tint: "urgent", bob: 250 }
    case "zen":     return { eye: 0.5,  smile: 0.4,  brow: 0.0,  tint: "muted",  bob: 3000 }
    case "poked":   return { eye: 1.0,  smile: -0.2, brow: 0.9,  tint: "accent", bob: 300 }
    case "meeting": return { eye: 1.0,  smile: 0.0,  brow: 0.8,  tint: "accent", bob: 400 }
    case "rationed":return { eye: 0.7,  smile: -0.4, brow: -0.4, tint: "urgent", bob: 1400 }
    case "cooking": return { eye: 0.6,  smile: 0.5,  brow: 0.1,  tint: "normal", bob: 2200 }
    case "agentDone":return { eye: 1.0, smile: 0.7,  brow: 0.7,  tint: "accent", bob: 500 }
    default:        return { eye: 0.9,  smile: 0.3,  brow: 0.0,  tint: "normal", bob: 1800 }
  }
}
