# Chapter 3, Japanese reading modes and town art: completed checks (2026-10-16)

Chapter 3 (`05-chapter-3.md`, ADR-0069), the Japanese town (`06-japanese.md`, ADR-0070), profile-persisted Japanese
reading modes, and the Lanternroot town-art/collision/terrain pass are implemented. Focused checks, lint, full content
validation and the 602-script parse sweep pass; review findings have been addressed. Nothing has been committed: the player did not ask for a
commit. `WIP.md` is the player's checkpoint, never committed.

## 1. Where it stands

**Built and passing:**
- **Eleven tasks** (count, glow, drills, locks, forge, stones, weather, hours, shop, tidy, history), each with:
  references in `game/test/fixtures/tasks/`, block answers, its judge, and a content test.
- **Eleven quests (14 to 24)** and the givers' talk: Orin's opening and ending, Hotaru's glow beat, Fern's wait for
  the rain, Nym's shop.
- **The town's wiring** (`game/scenes/overworld/overworld.gd`, the "chapter 3" section):
  - talk rewards (`receive:<item>[:n]`);
  - Pip's tally board, Nix's lockbox and Brisk's drill board;
  - Nym's shop (sell with `price` and `remove`, buy with `can_buy` and `add`, coins counted again);
  - the bag's coins, total and T to tidy, and the Workbench's history (Before/Now);
  - rain and cloud over the town;
  - people moving by the player's hours;
  - Hotaru's glow following the player's `glow()`;
  - the day counter at midnight.
- **Japanese:** every string the town shows has Japanese, and `overworld_locale_test` is 5 of 5 green: coverage
  (2,315 strings) and nothing stale.
  - Wave 1: seven files, `overworld-tasks-a/b`, `-talk-a/b`, `-screens-a/b` and `-world`, plus a consistency pass.
  - Wave 2: four files, `overworld-ch3-talk`, `-ch3-tasks-a/b` and `-ch3-screens`.
  - The profile defaults to **ひらがな** and offers **漢字（かんじ）** in title Settings → 文字とフォント and town
    pause Settings. The setting is saved per profile and can be changed live. Reviewed phrase readings keep town
    hiragana complete while preserving unknown compounds, code and inserted values; common programming terms use
    `辞書` and `オブジェクト`, and generic programming “value” uses `あたい` (rendered `値（あたい）` in kanji mode).
  - Existing parenthetical readings are kept in kanji mode and removed when hiragana mode already supplies the reading.
    Furigana uses compact parenthetical hints, not ruby layout.
- **Town presentation:** generated home/shrine sources, building wall-row masks, sparse lantern-tree collision cells,
  open-door sorting, and varied ground/creek rendering are integrated. The map schema and Studio writer preserve the
  collision fields.

**Last test results:**
- **Full suite:** 1,986 cases; the only two known failures are `shardrun_screen_test` (loot-screen error) and
  `program_upgrades_test` (missing upgrades for ten cards). The earlier 18 `studio_quests_test` fixture failures were
  fixed; that suite now passes 6 of 6.
- **Rerun green after the fixes:**
  - `chapter3_acceptance` (9);
  - `chapter3_town` (8);
  - `chapter2_acceptance`, `overworld_content`, `jsonc_writer_quests`, `quests`, `talk`;
  - `weather_judges` (9);
  - `shop_panel` and `weather_task`;
  - the locale suite.
- **Japanese live-mode regressions:** `text_test` 9/9, `quest_tracker_test` 16/16, and
  `chapter2_acceptance_test` 10/10 passed in isolated XDG data. These cover all reviewed hiragana readings, all town
  Japanese catalog strings, repeated auto-translation refresh, mounted tracker refresh, and an async place-caption
  rebuild from kana to kanji. `foundry_menu_test` 29/29 also passed. Sol independently reran the tracker and real-sandbox
  acceptance suites: 26/26 passed (`game/reports/report_1255/results.xml`). The last text/data check is 9/9 with no
  errors, failures or orphans (`game/reports/report_1256/results.xml`).
- **World and layout checks:** ground rendering 9/9; collision/content/render/map roundtrip 32/32; Studio writer/files
  37/37; Workbench layout 9/9, including geometry at 1280 and 1920 widths. The 1920 Workbench capture was inspected;
  its 1280 screenshot attempt produced no artifact.
