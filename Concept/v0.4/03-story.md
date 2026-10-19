# v0.4 story: chapter 2, "The Workshop Inside"

Written 2026-10-15 by the story worker. This is the flow of the story for the slice in `01-the-game-you-build.md`
(section 13 is the brief). The words themselves live in `quests.jsonc`, `talk/*.jsonc` and the new `talk/hotaru-*.jsonc`.
Every line is short, kind and plain enough to cross into Japanese, and no one says the code answer: a person says what
a part should DO, and the editor's hints do the rest.

## The arc

1. **Chapter 1 now has a new middle.** Mira's menu (quest 3) comes before the save. The tinker builds a
   key and a menu, then a save, then lights the lane.
2. **The turn.** The lane lights at once, and Lumen says the lamps *listened*. They have never listened to her. Hotaru
   asks if that is unusual. It is. "Ask Elder Orin about the Makers."
3. **The Long Hush.** Orin tells it plainly. Lanternroot was built by Makers, who wrote the town's everyday parts as
   code: keys, menus, the bells' loudness, the inn's songs, bags, maps, the clock. Then came the Long Hush, and the code
   went quiet piece by piece. Some parts fell silent, some were never finished, and the town learned to live without
   them. The tinker is the first Maker in a long time. (Hotaru: "Tinker. Maker. It's the same word in a different hat!")
4. **Mending, in any order.** Seren and Nym open after the lamps. Marta, Pip, Pell and Lumen's clock open as their
   parts come. Each giver wants one small human thing (a neat device, a knob, evening music, a bag, colour, a bar that
   fills, a lamp that knows evening). Nobody explains the whole chapter. Orin's talk just says "in any order".
5. **The wink.** After Orin's story Hotaru thinks aloud: "Is the menu part of Lanternroot? Or part of *us*?". Nobody
   answers. It is light, one beat, and she shrugs it off.
6. **The credits are the answer.** When everything works, Orin offers the Book of Makers. The tinker's `credits` function
   writes their own name and every part they built, the Root reads it out, and "Made by <name>" ends it. The game
   answers the wink: the parts are *theirs*. Afterwards the Warden mentions the Root Gate sealed but listening, the hook
   for the spells that come later.

Tone rules: Hotaru is playful, curious and proud. Each giver keeps the voice of their file (Mira: eager, "machines do
what they're told"; Seren: calm and dreamy; Marta: warm; Nym: dry, "very, very nearly"; Pell: bubbly; Pip: sharp and
loud-whispering, counts; Lumen: solemn and poetic; Orin: slow and gentle).

## The quests

Every quest's steps follow one pattern: the giver's ask, one step for each task stage built, then a "use it" step when
the game sets a flag. A giver's offer (the `offer` node) shows once the quest before it has its last flag set, because
Talk cannot read quest status. The tracker is still the truth: a quest is locked until its `after` quests are done.

### 3. A key for every door (Mira, artificer; after hello)

- **Want:** Mira likes neat devices. Esc opens only Hotaru's pocket menu, and a menu is a door that needs a key.
- **Beats:** Mira asks if you pressed Esc. Hotaru defends her pocket menu. Mira builds the key first (shortcut), then the
  list behind it (menu_items). "Continue goes first and Quit goes last, or people get grumpy" (Hotaru).
