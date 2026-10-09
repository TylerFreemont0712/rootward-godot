# Lanternroot's quests: the first four, and where they go next

Written 2026-10-09 with the polish pass. Every quest is a program the player writes, and every program changes the
town in a way they can see. That is the rule from here on: **you build everything in the game**, from your own feet to
your own save.

## The first four (built)

| # | Quest | Giver | The program | What it teaches | What changes in town |
|---|---|---|---|---|---|
| 1 | Your own two feet | Hotaru | `on_key(key, player)`: change `player.x` or `player.y` | Events, coordinates (y grows downward), if | You can walk at all; Hotaru refuses a step of 2 |
| 2 | Hello, Lanternroot | Hotaru | No program: meet the town and read the noticeboard | Reading other people's work (the letters) | The noticeboard opens the letters |
| 3 | Remember me | Vell | `save(player)` returns what the town should keep | Functions that return data; dictionaries and objects | The menu's Save works, and Continue puts you where your save says. Forget the map and you wake at home |
| 4 | Light the lane | Lumen | `light_all(lamps)` sets every lamp's `lit` | Loops over a list, including the empty list | The north lane's lamps light one by one |

Quests are content (`game/content/packs/core/overworld/quests.jsonc`). Each step is done when a condition over the
town's flags holds (`Quests`, `game/core/overworld/quests.gd`), so a new quest needs no engine code, only its steps,
its talk and, if it has one, its lesson.

## Next, by idea

Each one is a person, a problem in town, a program, and something you can see when it works.

### Chapter 1 continued (beginner)

- **Pip's count** (Pip). Pip counts the lanterns on the Lantern Root and always gets ten; Hotaru says eleven. Write
  `count(lanterns)`. *Off by one, counting from zero, `len`.* When it works, Pip's number appears above the tree,
  and Pip finally believes Hotaru.
- **Boots, part two: running** (Hotaru). A new key, `shift`. Hotaru still refuses +2 steps, until a hint explains
  that a run is two steps, one after another, not one jump. *Calling a function twice, sequences.* You can run.
- **Hotaru's glow** (Hotaru). Write `glow(t)`, the brightness of her light at time `t`. Real fireflies flash in a
  pattern of their own, and Genji fireflies even flash in time with each other. *Variables, arithmetic, `%`.* Hotaru
  blinks your pattern, and at night the fireflies by the pond answer it. (A gift for the player's wife.)
- **Marta's always-ready soup** (Marta). Orders come in; cooking is slow. Write `serve(order, pot)` that cooks only
  what the pot doesn't already hold. *Caching, dictionaries, `in`.* A counter shows the cooking you saved.

### Chapter 2 (data and decisions)

- **Brisk's drills** (Sergeant Brisk). Someone else's code is wrong. Write the tests that catch it. *Tests,
  assertions, edge cases.* Red flags on the drill ground turn green.
- **Nix's locks** (Nix). Write `opens(key)`. Then Nix tries strange keys: empty, too long, upside down. *Validation,
  defensive code, thinking like an attacker.* The locks hold, and Nix grins.
- **The forge never lies** (Brannoc). A recipe in, a tool out, the same every time. Brannoc rejects any function
  that changes something outside itself. *Pure functions, side effects.* Your tools hang on the forge wall.
- **Orin's festival vote** (Orin). Tally who wants which festival dish. *Counting in a dictionary, `max`.* The
  square decorates itself for the winner.

### Chapter 3 (structure)

- **Vell's changelog** (Vell). Compare yesterday's boots with today's and say what changed. *Diffs, version
  history.* The Archive's shelves fill with your programs, one book per version, and you can open any of them.
- **Seren's helpers** (Seren). Helpers that act when something happens: when it rains, cover the bread. *Events
  and callbacks.* Small spirits run around town doing your bidding.
- **Morrow's old stones** (Morrow). Old code nobody uses. Read it, say what it does, and retire it safely. *Reading
  code, refactoring, deprecation.* The graveyard becomes a garden.
- **Pell's map of the roots** (Pell). A grid of tunnels. Find a way from the gate to the lantern. *2D lists,
  breadth-first search.* The way down glows on Pell's map.

### The gate (the bridge to the Shardrun)

- **The Root Gate** (the Warden). The Warden asks for something only the earlier programs together can answer. *Composing
  functions.* The gate opens onto the roots, and onto the Shardrun's world.

## Systems that would help

- **A code museum.** Every program you have written, on the Archive's shelves, readable and re-runnable. It is
  the progress screen, made into a place.
- **The Night Watch** (ADR-0055) **walking the overworld.** At night, every program in town runs again; something you
  broke shows as a dark lamp you can walk to.
- **Picture blocks for the youngest.** Arrows and lamps instead of words, the Viscuit way, with the code shown under
  them.
- **Disciplines** (like the Shardrun's classes). A Tinker builds; a Scribe reads and fixes; a Warden tests and
  defends. Each gets their own quests through the same town.
- **Badges for ideas, not points.** "Counted from zero", "Wrote a loop", "Caught a bug". Shown on the character's
  progress page.
