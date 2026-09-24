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
  app/                the glue: the run session, spell runs off the main thread, saves, settings, sound (ADR-0006)
  core/               pure rules: rng, shardrun (engine, map, relics, score)
  content/            the JSON packs and their loader and validators
  sandbox/            running player code: the runner, its protocol, limits, the spell harness
  scenes/             boot, title, shardrun (map, workbench, rooms, fight: stage, foes, spell cards, log playback)
  ui/                 theme, fonts, shared controls (the code view, shard and relic cards, options)
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
- [x] Codex MCP workflow: the Godot CLI and Blender servers plus Rootward's editor bridge are configured and live-tested.
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
- [x] `tools/content/convert.ts`: the Shardrun part of the old packs and `balance.yaml` as JSONC under
      `game/content/`, comments kept, each shard's code in its own `.py` and `.js` (ADR-0004).
- [x] `Schema` and `ShardrunSchemas` with the old schemas' rules and defaults, and `ShardrunChecks` between files; the
      loader builds exactly the old engine's catalog.
- [x] `scripts/validate.sh`: every shard's 154 worked examples run in the sandbox in both languages.
- [x] Japanese overlays load, keyed by the English text; `scripts/locale.sh ja` reports 335 of 335 translated.

### Phase 4: the asset pipeline into Godot (smooth by design)
- [x] `pipeline/` with one manifest and one command per kind (`scripts/art.sh`, `audio.sh`, `character.sh`), writing
      straight into the Godot project with a GPU guard; `Art` loads by id with a null fallback (ADR-0005).
- [x] Characters: Emberfox's rig to glTF with all 11 clips, imported and tested, toon shader, ink, spring bones;
      contact sheet and close-up screenshots.
- [x] The Shardrun's 190 pictures regenerated from the cached renders (pixel-identical to the old game) and its
      audio re-encoded as Ogg Vorbis from the raw renders, with loop points.

### Phase 5: the spellbook Shardrun, playable
- [x] Title and a menu to start a run: language, difficulty; continue the run underway, or see how the last one ended.
- [x] The layer map as a place (chambers and corridors, the open rooms glowing); rewards, forge, rest, treasure,
      relics; the spellbook workbench with drag and drop (or click, then click) and a shard inspector with the code.
- [x] The fight: the stage over the painted arenas with Emberfox in 3D, foes and intents, HP and block, the code view
      playing the spell's code line by line with the measured numbers, a preview the cast lands exactly (the same
      sandbox run, ADR-0006), bolts in flight, damage numbers, hit-stop and shake, skippable.
- [x] Saves in `user://`, one run per playstyle, written atomically; a save that cannot continue is set aside.
- [x] Options (code speed, predictions, shake, music and sound volume), stats, abandon, the end of a run with its score.
- [x] Sandbox runs with the dev drawer (grant or remove shards and relics, set Integrity and mana, spawn foes, win or
      lose a fight, jump layers, add a spell), offered when the game runs from the Godot binary or with ROOTWARD_DEV=1.
- [x] Proof: a bot plays whole runs through the session and through the real run screen in tests; screenshots of
      every screen from `tools/shardrun_shot.tscn`.

Not yet (next candidates): the screens in Japanese (content is translated; the interface strings are not), a Codex,
the rules' modifiers table in Stats, keyboard focus through the map.

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
