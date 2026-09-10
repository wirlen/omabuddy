// Canned lines, grouped by mood. Add yours: keep them short (one line, under
// ~90 chars), kind, and in the voice of a small creature who lives in a
// screen corner. Tokens: {repo} {branch} {dirty} {hour} {streak} {battery}
// {event} {eta} {agent} {prompts} {limit}.
.pragma library

var lines = {
  idle: [
    "Just vibing over here.",
    "I have no notifications for you. Isn't that nice?",
    "Did you know I am 100% procedurally generated? Neither did I.",
    "You look focused. I'll be quiet. Ish.",
    "Reminder that most bugs are just misunderstandings.",
    "Tabs or spaces? Don't answer. I like both of us too much."
  ],
  sleepy: [
    "It's {hour} o'clock. Are we sure about this?",
    "Coffee first, semicolons later.",
    "The bugs are asleep. Maybe you should be too.",
    "Early bird gets the merge conflict.",
    "Yawn. Let's start with something easy."
  ],
  hyped: [
    "Post-lunch energy! Ship it!",
    "This is the golden hour. Do the hard thing now.",
    "I believe in {branch}. Mostly.",
    "You got this. I got this. We got this.",
    "Let's turn that TODO into a DONE."
  ],
  stretch: [
    "{streak} minutes straight. Legs still work?",
    "Stand up, look at something far away, come back a hero.",
    "Your spine called. It wants a word.",
    "Hydration check. I'll wait.",
    "Even compilers take breaks. Well, no, but you should."
  ],
  worried: [
    "{dirty} changed lines and no commit? Bold.",
    "That diff is getting... ambitious.",
    "A commit a day keeps the git stash away.",
    "I would feel safer if {branch} had a checkpoint.",
    "Not judging. Okay, a little judging. Commit?"
  ],
  proud: [
    "Committed! Look at you go.",
    "Another one for the history books. Literally.",
    "Clean tree, clean mind.",
    "That commit message was... fine. The code is great though.",
    "Nice. Now push it before I forget."
  ],
  shipped: [
    "Pushed! It's someone else's problem now.",
    "And it's off! Godspeed, little commits.",
    "The remote thanks you for your service.",
    "CI is about to have feelings about that."
  ],
  sweaty: [
    "Is it hot in here or is that your CPU?",
    "Something is eating all the cores. Hope it's on purpose.",
    "I can hear the fans from here.",
    "Compiling? Or did you leave a while(true) somewhere?"
  ],
  panic: [
    "Battery at {battery}%! Find a cable! FIND A CABLE!",
    "{battery}% and unplugged. I'm too young to hibernate.",
    "This is not a drill. Charger. Now."
  ],
  zen: [
    "Evening. Wrap up gently.",
    "Whatever's left can wait until tomorrow.",
    "Good work today. I mean it.",
    "Close the laptop, open the sky."
  ],
  poked: [
    "Hey!",
    "Ouch. Rude.",
    "Yes? I'm here.",
    "I'm working, you know. Vibing is work.",
    "Poke me again and I'll rebase your main branch."
  ],
  meeting: [
    "{event} in {eta} minutes. Hair check.",
    "Heads up: {event} at T-minus {eta}.",
    "Wrap the thought. {event} is about to happen.",
    "Camera on or camera off? {event}, {eta} min."
  ],
  rationed: [
    "{agent} is at {limit}% of its limit. Easy on the tokens, chief.",
    "You have been very chatty with {agent} today. {prompts} prompts!",
    "{agent} is nearly rationed. Maybe write this one yourself?",
    "Budget check: {agent} at {limit}%. I'm free, by the way."
  ],
  cooking: [
    "The agent's cooking. Don't open the oven.",
    "Let it think. Stretch your hands.",
    "Somewhere, an agent is reading your whole repo again.",
    "This is the part where you pretend not to watch the spinner.",
    "{prompts} prompts today. The agent needs a union."
  ],
  agentDone: [
    "Ding! The agent wants you.",
    "It stopped spinning. Your move.",
    "Agent's done. Go check the damage.",
    "Review time. Trust, but diff."
  ],
  greeting: [
    "Morning! Or whatever this is.",
    "Hi. I live here now.",
    "Reporting for duty. Duty being: sitting here.",
    "Oh, hello. I'll be in the corner."
  ]
}

function pick(mood, ctx) {
  var pool = lines[mood] || lines.idle
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
