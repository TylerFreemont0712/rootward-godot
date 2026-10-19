# v0.4, part 2: chapter 3, "The Town Comes Alive"

Written 2026-10-16 on the player's word: *"let's actually start with Chapter 3, write as many tests and lessons as you
can (lessons being quests...)"*, with Haiku workers. Chapter 3 builds on the engine of
`01-the-game-you-build.md` and `02-task-format.md` (tasks, stages, judges, the runtime). It adds eleven quests, each
with its own task, and a few small engine hooks so every part changes something the player can see or hold.

The rules of section 3 of 01 hold:
- real execution;
- the last passing program runs;
- validated answers;
- easy, one idea a stage;
- hints, not answers;
- Builder and Scribe;
- Python and JavaScript.

## 1. The chapter

After the credits, Orin says the town has its parts back, but it is still *still*: nobody moves, nothing grows, the
weather never changes. Chapter 3 is the town waking up:
- its people keep hours;
- the rain comes;
- Hotaru shines her own way;
- the shop opens;
- and the tinker learns to test, to read old code, to guard a lock, and to keep a history.

| # | Quest id | Title | Giver | Task: function(s) | After | What changes |
|---|---|---|---|---|---|---|
| 14 | count | Pip's count | Pip | count: `count(lanterns)` | credits | Pip's tally board by the Root says how many lanterns are lit, by your count |
| 15 | glow | Hotaru's glow | Hotaru | glow: `glow(t)` | credits | Hotaru's light shines in your pattern |
| 16 | drills | Brisk's drills | Sergeant Brisk | drills: `drills()` (three stages: write tests that catch three bugs) | credits | the drill board's three flags go green; Brisk gives a pebble medal |
| 17 | locks | Nix's lock | Nix | locks: `good_code(code)` (two stages) | drills | Nix's lockbox opens and gives you a key |
| 18 | forge | The forge never lies | Brannoc | forge: `forge(materials)` | drills | Brannoc forges you a gear; your forge function never changes what it is given |
| 19 | stones | Morrow's old stones | Morrow | stones: `answer()` (three stages: read old code, say what it gives) | count | the Old Stones' riddles are answered; Morrow gives a flower |
| 20 | weather | Fern's weather | Fern | weather: `weather(day)` | glow | rain falls in town on the days your code says |
| 21 | hours | Everyone's hours | Hollis | hours: `where(person, hour)` | weather | townsfolk walk between home, work and the inn by the clock |
| 22 | shop | Nym's shop | Nym | shop: `price(prices, item, count)`, `can_buy(coins, cost)` | forge | Nym's shop opens: sell what you pick, buy bread, oil and gears with coins |
| 23 | tidy | A tidy bag | Mira | tidy: `total(bag)`, `tidy(bag)` | shop | the bag counts everything you hold and tidies itself |
| 24 | history | Vell's changelog | Vell | history: `changed(old, new)` (two stages) | stones, tidy | the Workbench shows which lines changed in your last version |

That is eleven tasks with 17 functions' stages. Quests open by `after`, so the chapter branches three ways at once
(count, glow and drills), and the tracker follows the tracked quest.

## 2. The parts (exact functions, stages, judges)

The workers write each task's cases, blocks, hints and advice in the format of 02. Flags are
`<task>-<what>` and unique. Every judge reason gets a test.

### 2.1 count: `count(lanterns)` (Pip)

- **Gets:** `lanterns`, a list of `{"name", "lit"}`.
- **Gives:** how many are lit.
- **One stage:**
  - Flag `count-built`, judge `equals`.
  - Cases: three of five lit, all lit, none lit, and an empty list (edge, which gives 0).
- **Pip's story:** Pip counts ten when Hotaru says eleven: off by one, so count from the start.
- **In the game:** a new prop, Pip's tally board (`"opens": "tally"`), stands beside the Root. Space runs your
  `count` live on the town's lanterns (every lamp prop, lit once the lane is lit and otherwise dark) and says "Pip's
  board: N lanterns lit."

### 2.2 glow: `glow(t)` (Hotaru)

- **Gets:** `t`, a second, 0 to 59.
- **Gives:** a brightness from 0.0 to 1.0.
- **One stage:**
  - Flag `glow-built`, judge `glow_pattern`.
  - All 60 seconds are cases.
  - Every answer is a number from 0 to 1, and the pattern must blink: at least one answer at 0.3 or less and one at
    0.7 or more.
