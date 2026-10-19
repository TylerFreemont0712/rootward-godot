# Handoff, 2026-10-13: Lanternroot at 40 px, the cast, the world pipeline, and Lanternroot Studio under way

Written at the end of a long session (about 14:20 on 2026-10-13) for a **fresh conversation**. Section 1 is the prompt to
paste. Sections 2 to 9 are everything the next session needs: what exists, what is half-built, what the player has
decided and still has to decide, how the multi-agent "conductor" workflow runs, and the order of work. Nothing in this
session was committed (see section 8).

---

## 1. The prompt (paste this into the new session)

> Read `AGENT.md`, `CLAUDE.md`, `WIP.md` (the top section) and `Concept/v0.3/11-studio-handoff.md` (all of it), then
> `Concept/v0.3/10-lanternroot-studio.md` (the Studio spec, all of it) and `docs/decisions/ADR-0066-lanternroot-studio.md`.
> Run `git log --oneline -5` and `git status --short | wc -l`.
>
> We are building Lanternroot Studio, the editor inside the game (spec 10). You are the **conductor**: plan, write precise
> briefs, spawn **Haiku** workers for well-defined pieces (pure code with tests, content, docs) and **Sonnet** for
> medium UI work, review everything they return (read the code, run the tests, look at screenshots), and run a small
> **Haiku checkpoint agent** after each milestone to update `docs/PLAN.md` and `WIP.md`. Section 6 of the handoff says
> exactly how. Don't hold back on using Haiku.
>
> First do section 4 (check what the S1 worker left), then continue with section 7 in order. Ask me only the questions
> in section 5 when you reach the work that needs them.
>
> My standing rules: loose rules (it runs and tests pass; style later), no paid tools or assets, never commit `WIP.md`,
> ComfyUI and Blender never at once, nothing writes the game's content files except the Studio's Publish.

---

## 2. Where things stand (one screen)

