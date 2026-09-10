// What the buddy says, by mood and tone. Two voices: `snarky` (default) and
// `polite`. Keep lines short (one line, under ~90 chars), lowercase like the
// design, and in the voice of a small creature who lives in a screen corner.
// Tokens: {repo} {branch} {dirty} {hour} {streak} {battery} {event} {eta}
// {agent} {prompts} {limit} {windows}.
.pragma library

var lines = {
  idle: {
    snarky: [
      "{windows} terminals. you use two.",
      "just standing here. professionally.",
      "no notifications. suspicious.",
      "i am 100% text. no pixels were harmed.",
      "tabs or spaces? don't. i like both of us too much."
    ],
    polite: [
      "you have {windows} windows open — want to tidy up?",
      "all quiet. nice.",
      "i'll be in the corner if you need me."
    ]
  },
  worried: {
    snarky: [
      "{dirty} changed lines and no commit. i'm not saying anything. i'm just standing here.",
      "that diff is getting ambitious.",
      "i would feel safer if {branch} had a checkpoint.",
      "not judging. okay, a little judging. commit?"
    ],
    polite: [
      "{dirty} uncommitted lines on {branch} — maybe a checkpoint?",
      "a commit now would be a nice safety net."
    ]
  },
  meeting: {
    snarky: [
      "{event} in {eta}. yes, camera on. i read the invite.",
      "{event}, t-minus {eta}. hair check.",
      "wrap the thought. {event} is about to happen."
    ],
    polite: [
      "{event} in {eta} minutes, camera expected.",
      "heads up: {event} starts in {eta} minutes."
    ]
  },
  proud: {
    snarky: [
      "committed. i had nothing to do with it and i'm still taking credit.",
      "another one for the history books. literally.",
      "that commit message was... fine. the code is great though."
    ],
    polite: [
      "committed. nicely done.",
      "clean tree, clean mind."
    ]
  },
  shipped: {
    snarky: [
      "pushed. it's someone else's problem now.",
      "and it's off. ci is about to have feelings about that.",
      "green. all of it. i had nothing to do with it and i'm still taking credit."
    ],
    polite: [
      "pushed. the remote thanks you.",
      "shipped. good work."
    ]
  },
  cooking: {
    snarky: [
      "your agent's on it. you could also just… wait. like i do.",
      "don't open the oven.",
      "somewhere, an agent is reading your whole repo again.",
      "{prompts} prompts today. the agent needs a union."
    ],
    polite: [
      "your agent is working on it.",
      "let it think. stretch your hands."
    ]
  },
  agentDone: {
    snarky: [
      "it stopped spinning. your move.",
      "agent's done. go check the damage.",
      "review time. trust, but diff."
    ],
    polite: [
      "your agent is waiting for you.",
      "the agent finished. time to review."
    ]
  },
  rationed: {
    snarky: [
      "{agent} is at {limit}% of its limit. easy on the tokens, chief.",
      "you have been very chatty with {agent} today. {prompts} prompts.",
      "{agent} is nearly rationed. maybe write this one yourself?"
    ],
    polite: [
      "{agent} is at {limit}% of its limit.",
      "{prompts} prompts with {agent} today — the limit is close."
    ]
  },
  grabbed: {
    snarky: ["hands. HANDS.", "put me down.", "i had a spot. i liked my spot."],
    polite: ["moving, okay.", "where to?"]
  },
  dropped: {
    snarky: [
      "oh, sure. next to the red build. lovely.",
      "fine. here works. i guess.",
      "cozy. in a corner sort of way."
    ],
    polite: ["fine, here works.", "okay, settling in."]
  },
  poked: {
    snarky: [
      "that's my face. do it again, see what happens.",
      "ow. rude.",
      "poke me again and i'll rebase your main branch."
    ],
    polite: ["ow.", "yes? i'm here."]
  },
  sleepy: {
    snarky: [
      "it's {hour}:00. i'm going to sleep. you should think about it.",
      "the bugs are asleep. take the hint.",
      "coffee first, semicolons later."
    ],
    polite: [
      "it's late — heading to sleep.",
      "early start. let's begin with something easy."
    ]
  },
  zen: {
    snarky: ["evening. whatever's left can wait.", "close the laptop, open the sky."],
    polite: ["good work today. i mean it.", "wrap up gently."]
  },
  panic: {
    snarky: [
      "{battery}%. i can feel myself dimming. dramatic? yes. wrong? no.",
      "{battery}% and unplugged. i'm too young to hibernate.",
      "this is not a drill. charger. now."
    ],
    polite: ["{battery}% battery — plug in soon.", "battery is low. a cable would help."]
  },
  hyped: {
    snarky: ["post-lunch energy. ship it.", "golden hour. do the hard thing now.", "i believe in {branch}. mostly."],
    polite: ["good time for the hard task.", "you've got this."]
  },
  stretch: {
    snarky: [
      "{streak} minutes straight. legs still work?",
      "your spine called. it wants a word.",
      "even compilers take breaks. well, no. but you should."
    ],
    polite: ["{streak} minutes without a break — stand up for a bit?", "hydration check."]
  },
  sweaty: {
    snarky: [
      "is it hot in here or is that your cpu?",
      "i can hear the fans from here.",
      "compiling? or did you leave a while(true) somewhere?"
    ],
    polite: ["the cpu is working hard.", "something is using all the cores."]
  },
  greeting: {
    snarky: ["hi. i live here now.", "reporting for duty. duty being: standing here.", "oh, hello. i'll be in the corner."],
    polite: ["hello! i'll be in the corner.", "morning. or whatever this is."]
  }
}

function pick(mood, ctx, tone) {
  var entry = lines[mood] || lines.idle
  var voice = tone === "polite" ? "polite" : "snarky"
  var pool = entry[voice] && entry[voice].length ? entry[voice] : entry.snarky
  var line = pool[Math.floor(Math.random() * pool.length)]
  return fill(line, ctx || {})
}

function fill(line, ctx) {
  return String(line).replace(/\{(\w+)\}/g, function(_, key) {
    var v = ctx[key]
    if (v === undefined || v === null || v === "") return key === "branch" ? "this branch" : key === "repo" ? "this repo" : "?"
    return String(v)
  })
}