- **Teaches:** `%` and arithmetic (`t % 2`, `(t % 4) / 3`).
- **The table:** t 0..59.
- **In the game:** Hotaru's halo and light follow your table, one value a second, looping, scaled within her glow's
  range.

### 2.3 drills: `drills()` (Sergeant Brisk). Writing tests.

- **Gives:** a list of drills, each `[input, expected]`, for a function Brisk wrote that has a bug. The player writes
  tests; the game runs Brisk's buggy function and the correct one on them.
- **The judge `drills`** (all three stages):
  - Every drill's expected must be what the correct function gives (`wrong-expect`, with the input).
  - At least one drill must catch the bug, where the buggy function gives something else (`no-catch`).
  - There must be one to ten drills (`count`), each a list of two (`not-drill`).
- **Stage 1:**
  - Brisk's `double(n)` gives `n + 2` instead of `n * 2`.
  - Flag `drills-double`.
  - A drill on 2 does not catch it, which is the lesson.
- **Stage 2:**
  - Brisk's `total(numbers)` forgets the last number.
  - Flag `drills-total`, unlocked by `drills-double`.
- **Stage 3:**
  - Brisk's `first(items)` crashes on an empty list (correct: `None`/`null` for an empty list).
  - Flag `drills-first`, unlocked by `drills-total`.
- **Each stage's single case** is `{"args": [], "function": "double" | "total" | "first"}`. The judge knows the three
  functions, the correct and the buggy, in GDScript.
- **Teaches:** tests, expected answers, edge cases.
- **In the game:** Brisk's drill board (a noticeboard-style prop) lists the stages done ("Drill 1: caught!"), and the
  third stage's talk gives `pebble` (a "medal") through your `add`.

### 2.4 locks: `good_code(code)` (Nix)

- **Gets:** `code`, text.
- **Gives:** `True`/`true` when it is a good lock code.
- **Stage 1:**
  - Flag `locks-built`.
  - A good code is exactly 4 characters, all digits.
  - Cases: "2580" true, "12a4" false, "123" false, "12345" false, "" false (edge).
- **Stage 2:**
  - Flag `locks-strong`, unlocked by `locks-built`.
  - Not all four the same either: "1111" false, "1112" true.
  - Plus every stage 1 case.
- **Judge** `equals`.
- **Teaches:** text length, checking each character (`isdigit`, or `/^[0-9]+$/` or a loop), "thinking like a thief".
- **In the game:** Nix's lockbox (a crate prop with `"opens": "lockbox"`) opens once `locks-strong` is set: Nix's talk
  gives `key` through your `add`.

### 2.5 forge: `forge(materials)` (Brannoc)

- **Gets:** `materials`, a list of material names.
- **Gives:** the tool they make: `["iron", "wood"]` gives "hammer", `["iron", "iron"]` gives "gear", `["wood",
  "wood"]` gives "stick", and anything else gives "nothing". Order does not matter.
- **One stage:**
  - Flag `forge-built`, judge `forge_pure`.
  - The answer must be right, and the function must not change its list (`changed-input`, read from the harness's new
    `args_after`, section 3).
  - Cases include `["wood", "iron"]` (order) and `[]`.
- **Teaches:** pure functions (sort a copy, not the list you were given), lookups.
- **In the game:** Brannoc's talk forges a `gear` for you, through your `add`.

### 2.6 stones: `answer()` (Morrow). Reading code.

- **Gives:** what an old piece of code gives back. Each stage's goal shows a short snippet, in the player's language
  (Python, or JavaScript), in the stage's `goal`. The function returns the value that snippet would give.
- **Three stages,** flags `stones-1`, `stones-2` and `stones-3`, each unlocked by the one before. Judge `equals`.
  - **Stage 1:** a loop adding 1, 2 and 3 gives 6.
  - **Stage 2:** an `if` on a word's length gives "long".
  - **Stage 3:** a list built backwards gives [3, 2, 1].
- **The snippets** live in the stage's own glossary example (`words`), shown in the Hints column, and in the goal. This
  task's hints are about reading code, never the answer.
- **Teaches:** reading code, tracing a loop.
- **In the game:** Morrow's talk after the third stage gives a `flower` ("the stones bloom").

### 2.7 weather: `weather(day)` (Fern)

- **Gets:** `day`, the town's day number from 0.
- **Gives:** "sun", "rain" or "cloud".
- **One stage:**
  - Flag `weather-built`, judge `weather_week`.
  - Cases: days 0..27.
  - Every answer is one of the three; in every 7 days in a row there is at least one rain and at least one sun.
