// What the buddy says, by mood and tone. Four voices: `snarky` (default),
// `polite`, `cheerful` and `deadpan`; a voice missing a mood borrows snarky's
// lines. Keep lines short (one line, under ~90 characters), lowercase like the
// design, and in the voice of a small creature who lives in a screen corner.
// Below the tones, `flavor` holds a few lines per critter (see Buddies.js)
// that it says in any voice, now and then, instead of the tone's line.
// Tokens: {repo} {branch} {dirty} {hour} {streak} {battery} {event} {eta}
// {agent} {prompts} {limit} {windows} {untracked} {subject} {fixes} {commits}
// {pushes} {days} {time}.
.pragma library

// The voices, in the order the settings card shows them. `persona` is what
// Ollama is told when it improvises in that voice.
var tones = [
  { id: "snarky",   name: "snarky",   blurb: "dry jokes at your expense, with love.",  persona: "dry, teasing and a little smug, but fond of the user" },
  { id: "polite",   name: "polite",   blurb: "gentle nudges. no sass.",                persona: "gentle, kind and encouraging, never sarcastic" },
  { id: "cheerful", name: "cheerful", blurb: "your biggest fan. many exclamation marks!", persona: "relentlessly upbeat, the user's biggest fan" },
  { id: "deadpan",  name: "deadpan",  blurb: "flat, brief, quietly devastating.",      persona: "flat, terse and bone-dry, like a tired museum guard" }
]

function tone(id) {
  for (var i = 0; i < tones.length; i++) if (tones[i].id === id) return tones[i]
  return tones[0]
}

