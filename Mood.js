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
  if (s.windows >= 20)
    return { mood: "overwhelmed", reason: s.windows + " windows" }
  if (s.inRepo && s.untracked >= 40)
    return { mood: "cluttered", reason: s.untracked + " untracked files" }
  if (s.inRepo && s.dirty >= 20 && isMainBranch(s.branch))
    return { mood: "daring", reason: "dirty on " + s.branch }
  if (mem.streakMin >= 90)
    return { mood: "stretch", reason: Math.round(mem.streakMin) + " min streak" }
  if (s.hour < 8 || s.hour >= 23 || (s.hour >= 20 && mem.ignoredMin >= 20))
    return { mood: "sleepy", reason: "hour " + s.hour }
  if (s.hour >= 20)
    return { mood: "zen", reason: "evening" }
  if (s.dow === 1 && s.hour < 11)
    return { mood: "monday", reason: "monday morning" }
  if (s.dow === 5 && s.hour >= 16)
    return { mood: "friday", reason: "friday afternoon" }
  if (s.hour >= 13 && s.hour < 15)
    return { mood: "hyped", reason: "afternoon" }
  return { mood: "idle", reason: "nothing special" }
}

function isMainBranch(b) { return b === "main" || b === "master" || b === "trunk" }

// What a commit subject says about its author. Returns a mood name or "".
function judgeSubject(subject, fixStreak) {
  var s = String(subject || "").trim()
  if (fixStreak >= 5) return "fixStreak"
  if (/^wip[\s!.:]*$/i.test(s)) return "wipCommit"
  if (s.length > 72) return "longSubject"
  var bare = s.replace(/[\s\uFE0F\u200D]/g, "")
  // No letters or digits, and at least one symbol from the emoji ranges
  // (Misc Symbols, Dingbats, or a surrogate pair from the SMP).
  if (bare && !/[A-Za-z0-9]/.test(bare) && /[\u2600-\u27BF\uD83C-\uD83E]/.test(bare)) return "emojiCommit"
  return ""
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
  // The clock jumped: the machine slept or you walked off. Everything else
  // that "changed" in between is stale, so the greeting is the only event.
  if (next.now - prev.now > 30 * 60) return ["welcomeBack"]
  if (next.inRepo) {
    var sameRepo = prev.inRepo && prev.repo === next.repo
    if (sameRepo && next.lastCommit > prev.lastCommit)
      out.push(judgeSubject(next.subject, next.fixStreak) || "proud")
    if (sameRepo && prev.ahead > 0 && next.ahead === 0 && next.lastCommit === prev.lastCommit)
      out.push(next.hour >= 23 || next.hour < 5 ? "lateShip" : "shipped")
  }
  // An agent went from working to waiting: it wants you back.
  if (prev.agentBusy > 0 && next.agentBusy < prev.agentBusy && next.agentWindows > 0) out.push("agentDone")
  // Power: the cable is the buddy's dinner.
  if (next.battery >= 0 && prev.battery >= 0) {
    if (!prev.charging && next.charging) out.push("plugged")
    if (prev.charging && !next.charging) out.push("unplugged")
    if (next.charging && prev.battery < 100 && next.battery >= 100) out.push("full")
  }
  return out
}

// Costume for the day: a hat line drawn above the head, or "" for none.
// `installedOn` is the YYYY-MM-DD the plugin first ran, for its birthday.
function costume(date, installedOn) {
  var d = date || new Date()
  var m = d.getMonth() + 1, day = d.getDate()
  if (m === 10 && day === 31) return { hat: "     ▟███▙", name: "halloween" }
  if (m === 1 && day === 1) return { hat: "    ✦  ✦  ✦", name: "newyear" }
  var b = /^(\d{4})-(\d{2})-(\d{2})$/.exec(String(installedOn || ""))
  if (b && Number(b[2]) === m && Number(b[3]) === day && Number(b[1]) < d.getFullYear())
    return { hat: "      ◢█◣", name: "birthday" }
  return { hat: "", name: "" }
}