- **Teaches:** `%` patterns, `if`/`elif`.
- **The table:** days 0..27, then repeating (day % 28).
- **In the game:**
  - **The day counter:** `state.day` grows by one each time the clock passes midnight. It is a new state field,
    default 0.
  - **Rain:** on a rain day, rain falls over the town, an overlay of drops drawn over the town but not over the UI.
    "cloud" makes the tint a little greyer, and "sun" changes nothing.
  - **Before the clock is built** there are no days, and the weather is always sun.

### 2.8 hours: `where(person, hour)` (Hollis)

- **Gets:** `person`, a townsfolk id, and `hour`, 0 to 23.
- **Gives:** "home", "work" or "inn".
- **One stage:**
  - Flag `hours-built`, judge `hours`.
  - Every answer is one of the three.
  - Cases: for any person, hour 3 gives home, 10 gives work and 20 gives inn. The player may refine further, but
    these must hold.
- **Teaches:** ranges (`if hour < 7`), `and`/`or`.
- **The table:** the scheduled people × 24 hours.
- **In the game:**
  - `schedules.jsonc` gives six to eight townsfolk three spots each on the town map: home, work and inn. Each spot is
    a free, walkable cell, checked by the content loader.
  - When the clock's hour changes, every scheduled person whose answer changed moves to that spot. If the player
    stands on the spot, they wait an hour.
  - Talk works wherever they stand. Before the part is built, people stand where the map puts them.

### 2.9 shop: `price(prices, item, count)` and `can_buy(coins, cost)` (Nym)

- **Stage 1, `price`:**
  - Gets the shop's prices (a dictionary `{item: coins}`), an item and how many.
  - Gives the coins, `prices[item] * count`, or 0 when the item is not in prices.
  - Flag `shop-price`, judge `equals`.
- **Stage 2, `can_buy`:**
  - Gives `True` when coins are at least the cost.
  - Flag `shop-buy`, unlocked by `shop-price`. Judge `equals`.
  - Cases include exactly enough (edge).
- **In the game:**
  - The state's coins are a new field, default 0.
  - **Nym's shop panel** opens from Nym's talk (`"open": "shop"`).
    - **Sell:** your bag's stacks, with the price for one and for all from your `price`, a live call. Selling runs your
      `remove` once for each item sold, and the coins go up.
    - **Buy:** bread (5), lantern oil (8) and a gear (12). Your `can_buy` decides, live, and your `add` puts the item in
      the bag.
  - `shop.jsonc` holds what Nym buys (and for how much) and sells.
  - The Bag panel shows your coins.

### 2.10 tidy: `total(bag)` and `tidy(bag)` (Mira)

- **Stage 1, `total`:**
  - Gives how many things are in the bag, all counts added.
  - Flag `tidy-total`, judge `equals`.
  - Cases include an empty bag.
- **Stage 2, `tidy`:**
  - Gives the bag sorted by item name, A to Z.
  - Flag `tidy-sorted`, judge `tidy_sorted`: the same stacks, in name order (`not-sorted`, `lost`).
- **Teaches:** sums, sorting (`sorted(..., key=...)` or a simple sort), and the "same things, new order" idea.
- **In the game:** the Bag panel's header says "12 things" (your `total`, a live call), and T tidies the bag (your
  `tidy`, a live call, judged as in the task before the bag is replaced).

### 2.11 history: `changed(old, new)` (Vell)

- **Gets:** two lists of lines.
- **Gives:** the numbers of the lines that differ, counted from 1.
- **Stage 1:**
  - The lists are the same length.
  - Flag `history-built`, judge `equals`.
- **Stage 2:**
  - New lines at the end count as changed.
  - Flag `history-longer`, unlocked by `history-built`.
- **Teaches:** two lists side by side, indices, `len`/`max`.
- **In the game:** a task's record keeps its last five passing programs (`versions`, oldest first). The Workbench's side
  panel says "Changed since the version before: lines 3, 5", from your `changed`, a live call. It also lets you view
  the version before.

## 3. Engine additions (the conductor's)

- **The harness's `args_after`:** a call may ask `"args_after": true`, and the result then carries the arguments as
  the function left them. A stage says `"args_after": true` (the task schema learns it), and the judge reads
  `results[i].args_after`.
- **Talk opens:**
  - `"open": "receive:<item>[:n]"` gives items through the player's `add` (a reward).
  - `"open": "shop"` opens the shop.
- **Prop opens:** `"opens"` learns "tally", "lockbox" and "drills" (the board).
- **State:**
  - `day` (0), `coins` (0), and each task record's `versions`, the last five passing programs.
  - Normalised for old saves.
