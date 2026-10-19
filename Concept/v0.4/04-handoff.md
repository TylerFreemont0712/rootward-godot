# v0.4: who builds what

The conductor (Claude) builds the engine and integrates. Haiku workers write the tasks, the art specs and the level
pass. Sonnet workers write the story and the UI. An Opus checker reviews the final output. A Haiku checkpoint runs after
the middle milestone. This is the player's split of 2026-10-15, on the conductor workflow (`Concept/v0.3/11`).

## The rules every worker gets (they do not know this project)

- **The working agreement:** read `AGENT.md` and `CLAUDE.md` first; they are the working agreement. Then read this
  folder: `01-the-game-you-build.md`, `02-task-format.md`, and your part below.
- **Code:**
  - Typed GDScript everywhere (untyped declarations are errors).
  - `game/core/` stays pure: no nodes, no I/O, no `randf`.
  - Godot 4.7: verify an API in the engine or the docs; do not guess.
- **Running Godot:**
  - Only under the lock, with standard input closed: `flock /tmp/rootward-godot.lock <command> < /dev/null`.
  - Tests: `flock /tmp/rootward-godot.lock scripts/test.sh -a res://test/<your suite> < /dev/null`.
  - Run your own suites, not the whole suite (the conductor runs it).
  - The parse check: `scripts/check.sh`.
- **Never:**
  - commit, or edit `WIP.md`;
  - edit locale files (Japanese stays as it is);
  - run ComfyUI or Blender (the conductor runs the GPU);
  - use a paid tool or asset;
  - stop the launcher on port 7331;
  - touch `~/personal-project/ProgramMe`.
- **Hints, not answers.** No starter, hint, glossary example or line of talk may give the player the solving line.
- **Only your files.** Edit only the files your part owns. If you need a change elsewhere, say so in your report and
  the conductor makes it.
- **Look at what you make.** Screenshot anything visible (`scripts/screenshot.sh`, `tools/overworld_shot.tscn`) into
  `shots/v04/` and look at it before you call it done.
- **Report:**
  - the files changed;
  - the tests run, with their result lines;
  - the screenshots looked at;
  - anything skipped or left open, said plainly.

## Waves

| Wave | When | Who | Part |
|---|---|---|---|
| 0 | first | conductor | the engine core: Tasks, TaskJudges' dispatch and stubs, harness, TaskRun, Parts, Bag, state, content loading, PartsRuntime's skeleton, the `shortcuts` task as the template |
| 1 | at once | Sonnet **story** | `03-story.md`, quests.jsonc, the givers' talk, Hotaru's beats |
| 1 | at once | Sonnet **hud** | QuestTracker overhaul, Minimap, FullMap, quest log Track, character select made basic |
| 1 | at once | Haiku **art** | world-pipeline specs: 16 item icons, music box, map table |
| 2 | engine landed | Haiku **t-menu** | tasks `menu`, `options` |
| 2 | engine landed | Haiku **t-volume** | tasks `volume`, `progress` |
| 2 | engine landed | Haiku **t-bag** | task `bag`, `items.jsonc` |
| 2 | engine landed | Haiku **t-music** | tasks `music`, `clock`, `tracks.jsonc` |
| 2 | engine landed | Haiku **t-map** | tasks `map`, `credits` |
| 2 | engine landed | Sonnet **editor** | TaskEditor (blocks cloze, code, results, hints), WorkbenchPanel, PartBanner |
| 2 | engine landed | Sonnet **menus** | PocketMenu, PauseMenu's list, OptionsPage, MusicPanel, BagPanel, CreditsRoll |
| 3 | art made | Haiku **level** | place the new assets, `pickups.jsonc`, `places.jsonc` |
| 3 | all in | conductor | wiring into the overworld, PartsRuntime's tables and live calls, day and night, acceptance |
| 4 | | Haiku **checkpoint** | review against the spec; list what is missing or wrong |
| 5 | | Opus **checker** | the final review of the output: correctness, the spec, the player's brief, screenshots |

## File ownership

| Owner | Files |
|---|---|
| conductor | `game/core/overworld/{tasks,task_judges,parts,bag}.gd`, `game/core/overworld/{quests,talk}.gd` (the `has` condition), `game/core/overworld/overworld_state.gd`, `game/sandbox/overworld/{tasks.py,tasks.js,task_run.gd}`, `game/content/overworld_content.gd`, `game/scenes/overworld/{overworld,parts_runtime,task_host}.gd`, `game/scenes/studio/studio_quest_work.gd`, `tasks/shortcuts.*`, the test helpers `game/test/content/task_check.gd`, docs |
| story | `Concept/v0.4/03-story.md`, `quests.jsonc`, `talk/*.jsonc` (existing files: add, never remove a node another quest uses), new `talk/hotaru-*.jsonc` |
| hud | `quest_tracker.gd`, `quest_log.gd`, new `minimap.gd`, `full_map.gd`, `character_select.gd`, `character_card.gd`, their tests, `tools/overworld_shot.gd` (new moments only, at the end of its match), `tools/select_shot.gd` |
| art | `pipeline/world/objects/item-*.jsonc`, `music-box.jsonc`, `map-table.jsonc` |
| t-* | `game/content/packs/core/overworld/tasks/<their ids>.*`, `game/core/overworld/judges/<task>_judges.gd`, `game/test/core/overworld/judges/<task>_judges_test.gd`, `game/test/fixtures/tasks/<their ids>.*`, `game/test/content/tasks/<id>_task_test.gd`; t-bag also `items.jsonc`, t-music also `tracks.jsonc` |
| editor | new `task_editor.gd`, `task_blocks.gd`, `task_results.gd`, `workbench_panel.gd`, `part_banner.gd`, `code_glossary.gd` (a task branch only), their tests |
| menus | new `pocket_menu.gd`, `pause_menu.gd`, new `options_page.gd`, `music_panel.gd`, `bag_panel.gd`, `credits_roll.gd`, `dialogue_box.gd` (text speed only), their tests |
| level | `maps/lanternroot.jsonc`, `maps/home.jsonc` (add objects only), `pickups.jsonc`, `places.jsonc` |

## Done means

- Each worker:
  - its suites green;
  - `scripts/check.sh` clean;
  - its screenshots looked at;
  - its report.
- The slice:
  - section 15 of `01-the-game-you-build.md`;
  - `docs/PLAN.md` ticked;
  - ADR-0068;
  - the learning log;
  - WIP.md's top section;
  - no commit (the player's call).