- **Steps and flags:** `menu-asked` (Mira's teach node), `menu-key-written`, `menu-built`, `menu-opened` (the game).
- **Hotaru:** `hotaru-pocket-menu` on the first Esc, and `hotaru-own-menu` on the first real menu: "That's YOUR menu!".
- **Hands off:** to Vell (memory, now after menu). "Save from the menu" now happens in the player's own menu.

### 4 and 5. Remember me, Light the lane (Vell, Lumen; existing)

Their steps and flags are unchanged. `memory` is now order 4 after `menu`, and `lamps` is order 5. Lumen's turn (above)
follows `lamps-lit`, once: `turn-told` makes her ordinary `glow` node return afterwards.

### 6. Turn it up (Seren, summoner; after lamps)

- **Want:** Seren hears every sound in town at full volume, and wants a knob. ("I can hear a cabbage thinking.")
- **Beats:** a page with rows (options), then a notch to a loudness (volume), then "past the ends": a pad can push a
  slider below none and above all. Hotaru: "Louder than loud? That sounds like trouble."
- **Steps and flags:** `options-asked`, `options-built`, `volume-built`, `volume-clamped`, `volume-tried` (the game).
- **Hotaru:** `hotaru-first-volume` at `volume-tried`: the little chart is "the shape of your code".
- **Hands off:** to Marta (music, after options) and Pip (progress, after options and bag). Seren's last line is that
  Lanternroot "has a volume of its own".

### 7. The music box (Marta, innkeeper; after options)

- **Want:** music for the quiet evenings, in the box beside her door.
- **Beats:** the box has no names (titles), then no way to go on (next_track, going round after the last).
- **Steps and flags:** `music-asked`, `music-listed`, `music-next`, `music-played` (the game).
- **Hotaru:** `hotaru-first-song` at `music-played`.
- **Hands off:** to Orin's credits. Marta also mentions the soup as an extra choice, so neither quest hides the other.

### 8. A bag of your own (Nym, quartermaster; after lamps)

- **Want:** full shelves and nowhere to put things (a cabbage rolled all the way to Marta's).
- **Beats:** a bag of piles, each with a name and a number (add). Then "a bag you cannot open is only a very small
  cupboard", so Nym sends the tinker back to Mira's key machine (shortcut stage 2, `task:shortcuts`).
- **Steps and flags:** `bag-asked`, `bag-built`, `bag-key-written`, then three different `picked-*` (the game).
- **Hotaru:** `hotaru-first-pick` on the first pick-up. Before the bag exists the game's own "where would we put them"
  line stands.
- **Hands off:** to Marta (soup), Pell (map) and Pip. Nym ends on "Very, very nearly?" / "Do not start.".

### 9. Soup for the Hearth (Marta; after bag)

- **Want:** cabbage soup for the whole town, three cabbages from the plot in Home Hollow (the one the boots' gate opens).
- **Beats:** "A bag that only takes is a bit greedy" (Hotaru). The bag learns to give (remove). Then Marta sees three
  cabbages and asks for them; `give:cabbage:3` runs the player's `remove` three times. Thanks: "your bag gave them
  without losing a leaf".
- **Steps and flags:** `soup-asked`, `bag-remove`, `picked-cabbage` (the game), `gave-cabbage` (the game),
  and `soup-thanked` (a talk flag, so the thanks plays once and never hides the music quest).
- **Hands off:** to the credits.

### 10. Pell's little map (Pell; after bag)

- **Want:** every street is drawn, all in grey, and she cannot tell water from grass.
- **Beats:** colours (map_colour), then names ("point at nowhere and it says nothing"), then the map's key (shortcut
  stage 3), then open it.
- **Steps and flags:** `map-asked`, `map-built`, `map-places`, `map-key-written`, `map-opened` (the game).
- **Hotaru:** `hotaru-map-opened`.
- **Hands off:** to Lumen's clock (after map).

### 11. Pip's progress (Pip; after options and bag)

- **Want:** Pip dislikes halves. He wants a number out of one hundred for the tracker's bar.
- **Beats:** Hotaru asks about a quest with no steps ("...Do not ask me that."). At the end Hotaru still says eleven
  lanterns, and Pip says TEN.
- **Steps and flags:** `progress-asked`, `progress-built`. No game flag (the tracker's bar is the use).
- **Hands off:** to the credits.

### 12. What time is it? (Lumen, oracle; after map)

- **Want:** her lamps should know when evening comes. Today Lanternroot has no clock: "it is always now".
- **Beats:** day and night (time_of_day), then words for the clock (clock_text). Hotaru: "A clock that says seven colon
  five makes me sad." Then wait for the first evening and watch the lane glow. "The Makers would have liked you."
- **Steps and flags:** `clock-asked`, `clock-built`, `clock-text`, `clock-evening` (the game).
- **Hotaru:** `hotaru-evening` at `clock-evening`.
- **Hands off:** to the credits.

### 13. Sign your work (Orin, guildmaster; after music, soup, map, progress, clock)

- **Want:** Orin wants the tinker to sign the Book of Makers, and to see the Lantern Engine (the Workbench's gears) turn.
- **Beats:** the offer; the page; then `roll`, where Orin and Hotaru wait for the Root to read the lines, and the
  node opens `credits`. After the credits Orin points at the Warden.
- **Steps and flags:** `credits-asked`, `credits-built`, `credits-rolled` (the game).
- **After:** the Warden says the gate is sealed but now listening, and that below it are "spells nobody has written yet".

## Hooks for the conductor

Hotaru's beats are talk files for moments she speaks alone. Each has one node and sets its own `*-told` flag, so the
conductor opens a beat when its trigger first becomes true and its told flag is not yet set.

| File | Open it when | Sets |
|---|---|---|
| `hotaru-pocket-menu` | Esc (or Start) opens the pocket menu for the first time, once it closes | `pocket-menu-told` |
| `hotaru-own-menu` | `menu-opened` is first set, after the menu has flown in | `own-menu-told` |
| `hotaru-lamps-lit` | `lamps-lit` is first set and the lane has finished lighting | `lamps-lit-told` |
| `hotaru-wink` | `makers-told` is set and the tinker is next free in the town | `wink-told` |
| `hotaru-first-volume` | `volume-tried` is first set | `volume-told` |
| `hotaru-first-pick` | the first `picked-*` flag is set, with the bag built | `first-pick-told` |
| `hotaru-first-song` | `music-played` is first set | `music-told` |
| `hotaru-map-opened` | `map-opened` is first set | `map-told` |
| `hotaru-evening` | `clock-evening` is first set | `evening-told` |

Other hooks:

- **Esc with the shortcut broken** and the unbuilt-panel lines ("The bag isn't built yet. Nym can help!") belong to the
  game, not to a talk file.
- **`give:cabbage:3`** must set `gave-cabbage` on success and reopen Marta's talk, whose first start rule is `soup_thanks`.
- **`credits`** (Orin's `roll`) must set `credits-rolled` when the roll ends. Orin's `after_credits` can roll them again.
- **Vell's offer** (`archivist.jsonc`) is gated on `menu-opened` (the Haiku checkpoint's fix, 2026-10-16), so her
  save lesson follows Mira's menu in talk as well as in the tracker.
- **Old saves** past hello see Mira's offer on their next visit; nothing else of theirs changes.

## Notes for the review

- **The "Gather 3 cabbages" step** uses `picked-cabbage` (durable), not `{"has": "cabbage", "at_least": 3}`. A `has`
  step turns false once the cabbages are given, so `steps_done` would stop at it, the quest would reopen and
  `credits` would stay locked. Marta's talk uses `has` where it is safe (her `soup_have` start rule and its choice).
  If `Quests` gains a latch or an `any`, the step can switch back.
- **Talk cannot count** (`met-`, `picked-`), so offers lean on the stage flags named above.
- **Moods:** only `happy` is used, as everywhere in the existing talk.
