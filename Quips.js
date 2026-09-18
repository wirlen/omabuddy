// What the buddy says, by mood and tone. Two voices: `snarky` (default) and
// `polite`. Keep lines short (one line, under ~90 chars), lowercase like the
// design, and in the voice of a small creature who lives in a screen corner.
// Tokens: {repo} {branch} {dirty} {hour} {streak} {battery} {event} {eta}
// {agent} {prompts} {limit} {windows} {untracked} {subject} {fixes} {commits}
// {pushes} {days} {time}.
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
  },
  welcomeBack: {
    snarky: [
      "oh, you're back. i didn't move. i never move.",
      "welcome back. nothing happened. i checked.",
      "you left. i counted the pixels. all still here."
    ],
    polite: ["welcome back.", "hi again. fresh start on the streak."]
  },
  overwhelmed: {
    snarky: [
      "{windows} windows. this is a cry for help.",
      "{windows} windows open. i can't see the wallpaper anymore.",
      "close one. any one. as a treat."
    ],
    polite: ["{windows} windows open — a quick tidy might help.", "that's a lot of windows. want to close a few?"]
  },
  cluttered: {
    snarky: [
      "{untracked} untracked files. are these... yours?",
      "{untracked} files git has never heard of. a .gitignore would love to meet them.",
      "your repo has a junk drawer. it has {untracked} things in it."
    ],
    polite: ["{untracked} untracked files in {repo} — add or ignore them?", "a few strays in the working tree."]
  },
  daring: {
    snarky: [
      "editing straight on {branch}. living dangerously.",
      "{dirty} lines on {branch}, no branch, no net. respect. also, fear.",
      "git checkout -b costs nothing. just saying."
    ],
    polite: ["you're working directly on {branch} — a feature branch might be safer.", "uncommitted changes on {branch}. careful."]
  },
  grumpy: {
    snarky: [
      "okay. that's enough. i'm not talking to you for a bit.",
      "five pokes. FIVE. i have a face, not a button.",
      "i'm going to stare at the wall now. don't follow."
    ],
    polite: ["that's a lot of poking. i need a minute.", "i'll be quiet for a bit."]
  },
  ignoring: { snarky: [""], polite: [""] },
  fixStreak: {
    snarky: [
      "{fixes} fixes in a row. is the bug winning?",
      "fix. fix. fix. fix. fix. that's a poem now.",
      "the {fixes}th fix. bold of you to keep numbering them."
    ],
    polite: ["{fixes} fix commits in a row — maybe step back for a minute?", "another fix. you'll get it."]
  },
  wipCommit: {
    snarky: [
      "\"wip\". a commit message and a confession.",
      "wip. the history will thank you. it won't.",
      "committed \"wip\". future you is already annoyed."
    ],
    polite: ["a wip commit — remember to squash it later.", "saved. you can tidy the message later."]
  },
  longSubject: {
    snarky: [
      "that subject line has a subject line.",
      "a paragraph for a subject. the body is right there, you know.",
      "seventy-two characters is a suggestion. you took it as a dare."
    ],
    polite: ["long subject — the details can go in the body.", "committed. a shorter subject reads nicer in the log."]
  },
  emojiCommit: {
    snarky: [
      "{subject}. very expressive. means nothing.",
      "an emoji commit. git blame is going to be fun.",
      "i am made of block characters and even i want words."
    ],
    polite: ["committed with {subject} — a word or two would help later.", "nice emoji. maybe a word too?"]
  },
  lateShip: {
    snarky: [
      "pushing at {time}? bold.",
      "a {time} push. nothing has ever gone wrong at this hour.",
      "shipped at {time}. sleep now. ci can panic without you."
    ],
    polite: ["pushed at {time}. good night.", "late push, done. rest."]
  },
  plugged: {
    snarky: ["nom nom nom.", "ah. electrons. finally.", "plugged in. the dramatic phase is over."],
    polite: ["charging. thank you.", "plugged in."]
  },
  full: {
    snarky: ["100%. i'm full. unplug me before i get smug.", "topped up. i could run a marathon. i won't.", "battery full. peak me."],
    polite: ["battery is full.", "fully charged."]
  },
  unplugged: {
    snarky: ["...you unplugged me. okay. it's fine. {battery}%. fine.", "on battery now. i'm not nervous. you're nervous.", "free-range mode. {battery}%."],
    polite: ["running on battery, {battery}%.", "unplugged. keep an eye on the battery."]
  },
  monday: {
    snarky: ["monday. we don't have to talk about it.", "it's monday. coffee is a load-bearing wall.", "monday morning. start with something you can't break."],
    polite: ["happy monday. ease in.", "monday morning. small steps first."]
  },
  friday: {
    snarky: ["friday after four. don't you dare deploy.", "it's friday. the weekend is a merge away.", "friday afternoon: read-only mode, please."],
    polite: ["friday afternoon. wrap up gently.", "nearly the weekend. nice work."]
  },
  birthday: {
    snarky: ["it's my birthday. {days} days in this corner. no cake, i notice.", "one year older, same corner. a hat is the least you could do.", "happy birthday to me. i'd blow out a candle but i'm text."],
    polite: ["it's my birthday! {days} days with you.", "a year in the corner. thanks for having me."]
  },
  firstPush: {
    snarky: ["first push of the day. the remote missed you.", "one push down. confetti is mandatory.", "shipped something before {hour}:00. who are you?"],
    polite: ["first push of the day. lovely.", "shipped! nice start."]
  },
  tenCommits: {
    snarky: ["{commits} commits today. the log is a novel now.", "ten commits. history will remember. or squash.", "double digits. i'm making confetti out of your diff."],
    polite: ["{commits} commits today — great pace.", "ten commits. excellent."]
  },
  calmWeek: {
    snarky: ["a whole week without a battery panic. i'm oddly proud.", "seven calm days. suspicious. impressive. both.", "one week, zero meltdowns. from either of us."],
    polite: ["a calm week — no low-battery scares.", "seven days without a panic. well done."]
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
