# Turn 2: Lanternroot's overworld, handoff and prompt

Written 2026-10-09 at the end of the session that built the overworld's first slice. Section 1 is the prompt to
paste into a fresh session. The rest is the detail it points to: what exists, where it lives, what was checked, what
is open, and how to split the next work across several agents.

---

## 1. The prompt (paste this)

> Read `AGENT.md`, `CLAUDE.md`, `WIP.md` (top section) and `Concept/v0.3/06-overworld-handoff.md` (all of it), then
> `docs/decisions/ADR-0061-lanternroot-overworld.md`, `pipeline/pixel/README.md` and `Concept/v0.3/05-lanternroot-overworld.md`.
> Run `git log --oneline -8` and `git status`.
>
> We are building Lanternroot's overworld: a top-down 16-pixel town where the player walks on movement code they
> write themselves (`on_key(key, player)`), with Hotaru the firefly beside them, light-novel dialogue with the
> townspeople's portraits, and a character creator for my daughters. The first slice is committed (602cff9 and the
> three commits before it). It works, but it isn't on the title screen yet and has no Japanese.
>
> This turn: finish slice 1 so I can play the opening start to finish from the title, in English and Japanese. Use
> the order in section 6 of the handoff. **Use a multi-agent workflow** as section 7 describes: lanes with separate
> file ownership, one Godot lock, and the GPU rule (ComfyUI and Blender never at once). Merge, then run the full
> verification yourself.
>
> My standing rules: no paid tools or assets (ComfyUI, Blender, their MCPs, code, hand-placed pixels, CC0 only).
> Keep my uncommitted files exactly as they are. Never commit `WIP.md` or `.obsidian/`. Screenshots before calling
> anything visible done. Hotaru matters (my wife loves fireflies). Dialogue should be fresh and flow naturally, not
> copied from the old game. End with what to run to play it, and anything I need to choose.

---

## 2. What the player decided (2026-10-09)

- **No budget.** Free, local tools only (now in `CLAUDE.md`). Keep `docs/ASSET_LICENCES.md` current.
- **16 px tiles**, characters shorter than the old 32 x 48 sprites. "Slightly more detailed than Pokemon" is welcome;
  simple is fine.
