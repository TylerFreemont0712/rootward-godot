# The plan: Rootward in Godot, Shardrun first

Decided by the player on 2026-09-24: a full rewrite in a new folder rather than an in-place migration. *"The only
thing that really needs to stick is the game concept … this is the time to do the rewrite … first we're going to be
focusing on the Shardrun piece, and making it as smooth as possible for our Blender/Godot/ComfyUI setup."* The World
comes after. The old game (`~/personal-project/ProgramMe`, tag `checkpoint-before-godot`) keeps running until this
one replaces it, and is the reference for how the spellbook Shardrun plays.

Each phase ends with tests green, screenshots of anything visible, this file ticked, and a commit.

## Layout

```
game/                 the Godot project (res://)
  core/               pure rules: rng, shardrun (engine, map, relics, score)
  content/            the JSON packs and their loader and validators
  sandbox/            running player code: the runner, its protocol, limits, the spell harness
  scenes/             boot, title, shardrun (map, fight, rewards), options
  ui/                 theme, fonts, shared controls (the code view, shard cards)
  characters/         imported characters, the toon shader, animation trees
  assets/             art and audio the pipeline exports (imported by Godot)
  i18n/               en and ja
  test/               gdUnit4 suites, fixtures from the TypeScript engine
  tools/              in-engine tools (screenshot)
pipeline/             making assets: ComfyUI art, Blender characters, audio; one manifest, one command per asset
tools/                outside the engine: fixture writers, content converters
scripts/              test, lint, screenshot
docs/                 this plan, ADRs, the learning log
```

## Phases

### Phase 0: the project and the rules of work
- [x] `game/project.godot` (4.7.2, Forward+, 1600x900, `canvas_items` stretch), the folder skeleton, `.gitignore`.
- [x] gdUnit4 6.2.1 as an addon; `scripts/test.sh` runs every suite headless.
- [x] Static typing enforced (untyped declarations are errors); gdlint/gdformat (gdtoolkit 4.5.0) as `scripts/lint.sh`.
- [x] `scripts/screenshot.sh`: a scene rendered on the GPU under Xvfb and saved to PNG.
- [x] `Rng` ported bit for bit and proven against fixtures from the TypeScript engine (the first differential test).
- [x] AGENT.md, CLAUDE.md, this plan, ADR-0001.

### Phase 1: the sandbox (go / no-go, first because it is the riskiest)
- [x] Runtime chosen: the `wasmtime` CLI as a sidecar process per job (godot-wasm has no WASI filesystem, so no
      CPython), with CPython 3.14.7 and QuickJS-ng 0.17.0 as WASI modules, pinned by SHA-256
      (`scripts/fetch-sandbox.sh`).
- [x] `Sandbox.run(job)` in GDScript: files, stdin, a time limit, a memory cap, an output cap, no network, no files
      beyond the job; the old contract's statuses. `Background.run` keeps it off the main thread.
- [x] The Shardrun spell harness returns the same bolts, traces, work and failures as the TypeScript server for 105
      spells x 3 inputs x 2 languages; the io grader grades tally-wisp as the old runners did.
- [x] Limits proven: the old runners' malicious suite ported and green, plus a read-only standard library and a
      symlink escape on cleanup.
- [x] Timing measured and written into ADR-0002: a Shardrun turn is 74 ms in Python and 11 ms in JavaScript.

### Phase 2: the Shardrun rules, proven against the old engine
- [x] `tools/fixtures/shardrun.ts`: 36 seeded runs (3,789 steps with every snapshot, refusal and preview), maps,
      pricing, clamps, relic modifiers and scores from the TypeScript engine.
- [x] `game/core/shardrun/`: map, engine (`Shardrun.step(state, command, catalog)`), commands, dev commands, battle,
      rules, relic conditions, score (ADR-0003; the state's shape in `docs/shardrun-state.md`).
- [x] Every fixture reproduced exactly, and the old unit tests' cases ported by recording the 2,517 calls they make
      (`tools/fixtures/record/`) and replaying them.

### Phase 3: Shardrun content
- [ ] `tools/content/convert.ts`: the Shardrun part of the old packs (shards, relics, foes, `run.yaml`) and
      `balance.yaml` as JSON under `game/content/`.
- [ ] GDScript validators with the old schemas' rules, run at load and in a test.
- [ ] Every shard's worked examples run in the sandbox, headless, in both languages.
- [ ] Japanese overlays load, keyed by the English text.

### Phase 4: the asset pipeline into Godot (smooth by design)
- [ ] One manifest for art, characters and audio under `pipeline/`, and one command per asset that renders it and
      writes it straight into `game/assets/` (imported by Godot, listed in a catalog, with a fallback).
- [ ] Characters: Blender to glTF with the Mixamo clips as named animations, a check that the export imports in
      Godot, and a turntable screenshot.
- [ ] ComfyUI art (arenas, foes, portraits) and audio carried over from the old repo's outputs, re-rendered only when
      needed.

### Phase 5: the spellbook Shardrun, playable
- [ ] Title and a menu to start a run: language, difficulty.
- [ ] The layer map as a place; rooms, rewards, forge, rest, treasure, relics.
- [ ] The fight: the stage over the painted arenas, foes and intents, HP and block, the code view playing the spell's
      code line by line, a preview the cast lands exactly, damage numbers, hit-stop.
- [ ] Saves in `user://`, one run per playstyle.

### Phase 6: characters and spells in 3D
- [ ] Emberfox as the first character: glTF, a toon shader (two tones, rim, outline), clips in an AnimationTree with
      blending, a looping idle, casts that release within about 0.4 s, the spell circle launching the bolts.
- [ ] Spell effects as Godot particles and shaders, per element, and the ward.
- [ ] Sound and music on audio buses with volume and mute settings.

### Phase 7: the deck playstyle
- [ ] Hand, holding, deck relics, and a run per playstyle.

### Later
The World (towns, NPCs, quests, code-graded fights), the Codex, the stats drawer, Japanese throughout, importing the
player's characters from the old game's SQLite, and retiring the old repo (only with the player's go-ahead).