- **Final commands:** `scripts/lint.sh` exits 0 (formatting remains advisory); full `scripts/validate.sh` passes
  77 shards and 1,036 worked examples per language with zero errors/warnings; `scripts/check.sh` exits 0 across all
  602 scripts (`/tmp/rootward-final-parse.log`, empty because there are no reported parse errors).
- The complete suite preceded the final reading-mode and town-art refinements. Those changes received the focused
  checks above; no second complete-suite rerun is claimed.

**Looked at (`shots/v04/`, gitignored):**
- `ch3-town-shop.png` and `ch3-town-bag.png`: the shop and the bag in the live town, in the rain;
- `ch3-rain-town.png`: rain and Hotaru's glow beat;
- `ch3-level-lockbox2.png`, `ch3-level-tally.png` and `ch3-level-drills.png`: the props;
- `ja-menu-hiragana.png`, `ja-shop-hiragana.png`, `ja-bag-hiragana.png`, `ja-music-hiragana.png`,
  `ja-tracker-hiragana.png`, `ja-talk-hiragana.png`, `ja-talk-kanji.png`, `ja-task-kanji.png`,
  `ja-settings-fonts-hiragana.png` and `ja-workbench-hiragana.png`: town UI in Japanese, including both reading styles
  and the live settings selector. The workbench screenshot is regenerated by the layout fix and visually inspected; the
  tracker fixture now uses the production quest text and its capture was regenerated and inspected. A fresh
  `ja-task-hiragana.png` accompanies the kanji example. All listed contexts were inspected after town art integration.
- `town-collision-home-final.png`, `town-collision-home-behind.png`, `town-collision-shrine.png`,
  `town-collision-lanterntree.png`, `terrain-variation/town-broad.png` and `terrain-variation/creek-close.png`:
  collision and terrain checks from the town pass.

## 2. Review outcome and reproduction

GPT-6 Luna handled implementation and the checkpoint. GPT-6 Sol was at capacity, so the final source, Japanese and
visual review used GPT-6.1 Sol. Its concrete findings were fixed: programming values confused with prices, partial
compound conversion, reading-hint corruption, live tracker/place text, repeated reading-table rebuilds, Workbench
overflow, and door warps disappearing with empty collision masks. Sol's independent 26-case rerun passed; its latest
review reported no remaining concrete source or visual blocker.

The delegated workers reached the workspace credit limit before the last parse result and fixture captures. The
parent completed those local checks and inspected the refreshed tracker/task; it also added the shared Close label's
`閉じる` → `とじる` reading and reran the text suite, 9/9. No additional gameplay change followed the review.

For reproduction, run Godot checks under `flock /tmp/rootward-godot.lock` with an isolated `XDG_DATA_HOME` in `/tmp`.
Use `scripts/lint.sh`, full `scripts/validate.sh`, and `scripts/check.sh`. The complete suite already ran in this
phase: 1,986 cases with the two pre-existing issues. Repeat it when a subsequent change warrants the full run.

Nothing is committed. A commit requires the player's request; never commit `WIP.md`. New untracked files include
tasks, fixtures, tests, locale files, ADRs, source art and `.gd.uid` files.

The shot commands (from the repo root):