- **Content:**
  - `schedules.jsonc` (person → {home, work, inn: [x, y]}) and `shop.jsonc` (buys, sells).
  - Both are loaded and cross-checked:
    - each spot is a walkable, free cell of Lanternroot;
    - each item exists.
- **PartsRuntime:** the tables for glow, weather and hours; the live calls for count, price, can_buy, total, tidy and
  changed; and the validations.
- **Overworld:**
  - Hotaru's glow follows the glow table.
  - Rain falls on rain days.
  - People move by the hours table.
  - The tally board, the lockbox and the drill board each open.
  - The shop opens, and rewards are given.

## 4. Who builds what (Haiku, as the player asked)

- **The conductor:** this spec, the engine (section 3), the overworld wiring and the reviews.
- **Haiku task workers, five, two tasks each:**
  - count and glow;
  - drills and stones;
  - locks and forge;
  - weather and hours;
  - shop, tidy and history (one worker does three small ones).
- **Haiku story workers, two:**
  - the quests (quests.jsonc) and the talk of Pip, Hotaru (beats), Brisk, Nix, Brannoc and Morrow;
  - Fern, Hollis, Nym, Mira and Vell, and Orin's chapter 3 opening.

  The beats are in section 1's table and section 5.
- **Haiku UI worker:** the shop panel, the bag's coins, total and tidy, and the Workbench's history line.
- **Haiku level worker:** `schedules.jsonc`; the tally board, lockbox and drill board props; and `shop.jsonc`.
- **Checks:** a Haiku checkpoint, then an Opus final check.

## 5. Story beats (for the story workers)

- **Opening:**
  - After `credits-rolled`, Orin: "Lanternroot has its parts back, but it is so still. Nobody keeps an hour. Not even
    the rain."
  - Hotaru: "Then let's wake it up!"
- **Pip** wants to prove he can count. Hotaru teases him about ten against eleven; the tally board is his pride.
- **Hotaru** asks the tinker to give *her* a glow of her own (the first part that is about her). This beat is a gift.
- **Brisk:** "Someone wrote my drills wrong. A drill that never fails catches nothing." Write tests that catch three
  bugs.
- **Nix:** "A lock is only as good as the codes it refuses." Nix tests the tinker's checker with tricks.
- **Brannoc:** "The forge never lies. Same iron in, same tool out, and nothing else touched."
- **Morrow:** the old stones carry old code. "Tell me what they say, and they can rest."
- **Fern:** the grove needs rain, so write the weather.
- **Hollis:** the guard is tired of standing in one place all day, and so is everyone.
- **Nym:** at last, a shop with prices.
- **Mira:** the bag needs tidying ("a neat bag is a happy bag").
- **Vell:** every version of your code is a page in the Archive, so make the changelog.
- **The end:** when all eleven are done, Orin notes that the town keeps its own time now. The Warden's line about the
  Root Gate "listening" remains the hook for the spells chapter.

## 6. As built (2026-10-16)

What differs from the sections above, and why:

- **glow's giver** is Lumen (`oracle`) in `quests.jsonc`, since Hotaru is not a townsperson. Hotaru asks herself, in a
  beat (`hotaru-glow`). The beat comes after Orin's opening, or after Pip's count or Brisk's first drill for a player
  who went there first (ADR-0069, beats in OR). Lumen offers the task again while it is asked and not built.
- **history** is `changed(old, latest)`: `new` is a reserved word in JavaScript.
- **Fern's "wait for the rain"** (`"open": "next-rain"`): the town sleeps to the morning of the next day the player's
  `weather()` says rains, so the quest's last step takes seconds, not up to six town days.
- **Orin's opening** sets `town-still-told`, and plays once after the credits, until rain or hours are seen. His ending
  needs rain, hours and history seen, and plays once (`town-time-told`).
- **Hollis** offers the hours once the weather is built (`weather-built`), not after the first rain.
- **Judges** give a few reasons beyond the spec's, each tested:
  - drills: `not-drill` (an input of the wrong kind) and `unknown-function` (a content slip);
  - tidy: `not-list`, `not-stack` and `invented` (a stack the bag did not have);
  - forge: `not-checked`, when a result has no `args_after`.
- **Nix's lockbox** is a crate at (64, 30), beside a barrel: at (66, 29) the big tree's canopy hid it.
- **The shop** shows the coins in the bag once the shop task is started, and T tidies only once tidy stage 2 passes.