- **Stand-in art is fine if it can be replaced.** Publishable assets are preferred, but in-house is OK.
- **Hotaru** is the companion: a firefly (the player's wife loves fireflies). Treat her with care.
- **Part one is "create your own movement".** The code style was left to Claude: `on_key(key, player)` changing
  `player.x` and `player.y`, plus blocks for the youngest.
- **Use ComfyUI and Blender where they work.** The player first worried the hand-placed art was "terminal art"; it
  is ordinary PNG pixel art. Section 3 says why each kind of picture comes from where it does. Show evidence when
  that question comes up.
- **Dialogue is fresh and fluid**, not copied from the old game's YAML.

## 3. Where the art comes from, and why (the evidence)

| Kind | Source | Evidence |
|---|---|---|
| Characters, 16 x 24, 4 facings, walk | Hand-placed parts (`pipeline/pixel/sprites/*.sprite`), recoloured per look | ComfyUI's pose-guided walk sheets downscaled to 16 x 24 came out thin, tall and faceless (`shots/pixel/comfy-walkers.png`, regenerate from the cache `pipeline/cache/art/ow-walk-*`) versus `shots/pixel/townsfolk.png` |
| Small props (16 to 32 px) | Hand-placed (`sprites/props.sprite`) | The ComfyUI barrel and lamp post were mush (`shots/pixel/comfy-props.png`) |
| Ground tiles | Code (`pipeline/pixel/terrain.py`, dual grid) | `shots/pixel/terrain-sample.png` |
| Buildings, landmarks, trees, bigger props (32 to 96 px) | **ComfyUI**, SDXL + Pixel Art XL LoRA, background removal, palette lock | `shots/pixel/comfy-town.png`, `comfy-nature.png`: the inn, archive, shrine, hall, Root Gate and lantern tree are good |
| Portraits | ComfyUI (the townspeople's set; Hotaru's four candidates in `pipeline/cache/art/ow-portrait-hotaru/`, pick 3 in use) | `shots/pixel/hotaru-portraits.png` |
| Blender | Not used yet. Good candidates: interiors or larger landmarks rendered orthographic with flat shading, then palette-locked; or turnarounds of a chibi rig for reference | Untried |

`shots/` is git-ignored; regenerate the previews with the commands in `pipeline/pixel/README.md` if they are gone.

## 4. What exists (commits 626085c, cd8dd47, e102a78, 602cff9)

### Pipeline (`pipeline/pixel/`, `scripts/pixel.sh`)

- `palette.json`: named ramps (skins, hair, cloth, steel, gold, grass, leaf, dirt, cobble, stone, water, wood,
  plaster, thatch, glow, firefly), plus the character slots and the shared `.sprite` legend.
- `pixelkit.py`: palette, `.sprite` parser (`from`, `at`, `replace`, `shift`, `_` clears), lint, previews.
- `characters.py`: sheet layout (rows down/up/left; columns stand/step_a/step_b), recolour, compose.
- `terrain.py`: grass, dirt, cobble, water (3 ripple frames), wood floor, inside wall, void; dual-grid overlays
  for path, cobble, flowers and water.
- `build.py`: writes `game/assets/overworld/` (palette, tiles, character parts, Hotaru, props plus
  `props/props.json` frame counts, portraits copied from `Concept/v0.3/Townspeople/`) and lints. Portraits are exempt.
- `manifest.json`: ComfyUI entries (buildings, landmarks, trees, well, stall, laundry, bushes, Hotaru's portrait).
  It runs through `pipeline/art/generate.py`, which gained post kind `overworld-walk` (kept, unused) and the `lock`
  palette snap (`locked()`).
- `sprites/`: `body.sprite` (body/base), `outfits.sprite` (tunic, dress, robe, armor, coat, vest),
  `hair.sprite` (short, long, bun, spiky, fluffy, braid), `hats.sprite` (hood, kettle, visor, wide, goggles,
  leaves), `faces.sprite` (glasses, beard, mask), `items.sprite` (lantern, staff, book), `hotaru.sprite`, and
  `props.sprite` (25 props, among them the bed, desk, bookshelf, rug, window, doormat and lantern).

### Game

- `game/core/overworld/`: `overworld_map.gd` (build, blocked, warp_at, thing_at, ahead), `boots_rules.gd`
  (move kinds walk/bump/still/far/outside/error/empty; `taught`), `boots_code.gd` (blocks to Python or JS,
  starter), `talk.gd` (opening, holds, lines, choices, next, sets, remember, problems), `overworld_state.gd`.
- `game/sandbox/overworld/`: `boots.py`, `boots.js` (harnesses), `boots_run.gd` (`BootsRun.run(language, source,
  size)` gives a table of `PackedInt32Array` x, y and error per key and tile, plus `remembers` and `printed`).
- `game/content/overworld_content.gd` (`OverworldContent.load_world()`, schemas and cross-checks), and
  `game/content/packs/core/overworld/`: `terrain.jsonc`, `looks.jsonc` ("none" means nothing), `townsfolk.jsonc`
  (16 people with name, title, portrait, look, talk and voice), `maps/lanternroot.jsonc` (40 x 30) and
  `maps/home.jsonc` (11 x 8). The maps were generated by a script in the scratchpad, which is gone; edit them by hand
  now. `talk/` holds 16 townspeople plus `hotaru-wake`, `hotaru-first-step`, `hotaru-all-ways` and `hotaru-town`.
- `game/app/overworld_store.gd`: `<profile>/overworld.json`.
- `game/scenes/overworld/`:
  - `overworld.tscn` and `overworld.gd` (`OverworldScreen`): input, walking, warps with a fade, the boots table
    made on a thread, Hotaru's speech bubble, story beats, save.
  - `pixel_view.gd` (whole-number scaling).
  - `town_map_view.gd` (`TownMapView`; the name `MapView` belongs to the Shardrun).
  - `ground_layer.gd`, `walker.gd`, `hotaru_sprite.gd` (glow, light, bob, wings).
  - `dialogue_box.gd` (portrait slide, typewriter, blips, choices, `open`/`say`/`advance`, `ended(flags, opens)`).
  - `boots_editor.gd` (blocks, code, Try them, report).
  - `character_creator.gd`, `overworld_art.gd` (loading with fallbacks, look composition with recolour).
- `game/tools/overworld_shot.gd` / `.tscn`: `ROOTWARD_LANTERNTOWN=<creator|wake|home|boots|code|town|square|talk>[-ja]`.
- Tests: `game/test/core/overworld/` (boots_rules, boots_code, talk, overworld_map) and
  `game/test/sandbox/boots_run_test.gd` (real sandbox, both languages). 34 cases pass.

### The opening as written

1. First launch: the creator (name, hair, hair colour, skin, clothes, two colours, an extra, "Surprise me").
2. The house: `hotaru-wake` plays (she introduces herself; "everything runs on code, even your boots") and ends by
   opening the boots editor.
3. The player adds rules and presses "Try them". The town runs them in the sandbox and Hotaru reports.
4. The first walk plays `hotaru-first-step` (a hint that y grows going down). Teaching all four keys plays
   `hotaru-all-ways`. Walking out the door (the mat warp) plays `hotaru-town`.
5. In town: Space talks to whoever you face, or reads a sign or a shut door. B opens the boots. Esc goes to the title.

## 5. Verified, and not

**Verified:**

- The 34 tests pass, and lint is clean on the new GDScript.
- `scripts/pixel.sh` lint is clean, and `scripts/check.sh` parses everything.
- Screenshots:
  - `town`: the town, Pip, a lit lamp post and Hotaru's glow.
  - `talk`: Marta's portrait and typed line.
  - `boots`: blocks, code and Hotaru's hint.
  - `wake`: the house and Hotaru's portrait.

**Not verified or not done:**

- The **full** suite, `scripts/lint.sh` over the whole tree, and `scripts/validate.sh` were not run this session.
- No screenshot yet of the creator, the code tab, Japanese, or a choice menu.
- Walking was never driven by real key presses (only rules and screenshots). The door warps in both directions and
  saving and continuing are untested in play.
- How long BootsRun takes for the 40 x 30 town in Python (4,800 calls) was **not measured**. It is about 0.1 s on a
  6 x 4 map with start-up. Measure it. If it is slow, compute only walkable cells, or the current map's area.
- Hotaru's tiny sprite is mostly hidden by her glow in town: check `_home()`'s offset, her z order, and the glow size.
- **The first rule:** `hotaru-wake` says "I'll start you off with one rule", but the code does not place one. Add a
  `right, x, +1` rule the first time the editor opens with no blocks, with a hint that explains it.
- The dialogue and editor use the game's display font (small capitals), which is hard for children to read. Use a
  plain font (Lora or Alegreya) for dialogue, choices and the editor, and check Japanese glyphs.
- No `ja` overlay for any overworld string or talk line. `scripts/locale.sh` covers the Shardrun catalog and the
  interface strings found in the source; check whether `TextCoverage` finds `Text.t()` in the new scenes, and add
  talk lines to coverage if it does not.
- Not on the title: `Game.LANTERNROOT` still opens the letters screen (ADR-0055).
- No `docs/PLAN.md` section and no `docs/LEARNING_LOG.md` entries. The player's working copy of the learning log has
  uncommitted edits, so append ours and stage only our hunk (`git diff -U0`, filter, `git apply --cached --unidiff-zero`).
- `pipeline/pixel/` has no unittest suite yet (the convention: `python -m unittest discover pipeline/pixel`).
- Lint the slime has no sprite and is not placed. Interiors exist only for the house. There is no night, lights, idle
  animation, footstep sounds per ground, or analog stick.

## 6. Next, in order (slice 1 done, then slice 2)

1. **Wire the title.** The Lanternroot button opens the overworld. A notice board or a building in town opens the
   existing letters screen (ADR-0055), and its back button returns to town. Continue loads the save.
2. **The first rule and the opening's flow.** Pre-place the first rule with an explaining hint. Hotaru's bubble for
   "still", "far", "outside" and "error". Make sure every beat fires once and is saved.
3. **Japanese.** `game/content/packs/core/locales/ja/overworld.jsonc` for every `Text.t()` string in
   `scenes/overworld/`, every talk line and choice, townspeople's names and titles, map texts and prop texts.
   Mostly hiragana (the daughters). The town's name is ともしび村 and Hotaru is ほたる. Screenshot with `-ja`.
4. **Readability.** A plain font for dialogue and editor, larger text, and the key help visible.
5. **Measure and verify.** BootsRun timing on 40 x 30; full suite, lint, validate; screenshots of every moment in
   both languages. Drive a real walk (a test that feeds InputEventKey to the screen, or a scripted shot).
6. **Hotaru polish.** Sprite visible, glow softer, a tiny "!" when she has something to say. Ask the player
   whether pick 3 is the face they want.
7. **Slice 2 (life):** NPC idle turns and short wanders, dusk and lanterns lit (lamp post frame 1, PointLight2D,
   CanvasModulate), lit windows on buildings, footstep sounds per ground (`terrain.jsonc` `step`), voice blips,
   ambient sound. More interiors (inn, shop) with Blender or ComfyUI furniture. Lint's slime. The Root Gate as the
   future way down to the Shardrun.
8. **Docs.** A `docs/PLAN.md` section, learning-log entries (dual grid, a function as a table, whole-number scaling,
   palette lock), ADR-0061 consequences updated, and a `WIP.md` handoff.

## 7. Fanning out: a multi-agent workflow for turn 2

The player wants a multi-agent workflow. Workflows need explicit opt-in: the prompt in section 1 asks for one, or
say "use a workflow". These rules came out of earlier sessions here, where results were lost.

### Ground rules for every lane

- **Run in the foreground.** No `run_in_background`, no Monitor. Lanes that armed monitors ended early and lost their
  results.
- **One Godot lock.** Wrap every Godot command (tests, check, screenshots, imports) in
  `flock -w 580 /tmp/rootward-godot.lock <command>`, with a Bash timeout of 600000. Two Godot imports at once corrupt
  `.godot/`.
- **The GPU rule.** Only one lane may use the GPU, and it owns ComfyUI. Blender only after ComfyUI is stopped
  (`scripts/gpu-guard.sh`).
- **Stop processes by PID only, after looking at them.** A `pkill -f` pattern once killed the session's own shell.
- **File ownership.** Each lane edits only its own files. Shared files (`docs/PLAN.md`, `docs/LEARNING_LOG.md`,
  ADRs, `CLAUDE.md`, `WIP.md`) belong to the orchestrator.
- **The player's uncommitted files are off-limits:**
  - `docs/LEARNING_LOG.md` (their hunks), `game/app/settings.gd`
  - `game/assets/portraits/{emberfox,vesper}.png` and the untracked `anby`, `mana` and `vesper-v*` files
  - `game/core/shardrun/shardrun_commands.gd`
  - `game/scenes/shardrun/{card_face,room_panel,run_summary}.gd`, `game/scenes/shardrun/fight/script_belt.gd`
  - `game/scenes/title/foundry_character.gd`, `game/tools/shardrun_shot.gd`
  - `game/ui/{profile_panel,skin_selection}.gd`
  - `pipeline/sprites/*` (untracked), `Concept/v0.2/Academy/`, `Concept/v0.3/Townspeople/`, `.obsidian/`
- **Lanes do not commit.** Each lane reports its files and results; the orchestrator reviews, runs the gates and
  commits.
- **Pass each lane the project's rules:**
  - typed GDScript and gdformat with line length 120
  - tests in `game/test/`, mirroring the source
  - content keyed in English
  - `# LEARN:` comments where something is non-obvious
  - verify Godot APIs against 4.7
  - Hotaru and dialogue tone

  Specialist agents in `.claude/agents/` do not know the project.

### Lanes

| Lane | Agent type | Owns | Does |
|---|---|---|---|
| A: flow | Godot Gameplay Scripter | `scenes/overworld/overworld.gd`, `scenes/title/title.gd` (only `_open_lanternroot`), `app/game.gd` (a constant), the letters screen's back button | Section 6, steps 1, 2 and 6 (Hotaru's code side); a scripted-walk test |
| B: words | Internationalization Engineer, then Narrative Designer for tone | `content/packs/core/locales/ja/overworld.jsonc`; reads every talk file | Section 6, step 3, plus a check that every string is covered |
| C: readability | UI Designer | `scenes/overworld/{dialogue_box,boots_editor,character_creator}.gd` | Section 6, step 4; screenshots in both languages |
| D: proof | Test Automation Engineer | `test/content/overworld_content_test.gd`, `test/scenes/overworld_*_test.gd`, `pipeline/pixel/test_*.py`, a timing probe | Section 6, step 5; reports the BootsRun timing |
| E: art (GPU) | Technical Artist | `pipeline/pixel/**`, `game/assets/overworld/**` | Hotaru's sprite and glow, Lint's slime, lit windows and lamp frames, interior furniture; Blender trials for interiors |
| F: review | Code Reviewer, then Reality Checker | read-only | The whole diff against AGENT.md, then screenshots against the brief |

### Shape of the workflow

1. **Understand** (one agent, read-only): confirm sections 4 and 5 against the code, and list the strings for lane B.
2. **Build:** lanes A to E run in parallel, E alone on the GPU. Pipeline them: each lane's verify step starts when its
   build ends, not after every lane finishes.
3. **Verify per lane:** an adversarial check of each lane's claims (screenshots exist and show the thing; tests fail
   without the change).
4. **Merge and gate** (the orchestrator): import, then the full test suite, then `scripts/lint.sh`,
   `scripts/validate.sh`, `scripts/pixel.sh --lint`, `scripts/locale.sh ja --missing`, and screenshots of every moment
   in both languages.
5. **Review** (lane F), fix, commit, then `PLAN.md`, the learning log and `WIP.md`.

Keep it to about 5 to 7 agents unless the player asks for more.

## 8. Commands

```sh
scripts/pixel.sh                                   # build + lint the overworld art (no GPU)
scripts/pixel.sh --comfy 'ow-building-*'           # ComfyUI pictures (start ComfyUI first; Blender closed)
ROOTWARD_LANTERNTOWN=town scripts/screenshot.sh res://tools/overworld_shot.tscn shots/overworld/town.png 50
scripts/test.sh -a res://test/core/overworld -a res://test/sandbox/boots_run_test.gd
godot --path game res://scenes/overworld/overworld.tscn   # play it now (until the title is wired)
```

ComfyUI: `cd ~/personal-project/ComfyUI && setsid nohup .venv/bin/python main.py --listen 127.0.0.1 --port 8188 >>
.launcher/comfyui-server.log 2>&1 < /dev/null &`. It was stopped at the end of this session.