```bash
TOLD=pocket-menu-told,own-menu-told,lamps-lit-told,wink-told,volume-told,first-pick-told,music-told,map-told,evening-told,boots-hint-seen,glow-asked,town-still-told,glow-told
CH1=met-innkeeper,met-guildmaster,read-notices,menu-asked,menu-opened,memory-asked,memory-written,saved-once,lamps-asked,lamps-written,lamps-lit
shot() { env "${@:3}" flock /tmp/rootward-godot.lock scripts/screenshot.sh res://tools/overworld_shot.tscn shots/v04/$1.png $2 < /dev/null; }
shot ja-menu 150 ROOTWARD_LANTERNTOWN=square-ja ROOTWARD_LANTERNTOWN_PARTS=all ROOTWARD_LANTERNTOWN_CLOCK=700 ROOTWARD_LANTERNTOWN_FLAGS=$TOLD,$CH1 ROOTWARD_LANTERNTOWN_CALL=_open_menu
shot ja-shop 240 ROOTWARD_LANTERNTOWN=town-ja ROOTWARD_LANTERNTOWN_AT=64,25 ROOTWARD_LANTERNTOWN_PARTS=all ROOTWARD_LANTERNTOWN_FLAGS=$TOLD,$CH1 ROOTWARD_LANTERNTOWN_BAG=apple:3,pebble:2,carrot:2 ROOTWARD_LANTERNTOWN_CALL=_open_shop
shot ja-bag 240 ROOTWARD_LANTERNTOWN=town-ja ROOTWARD_LANTERNTOWN_AT=64,25 ROOTWARD_LANTERNTOWN_PARTS=all ROOTWARD_LANTERNTOWN_FLAGS=$TOLD,$CH1 ROOTWARD_LANTERNTOWN_BAG=apple:3,pebble:2 ROOTWARD_LANTERNTOWN_CALL=_open_bag
shot ja-workbench 150 ROOTWARD_LANTERNTOWN=square-ja ROOTWARD_LANTERNTOWN_PARTS=all ROOTWARD_LANTERNTOWN_FLAGS=$TOLD,$CH1 ROOTWARD_LANTERNTOWN_CALL=_shot_workbench
shot ja-task 120 ROOTWARD_LANTERNTOWN=square-ja ROOTWARD_LANTERNTOWN_PARTS=shortcuts ROOTWARD_LANTERNTOWN_FLAGS=$TOLD,met-innkeeper,met-guildmaster,read-notices,menu-asked ROOTWARD_LANTERNTOWN_CALL=_shot_task_menu
shot ja-music 150 ROOTWARD_LANTERNTOWN=square-ja ROOTWARD_LANTERNTOWN_PARTS=all ROOTWARD_LANTERNTOWN_FLAGS=$TOLD,$CH1 ROOTWARD_LANTERNTOWN_CALL=_shot_music
```

## 3. Remaining notes (none blocks play)

**Japanese (resolved for this pass):**
- Title Settings → 文字とフォント and town pause Settings expose the per-profile **ひらがな** / **漢字（かんじ）**
  choice; new profiles default to hiragana.
- Use `辞書` for dictionary, `オブジェクト` for object, and `あたい` for a programming value. In kanji mode the value
  may appear as `値（あたい）`; existing parenthetical readings such as `番人（ばんにん）` stay intact. These are
  plain-text hints, not ruby furigana.
- Town prose has reviewed hiragana readings; unknown compounds, quoted code, identifiers and inserted values remain
  unchanged. Shardrun proper names and legacy non-town strings are outside the complete-hiragana guarantee.
- “Your lock holds” now uses 「きみの ロックは ちゃんと うごいて いるよ。」

**Design (the workers' notes):**
- **hours:** the cases pin only hours 3, 10 and 20, so the edges (6 against 7) are the player's to choose.
- **Two Builders are guessable:**
  - stones: one answer slot with three choices;
  - weather: every cloud choice passes the judge.
- **Starters:** the drills and stones starters hold all three stage functions, while the other tasks hold only the
  first.
- **Older choices hidden:** after a chapter 3 finished state, some older "change my bag, menu or save" choices no longer
  show. The Workbench still opens every part.
- **Vell's line:** his offer line is 117 characters, over the 110 limit. It is older, and it is hand-formatted.
- **The shop's list:** it has a fixed height of 360 px, which leaves a gap when there are few rows.
- **Hotaru's glow:** it is checked by a test, not by a picture, because a still cannot show a blink. A short screen
  recording would.
- **Repeated case names:** the sixty "second N" and twenty-eight "day N" case descriptions are separate keys. A
  pattern in `Text` could replace them later.

**Housekeeping:**
- Untracked probes from an earlier session are in `game/`: `probe_town_overview.gd`, `probe_front/` and
  `tmp_editor_probe/`. They are not from this work. Ask the player before deleting them.

## 4. What changed for the player

- After the credits, Orin says the town is still, and Hotaru asks for a glow of her own.
- Ten more townsfolk each bring a part, and three of them teach programming itself:
  - Brisk: writing tests;
  - Morrow: reading code;
  - Brannoc: pure functions.
- Then Nym opens a shop with coins, Mira tidies the bag, and Vell shows what changed between versions.
- With the weather and the hours built, it rains on the player's rain days and people walk to their hours.
- With the language set to Japanese, all of it is in Japanese.