// Achievements: pure bookkeeping over the counters the panel keeps in its
// shell.json entry. `stats` is { day, commits, pushes, lastPanic, calmSince,
// calmAwarded }. Returns { stats, awards } where awards is a list of mood
// names to celebrate. `today` is a YYYY-MM-DD string.
function tally(stats, event, mood, today) {
  var st = {}
  var src = stats && typeof stats === "object" ? stats : {}
  for (var k in src) st[k] = src[k]
  var awards = []
  if (st.day !== today) { st.day = today; st.commits = 0; st.pushes = 0 }
  if (!st.calmSince) st.calmSince = today
  if (event === "proud" || event === "fixStreak" || event === "wipCommit" || event === "longSubject" || event === "emojiCommit") {
    st.commits = (st.commits | 0) + 1
    if (st.commits === 10) awards.push("tenCommits")
  }
  if (event === "shipped" || event === "lateShip") {
    st.pushes = (st.pushes | 0) + 1
    if (st.pushes === 1) awards.push("firstPush")
  }
  if (mood === "panic") { st.lastPanic = today; st.calmSince = today }
  var calmDays = daysBetween(st.calmSince, today)
  if (calmDays >= 7 && st.calmAwarded !== today) { st.calmAwarded = today; st.calmSince = today; awards.push("calmWeek") }
  return { stats: st, awards: awards }
}

function daysBetween(a, b) {
  var pa = /^(\d{4})-(\d{2})-(\d{2})$/.exec(String(a || "")), pb = /^(\d{4})-(\d{2})-(\d{2})$/.exec(String(b || ""))
  if (!pa || !pb) return 0
  var ta = Date.UTC(+pa[1], +pa[2] - 1, +pa[3]), tb = Date.UTC(+pb[1], +pb[2] - 1, +pb[3])
  return Math.floor((tb - ta) / 86400000)
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
    case "greeting":
    case "welcomeBack": return { eyes: "◠    ◠", mouth: "▁▁", extra: "",   role: "accent", bob: 900 }
    case "overwhelmed": return { eyes: "◉    ◉", mouth: "○ ", extra: " ▪▪", role: "yellow", bob: 400 }
    case "cluttered": return { eyes: "◉    ◦", mouth: "~ ", extra: " ?", role: "yellow", bob: 1400 }
    case "daring":    return { eyes: "◉    ◉", mouth: "▁▁", extra: " ▪", role: "yellow", bob: 1000 }
    case "grumpy":    return { eyes: "▀    ▀", mouth: "▂▂", extra: "",   role: "muted",  bob: 0 }
    case "ignoring":  return { eyes: "◦    ◦", mouth: "▁▁", extra: " …", role: "muted",  bob: 0 }
    case "fixStreak":
    case "wipCommit":
    case "longSubject":
    case "emojiCommit": return { eyes: "◉    ▀", mouth: "▂▂", extra: "",   role: "yellow", bob: 1400 }
    case "lateShip":  return { eyes: "◉    ◉", mouth: "▽ ", extra: " ᶻ", role: "green",  bob: 500 }
    case "plugged":   return { eyes: "◠    ◠", mouth: "○ ", extra: "",   role: "green",  bob: 500 }
    case "full":      return { eyes: "◠    ◠", mouth: "‿‿", extra: "",   role: "green",  bob: 1600 }
    case "unplugged": return { eyes: "◉    ◦", mouth: "▂▂", extra: "",   role: "yellow", bob: 900 }
    case "monday":    return { eyes: "–    –", mouth: "▂▂", extra: "",   role: "muted",  bob: 2400 }
    case "friday":    return { eyes: "◠    ◠", mouth: "▽ ", extra: "",   role: "cyan",   bob: 700 }
    case "birthday":
    case "firstPush":
    case "tenCommits":
    case "calmWeek":  return { eyes: "◠    ◠", mouth: "▽ ", extra: " ✦", role: "accent", bob: 400 }
    default:          return { eyes: "◉    ◉", mouth: "▁▁", extra: "",   role: "accent", bob: 1800 }
  }
}