| Area | State |
|---|---|
| World scale (ADR-0064) | **Done.** 40 px tiles, 1280 x 720 view (2x on the 2560 x 1440 laptop, 32 x 18 tiles), people 64 x 96. `OverworldScale` + `game/content/packs/core/overworld/scale.jsonc` (a test keeps them equal). Older art is enlarged on load. |
| Ground tiles | **Done.** `pipeline/pixel/terrain.py` draws at 40 px (periodic noise, dither-only variation, Voronoi cobbles). `black` added to the palette for interior void. |
| Interiors | **Done.** Same scale as the town, drawn alone on pure black (`GroundLayer`). |
| The cast (ADR-0063) | **Done.** 17 sheets at 64 x 96 with a true right view (`scripts/cast.sh`). The player's notes fixed (sergeant's face and hair, staves gripped, the book, the necromancer and keeper picks). Overview: `Concept/v0.3/animation/cast/overview.png`. |
| Player customization (ADR-0065) | **Layering prototype reverted after visual review on 2026-10-17.** The player again uses one composed sheet with directional step frames; see the decision record for the prototype history. |
| The world pipeline (ADR-0064) | **Done.** `pipeline/world/`, `scripts/world.sh`, the `rootward-world-art` skill. 21 pictures adopted (re-cut ComfyUI buildings and trees), 17 made from blockouts (11 props, 6 home furniture). Reviews in `Concept/v0.3/world/`. |
| Lanternroot Studio (ADR-0066, spec 10) | **S0 done; S1 in progress (maybe partial, section 4); S2 pure parts done.** Details in section 3. |
| Lint | **Loosened on the player's word.** `.gdlintrc` flags only likely bugs; `scripts/lint.sh` passes; formatting is advice (`--fix` formats). |
| Tests | Last full suite run: 1031 cases, the 3 known pre-existing failures only (Shardrun loot screen, program upgrades, the overworld's missing Japanese). Studio: 80 core + 6 shell + 19 files, all green at 14:16. |

---

## 3. Lanternroot Studio in detail

**Spec:** `Concept/v0.3/10-lanternroot-studio.md` (phases S0 to S11, acceptance checks in section 10, agent rules in
section 11, the player's guide in section 12, open questions in section 13). **Decision:** ADR-0066. **Plan:** the
"Lanternroot Studio" section at the end of `docs/PLAN.md`.

How to see it: `ROOTWARD_STUDIO=1 scripts/play.sh`, walk into Lanternroot, press **F2** (Edit) and **F1** (Play).
Screenshot: `SHOT_SIZE=2560x1440 ROOTWARD_LANTERNTOWN=studio scripts/screenshot.sh res://tools/overworld_shot.tscn
shots/studio/studio.png 50` (also `studio-plain`; `ROOTWARD_STUDIO_OVERVIEW=1` adds the overview).

### What exists (all untracked, nothing committed)

Pure, tested headless (`game/core/studio/`, tests in `game/test/core/studio/`):

| File | Class | What | Tests |
|---|---|---|---|
| `jsonc_writer.gd` | JsoncWriter | the canonical map text (header kept, one row/object per line, whole floats written as ints) | 7 |
| `studio_doc.gd` | StudioDoc | one content file: data, header, base hash, session ids (sids) | 7 |
| `studio_commands.gd` | StudioCommands | add, remove, move, set, set_map, batch; each with an exact undo (key order kept) | 17 |
| `studio_history.gd` | StudioHistory | undo/redo stacks and labels | 5 |
| `studio_diff.gd` | StudioDiff | the changes in plain words for the Publish dialog | 20 |
| `studio_rules.gd` | StudioRules | the publish checks (errors and warnings of spec 9.5); the real maps give none | 24 |

Scenes (`game/scenes/studio/`):

| File | What |
|---|---|
| `studio.gd` (StudioMode) | the mode controller: mounts when available, F2/F1, panels, camera, overlays, picking, read-only inspector. The overworld hands it `parts` (view, map, camera, player, current, held, idle, hud, catalog, store). |
| `studio_files.gd` (StudioFiles) | the only file writer: drafts (`user://studio/drafts/`), backups, safe writes (temp then rename). 19 tests. |
| `studio_camera.gd`, `studio_overlay.gd`, `studio_pick.gd`, `studio_inspector.gd`, `studio_status_bar.gd`, `studio_top_bar.gd`, `studio_tools.gd`, `studio_style.gd`, `studio_text.gd` | S0's shell pieces |
| `studio_session.gd`, `studio_ghost.gd`, `studio_fit.gd`, `studio_assets.gd`, `studio_history_list.gd`, `studio_place_panel.gd` | **S1, written by a Sonnet worker still running when this handoff was written; may be incomplete** |

Content: `game/content/packs/core/overworld/catalog.jsonc` (81 entries in spec 8.2's tree; nothing reads it yet; it
lacks `sink` and `group` defaults, needed for the lantern, footbridge and lamps).

Changes this session to shared game files (the conductor's, keep them): `game/app/settings.gd` (`Settings.studio`),
`game/content/overworld_content.gd` (`load_world(root, drafts)`, the `flip` field on props),
`game/scenes/overworld/overworld.gd` (mounts the Studio, stops while editing, hands over `parts`),
`town_map_view.gd` (every node knows its `object_index`; props draw `flip`), `game/core/overworld/overworld_map.gd`
(`build` also returns structured `problems` with code, index and cell), `pixel_view.gd` (`to_world`).

Both map files were rewritten once in the canonical format (data checked identical): `lanternroot.jsonc` (two
hand-wrapped objects joined), `home.jsonc` (151 lines to 33).

### Phase status

- **S0 Foundations:** done except a Studio toggle in the settings screen (today `Settings.studio` in settings.json, or
  `ROOTWARD_STUDIO=1`). The checkpoint also noted: the round-trip covers maps only (other content kinds come with S8/S9).
- **S1 Arrange:** pure core done (commands, history). UI: a Sonnet worker was building it (section 4).
- **S2 Publish:** pure core done (StudioDiff, StudioRules, StudioFiles). Open: the Publish dialog and wiring, backups,
  reload, revert, conflict detection and three-way rebase; the program, placeholder and quest-reference checks wait for
  S4, S8, S9.
- **S3 to S11:** not started (S3 has the catalog content drafted).

---

## 4. First thing: what did the S1 worker leave?

A Sonnet worker was building phase S1 (spec 10, section 10) when the session ended. Its brief, which still holds: move
with a snapped green/red ghost (Alt for free placement), arrows nudge, box select, Ctrl+D duplicate, Ctrl+C/V copy and
paste, Del delete (asks for people and things), F flip (props; catalog `flippable` when present), place from a plain
list of every catalog picture (search box), E eyedropper, an editable inspector (text, name, solid, sink, facing,
draw_layer as `set` commands), undo/redo (Ctrl+Z/Y) with a history list, drafts saved (debounced and on leaving Edit)
and reloaded in a new run, Play draft (top bar toggle; saves redirected to `user://studio/playtest/` via `store.root`;
a "DRAFT" tag), the draft status text ("Draft: N changes, saved HH:MM"), and `game/test/scenes/studio_arrange_test.gd`
automating spec S1's acceptance check (move the noticeboard 3 cells, add 2 barrels, delete a bench, flip a tree, undo
all, redo, restart, content files byte-identical). It owned all of `game/scenes/studio/` except `studio_files.gd`, that
test, `studio_mode_test.gd` and a `studio-arrange` shot moment.

Do this:
1. `ls -la game/scenes/studio/ game/test/scenes/ | grep studio` and read each S1 file's top comment.
2. Parse-check and test (the lock is harmless alone):
   `cd game && godot --headless --import --path . >/dev/null 2>&1; cd ..`
   `scripts/test.sh -a res://test/scenes/studio_mode_test.gd < /dev/null` and the same for `studio_arrange_test.gd` (if
   it exists), `res://test/core/studio`, `res://test/scenes/overworld_flow_test.gd`, `res://test/scenes/town_things_flow_test.gd`.
3. Launch: `ROOTWARD_STUDIO=1 scripts/play.sh`, F2, try moving a barrel. Or the screenshot above.
4. If S1 is incomplete, brief a new Sonnet worker with the remaining S1 items (the list above minus what works),
   telling it which files exist and must be finished, not rewritten.

---

## 5. Waiting on the player (ask when the work needs it)

1. **The full customization kit** from the reverted ADR-0065 prototype is not active. Revisit a character-layering
   approach only after the player asks to resume it.
2. **A branch commit** so workers can run in isolated git worktrees (`isolation: "worktree"`): commit the current state
   to a new branch, leave `main` and `WIP.md` alone, merge only with the player's OK. (Asked; no answer: so far workers
   share the tree with strict file ownership, which works.)
3. **Spec 10, section 13** (8 questions: Godot map tool dropped; Studio from the title screen; editing people's looks;
   flip vs four-facing art; the catalog's tree; unlock rules; Japanese; named drafts).
4. **From WIP.md "Your calls":** 40 px vs 32 px tiles (one number); the creator (custom looks still use 25 x 35 parts,
   enlarged, until the full kit); the shrine's narrow picture; five buildings from ChatGPT image sources (outside the
   free-and-local rule, listed in `docs/ASSET_LICENCES.md`); the typed-GDScript rule (the one strict rule left: keep, or
   relax to a warning?).
5. **Commits:** nothing has been committed since 2026-10-09 (`89bcc9a`); the tree has 385 changed or new paths, many
   from earlier sessions. Commit only when the player says.

---

## 6. The conductor workflow (how this session ran, and should keep running)

**Models.** Haiku (`model: "haiku"`) for well-defined pieces: a pure class and its tests, content files, docs, an ADR,
reviews of facts. Sonnet (`model: "sonnet"`) for medium UI work (panels, tools, scene wiring). The conductor (you) does
architecture, edits shared files, reviews, integration, screenshots. The player said: don't hold back on Haiku.

**Every brief contains** (copy the briefs' shape from this session's: they worked):
- What Rootward is in one line, the repo path, `res://` = `game/`, `user://` = `~/.local/share/godot/app_userdata/Rootward/`.
- What to read first (spec sections by number, the exact files and classes it builds on).
- **Exactly which files it may create or change**, and that it must not edit anything else (other agents share the
  tree; much of it is uncommitted work) and must never run git commands that change anything.
- The API to build (signatures), the behaviours, and the tests to write (gdUnit4: `extends GdUnitTestSuite`,
  `test_<sentence>`).
- Conventions: typed GDScript (untyped declarations, including `for x in` loop variables, are compile ERRORS: write
  `for x: T in ...`); tabs; `##` doc comments in the codebase's plain style; no names `trait`, `log`, `set`, `_set`.
- **Godot only under the lock:** `flock /tmp/rootward-godot.lock scripts/test.sh -a res://test/... < /dev/null`
  (parallel Godot runs share the import cache). Probes: `game/probe_x.gd` with `extends SceneTree`, run with the lock
  and `< /dev/null`, then delete it and its `.uid`.
- Screenshots: free ComfyUI's GPU first (`curl -s -X POST http://127.0.0.1:8188/free -H 'Content-Type: application/json'
  -d '{"unload_models": true, "free_memory": true}'`), then `scripts/screenshot.sh` under the lock; read the PNGs.
- "Done means" and "report back briefly: files, test summary lines, decisions the brief did not settle, changes needed
  in files you do not own".

**Ownership rule.** Shared files (`overworld.gd`, `town_map_view.gd`, `overworld_content.gd`, `overworld_map.gd`,
`settings.gd`, content files) are the conductor's: make small hook changes yourself before spawning, so workers only
create or own new files. When a worker asks for a shared-file change, make it yourself (this session: the play HUD
hidden while editing, the held keys, the store).

**Reviewing.** Read the worker's code (at least the public functions), run its tests and the neighbouring suites, look at
screenshots, check its "decisions" list against the spec and fix the spec if the worker found a gap (the ADR worker found
nine; the publish-checks worker found a regex fragility, since replaced by structured problems).

**Checkpoints.** After each milestone (a phase's pieces merged), spawn a Haiku checkpoint agent that: reads the spec,
plan, WIP and ADR; lists the Studio files; runs the Studio suites and the lint under the lock; updates only the Studio
section of `docs/PLAN.md` (`[ ]`, `[~]` with "Done: ...; open: ...", `[x]`) and adds a "Studio checkpoint (HH:MM)" block
to the top section of `WIP.md`; reports drift. It edits no code.

**Parallelism.** Up to 3 or 4 workers at once worked well when their files did not overlap and each took the lock for
Godot. GPU work (ComfyUI, Blender) is one job at a time and never both: `scripts/world.sh make` and the cast's scripts
handle ComfyUI and Blender for you.

---

## 7. Next, in order

1. **Finish S1** (section 4), checkpoint.
2. **S2 Publish UI** (Sonnet): the problems panel and live status from `StudioRules` (build its `world` from the drafts,
   the catalog, the art indexes and `world/world.json` footprints), the Publish dialog with `StudioDiff.lines`, backups
   (`StudioFiles.backup`), writes (`StudioFiles.write_content` via `doc.to_text()`), reload of the content
   (`OverworldScreen.catalog_of` cache must be refreshed), Revert draft, conflict detection by `base_hash` and the
   three-way rebase of spec 9.7 (a pure `studio_rebase.gd` for Haiku first). Acceptance: spec 10, S2. Then a checkpoint.
3. **S3 Catalog:** add `sink`/`group` defaults to `catalog.jsonc` (Haiku), a catalog test (Haiku), the Sims-style panel
   with thumbnails, filters and search (Sonnet), place mode and eyedropper from it.
4. **S4 Resize, S5 Land, S6 People and doors and interiors, S7 the developer inspector**, then S8 to S11 (spec 10).
5. **After the Studio work the player listed** (in their order): the full customization kit (once approved), then the
   **startup menu redesign**: the title screen is too big; make it more interactive and fit the finer, more modern pixel
   style (`game/scenes/title/`, about 3,900 lines in 16 scripts: the foundry and its rooms). Look at it with
   screenshots first.
6. **Remaining art at 40 px** (world pipeline, `rootward-world-art` skill): fences and gates and lamps (they need a second
   frame: open, lit; the pipeline makes one frame today), the cabbage rows, the forest band, rocks, sacks, the rug and
   doormat (flat things want unforeshortened depth), the lantern (its map `sink` was for the old art), Hotaru at 40 px.
7. **A layout pass** of the town for two-tile people (doors, lanes) and **modern menus** at full resolution.
8. **Ideas from the player, not started** (`WIP.md`): wireable programmable things (`on_step`, `on_change`, links,
   weights: a plate opens a door), the players' build mode (S11), the dev inspector (S7).

---

## 8. Facts and pitfalls

- **Nothing committed** since `89bcc9a` (2026-10-09). Many uncommitted files are the player's earlier work: never revert,
  reformat or "clean up" files you did not change.
- **GPU:** 8 GB. ComfyUI and Blender never at once. ComfyUI was up at the end of the session
  (`~/personal-project/ComfyUI`, started detached with `setsid nohup .venv/bin/python main.py --listen 127.0.0.1 --port
  8188 >> .launcher/comfyui-server.log 2>&1 < /dev/null &`). `scripts/gpu-guard.sh` has `comfy_stop` and
  `comfy_start`. Free its VRAM before Godot screenshots (curl above). Never `pkill -f` a pattern that your own shell
  command line contains (it kills the shell): use the `[.]venv` bracket trick, as `comfy_stop` does.
- **Godot's JSON numbers are floats:** always `JsoncWriter.normalized()` before writing or comparing.
- **The canonical map format:** one object per line; `JsoncWriter.map_text`. Reading and writing a map unchanged gives
  the same bytes (tested).
- **Drafts:** `StudioFiles` writes only under `user://studio/` (drafts, backups, playtest saves) and, through Publish,
  the content files. Tests use temp folders under `user://studio_test/`.
- **The two solid-overlap rule:** the game refuses two solid things on one cell (`OverworldMap.build` problem code
  `overlap`), so Publish refuses it too.
- **Typed GDScript** is the one strict rule (project.godot makes untyped declarations errors; the `set` and `_set` names
  clash with Godot internals).
- **Tests:** `scripts/test.sh` (full suite about 20 minutes; 3 known failures). `scripts/test.sh -a res://test/<path>`
  for one suite or folder.
- **Background tasks die with the session**, so a long ComfyUI job started by a session must be checked in the next one
  (the caches mean re-running a stage only renders what is missing).

---

## 9. Commands

```sh
ROOTWARD_STUDIO=1 scripts/play.sh                       # the game with the Studio (F2 edit, F1 play)
scripts/test.sh -a res://test/core/studio               # the Studio's pure suites
scripts/lint.sh [--fix]                                 # loose lint (bugs only); --fix formats
SHOT_SIZE=2560x1440 ROOTWARD_LANTERNTOWN=studio scripts/screenshot.sh res://tools/overworld_shot.tscn shots/studio/studio.png 50
SHOT_SIZE=2560x1440 ROOTWARD_LANTERNTOWN=town scripts/screenshot.sh res://tools/overworld_shot.tscn shots/overworld/town.png 50
scripts/world.sh check | make --only <ids> | adopt <render> --as <id>   # the world's things (pipeline/world/README.md)
scripts/cast.sh turns | restyle | sheets                # the townspeople's sheets (pipeline/animation/README.md)
uv run --project pipeline python -m unittest discover -s pipeline/world -p 'test_*.py'      # 17
uv run --project pipeline python -m unittest discover -s pipeline/animation -p 'test_*.py'  # cast sheets
```