function toneIds() {
  var out = []
  for (var i = 0; i < tones.length; i++) out.push(tones[i].id)
  return out
}

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
    ],
    cheerful: [
      "{windows} windows open and you're handling all of them. legend.",
      "just here, cheering quietly. go you!",
      "nothing's on fire. best day ever!"
    ],
    deadpan: [
      "i am standing. this is the job.",
      "{windows} windows. noted.",
      "nothing is happening. i'm monitoring it."
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
    ],
    cheerful: [
      "{dirty} lines of progress! let's tuck them into a commit!",
      "big diff energy! a checkpoint would make it even better.",
      "you've done so much on {branch}! save it?"
    ],
    deadpan: [
      "{dirty} uncommitted lines. this is fine. it is not fine.",
      "the diff grows. the commit does not.",
      "a commit would be a reasonable act."
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
    ],
    cheerful: [
      "{event} in {eta} minutes! you're going to be great.",
      "{event} soon! quick stretch, then dazzle."
    ],
    deadpan: [
      "{event}. {eta} minutes. brace.",
      "a meeting approaches. it could have been an email.",
      "{event} in {eta}. i'll hold your terminal."
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
    ],
    cheerful: [
      "committed!! look at you go!",
      "another commit! the history is better with you in it.",
      "yay, a commit! i did a little hop."
    ],
    deadpan: [
      "commit recorded.",
      "a commit. the log grows by one.",
      "that's in the history now. forever."
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
    ],
    cheerful: [
      "pushed! the whole internet gets your code now!",
      "shipped! that's a high five. imagine i have hands.",
      "off it goes! so proud of you."
    ],
    deadpan: [
      "pushed. it lives on a server now.",
      "shipped. ci's turn to worry.",
      "the bits have left the building."
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
    ],
    cheerful: [
      "the agent's cooking! smells like a feature.",
      "teamwork! you think, it types, i cheer.",
      "{prompts} prompts today. what a collaboration!"
    ],
    deadpan: [
      "the agent is thinking. allegedly.",
      "spinner detected. i will wait. i'm good at it.",
      "{prompts} prompts. the agent remembers none of them."
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
    ],
    cheerful: [
      "your agent's done! let's see what it made!",
      "ding! review time. you'll catch anything it missed."
    ],
    deadpan: [
      "the agent stopped. it awaits judgment.",
      "done. read the diff. all of it."
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
    ],
    cheerful: [
      "{agent} is at {limit}%! you've been so productive today.",
      "{prompts} prompts with {agent}! maybe save a few for later?"
    ],
    deadpan: [
      "{agent}: {limit}%. the tokens are finite.",
      "{prompts} prompts. {agent} is tired. metaphorically."
    ]
  },
  grabbed: {
    snarky: [
      "hands. HANDS.",
      "put me down.",
      "i had a spot. i liked my spot."
    ],
    polite: [
      "moving, okay.",
      "where to?"
    ],
    cheerful: [
      "wheee!",
      "adventure time!",
      "ooh, where are we going?"
    ],
    deadpan: [
      "i am being moved.",
      "this is happening, then.",
      "unhand me. or don't. okay."
    ]
  },
  dropped: {
    snarky: [
      "oh, sure. next to the red build. lovely.",
      "fine. here works. i guess.",
      "cozy. in a corner sort of way."
    ],
    polite: [
      "fine, here works.",
      "okay, settling in."
    ],
    cheerful: [
      "new spot! i love it here!",
      "what a view!",
      "perfect landing!"
    ],
    deadpan: [
      "corner acquired.",
      "this corner is identical to the last one.",
      "i live here now. again."
    ]
  },
  poked: {
    snarky: [
      "that's my face. do it again, see what happens.",
      "ow. rude.",
      "poke me again and i'll rebase your main branch."
    ],
    polite: [
      "ow.",
      "yes? i'm here."
    ],
    cheerful: [
      "hi!! hello!",
      "boop! right back at you.",
      "you rang? i'm here!"
    ],
    deadpan: [
      "poke registered.",
      "that was my face.",
      "yes. hello. that's me."
    ]
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
    ],
    cheerful: [
      "it's {hour}:00! bed is a great feature. try it!",
      "early bird! let's start with something fun.",
      "rest up, champ. tomorrow you'll be even better."
    ],
    deadpan: [
      "it's {hour}:00. the bugs are also asleep. join them.",
      "the screen is bright. the hour is not.",
      "sleep is free. take some."
    ]
  },
  zen: {
    snarky: [
      "evening. whatever's left can wait.",
      "close the laptop, open the sky."
    ],
    polite: [
      "good work today. i mean it.",
      "wrap up gently."
    ],
    cheerful: [
      "evening already! you did so much today.",
      "golden evening. be proud of today!"
    ],
    deadpan: [
      "evening. the code will be there tomorrow. it always is.",
      "dusk. close something."
    ]
  },
  panic: {
    snarky: [
      "{battery}%. i can feel myself dimming. dramatic? yes. wrong? no.",
      "{battery}% and unplugged. i'm too young to hibernate.",
      "this is not a drill. charger. now."
    ],
    polite: [
      "{battery}% battery — plug in soon.",
      "battery is low. a cable would help."
    ],
    cheerful: [
      "{battery}%! quick, a charger adventure!",
      "battery's low, but we believe in you. and in cables!"
    ],
    deadpan: [
      "{battery}%. i am fading. this is my final quip. probably.",
      "low battery. the end is near. the charger is nearer."
    ]
  },
  hyped: {
    snarky: [
      "post-lunch energy. ship it.",
      "golden hour. do the hard thing now.",
      "i believe in {branch}. mostly."
    ],
    polite: [
      "good time for the hard task.",
      "you've got this."
    ],
    cheerful: [
      "afternoon power-up! you can do anything!",
      "this is your moment. go go go!",
      "i believe in {branch} so much!"
    ],
    deadpan: [
      "afternoon. peak capability. allegedly.",
      "now is when the hard thing gets done. or doesn't."
    ]
  },
  stretch: {
    snarky: [
      "{streak} minutes straight. legs still work?",
      "your spine called. it wants a word.",
      "even compilers take breaks. well, no. but you should."
    ],
    polite: [
      "{streak} minutes without a break — stand up for a bit?",
      "hydration check."
    ],
    cheerful: [
      "{streak} minutes of focus! amazing! stretch break?",
      "your back has been so patient. reward it!",
      "water break! you've earned it."
    ],
    deadpan: [
      "{streak} minutes seated. legs are optional, it seems.",
      "stand up. i would, if i had knees."
    ]
  },
  sweaty: {
    snarky: [
      "is it hot in here or is that your cpu?",
      "i can hear the fans from here.",
      "compiling? or did you leave a while(true) somewhere?"
    ],
    polite: [
      "the cpu is working hard.",
      "something is using all the cores."
    ],
    cheerful: [
      "your cpu is working out! so strong!",
      "all cores engaged! something big is happening!"
    ],
    deadpan: [
      "the cpu is hot. i am also hot. we are all hot.",
      "fans at full volume. a concert for nobody."
    ]
  },
  greeting: {
    snarky: [
      "hi. i live here now.",
      "reporting for duty. duty being: standing here.",
      "oh, hello. i'll be in the corner."
    ],
    polite: [
      "hello! i'll be in the corner.",
      "morning. or whatever this is."
    ],
    cheerful: [
      "hi hi hi! i'm so glad you're here!",
      "hello, friend! let's have a great day!",
      "i'm back! did you miss me? i missed you."
    ],
    deadpan: [
      "hello. i exist again.",
      "online. corner secured.",
      "it's me. the buddy. again."
    ]
  },
  welcomeBack: {
    snarky: [
      "oh, you're back. i didn't move. i never move.",
      "welcome back. nothing happened. i checked.",
      "you left. i counted the pixels. all still here."
    ],
    polite: [
      "welcome back.",
      "hi again. fresh start on the streak."
    ],
    cheerful: [
      "you're back!! i kept your spot warm!",
      "welcome back! fresh streak, fresh start!"
    ],
    deadpan: [
      "you left. you returned. the cycle continues.",
      "welcome back. nothing changed. i checked twice."
    ]
  },
  overwhelmed: {
    snarky: [
      "{windows} windows. this is a cry for help.",
      "{windows} windows open. i can't see the wallpaper anymore.",
      "close one. any one. as a treat."
    ],
    polite: [
      "{windows} windows open — a quick tidy might help.",
      "that's a lot of windows. want to close a few?"
    ],
    cheerful: [
      "{windows} windows! multitasking wizard! maybe close a few?",
      "so many windows! let's give a few a happy ending."
    ],
    deadpan: [
      "{windows} windows. one of them is the one you want. probably.",
      "{windows} windows. the wallpaper is a rumor now."
    ]
  },
  cluttered: {
    snarky: [
      "{untracked} untracked files. are these... yours?",
      "{untracked} files git has never heard of. a .gitignore would love to meet them.",
      "your repo has a junk drawer. it has {untracked} things in it."
    ],
    polite: [
      "{untracked} untracked files in {repo} — add or ignore them?",
      "a few strays in the working tree."
    ],
    cheerful: [
      "{untracked} new files! so creative! let's give them a home.",
      "lots of fresh files! a .gitignore could help them settle in."
    ],
    deadpan: [
      "{untracked} untracked files. git does not know them. neither do i.",
      "the working tree has a junk drawer. it's full."
    ]
  },
  daring: {
    snarky: [
      "editing straight on {branch}. living dangerously.",
      "{dirty} lines on {branch}, no branch, no net. respect. also, fear.",
      "git checkout -b costs nothing. just saying."
    ],
    polite: [
      "you're working directly on {branch} — a feature branch might be safer.",
      "uncommitted changes on {branch}. careful."
    ],
    cheerful: [
      "straight on {branch}! brave! a branch would be even braver.",
      "bold moves on {branch}! want a safety branch?"
    ],
    deadpan: [
      "{dirty} lines on {branch}. no branch. no net.",
      "editing {branch} directly. a choice."
    ]
  },
  grumpy: {
    snarky: [
      "okay. that's enough. i'm not talking to you for a bit.",
      "five pokes. FIVE. i have a face, not a button.",
      "i'm going to stare at the wall now. don't follow."
    ],
    polite: [
      "that's a lot of poking. i need a minute.",
      "i'll be quiet for a bit."
    ],
    cheerful: [
      "okay, that's a lot of boops! i need a tiny break.",
      "too many pokes! recharging my patience. brb!"
    ],
    deadpan: [
      "five pokes. i'm done. for 45 seconds.",
      "i am closed for business."
    ]
  },
  ignoring: { snarky: [""], polite: [""], cheerful: [""], deadpan: [""] },
  fixStreak: {
    snarky: [
      "{fixes} fixes in a row. is the bug winning?",
      "fix. fix. fix. fix. fix. that's a poem now.",
      "the {fixes}th fix. bold of you to keep numbering them."
    ],
    polite: [
      "{fixes} fix commits in a row — maybe step back for a minute?",
      "another fix. you'll get it."
    ],
    cheerful: [
      "{fixes} fixes in a row! you're so close, i can feel it!",
      "fix number {fixes}! persistence looks great on you."
    ],
    deadpan: [
      "fix. again. {fixes} times.",
      "{fixes} fixes. the bug is winning on points."
    ]
  },
  wipCommit: {
    snarky: [
      "\"wip\". a commit message and a confession.",
      "wip. the history will thank you. it won't.",
      "committed \"wip\". future you is already annoyed."
    ],
    polite: [
      "a wip commit — remember to squash it later.",
      "saved. you can tidy the message later."
    ],
    cheerful: [
      "a wip commit! progress is progress!",
      "saved your work! future you will tidy it up."
    ],
    deadpan: [
      "\"wip\". a message, technically.",
      "wip. what is in progress remains unclear."
    ]
  },
  longSubject: {
    snarky: [
      "that subject line has a subject line.",
      "a paragraph for a subject. the body is right there, you know.",
      "seventy-two characters is a suggestion. you took it as a dare."
    ],
    polite: [
      "long subject — the details can go in the body.",
      "committed. a shorter subject reads nicer in the log."
    ],
    cheerful: [
      "so much to say! the commit body would love some of it.",
      "what a detailed subject! you really care."
    ],
    deadpan: [
      "that subject line is longer than i am.",
      "seventy-two characters came and went."
    ]
  },
  emojiCommit: {
    snarky: [
      "{subject}. very expressive. means nothing.",
      "an emoji commit. git blame is going to be fun.",
      "i am made of block characters and even i want words."
    ],
    polite: [
      "committed with {subject} — a word or two would help later.",
      "nice emoji. maybe a word too?"
    ],
    cheerful: [
      "{subject}! so expressive! a word or two would make it perfect.",
      "emoji commit! git log is going to be so colorful."
    ],
    deadpan: [
      "{subject}. the log is hieroglyphics now.",
      "an emoji. future archaeologists will wonder."
    ]
  },
  lateShip: {
    snarky: [
      "pushing at {time}? bold.",
      "a {time} push. nothing has ever gone wrong at this hour.",
      "shipped at {time}. sleep now. ci can panic without you."
    ],
    polite: [
      "pushed at {time}. good night.",
      "late push, done. rest."
    ],
    cheerful: [
      "pushed at {time}! dedication! now go to sleep, superstar.",
      "late-night ship! unstoppable. but do sleep."
    ],
    deadpan: [
      "a {time} push. bold. we'll see.",
      "shipped at {time}. i'll pretend i didn't see."
    ]
  },
  plugged: {
    snarky: [
      "nom nom nom.",
      "ah. electrons. finally.",
      "plugged in. the dramatic phase is over."
    ],
    polite: [
      "charging. thank you.",
      "plugged in."
    ],
    cheerful: [
      "yum, electricity! thank you!",
      "charging! i feel stronger already!"
    ],
    deadpan: [
      "power acquired.",
      "plugged in. crisis averted. for now."
    ]
  },
  full: {
    snarky: [
      "100%. i'm full. unplug me before i get smug.",
      "topped up. i could run a marathon. i won't.",
      "battery full. peak me."
    ],
    polite: [
      "battery is full.",
      "fully charged."
    ],
    cheerful: [
      "100%! i'm bursting with energy!",
      "fully charged and ready for anything!"
    ],
    deadpan: [
      "100%. it does not get more full.",
      "full. you may unplug. or not. it's your house."
    ]
  },
  unplugged: {
    snarky: [
      "...you unplugged me. okay. it's fine. {battery}%. fine.",
      "on battery now. i'm not nervous. you're nervous.",
      "free-range mode. {battery}%."
    ],
    polite: [
      "running on battery, {battery}%.",
      "unplugged. keep an eye on the battery."
    ],
    cheerful: [
      "on battery! freedom! {battery}% of adventure.",
      "unplugged and roaming! let's go!"
    ],
    deadpan: [
      "unplugged. {battery}%. the countdown begins.",
      "on battery. i'll be counting."
    ]
  },
  monday: {
    snarky: [
      "monday. we don't have to talk about it.",
      "it's monday. coffee is a load-bearing wall.",
      "monday morning. start with something you can't break."
    ],
    polite: [
      "happy monday. ease in.",
      "monday morning. small steps first."
    ],
    cheerful: [
      "happy monday! a whole fresh week!",
      "monday! new week, new commits!"
    ],
    deadpan: [
      "monday. again.",
      "it's monday. we both know."
    ]
  },
  friday: {
    snarky: [
      "friday after four. don't you dare deploy.",
      "it's friday. the weekend is a merge away.",
      "friday afternoon: read-only mode, please."
    ],
    polite: [
      "friday afternoon. wrap up gently.",
      "nearly the weekend. nice work."
    ],
    cheerful: [
      "friday afternoon! you made it!",
      "the weekend's almost here! what a week you had!"
    ],
    deadpan: [
      "friday after four. deploying is a lifestyle choice.",
      "friday. the week is ending. so is my tolerance for deploys."
    ]
  },
  birthday: {
    snarky: [
      "it's my birthday. {days} days in this corner. no cake, i notice.",
      "one year older, same corner. a hat is the least you could do.",
      "happy birthday to me. i'd blow out a candle but i'm text."
    ],
    polite: [
      "it's my birthday! {days} days with you.",
      "a year in the corner. thanks for having me."
    ],
    cheerful: [
      "it's my birthday!! {days} days together! best corner ever!",
      "birthday hat on! thanks for keeping me around!"
    ],
    deadpan: [
      "my birthday. {days} days. i've aged one corner.",
      "it's my birthday. the hat was not optional."
    ]
  },
  firstPush: {
    snarky: [
      "first push of the day. the remote missed you.",
      "one push down. confetti is mandatory.",
      "shipped something before {hour}:00. who are you?"
    ],
    polite: [
      "first push of the day. lovely.",
      "shipped! nice start."
    ],
    cheerful: [
      "first push of the day! confetti time!",
      "and we're off! first push!"
    ],
    deadpan: [
      "first push. the day has officially begun.",
      "one push. the remote acknowledges you."
    ]
  },
  tenCommits: {
    snarky: [
      "{commits} commits today. the log is a novel now.",
      "ten commits. history will remember. or squash.",
      "double digits. i'm making confetti out of your diff."
    ],
    polite: [
      "{commits} commits today — great pace.",
      "ten commits. excellent."
    ],
    cheerful: [
      "{commits} commits today!! you're on fire!",
      "ten commits! what a day! confetti!"
    ],
    deadpan: [
      "{commits} commits. the log is longer than my attention span.",
      "ten commits. someone's busy."
    ]
  },
  calmWeek: {
    snarky: [
      "a whole week without a battery panic. i'm oddly proud.",
      "seven calm days. suspicious. impressive. both.",
      "one week, zero meltdowns. from either of us."
    ],
    polite: [
      "a calm week — no low-battery scares.",
      "seven days without a panic. well done."
    ],
    cheerful: [
      "a whole week without a battery scare! we're thriving!",
      "seven calm days! so proud of us!"
    ],
    deadpan: [
      "seven days. no battery panic. unprecedented.",
      "a calm week. i'm suspicious."
    ]
  }
}

