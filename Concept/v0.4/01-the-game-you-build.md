# v0.4: the game you build from inside the game

Written 2026-10-15 by Claude (the conductor), on the player's brief of the same morning. This is the design of the
whole slice. `02-task-format.md` covers the exact content format and engine interfaces the workers build against.
`03-story.md` covers the chapter's story beats; the story worker writes that file from section 13.
`04-handoff.md` covers who builds what.

## 1. The brief, in the player's words

> "I want to start actually adding more programming tasks to the game. For now, the boots thing is great. But I'd like
> you to seamlessly add more and more to the game. Including an inventory system, which we can expand upon later,
> different tasks to do the various different functions of the game (esc to open menu, save function, options menu,
> create a slider for the volume, soundtrack to choose from a list of available tracks, etc.) Honestly, the idea is to
> go a little overboard, as I want it to feel like you're creating the game from in the game... for now, the main
> flow of the game is a puzzle game (programming)."

> "I would like there to be a small map and an improvement to the look of the quest tracker/menu in the upper right as
> it's a little too basic. The character select could also be improved, the different stats aren't really required
> right now, things like KEYS 4/4 isn't that great... For now, have it be a little more basic with what it shows."

> "Use primarily haiku agents to create the different function quests and plans, as they should essentially be a
> little easy in terms of difficulty. Sonnet should be in charge of the flow of the story, and OPUS the checker for
> the final output."

The player was away for the day and gave full authority. The decisions they would otherwise make are listed in
section 17 with the default chosen.

## 2. Where the game stands (the baseline, looked at 2026-10-15)

- **Quests 1 to 4** exist (`07-lanternroot-quests.md`):
  - boots: `on_key(key, player)`. The town walks on a table made from it in one sandbox job.
  - hello: meet the town.
  - memory: `save(player)`. The menu's Save runs it.
  - lamps: `light_all(lamps)`.
