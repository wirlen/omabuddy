// The critters the buddy can be. Each one is block-character art with slots
// for the mood's eyes (6 columns), mouth (2 columns) and extra mark (drawn
// right of the eye row), plus the day's hat above the head. Every mood,
// blink, costume and confetti burst works for every buddy.
//
// `tick` flips a few times a second (faster when the mood is excited) for the
// one thing each critter fidgets with: the cat's tail, the ghost's hem, the
// bot's antenna light. `floaty` lifts the body off its shadow. `persona` is
// handed to Ollama so an improvised line knows who is talking.
.pragma library

var list = [
  {
    id: "blob",
    name: "blob",
    blurb: "the original. a loaf with opinions.",
    persona: "a small block-character blob",
    floaty: false,
    art: function(p) {
      return "   ▄▄▄▄▄▄▄▄\n" +
             "  █ " + p.eyes + " █" + p.extra + "\n" +
             "  █        █\n" +
             "  █   " + p.mouth + "   █\n" +
             "   ▀▀▀▀▀▀▀▀\n" +
             "    ▀▀  ▀▀"
    }
  },
  {
    id: "cat",
    name: "cat",
    blurb: "ignores some pokes. wags when happy.",
    persona: "a small block-character cat who is only mildly interested in you",
    floaty: false,
    art: function(p) {
      return "  ▄▖      ▗▄\n" +
             "  ██▄▄▄▄▄▄██\n" +
             "  █ " + p.eyes + " █" + p.extra + "\n" +
             " ═█   " + p.mouth + "   █═\n" +
             "   ▀▀▀▀▀▀▀▀" + (p.tick ? "  ▄▀" : " ▄▄▀") + "\n" +
             "    ▀▀  ▀▀" + (p.tick ? " ▀▀" : " ▀")
    }
  },
  {
    id: "ghost",
    name: "ghost",
    blurb: "haunts the corner. fades when sleepy.",
    persona: "a small block-character ghost who haunts the corner of the screen",
    floaty: true,
    art: function(p) {
      return "    ▄▄▄▄▄▄\n" +
             "  ▄▀      ▀▄\n" +
             "  █ " + p.eyes + " █" + p.extra + "\n" +
             "  █   " + p.mouth + "   █\n" +
             "  █        █\n" +
             (p.tick ? "  █▄▀▄▀▀▄▀▄█" : "  █▀▄▀▄▄▀▄▀█")
    }
  },
  {
    id: "bot",
    name: "bot",
    blurb: "antenna blinks. runs on your electricity.",
    persona: "a small block-character robot with a blinking antenna",
    floaty: false,
    art: function(p) {
      return "      " + (p.tick ? "▄▄" : "  ") + "\n" +
             "      ▐▌\n" +
             "   ▄▄▄▐▌▄▄▄\n" +
             " ▐█ " + p.eyes + " █▌" + p.extra + "\n" +
             "  █        █\n" +
             "  █  ▕" + p.mouth + "▏  █\n" +
             "  ▀▀▀▀▀▀▀▀▀▀\n" +
             "   ▀█    █▀"
    }
  }
]

function byId(id) {
  for (var i = 0; i < list.length; i++) if (list[i].id === id) return list[i]
  return list[0]
}

function ids() {
  var out = []
  for (var i = 0; i < list.length; i++) out.push(list[i].id)
  return out
}

// Hat line, if any, sits above the critter's first row.
function draw(id, p) {
  var art = byId(id).art(p)
  return p.hat ? p.hat + "\n" + art : art
}