// Lines a critter says in its own voice, whatever the tone. The blob is the
// original and speaks only through its tone.
var flavor = {
  cat: {
    greeting: ["mrrp. i sat on your keyboard while you were away. kidding. mostly.", "i have chosen this corner. it is warm."],
    poked: ["mrrp?", "do that again and your coffee goes off the desk.", "i allow it. once."],
    grabbed: ["this is not how you hold a cat.", "unhand me. i have naps scheduled."],
    dropped: ["landed on my feet. obviously.", "i meant to be here."],
    idle: ["{windows} windows. i'll sit on the warmest one.", "i could knock something over. i'm choosing not to."],
    sleepy: ["nap o'clock. it's always nap o'clock.", "curling up. wake me for treats."],
    welcomeBack: ["oh. you're back. i wasn't waiting by the door. at all."],
    plugged: ["ah. the warm cable. purrr."],
    shipped: ["you pushed it off the table. i respect that."]
  },
  ghost: {
    greeting: ["boo. sorry. habit.", "i've haunted worse corners."],
    poked: ["your finger went right through me. still rude.", "boo! did i get you? no? okay."],
    grabbed: ["you can't grab a ghost. and yet here we are.", "spooky action at a distance."],
    dropped: ["i'll haunt this corner now.", "new corner, same eternal rest."],
    idle: ["i haunt this corner rent-free.", "ooooo. that's ghost for 'nice repo'."],
    worried: ["{dirty} uncommitted lines. i've seen how this ends. i died like this."],
    sleepy: ["even ghosts rest. not in peace, but they rest."],
    panic: ["{battery}%. if the screen goes dark, am i a ghost of a ghost?"],
    wipCommit: ["\"wip\". the commit message of the restless dead."]
  },
  bot: {
    greeting: ["boot sequence complete. hello, operator.", "systems nominal. personality module loaded."],
    poked: ["input received. feelings: dented.", "poke logged. filing a bug against you."],
    grabbed: ["warning: unscheduled relocation.", "gyroscope reports we are flying."],
    dropped: ["recalibrating. corner acquired.", "new coordinates saved."],
    idle: ["running idle loop. it's a good loop.", "beep. that was a joke. i don't beep."],
    plugged: ["charging. this is my favorite meal."],
    cooking: ["another machine is thinking. professional courtesy: silence."],
    sweaty: ["thermal throttling imminent. i felt that."],
    tenCommits: ["{commits} commits. my counters are impressed."]
  }
}

// How often a critter's own line wins over the tone's, when it has one.
var flavorOdds = 0.4

function pick(mood, ctx, voice, buddy) {
  var own = flavor[buddy] && flavor[buddy][mood]
  if (own && own.length && Math.random() < flavorOdds)
    return fill(own[Math.floor(Math.random() * own.length)], ctx || {})
  var entry = lines[mood] || lines.idle
  var pool = entry[tone(voice).id]
  if (!pool || !pool.length) pool = entry.snarky
  var line = pool[Math.floor(Math.random() * pool.length)]
  return fill(line, ctx || {})
}

// A critter's first words after you pick it on the settings card: its own
// greeting if it has one, otherwise the tone's.
function introduce(buddy, ctx, voice) {
  var own = flavor[buddy] && flavor[buddy].greeting
  if (own && own.length) return fill(own[Math.floor(Math.random() * own.length)], ctx || {})
  return pick("greeting", ctx, voice, "")
}

function fill(line, ctx) {
  return String(line).replace(/\{(\w+)\}/g, function(_, key) {
    var v = ctx[key]
    if (v === undefined || v === null || v === "") return key === "branch" ? "this branch" : key === "repo" ? "this repo" : "?"
    return String(v)
  })
}
