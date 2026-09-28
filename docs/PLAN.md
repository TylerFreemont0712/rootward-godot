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
- [ ] Vesper, the Star-Script Witch, as a new skin. [x] Modelled and rigged in code (ADR-0007), then set aside for
      a sprite version. [x] A small, cute sprite Vesper from ComfyUI (ADR-0008, `scripts/sprites.sh`): an idle and a
      cast, in the fight and the wardrobe. [ ] Her other clips (hurt, guard, victory, death, a heavy cast).
- [x] Spell sprites from the concept boards (ADR-0008): a bolt and a burst per element, a casting seal, a ward, each
      animated by one shader (dissolve, reveal, wobble, shimmer), flashes, shockwaves and sparkles.
- [x] Spell variety (ADR-0009): heavy spells call their element's strike down on each foe (lightning, a fire pillar,
      ice spikes, starlight) under a darkened stage and a vortex at the hand; a volley on several foes sends a wave
      across the floor.
- [ ] Spell effects as Godot particles and shaders, per element, and the ward.
- [ ] Sound and music on audio buses with volume and mute settings.

### Phase 7: the deck playstyle (the Shardrun, now the main mode)
- [x] A run per playstyle, chosen on the title: Shardrun (cards) and Spellforge (the spellbook) (ADR-0009).
- [x] The table: a hand dealt each turn, cards played by click or drag into blank spells, holding, the draw and
      discard piles, cards with their code on hover; the deck between rooms and in a drawer; card rewards and melting.
- [x] The title, run header, map sidebar, and fight controls reorganized; release-to-click makes dragging work,
      and a cast's code uses the work surface below the unobscured arena (ADR-0010).
- [x] Verifier, a separate code-reading course with twelve executable JavaScript lessons, checkpoint tracing,
      exact-output predictions, sandbox grading, and saved mastery; Artificer keeps Python/JavaScript and three looks
      (ADR-0011).
- [x] The build-code view (the spell's function growing card by card): in the program Shardrun, always on the table
      (Phase 8). [ ] Card art and card animations, and a balance pass by play.

### Phase 8: the program Shardrun (paradigms and the speed race, ADR-0012)
- [x] Rules in `core/programs/`: a Program's work measured per stage (its complexity class on the larger of the volley
      in and out), foe tempo (faster foes act before it lands, once), a budget (a timeout lands nothing), mana per
      card, bolts aimed at foes or turned to block, wasted overkill, and a lint for sorted invariants.
- [x] 23 cards, real algorithms in Python and JavaScript with worked examples run in the sandbox: merge sort, divide
      and conquer, tournament merges, prefix sums, binary search, hash maps, greedy assignment, all pairs, subset
      search, tabulation, 0/1 knapsack, naive and memoised Fibonacci (a forge optimises one into the other).
- [x] Five paradigms, and a draft before the first room: three paradigms offered, then five packs of three.
- [x] The fight: the Program's code always on screen, new lines written in with runes, a race bar of foe tempos
      against the program's work, and the program run line by line during a cast.
- [x] The title's Shardrun is the program run; the card Shardrun is kept for a run already underway.
- [x] The card table (ADR-0013): a painted card frame tinted per paradigm and a card back from the art pipeline, the
      hand held Slay the Spire style with details beside the pointed-at card, summaries as comments, the Program's run
      ending the turn (`▶ python program.py`), a guardian's health bar at the top, a portrait of the worn skin, and
      the fight's `.log`.
- [x] After the first play: the hand whole on screen, `main.py`, the numbers over the Maintainer, a calmer stage
      (ADR-0013's amendment).
- [x] Spell animations drawn as motion (ADR-0014): the sigil, the rune comet, the bracket slam, the falling code
      blocks, the hex ward, the shatter, the claw and the clock, coloured per element in the game.
- [x] The code walkthrough (ADR-0015): loops and recursion measured in the sandbox, each card's function walked during
      the cast, results landing like hits, the panel drawing the eye while it runs.
- [ ] More spell animations: one per card role (a sort, a search, a split), and per paradigm.
- [ ] A balance pass by play (tempos, budget, card numbers; Brute Force is weakest played naively).
- [ ] Cards of their own: pictures made for each card (the frame is done); Japanese for the new text.
- [ ] More of each paradigm (graph search, heaps, two pointers, backtracking), and relics that bend work and tempo.

### Next: the game plan (proposed on 2026-09-28)
`docs/ROADMAP.md` proposes stages 0 to 10 for two journeys: the Shardrun toward Slay the Spire's depth
(`docs/SHARDRUN_DESIGN.md`), and the Academy, a separate course from beginner to advanced (`docs/ACADEMY_DESIGN.md`).
Phase 8's open items are folded in: the balance pass is stage 1; cards of their own, more of each paradigm and relics
that bend work are stage 6; spell animations per role come with stage 10. The player chose to start with the
Shardrun's stages 1 and 6 (Phase 9); the rest become phases as they start.

### Phase 9: a deeper Shardrun (ROADMAP stages 1 and 6, ADR-0016)
- [x] Roles on every program card's face (source, shape, order, strike, guard), and first in its details.
- [x] Programs start from three 3-power bolts; a program run has its own foe HP by layer and pattern ward, tuned
      with the probe (53% of the smart bot's runs won, every paradigm a third or more).
- [x] Program relics of the run's own, tiered common to legendary, and loot tables by place (an elite offers only
      rare or better, a guardian epic or legendary); the fourteen old ones tiered, Spellforge's untouched.
- [x] The program's relic effects (`ProgramRelics`), the same in preview and cast; 28 new relics (42 in all).
- [x] 25 new cards (48 in all), real algorithms with worked examples in both languages; `worst_case` and `height`.
- [x] Pictures for the new cards and relics from the art pipeline.
- [x] Every finished run kept as a commit and shown as `git log` from the title; its commit line at the run's end.
- [x] Fifteen enemy concepts with briefs and game-ready sprites (`Concept/Enemies/`), for four or five layers.
- [x] Fights: every hit of a long volley reaches the bars before the screen settles (a heavy cast's later bolts died
      on a check against a freed animation, leaving a foe at a tenth of its HP until the final redraw).
- [x] The Deadlock Golem reworked as two locks; Initiative, speed per intent and a budget per layer as rules (stage 1,
      ADR-0017).
- [x] Imports and keywords, fight state, every card's + read as a diff at the forge, pictures of their own for every
      card (stage 6, ADR-0018); a second pass on three enemy concepts.
- [x] Japanese for the program run's content: every card and its +, relic, foe, paradigm and keyword (653 of 653
      content strings); the interface is stage 0's.
- [ ] A guided first run (stage 6).

### Later
The World (towns, NPCs, quests, code-graded fights), the Codex, the stats drawer, Japanese throughout, importing the
player's characters from the old game's SQLite, and retiring the old repo (only with the player's go-ahead).