- **The Esc menu** (`PauseMenu`) shows the tinker's figure, place, time played and quest. Its items are Continue,
  Quests, Your boots, Save (locked until lesson 2, with "You will build saving yourself. Ask Vell at the Archive."),
  Settings (the title's whole settings panel), Characters, Quit to title and Quit game.
  - Screenshot: `shots/v04/before/menu.png`.
  - The locked-Save pattern is the seed of this whole slice.
- **The quest tracker** (`QuestTracker`, top right) is a 400 px card with an amber title, step pips, one step line and
  a checkbox.
  - Screenshot: `shots/v04/before/town.png`.
  - It is plain: it has no giver, no progress, no direction and no map.
- **The character select** (`CharacterSelect`) shows the following, then Play, Progress and Delete.
  - The name and "Played today".
  - "Tinker · Python · Builder".
  - The current quest.
  - Three count boxes: "0 / 4 quests", "1 / 16 met" and "1 / 4 keys".
  - Screenshot: `shots/v04/before/select.png`.
- **Running player code:** a sandbox job costs about 72 ms in Python and 11 ms in JavaScript (measured today with
  `tools/bench_sandbox.gd`).
  - The boots answer every key on every tile in one job, so walking never waits.
  - This slice uses that pattern everywhere ("tables, not calls", section 3).
- **Things that take code** (TownThings, Studio S8) and **the quest editor** (S9) exist.
  - The quest editor lists flags and where they are set.
  - A step can have an `at` pin.
- **New art:** 90 catalog objects arrived on 2026-10-15 (`expand-*`: bakery, greenhouse, fountain, walls, beds, wardrobes,
  stove, wall clock, crop rows, beehive, tool rack, watering can and more).
  - None of them is placed in the town yet.

## 3. The idea: Parts

Lanternroot runs on code, and so does the game. Every part of the game the player uses (the menu key, the menu, the
options page, the volume knob, the music box, the bag, the map, the tracker's progress bar, the clock, the credits) is
a **Part**. Until the player writes it, the part is missing or a rough stand-in. Once they write its function, the part
appears, and from then on it is **powered by their code**: the menu lists what their `menu_items` returns, and the volume
is what their `volume` says. The player is not decorating a game. They are building the one they play.

### Words used in this spec

- **Part:** a piece of the game built by a task. Its id is the task's id: `shortcuts`, `menu`, `options`, `volume`,
  `music`, `bag`, `map`, `progress`, `clock`, `credits`.
- **Task:** one function the player writes (or two, in stages), as content: `tasks/<id>.jsonc` with its starter code,
  Builder blocks, cases, judges and hints.
- **Stage:** a task grows. Stage 1 builds the part, and later stages add to the same code: the bag's `add`, then its
  `remove`.
  - Each stage has cases. Checking a stage also runs every earlier stage's cases, so nothing breaks as the code grows.
- **Stand-in:** what the game shows before the part is built: Hotaru's pocket menu, a locked line, plain pips, or
  nothing at all.
- **Table:** a part's answers computed once, over every input the game can ask, in one sandbox job.
  - Examples: every key for `shortcut`, every notch for `volume`, every minute for `time_of_day`.
  - The game reads the table and never waits. A table is remade when the part's code changes or the map changes.
- **Live call:** a part the game must call with its current state: `add(bag, item)` when you pick something up, and
  `menu_items(built)` when the parts change.
  - It runs on a background thread (about 0.1 s) with a small animation, and the state changes only when the answer
    is valid.
- **Workbench:** the screen, and the desk in the player's home, that lists every part with its code, its stage and
  what it does.

### The rules every part follows

1. **Real execution.** A part's behaviour is the player's real code, run in the sandbox. It runs once into a table, or
   live for the bag and the menu. The game never imitates the player's code with its own.
2. **The last passing code runs.** The town runs the program that last passed the task's checks. Code that is being
   edited and fails does not replace it. The Workbench says "Your newest try isn't used until it passes."
3. **Never trapped.** Esc (or a pad's Start) always opens a menu, and that menu always has Quit to title, Quit game
   and Settings.
   - Before the menu part is built, Esc opens Hotaru's pocket menu.
   - If the player's code later stops mapping Esc to "menu", Esc still opens the pocket menu, with a line saying why.
   - The title's Settings panel is always reachable.
4. **Validated answers.** The game checks every answer before it uses it, with the same judge as the task's check.
   - An answer that fails is not used. Examples: a bag whose `add` lost an apple, a loudness of 7.0, an unknown colour.
   - The game keeps its stand-in for that input, and Hotaru says once what went wrong, with the line, and how to open
     the code.
5. **Easy, one idea at a time.** Each stage teaches one idea, and in Python is a few lines of code at most.
   - The ideas: a comparison, a list joined, a division, a loop with append, a dictionary lookup, a modulo, a range
     check, string formatting.
   - Difficulty follows the existing lessons: easier than lamps for most stages.
6. **Hints, not answers.** Starters say what the function gets and gives, and nothing more. Hints climb from a
   question, to a nudge, to the name of the tool, and never give the line itself.
   - Glossary examples are about something else (`AGENT.md` section 4).
7. **Builder and Scribe both.** A Builder makes the code with blocks (choices and switches on the real lines, section
   12.4) and sees the code they make. A Scribe types it and has the Hints column. Both run the same checks.
8. **Python and JavaScript.** Every task has both. JavaScript names are camelCase (`menuItems`), and a JavaScript
   program may also use the Python name, as the lessons allow.
9. **Seamless.** A part appears where it belongs, in the menu, the HUD or the town, with a short "part built" banner
   and Hotaru's word. There is no separate "programming mode" to enter: the quests bring you to the people, and the
   people open the editor.

## 4. The chapter map

Quest 3 is new and goes into chapter 1. Quests 6 to 13 are chapter 2, "The Workshop Inside". A quest opens when every
quest in its `after` list is done, so chapter 2 branches. The tracker follows the quest the player chose to track
(section 9.4), and otherwise the first open one.

| # | Quest id | Title | Giver | Task (stage): function | After |
|---|---|---|---|---|---|
| 1 | boots | Your own two feet | Hotaru | (exists) `on_key` | |
| 2 | hello | Hello, Lanternroot | Hotaru | (exists) | boots |
| 3 | menu | A key for every door | Mira (artificer) | shortcuts (1): `shortcut(key)`; menu (1): `menu_items(built)` | hello |
| 4 | memory | Remember me | Vell (archivist) | (exists) `save` | menu |
| 5 | lamps | Light the lane | Lumen (oracle) | (exists) `light_all` | memory |
| 6 | options | Turn it up | Seren (summoner) | options (1): `options()`; volume (1): `volume(slider)`; volume (2): the same, clamped | lamps |
| 7 | music | The music box | Marta (innkeeper) | music (1): `titles(tracks)`; music (2): `next_track(index, count)` | options |
| 8 | bag | A bag of your own | Nym (quartermaster) | bag (1): `add(bag, item)`; shortcuts (2): the bag's key | lamps |
| 9 | soup | Soup for the Hearth | Marta (innkeeper) | bag (2): `remove(bag, item)` | bag |
| 10 | map | Pell's little map | Pell | map (1): `map_colour(ground)`; map (2): `place_of(x, y, places)`; shortcuts (3): the map's key | bag |
| 11 | progress | Pip's progress | Pip | progress (1): `progress(done, total)` | options, bag |
| 12 | clock | What time is it? | Lumen (oracle) | clock (1): `time_of_day(minute)`; clock (2): `clock_text(minute)` | map |
| 13 | credits | Sign your work | Orin (guildmaster) | credits (1): `credits(maker, parts)` | music, soup, map, progress, clock |

Ten parts, fourteen functions and seventeen stages, across nine new quests. Every townsperson who gives a part already
lives in town with a portrait and a talk file.

Old saves keep working: new state fields default, and section 15 covers the rest. A character already past "hello"
finds "A key for every door" as their next quest, with the pocket menu until they build it. Their Save keeps working
in the pocket menu once memory is written.

## 5. The parts, one by one

The reason codes, case lists and judges are exact here. The hint wording is the task worker's, within these rules.
The format of every field is in `02-task-format.md`.

### 5.1 shortcuts: `shortcut(key)` (quests 3, 8 and 10)

- **Gets:** `key`, a key's name: `"escape"`, a letter `"a"` to `"z"`, or a digit `"0"` to `"9"`.
- **Gives:** the name of what that key opens (`"menu"`, `"bag"`, `"map"`, `"quests"`, `"workbench"`, `"options"`,
  `"music"`), or nothing (`None` / `null`, or `""`).
- **Teaches:** comparing strings with `==`, `if`, returning early, and a function that grows a line at a time.
- **Stages:**
  1. **The menu's key** (Mira). Cases: `shortcut("escape")` gives `"menu"`, and `shortcut("p")` must not raise (any
     answer will do). Flag `menu-key-written`.
  2. **The bag's key** (Nym). Unlocked by `bag-built`. Case: `"i"` gives `"bag"`, plus stage 1's cases. Flag
     `bag-key-written`.
  3. **The map's key** (Pell). Unlocked by `map-built`. Case: `"m"` gives `"map"`, plus the earlier cases. Flag
     `map-key-written`.
- **Judge** `shortcut`, per case:
  - A case with `want` must give exactly it.
  - A case without `want` may give anything except an error or a name the game does not know; an unknown name has
    reason `unknown-panel`, with the name.
- **The table:** every key in `Parts.SHORTCUT_KEYS`, one job.
  - The keys are `escape`, `c f g h i j k l m n o p q r t u v y`, and `0` to `9`.
  - The keys the town needs are never asked or used: the arrows, `w a s d`, Space, Enter, `e z b x` and Tab.
  - The key list is in `02-task-format.md` section 5.
- **In the game:**
  - Esc, and any other key in the table, opens what its answer names, when that part is built.
  - A name that is not built yet makes Hotaru say "The bag isn't built yet. Nym can help!".
  - A pad's Start always opens the menu: a pad cannot type, so the pad is never locked out.
- **Stand-in:** until stage 1 passes, Esc opens the pocket menu (section 8.1).
  - Once the menu part is built, Esc opens the real menu if the player's table maps `escape` to `"menu"`.
  - If it does not (they edited it away), Esc opens the pocket menu, and the pocket menu says "Your shortcut() doesn't
    open the menu on Esc." with a Fix it button that opens the task.
- **Builder blocks:**
  - A switch per stage: "Open something on a key" (stage 1), "Open the bag on a key" (2), "Open the map on a key" (3).
  - Each switch has a key slot with three or four choices. Stage 1's choices are `"escape"`, `"p"` and `"o"`.
  - `return None` closes the function.

### 5.2 menu: `menu_items(built)` (quest 3)

- **Gets:** `built`, a list of the items the town can show now, in the town's own order.
  - Example: `["quests", "workbench", "save", "settings", "characters", "title"]`, plus `"bag"`, `"map"`, `"music"`
    and `"options"` once those parts are built.
- **Gives:** the list of items the menu shows, in order. It must start with `"continue"`, end with `"quit"`, and hold
  every item of `built` exactly once.
  - Python: `["continue"] + built + ["quit"]`, or a loop with `append`. The player may reorder the middle (for example
    with `insert`), but the judge never requires it.
- **Teaches:** lists: making one, joining two, `append`, `len`.
- **Stage 1:** flag `menu-built`. Cases:
  - `built` as a fresh tinker's: quests, workbench, save, settings, characters, title.
  - A longer one with bag and map.
  - A short one, `["settings"]`.
- **Judge** `menu_items`, with these reasons:
  - `not-list`
  - `first` (not continue)
  - `last` (not quit)
  - `missing` (an item of built left out, with its name)
  - `twice` (an item shown twice)
  - `unknown` (a name nobody asked for)
- **Live call:** after each part is built, and on load (one job), the menu's list is computed again and kept in
  `state.tasks.menu.items`. The menu reads that list; it never waits on Esc.
- **In the game:** the real menu (section 8.2) shows the list's items, in its order, with the full look (figure,
  place, time, quest).
  - The first time it opens, the items fly in one by one, in the order the player returned, each with a soft click,
    and Hotaru says "That's YOUR menu.".
  - If the live call fails later (for example a new part's name meets a bug), the menu uses the town's order and
    Hotaru tells them once.
- **Stand-in:** the pocket menu.
- **Builder blocks:**
  - A line `items = [{first}]`, with choices `"continue"`, `"quit"` and `[]`.
  - A switch "Add everything the town built", which adds the loop `for item in built: items.append(item)`.
  - A line `items.append({last})`, then `return items`.

### 5.3 options: `options()` (quest 6)

- **Gets:** nothing.
- **Gives:** a list of rows for the town's Options page. Each row is a dictionary `{"setting": ..., "label": ...}`.
  - `setting` is one of `"music"`, `"sound"`, `"text_speed"`, `"track"` and `"fullscreen"`.
  - `label` is the player's own words, 1 to 24 characters ("Songs", "Boom volume").
- **Teaches:** dictionaries and lists written out (literals), and data that describes a screen.
- **Stage 1:** flag `options-built`. One case, the call itself.
- **Judge** `options_rows`, with these reasons:
  - `not-list`
  - `not-row` (an item that is not a dictionary with setting and label)
  - `unknown-setting`
  - `label-empty`
  - `label-long`
  - `twice`
  - `needs` (music or sound left out)
- **The table:** a single call, one job, recomputed when the code changes.
- **In the game:** the menu item "Options" (when in the menu's list) opens the town's Options page (section 8.3).
  - Its rows are the player's, in their order, with their labels. The kind of each row comes from its setting:
    `music` and `sound` are sliders, `text_speed` is three choices, `track` opens the music box, and `fullscreen` is a
    switch.
  - The page always ends with "More settings…", which opens the title's full settings panel.
- **Stand-in:** no Options item. Settings, the title's whole panel, is in every menu.
- **Builder blocks:** five switches, one row each (music, sound, text speed, track, fullscreen), each with a label slot
  of three choices. Example: "Music", "Songs", "Tunes".

### 5.4 volume: `volume(slider)` (quest 6)

- **Gets:** `slider`, a whole number. On the Options page it runs from 0 (all the way down) to 10 (all the way up).
- **Gives:** the loudness, from 0.0 (silent) to 1.0 (full).
- **Teaches:** numbers, division (`slider / 10`), and in stage 2, keeping a number inside a range (`min` and `max`, or
  `if`).
- **Stages:**
  1. **The knob** (Seren). Cases: each notch, 0 to 10. Flag `volume-built`.
     - Judge `volume_curve` looks at all eleven answers. Reasons:
       - `not-number`
       - `silent-end` (0 must give 0.0)
       - `full-end` (10 must give 1.0, within 0.01)
       - `out` (below 0 or above 1)
       - `goes-down` (a notch quieter than the one before)
     - Any curve that rises from 0 to 1 passes, so `(slider / 10) ** 2` is welcome, and the result shows the curve as
       a small chart.
  2. **Past the ends** (Seren). Unlocked by `volume-built`. Cases -3, -1, 11 and 14, plus all of stage 1. Flag
     `volume-clamped`.
     - Judge `volume_clamp`, which is `volume_curve` plus: below 0 gives 0.0, and above 10 gives 1.0.
     - Seren's story: the pad's shoulder buttons nudge past the ends.
- **The table:** notches -3 to 14, one job. The page uses 0 to 10. A pad nudge is clamped to the range only once stage
  2 passes. Before then the slider stops at its ends, and Seren mentions it.
- **In the game:**
  - The Options page's Music and Sound sliders have 11 notches. Moving one sets `Settings.music_volume` (or
    `sound_volume`) to the player's loudness for that notch, saves it, and plays a sample (a chime for Sound).
  - The row shows the notch and the player's percent ("7 → 49%"). A small chart of their curve sits beside the
    sliders, the current notch lit.
  - The game sets `volume-tried` the first time a slider moves.
- **Stand-in:** the sliders are drawn locked until stage 1 passes, with "Seren's knob isn't wired yet".
- **Builder blocks:** `return slider {op} {n}`, with `op` in `/ * + -` and `n` in `10 100 2`. Stage 2 adds two
  switches, "Not below 0" and "Not above 1", whose lines use `max` and `min`, or `if` in JavaScript (or `Math.max`).

### 5.5 music: `titles(tracks)` and `next_track(index, count)` (quest 7)

- **Gets, stage 1:** `tracks`, a list of dictionaries `{"id", "title", "place"}`, from `tracks.jsonc` (section 12.6).
- **Gives, stage 1:** the list of titles, in the same order.
- **Gets, stage 2:** `index`, the number of the track playing (0 for the first), and `count`, how many tracks there
  are.
- **Gives, stage 2:** the index of the next track, going round to 0 after the last.
- **Teaches:** a loop that collects one field (`for track in tracks: names.append(track["title"])`), and then `%`
  (modulo).
- **Stages:**
  1. **The list** (Marta). Flag `music-listed`.
     - Cases: three tracks, then one, then none (the empty list gives `[]`).
     - Judge `equals`, with reasons `not-list`, `wrong-length`, `wrong-item` (index, want, got).
  2. **Next!** (Marta). Unlocked by `music-listed`. Flag `music-next`.
     - Cases (index, count): (0, 3) gives 1, (1, 3) gives 2, (2, 3) gives 0, (0, 1) gives 0, and (4, 5) gives 0.
     - Judge `equals`. A wrong answer at the last track has reason `no-wrap`, which says "The last track should go
       round to the first."
- **The tables:**
  - The titles: a live call when the music box opens, so the list follows `tracks.jsonc`. It costs one job (11 to
    72 ms) behind a short "tuning…" line.
  - Next: a table over count 1 to 32 and every index, one job.
- **In the game:**
  - The music box, a new prop beside the Warm Hearth's door (section 11), opens the **Music** panel. So do Options'
    "track" row and a "music" item in the menu.
  - The panel lists the player's titles. Enter plays one, and "Next ▶" (and a pad's R) plays `next_track`'s choice.
  - "Play in town" sets `state.options.track`, which replaces the town's and the indoors' tracks everywhere but the
    code editors. "Lanternroot's own" (`""`) puts the places' tracks back.
  - The game sets `music-played` the first time a track is chosen.
- **Stand-in:** the music box says "It's a music box with no tunes in it yet." until Marta's quest.
- **Builder blocks:**
  - Stage 1: `names = []`, a switch "Go through every track", a line `names.append(track[{field}])` with `"id"`,
    `"title"` and `"place"`, then `return names`.
  - Stage 2: `return ({index} {op} 1) {wrap}`, with the wrap choices nothing, `% count` and `- count`.

### 5.6 bag: `add(bag, item)` and `remove(bag, item)` (quests 8 and 9), the inventory

- **The bag** is the player's inventory, `state.bag`: a list of stacks `{"item": id, "count": n}`, in the order the
  player's code leaves them. The player's code sees and returns exactly this.
- **Gets, stage 1:** `bag` and `item`, an item's id (`"apple"`).
- **Gives, stage 1:** the bag with one more of `item`. It adds to its stack if one exists, and otherwise adds a new
  stack `{"item": item, "count": 1}`.
- **Gets, stage 2:** `bag` and `item`.
- **Gives, stage 2:** the bag with one fewer of `item`. A stack that reaches 0 is taken out, and an item that is not
  there leaves the bag as it was.
- **Mutating is fine:** a stage may change `bag` in place and return nothing. The harness then reads the bag as the
  code left it (`"mutates": 0`, `02-task-format.md`).
- **Teaches:** searching a list of dictionaries with a loop, changing a value, `append`, and in stage 2, taking out
  (`remove`, `splice`) and the case where it is missing.
- **Stages:**
  1. **Pockets** (Nym). Flag `bag-built`.
     - Cases: an empty bag with an apple, `[{apple, 1}]` with an apple, and `[{apple, 2}]` with a cabbage. Then a
       bag of three stacks with the middle one's item.
     - Judge `bag_add`. Reasons:
       - `not-list`
       - `not-stack` (an item that is not `{item, count}`)
       - `no-more` (the item did not go up by one)
       - `two-stacks` (the same item twice)
       - `changed-other` (another stack's count changed, or one went missing)
       - `bad-count` (a count below 1, or not whole)
  2. **Giving** (Marta). Unlocked by `soup-asked`. Flag `bag-remove`.
     - Cases: `[{cabbage, 3}]` minus cabbage gives a count of 2, and `[{cabbage, 1}, {apple, 2}]` minus cabbage
       loses the stack. Then `[{apple, 2}]` minus pumpkin is unchanged, and `[]` minus apple is unchanged.
     - Judge `bag_remove`. Reasons: `not-list`, `not-stack`, `no-less`, `zero-stack` (left a 0 count),
       `changed-other`, `invented` (a missing item made something appear).
- **Live calls:**
  - Picking an item up runs `add` on a background thread. The item's icon arcs from the prop to the bag icon in the
    HUD.
  - Giving runs `remove`, as many times as the giving asks.
  - Each answer is judged as in the check. A wrong one is not used: Hotaru says, for example, "Your add() lost the
    cabbage! (line 4)", and X opens the bag's code.
- **The items:**
  - `items.jsonc` (section 12.6), sixteen to start: apple, cabbage, carrot, turnip, pumpkin, berries, mushroom,
    flower, honey, pinecone, pebble, bread, letter, gear, key, lantern oil.
  - Each item has a name, a description of one line, and an icon (section 11).
- **Picking up:**
  - `pickups.jsonc` names the props that give an item: apple trees give apples, the cabbage plot cabbages, the
    beehive honey, and so on.
  - Space on one picks it up, and the prompt says "Space: pick an apple". It regrows after `regrow` seconds of play.
  - The first time an item kind is picked up, the game sets `picked-<item>`.
  - Before the bag is built, Space on one makes Hotaru say "Ooh, apples! But where would we put them? Nym makes bags…
    well, Nym codes bags.", and nothing is picked.
- **Conditions over the bag:** quests and talk may ask `{"has": "cabbage", "at_least": 3}`. The game counts
  `state.bag` itself for conditions (the engine counts, so a condition can never run the player's code), and gives
  the counts to `Quests` and `Talk` as `bag:<item>` facts beside the flags. Those facts are never saved.
- **Giving:** a talk node `"open": "give:cabbage:3"`.
  - The game runs `remove` three times. When every call is valid it sets `gave-cabbage` and opens the same talk
    again, so its start rules see the flag (Marta's thanks).
  - When any call is not valid, the bag stays as it was and Hotaru explains why.
- **The Bag panel** (section 8.4) opens from the menu's "bag" item, or the key the player's `shortcut` gives `"bag"`.
  It shows the stacks in the bag's order.
- **Stand-in:** no bag in the menu, and no pickups.
- **Builder blocks:**
  - Stage 1: a loop over the stacks, with a switch "If this stack is the item" and an inner line
    `stack["count"] {op} 1`, where op is `+=` or `-=`. Then a choice of the return inside the loop (`return bag`).
    After the loop, a switch "Otherwise, a new stack": `bag.append({"item": item, "count": 1})`, then `return bag`.
  - Stage 2 follows the same frame, with `-= 1` and a switch "Take an empty stack out".

### 5.7 map: `map_colour(ground)` and `place_of(x, y, places)` (quest 10)

- **Gets, stage 1:** `ground`, what a map cell is.
  - A terrain id from `terrain.jsonc`: grass, flowers, path, cobble, bridge, floor, rug, water, hedge, wall, void.
  - Or `"building"`, `"tree"`, or `"thing"` (any other solid prop).
- **Gives, stage 1:** a colour's name from `Parts.MAP_COLOURS`: green, dark green, light green, blue, light blue, brown,
  tan, grey, dark grey, white, yellow, orange, red, pink, purple, black.
- **Gets, stage 2:** `x` and `y` (a cell) and `places`, a list of `{"name", "x", "y", "w", "h"}` rectangles.
- **Gives, stage 2:** the name of the place the cell is in, or `""` when it is in none.
- **Teaches:** a lookup with `if`/`elif` (or a dictionary), then a range check with `and` (`p["x"] <= x < p["x"] +
  p["w"]`), a loop and returning early.
- **Stages:**
  1. **Colours** (Pell). Flag `map-built`.
     - Cases: every ground above, one call each.
     - Judge `map_colours`, over all the answers. Reasons:
       - `not-colour` (with the ground and what it gave)
       - `same-water` (water as grass)
       - `same-path` (path or cobble as grass)
       - `same-building` (building as grass or path)
     - Anything else is the player's taste.
  2. **Where am I?** (Pell). Unlocked by `map-built`. Flag `map-places`.
     - Cases:
       - Inside a place.
       - On its top-left corner (inside).
       - On its right edge (`x == p.x + p.w`, outside).
       - In none.
       - In the second of two places.
       - An empty `places`.
     - Judge `equals`, with reason `edge` when the only failures are on an edge.
- **The tables:**
  - The colours: every ground, one job.
  - The places: every cell of the current map, one job per map (about 4,500 calls for the town, the size the boots
    already answer). Remade when the map or the places change.
- **In the game:**
  - **The minimap** (section 9.2) appears under the tracker, drawn in the player's colours, with the player's dot,
    people, doors and the tracked step's pin.
  - Once stage 2 passes, the place's name (from their `place_of`) shows under it.
  - **The full map** (section 9.3) opens from the menu's "map" item, or the key whose `shortcut` gives `"map"`.
  - The game sets `map-opened` the first time.
- **The places:** `places.jsonc` (section 12.6) names the rectangles of each map: the seven districts of Lanternroot
  from its map's comment (Home Hollow, Waterside, Lantern Square, Warm Hearth Row, Archive Quarter, Fern's Grove, North
  Green and the Old Stones, Root Gate Road), and the home as one place.
- **Stand-in:** no minimap and no map item.
- **Builder blocks:**
  - Stage 1: one line per ground, `if ground == "water": return {water}`, with three colour choices each, for water,
    path, building, grass and tree. Then `return {other}`.
  - Stage 2: a loop over places, with a switch "If the cell is inside it" that holds the range check. Its comparison
    has a choice (`<` or `<=` at the right edge), and is followed by `return place["name"]`. Then `return ""`.

### 5.8 progress: `progress(done, total)` (quest 11)

- **Gets:** `done` (steps finished) and `total` (steps in the quest).
- **Gives:** the percent done, a whole number from 0 to 100. Rounding down or to the nearest are both fine. A quest
  with no steps (total 0) gives 0, and not an error.
- **Teaches:** arithmetic, whole numbers (`//`, `int`, `round`, `Math.floor`), and the zero case (dividing by zero).
- **Stage 1** (Pip). Flag `progress-built`.
  - Cases: (0, 4) gives 0, (2, 4) gives 50, (4, 4) gives 100, (1, 3) gives 33, (2, 3) gives 66 or 67, and (0, 0)
    gives 0.
  - Judge `progress`. Reasons:
    - `not-whole` (0.5, or 33.333)
    - `fraction` (gave 0.5 for half: "Pip counts out of 100, not out of 1.")
    - `wrong`
    - `zero` (an error on (0, 0): "A quest with no steps. What's 0 out of 0?")
- **The table:** total 0 to 12, and every done from 0 to total. That is 91 answers in one job.
- **In the game:** the tracker's pips become a bar, filled to the player's percent, with the number at its end
  ("60%"). Pip notes the first time it shows 100%.
- **Stand-in:** the pips the tracker has now.
- **Builder blocks:** `return {expr}`, with the choices `done / total`, `done * 100 // total` and `total // done`. Then
  a switch "When there are no steps", which holds `if total == 0: return {zero}` with 0, 100 and None. Its line goes
  first.

### 5.9 clock: `time_of_day(minute)` and `clock_text(minute)` (quest 12)

- **Gets:** `minute`, the minute of the town's day, from 0 (midnight) to 1439 (23:59).
- **Gives, stage 1:** `"night"`, `"morning"`, `"afternoon"` or `"evening"`.
  - The town's own hours are given in the starter's comments, not as code: night until 6:00, morning until 12:00,
    afternoon until 18:00, evening until 21:00, then night.
- **Gives, stage 2:** the time as text, `"18:40"`, with two digits for the minutes (`"7:05"`, not `"7:5"`).
- **Teaches:** comparing ranges with `if`/`elif`, then `//` and `%`, and formatting text (f-strings, `zfill`,
  `padStart`).
- **Stages:**
  1. **Day and night** (Lumen). Flag `clock-built`.
     - Cases: 0, 359, 360, 719, 720, 1079, 1080, 1259, 1260 and 1439.
     - Judge `equals`, with reason `edge` when only the boundary minutes fail.
  2. **What does the clock say?** (Lumen). Unlocked by `clock-built`. Flag `clock-text`.
     - Cases: 0 gives `"0:00"`, 65 gives `"1:05"`, 600 gives `"10:00"`, 1119 gives `"18:39"`, 1439 gives `"23:59"`.
       A leading zero on the hour is also accepted (`"01:05"`).
     - Judge `clock_text`, with reasons `not-text`, `no-zero` (`"1:5"`), `wrong`.
- **The table:** 1440 minutes, one job for each stage.
- **In the game:**
  - The **town's clock** starts when the part is built. It starts at 8:00 for that save, and runs one town minute
    per second played (a day is 24 minutes); it stops while a menu is open.
  - The town is tinted by the player's phase (section 10), and the lane's lit lamps glow from evening.
  - Stage 2's text shows under the minimap, or alone at the top right when there is no minimap. The home's new wall
    clock reads it aloud on Space ("It's 18:40.").
  - The game sets `clock-evening` the first evening the player is in town (for Lumen's last step).
- **Stand-in:** before the part is built there is no clock: the town is always day.
- **Builder blocks:**
  - Stage 1: four lines, `if minute < {n}: return "night"` and its siblings, with three choices each for the hour
    (`360`, `300`, `400`…), plus a last `return {phase}`.
  - Stage 2: `hours = minute {op} 60`, `mins = minute {op2} 60`, and a switch "Two digits for the minutes", then the
    return.

### 5.10 credits: `credits(maker, parts)` (quest 13)

- **Gets:** `maker` (the player's name) and `parts` (the names of every part they built, in the order they built them:
  "Boots", "Save", "Lamps", "Shortcuts", "Menu" and so on).
- **Gives:** a list of lines for the credits to roll.
- **Teaches:** building a list of strings in a loop, and joining text.
- **Stage 1** (Orin). Flag `credits-built`.
  - Cases: ("Kai", five parts), ("Mina", one part), ("Tinker", ten parts).
  - Judge `credits`. Reasons:
    - `not-list`
    - `not-text`
    - `no-maker` (the maker's name is on no line)
    - `missing-part` (with its name)
    - `too-long` (more than 40 lines, or a line over 60 characters)
- **A live call** when the credits roll.
- **In the game:**
  - Finishing the quest rolls **the credits**: full screen, the Lantern Root at night with fireflies, the title track,
    and the player's lines in their order. Afterwards a card reads "Lanternroot, made by <name>" (the game's own words
    end it).
  - The game sets `credits-rolled`.
  - A "credits" item can then be in the menu.
- **Stand-in:** none. The quest is the end of the chapter.
- **Builder blocks:** `lines = [{title}]` (three choices), a switch "Add the maker" (`"Made by " + maker`), a switch
  "Add every part", and `return lines`.

## 6. The lessons that exist, as parts

Boots, Save (memory) and Lamps keep their own editors and runners (`BootsEditor`, `LessonEditor`, `LessonHost`); none
is rewritten in this slice. The Workbench lists them beside the new parts, and their "Open" opens their own editor.
`Parts.BUILT_BEFORE` maps each one to its flag: boots to `all-ways`, save to `memory-written` and lamps to `lamps-lit`.
The menu's "Your boots" item is now in the Workbench, and B still opens the boots directly.

## 7. The Workbench

- **Where:**
  - A menu item, "workbench", which every fresh tinker's `built` list holds.
  - The writing desk in the player's home: an `expand-writing-desk` placed by the bed, which opens the Workbench on
    Space through a thing field `"opens": "workbench"`.
- **What it shows:** a grid of part cards, three across, in the order of section 4. Each card has:
  - the part's name and an icon of a gear, lit when built and dim when not;
  - the giver's round portrait;
  - the function's signature in the player's language (`shortcut(key)`);
  - the status: "Built", "Stage 2 of 3", "Stage 2 waits: Nym has an idea", or "Not yet: ask Pell";
  - a line of what it does now ("Esc opens your menu.").
- **Choosing a card** opens a side panel with the code that runs (read-only, highlighted) and two buttons. **Open**
  opens the editor on the next unpassed unlocked stage, or the last stage for practice. **Check again** runs every
  case of every passed stage and lists the results.
- **The Lantern Engine:** a small drawing at the top. There is a gear per part, chained in the chapter's order; a
  built part's gear turns, and a missing one is an empty socket. It is where "creating the game from in the game"
  shows as a picture.
- **Stand-in:** the Workbench is there from the start. Boots and Save are its first cards.

## 8. The menus and panels

All of them use the Lanternroot panel style (`PauseMenu.panel_style`, `OverworldStyle`): a warm dark fill, an amber
edge, the menu's items with amber focus, Arrows, Enter, Esc and the pad.

### 8.1 Hotaru's pocket menu (the stand-in)

A narrow card, about 380 px wide, centred, with no figure.

- **Heading:** "Hotaru's pocket menu" in small amber letters.
- **Items:** Continue, Your boots, Save (locked as now until memory is written), Settings, Quit to title, Quit game.
- **A line at the bottom:** "This is just my pocket menu. Mira at the workshop could build you a real one!" Once the
  menu part is built but Esc no longer maps to "menu", the line is instead "Your shortcut() doesn't open the menu on
  Esc." with a Fix it item.
- **The look:** rougher than the real menu. It has a dashed edge (`draw_dashed_line` on the panel) and a slight tilt
  of 0.5°, so the real menu, when it comes, feels like an upgrade.

### 8.2 The real menu

The existing PauseMenu, with these changes:

- **Its items:**
  - The list comes from `state.tasks.menu.items` (5.2), so its length changes.
  - The item ids are continue, quests, workbench, bag, map, music, options, save, settings, characters, title,
    credits and quit.
  - "Your boots" moves into the Workbench.
- **Its side card:** the figure, the name, the place, the time played and the tracked quest.
  - When the map part has stage 2, the place line is the player's `place_of`.
  - When the clock is built, the line shows the clock's text, "18:40 · evening".
- **The first opening:** items fly in one at a time, in order (0.06 s apart). A built part's item shows a tiny gear
  mark the first time.

### 8.3 Options (the player's)

- **The page:** a panel of the player's rows (5.3), each row a label (theirs) and its control.
  - Music and Sound are sliders of 11 notches, using `volume` (5.4).
  - Text speed is three choices, slow, normal or fast, which set `state.options.text_speed` and change `DialogueBox`'s
    letters per second (`OverworldStyle.TEXT_SPEEDS`: 30, 55, 90).
  - Track is the current track's title, and Enter opens the Music panel.
  - Fullscreen is a switch that sets `Settings.fullscreen` and calls `Settings.apply_display()`.
- **Beside the sliders:** the curve chart (5.4).
- **At the bottom:** "More settings…", which opens the title's full panel, as the menu's Settings does now.
- **Saving:** changes save at once, to `state.options` for the town's choices and to `Settings` for the volumes.

### 8.4 The Bag

- **The panel:** a grid of 6 by 4 slots (64 px each, the panel's style, 4 px gaps). Each slot holds the item's icon at
  2x and its count in a small amber badge.
  - The selected slot's name and description are at the bottom.
  - The stacks are in the bag's order, which is the order the player's code leaves them in.
- **A note** under the title: "Nym's design, your code: add() put these here."
- **Empty:** "Nothing yet. Apple trees are a good start."
- **Later, not now:** using, dropping, selling and sorting. A `sort` stage is the natural next task (section 16).

### 8.5 Music

- **The panel:** the player's titles (5.5), one row each, with ♪ beside the playing one.
  - Enter plays the chosen one in the panel.
  - "Next ▶" (or R, or a pad's right shoulder) plays `next_track`'s answer.
  - "Play in town: <title>" or "Lanternroot's own" sets `state.options.track`.
- **The track list** is `tracks.jsonc`: the town, home, lesson and front tracks, the title track and the rest track,
  and the Shardrun's place tracks (heap, kernel, ring0 to ring2, salvage), each with a title and where it is heard.

### 8.6 The part-built banner

- **Where:** a banner at the top centre, 640 by 110, when a stage that builds a part passes and its editor closes.
- **What it shows:** a turning gear, "NEW PART" in small amber capitals, the part's name ("The Menu"), and the task's
  `built_line` ("Esc opens your menu now.").
- **Its sounds:** `sfx-pass`, then `sfx-chime`.
- **Timing:** it holds 3.5 s, and stays on screen if Hotaru starts talking.
- **A later stage's pass:** a smaller banner, "Part improved: The Bag (stage 2)".

## 9. The HUD: tracker, minimap, full map

### 9.1 The quest tracker, made richer

Top right, 440 px wide:

```
┌────────────────────────────────────────────────┐
│ (◉)  A KEY FOR EVERY DOOR                2 / 4 │  ← giver's round portrait (44 px), the quest title in amber
│      ▰▰▰▰▰▰▰▰▰▰▱▱▱▱▱▱▱▱▱▱  50%                 │    small capitals, the step count
│ ○  Write menu_items: what your menu shows.     │  ← the bar is Pip's progress() once built; pips until then
│    ↗ 14 tiles · Warm Hearth Row                │  ← the step's direction, when the step has a pin (S9's `at`)
└────────────────────────────────────────────────┘
┌──────────────────────────┐
│      the minimap         │  ← section 9.2, once the map part is built
│  Warm Hearth Row · 18:40 │
└──────────────────────────┘
```

- **The giver's portrait** sits in a round frame with an amber ring. The giver comes from the quest's `giver`.
- **The step count** "2 / 4" is right-aligned. A step that counts ("Meet more of the town", or "Gather 3 cabbages")
  shows its own count, "4 / 6", under the step.
- **The bar:**
  - With progress built, it is a bar of the panel's amber with the player's percent at its end.
  - Without progress, it is the pips the tracker has now, done ones filled and the current one ringed.
  - It animates to its new value in 0.4 s.
- **The direction** shows when the step has a pin on the current map. It is a small arrow (8 directions) toward the
  pin, then the distance in tiles, then the pin's place name, when map stage 2 exists.
  - On another map it says "In Lanternroot" or "At home". With no pin, the line is not there.
- **Motion:**
  - On a step change, the old step is ticked, slides away and the new one slides in.
  - A quest finished shows a toast.
  - A part built shows the banner of section 8.6, and the tracker's card waits under it.
- **Hide and show:** H hides and shows the card. It is not in `SHORTCUT_KEYS`, so it is reserved for this and listed
  in the reserved keys.
- **Tracking:** the quest log gets **Track** (T, or a button) on an open quest, and sets `state.tracked`. The tracker
  follows the tracked quest while it is open, and otherwise the first open one.

### 9.2 The minimap

- **Where:** under the tracker, right-aligned, 240 by 168.
- **What it draws:**
  - The whole map, scaled to fit. The town's 80 by 56 cells come to about 3 px a cell. A room is scaled up to fit,
    at most 14 px a cell.
  - It is baked to an `ImageTexture` once per map and per change of the colour table: each cell in the player's colour
    for its ground, and each solid object's footprint in its kind's colour (building, tree, thing).
  - The player is an amber dot of 6 px that pulses once a second.
  - Townspeople are cream dots of 4 px.
  - Doors and warps are small dark gaps.
  - The tracked step's pin is a green star.
- **A line under it:** the place (when map stage 2 is built) and the clock's text (when clock stage 2 is built),
  "Warm Hearth Row · 18:40".
- **Clicking it,** or the map key, opens the full map.
- **When it hides:** with the tracker, during talk, editors and menus.
- **The colours of the names** come from `Parts.MAP_COLOURS`, each a palette colour (`02-task-format.md` section 5).

### 9.3 The full map

- **The panel:** about 1300 by 900, with the whole map at the largest whole-number scale that fits.
  - Each place's name is drawn at the centre of its rectangle, in the overworld's body font with a dark outline.
  - It shows the player, the people and the pin.
- **A legend on the right:** each ground and its colour, from the player's own `map_colour` ("water: blue"). Under it:
  "Drawn with your map_colour()".
- **Esc, M or the map key** closes it.

### 9.4 The quest log

- **Track:** the log gets a Track button, as in 9.1.
- **Its look:** each quest's giver portrait (small) beside its title, and a part's gear icon beside a quest that
  builds a part.

## 10. Day and night (the clock part)

- **The tint:** a `CanvasModulate` in the town's viewport (PixelView), never on the UI.
  - The tints: morning `#fff6e8`, afternoon `#ffffff`, evening `#ffd9bf`, night `#8c9ef2`.
  - The tint blends over 20 town minutes into each phase, so a phase change is a soft fade.
- **Rooms:** they keep a softer version, halfway to white.
- **The lane's lamps:** once `lamps-lit`, they glow brighter (modulate 1.25) in the evening and at night. That is a
  first lamp of night, and later light work is not in this slice.
- **The clock:**
  - It lives in `state.clock` (minutes) and only runs once the clock part is built.
  - It advances in `_process` while the town is not paused, the same rule as time played.
- **Before the part:** no tint, and the town is the day it has always been.

## 11. Art

- **The free and local rule** (2026-10-09): every new picture comes from the world pipeline (Blender blockout, then a
  ComfyUI restyle, then the cut), at 40 px tiles, in the palette.
- **The GPU:** the conductor runs it, one job at a time, under the GPU lock. Workers write specs only.

| Id | What | Footprint | Where |
|---|---|---|---|
| `item-<id>` ×16 | One icon per item (apple, cabbage, carrot, turnip, pumpkin, berries, mushroom, flower, honey, pinecone, pebble, bread, letter, gear, key, lantern-oil): one object filling a 1 x 1 tile, seen from the town's 3/4 | 1 x 1 | the Bag, pickups' flight, the full list in `items.jsonc` |
| `music-box` | A wooden music box on a short stand, lid open, a brass comb inside (a gramophone horn optional) | 1 x 1 | beside the Warm Hearth's door |
| `map-table` | Pell's map table: a wooden table with a spread map, a compass and a candle | 2 x 1 | outside Pell's cottage |

- **Placing the new assets in town** (the 2026-10-15 batch): a level pass adds them where the chapter needs them.
  - Crop rows (carrot, turnip, pumpkin, berry patches) by the cabbage plot, and a beehive, all of them pickups.
  - The music box at the inn.
  - Pell's map table.
  - The writing desk and the wall clock in the home.
  - A few benches, hedges and planters round the square for life.
  - Placing is an edit of `maps/lanternroot.jsonc` and `maps/home.jsonc`. It keeps every existing object where it is,
    puts nothing on a door's cell or a path's only way through, and passes the Studio's checks (section 15).
- **Fallbacks:** an item with no icon is drawn as a circle in its colour (`items.jsonc`'s `colour`) with its initial.
  A missing prop is skipped as the town already does.

## 12. The engine (built by the conductor first; the full interfaces are in `02-task-format.md`)

1. **Content:**
   - `tasks/<id>.jsonc`, with `<id>.starter.py` and `<id>.starter.js` beside it.
   - `items.jsonc`, `pickups.jsonc`, `places.jsonc` and `tracks.jsonc`.
   - All of it is loaded by `OverworldContent.load_world` into `catalog.tasks`, `items`, `pickups`, `places` and
     `tracks`, with schemas and cross-checks:
     - a task's giver is a townsperson;
     - a pickup's item exists and its cell is under a prop;
     - a place lies inside its map;
     - a track's id has music.
2. **Pure rules** (`game/core/overworld/`):
   - `Tasks`: stages, the cases a stage runs, the check, the reasons and the source from blocks.
   - `TaskJudges`: one static function per custom judge.
   - `Parts`: what is built, records, the menu's built list, `SHORTCUT_KEYS`, `MAP_COLOURS`, table domains, facts for
     conditions.
   - `Bag`: counting, the facts, and the pickups' regrow.
   - `Quests.holds` learns `{"has", "at_least"}` over the facts.
3. **Running** (`game/sandbox/overworld/`):
   - `tasks.py` and `tasks.js`: one generic harness that calls the entry on each list of arguments.
   - `TaskRun`: a check run, and a table run, which is the same job without wants.
4. **Blocks:** a cloze of the real lines, with switches and choices (`02-task-format.md` section 3).
   `Tasks.source(task, blocks, language)` makes the code, which then runs like typed code.
5. **State** (`OverworldState`): new fields `tasks`, `bag`, `picked`, `options`, `clock` and `tracked`, each with a
   default, normalised for old saves.
6. **Scenes:**
   - `TaskHost`, like LessonHost: opens a task from talk (`"open": "task:<id>"`), records the result, sets the
     stage's flag, and shows the banner.
   - `TaskEditor`, the generic editor: blocks or code, results, and the Hints column fed from the task's glossary.
   - `PartsRuntime`: the tables in the background, the live calls, the validations, and the stand-ins' answers. The
     overworld asks it everything about parts.
   - The UI: `PocketMenu`, `PauseMenu`'s changes, `OptionsPage`, `MusicPanel`, `BagPanel`, `WorkbenchPanel`,
     `PartBanner`, the `QuestTracker` overhaul, `Minimap`, `FullMap` and `CreditsRoll`.
7. **Studio:**
   - The flag index lists every task stage's flag as set by "the game" (task id), and the game-set flags of this
     slice: `menu-opened`, `volume-tried`, `music-played`, `picked-*`, `gave-*`, `map-opened`, `clock-evening` and
     `credits-rolled`.
   - The F3 inspector shows `state.tasks` and the bag, and its Play draft pokes include "Build part" (sets a stage's
     flag and records the reference program from the test fixtures). That poke is the only use of a reference
     solution outside tests, and only in Play draft.

## 13. The story: what the story worker builds on

The frame is fixed here. The story worker (Sonnet) writes the beats, the dialogue and the quest text in `03-story.md`,
then in content. Its rules are in `04-handoff.md`.

- **The turn.** Lighting the lane with one loop shows the tinker something:
  - Lumen says the lamps "listened".
  - Orin explains that Lanternroot was built by Makers who wrote the town's everyday parts as code, and over the years
    of the Long Hush the code went quiet, piece by piece.
  - The menu Hotaru carries in her pocket, the bells' loudness, Marta's music box, Nym's bags, Pell's maps, the town's
    clock: each one fell silent or never was.
  - The tinker is the first Maker in a long time.
- **A wink, never a lecture.** Hotaru suspects these parts are not only the town's: "Wait… is the menu part of
  Lanternroot, or part of *us*?". Nobody answers, and the credits do.
- **Each giver's want** is small, human, and ties to their part:
  - Mira likes neat devices.
  - Seren hears every sound in town and wants a knob.
  - Marta wants music for the evenings.
  - Nym has goods but no bags to sell.
  - Pell draws maps but has no colour.
  - Pip counts and wants a bar that fills.
  - Lumen keeps lamps that should know when it's evening.
  - Orin wants the tinker to sign the Engine.
- **Soup for the Hearth** is the warm side quest. Marta needs three cabbages for the soup, and giving them is the bag's
  `remove`. Marta's soup brings the town to the inn, and its music box plays.
- **The end of the chapter** is the credits: the town at night, the Root's lanterns, every part's name, and "Made by
  <name>". Afterwards the Warden mentions the Root Gate, a hook for the spells that come later, as the player said.
- **The tone:** cozy, short lines, kind, funny. Hotaru is playful and proud. It must read well to children, and later
  in Japanese (short sentences, no idioms that cannot cross over).

## 14. What is not in this slice

- **Spells and the Shardrun's link:** the player said later.
- **Rewriting the boots, memory or lamps** into the task format.
- **Japanese** for the new strings. The player said the Japanese stays as it is for now. The new English strings are
  listed for a later pass, and the known locale-coverage failure grows.
- **Editing tasks in the Studio** (the quest editor edits quests and talk, as now).
- **More with the bag:** selling, buying, using items, or a shop economy (Nym's shop is the obvious next chapter).
- **Lights, weather and sounds of steps** beyond the lamps' glow.
- **Commits** stay the player's call, as in this whole run.

## 15. Tests and acceptance

- **Pure rules:** `tasks_test`, `task_judges_test` (every reason of every judge), `parts_test`, `bag_test`, and
  `quests_test`'s new `has` cases.
- **The sandbox:** `task_run_test` covers both languages, a broken program, a missing function, a timeout, `mutates`,
  and a table run.
- **Content:** `tasks_content_test`, for every task, in both languages:
  - the reference program in `game/test/fixtures/tasks/<id>.py` and `.js` passes every stage;
  - the starter fails stage 1;
  - the Builder's start fails;
  - the fixture's block answers (`<id>.blocks.json`) pass each stage;
  - every stage's flag is unique;
  - the hints are three or more;
  - no hint, starter or glossary example contains the reference program's working line (a crude "no answers" check:
    the reference's longest code line must not appear in any of them).
- **Content checks:** `scripts/validate.sh` passes. The Studio's check of the town after the level pass shows 0
  errors.
- **The acceptance test** (`chapter2_acceptance_test`) runs headless with reference programs:
  1. Build shortcuts and menu: Esc's table gives the menu, and the menu's items are the reference's order.
  2. Options and volume: notch 5 sets the music bus to the reference loudness.
  3. Pick up an apple: the bag has one, and `picked-apple` is set.
  4. Give three cabbages: the bag loses them, and `gave-cabbage` is set.
  5. Map: the minimap texture's water cell has the reference colour, and the place under the player is right.
  6. Progress: the tracker's bar shows 50% at 2 of 4.
  7. Clock: minute 1200 gives "evening" and its tint.
  8. Credits: the lines roll and `credits-rolled` is set.
- **Screenshots, all looked at:** these `shots/v04/` moments, through `overworld_shot` and `select_shot`:
  - `pocket-menu`, `menu-built`, `task-editor`, `task-editor-blocks`, `task-results`, `part-banner`, `workbench`,
    `options`, `music`, `bag`, `pickup`;
  - `tracker`, `tracker-progress`, `minimap`, `fullmap`;
  - `evening`, `night`, `credits`, `quest-log`, `select`.
- **The suite:** the full suite ends green except the three known failures (the Shardrun loot screen, a program card
  without an upgrade, and overworld Japanese coverage). Lint is clean.

## 16. Next, after this slice

- **More with the bag:** `sort` (tidy), `use(item, player)` (eat an apple), and Nym's shop (`price`, `can_afford`)
  with coins.
- **Pip's count** (from `07-lanternroot-quests.md`). The concept's chapter 2 ideas (Brisk's tests, Nix's locks,
  Brannoc's pure functions) become parts of the game too: a test runner panel, a lock on the Archive, a forge recipe
  book.
- **The boots, the save and the lamps** in the task format, and editing tasks in the Studio.
- **Japanese** for every string of this slice.

## 17. Decisions made for the player (defaults; any can change)

1. **The menu becomes a part,** with Hotaru's pocket menu before it, rather than locked items inside the existing menu.
   Why: "creating the game from in the game" needs the menu itself to be built, not only items unlocked. The pocket
   menu keeps Quit and Settings, so nobody is ever trapped.
2. **The menu quest goes before memory** (quest 3), so "Save from the menu (Esc)" happens in the player's own menu.
3. **A Settings item stays in every menu** (the title's whole panel). The player's own Options page is extra, and it
   ends with "More settings…".
4. **Chapter 2 branches:** options and bag both open after lamps, and the tracker can follow any open quest.
5. **A day is 24 minutes played** (one town minute a second), and the clock only exists once built.
6. **Items are 16 to start,** with icons from the world pipeline at 40 px (one tile), drawn at 2x in the Bag.
7. **The shortcut keys exclude every key the town uses,** and H hides the tracker.
8. **Old saves are not migrated,** beyond default fields: test characters meet quest 3 when they are past hello.
9. **New English strings go untranslated** for now (the player's word on Japanese stands).

## 18. As built (2026-10-16): where the build differs from this spec

- **Judges:** `place_of` (map stage 2) and `next_track` (music stage 2) have judges of their own. The judges live in
  five files, one per task worker (`judges/menu`, `volume`, `bag`, `music` and `map_judges.gd`): progress is in
  `volume_judges`, clock_text is in `music_judges` and credits is in `map_judges`.
- **A missing function** is the reason `no-function`; `missing` is the menu judge's (a left-out item).
- **Shortcut keys:** H hides the tracker and is not a shortcut key (section 5.1's list has it by mistake).
- **Block shapes differ in detail from section 5:**
  - The menu's first slot chooses a whole starting list.
  - The volume's switches are labelled "Not above 10" and use the notch.
  - The bag's and the map's loops are one switch each, because a loop with no body is a syntax error.
  - The clock's "two digits" is a choice, not a switch.
- **The tint** follows its phase over about four seconds, not twenty town minutes.
- **Workbench "Check again"** runs every passed stage's cases on the program that runs.
- **The credits** list the lessons first, then the parts in the order they were built (`built_at`, in seconds played).
- **The new catalog objects placed in town:**
  - the farm by the cabbage plot (carrot, turnip, pumpkin and berry rows, a beehive);
  - by the farm: a tool rack, a compost bin and a water trough;
  - a willow and a mossy boulder by the pond;
  - cherry and golden trees, a stone bench, a mossy stump and a fallen log at the North Green and the Old Stones;
  - an open crate and a basket of apples at the shop;
  - a lantern post and a young pine on the Root Gate Road;
  - two planters by the square;
  - the wall clock at home.
  Also placed: the music box, Pell's map table, a pine and a rock. A script checked that every cell anyone could reach
  before stays reachable, and every area was looked at in screenshots.
- **The clock** starts at 17:00 the first time it is built, so the first evening comes about a minute later.
- **Pickups under a prop** and **places outside a map** are warnings, not errors: a map changed in the Studio may move
  a prop. Pickups may sit under walkable props, such as a crop row.
- **The Studio:** the flag browser lists every task stage's flag and the game-set flags of section 12.7, and its
  condition editor knows `has`.
- **Not built in this slice:**
  - the Studio's F3 "Build part" poke;
  - the gear marks beside built items in the menu and the quest log;
  - the volume's pad nudge past the ends. Stage 2 teaches it, but the Options sliders stop at 0 and 10;
  - the picked item's icon arcing into the HUD (5.6): a pick plays a chime and Hotaru says the count;
  - Pip's remark the first time the bar shows 100% (5.8).
