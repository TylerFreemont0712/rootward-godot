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
- [~] Set aside for sprites (ADR-0008); the glTF pipeline still works. Emberfox as the first character: glTF, a toon shader (two tones, rim, outline), clips in an AnimationTree with
      blending, a looping idle, casts that release within about 0.4 s, the spell circle launching the bolts.
- [ ] Vesper, the Star-Script Witch, as a new skin. [x] Modelled and rigged in code (ADR-0007), then set aside for
      a sprite version. [x] A small, cute sprite Vesper from ComfyUI (ADR-0008, `scripts/sprites.sh`): an idle and a
      cast, in the fight and the wardrobe. [ ] Her other clips (hurt, guard, victory, death, a heavy cast).
- [x] Spell sprites from the concept boards (ADR-0008): a bolt and a burst per element, a casting seal, a ward, each
      animated by one shader (dissolve, reveal, wobble, shimmer), flashes, shockwaves and sparkles.
- [x] Spell variety (ADR-0009): heavy spells call their element's strike down on each foe (lightning, a fire pillar,
      ice spikes, starlight) under a darkened stage and a vortex at the hand; a volley on several foes sends a wave
      across the floor.
- [x] Spell effects as shaders and drawn motion per element and the ward (ADR-0008, ADR-0014).
- [x] VRM skins and a shared move library (ADR-0028): godot-vrm and MToon in the game, the VRM add-on in Blender,
      clips as data (`pipeline/moves/`, `scripts/moves.sh`) with nine fantastical clips, casts timed to the sigil,
      the trial skin Shibu in the wardrobe. [ ] Vesper as a VRM. [ ] The cast flash on MToon; blended expressions.
- [x] The anime look as tooling (ADR-0029): ZZZ-style shaders, VRM restyle, a rig normaliser, local reference skins.
      [x] The default look chosen (anime with ink). [x] The 2XKO / Guilty Gear method: edited normals, a light per
      character, limited animation. [ ] Our own characters and enemies made for it.
- [x] A motion dummy and a motion lab (ADR-0030): the moves judged on a plain mannequin first; follow-through springs;
      the moves re-keyed (a contrapposto guard, coil-drive-push, gather-crown-thrust); casts held while the volley
      flies; magic circles written in the air in front of the caster, the bolts born on them; the wardrobe as a wheel.
      [x] The idle opened to the viewer. [x] Motion capture under the moves (ADR-0031): the Quaternius idle, a snap
      for the light cast, the Quaternius spell for the heavy, hurt and death from capture, smooth playback.
      [ ] The moves tuned by play in the lab; more capture (Mixamo, Quaternius's second library) where it helps.
- [x] Sound and music on audio buses with volume and mute settings (ADR-0019, ADR-0020).

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
- [x] A first balance pass (ADR-0016, ADR-0017); the four-layer probe is Phase 9's last item.
- [x] Cards of their own: a picture for each card and Japanese for the text (ADR-0018, Phase 9).
- [ ] More of each paradigm (graph search, heaps, two pointers, backtracking), and relics that bend work and tempo.

### Phase 9: guardians and the fourth layer (ADR-0024, `docs/NewEnemies.md`)
- [x] Sixteen guardian designs, four new a stage (five a pool with the old guardians), each testing one quality of a
      deck; placeholder sprites from ComfyUI.
- [x] The Root: a fourth layer for program runs (Spellforge keeps three), its hallways, its HP and budget.
- [x] The Quine, the Root's guardian: `reprint` sends your last program back at you, and the same program twice
      cannot hurt it (its fixed point); the code panel warns before you run.
- [x] The Unhandled Exception and INT_MAX (a catch check; a damage transform).
- [x] The Cache Lich and Ouroboros (per-foe state; a guard shown each turn).
- [x] Malloc and the Call Stack Colossus (summons; a foe made of parts).
- [x] The Livelock Twins, the Short Circuit and the Profiler (small changes to the landing).
- [x] The Thunk, Karp and the Unreachable (per-foe state, a subset-sum check, a program cut before it runs).
- [x] The Page Fault (one resident page of three) and the Mutator (mutants made by mutation operators, ADR-0026).
- [x] The drawn guardian shown on the map from the start (ADR-0025: the map as a scroll, every layer's guardian on
      its rail).
- [x] The Root Compiler, compiling the guardians the run beat; every layer's pool of five (ADR-0026).
- [ ] A balance probe over four layers; per-guardian lines on the end screen, and ranks re-tuned.

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

### Polish pass: the run and its front door (2026-09-28, ADR-0022)
- [x] Enemy properties and owned relics explain themselves in hover windows; enemy art scales with the arena and the
      discard pile's hover stays centred on its card.
- [x] Three more Imports, three elemental Constants and six combination cards, each with Python and JavaScript code,
      worked examples, a +, Japanese content text and its own themed picture.
- [x] Casts draw a different flourish for split, sort, search, merge, element, guard and import cards.
- [x] Title, run setup, scene changes and options refreshed; an Archives browser searches cards, relics and game terms
      from the live catalogs in both playstyles. Two mismatched old card pictures replaced.
- [x] Boot enters the title through the new curtain safely, including when `Boot._ready` runs while root is attaching
      the scene (`tools/boot_check.gd`).

### Art polish in small passes (ADR-0023)
- [x] [ArtUpdate.md](ArtUpdate.md) lists every enemy, relic and shard image with checked newer art and unchecked
      older art for the remaining passes.
- [x] Pass 1: six early foes repainted in Vesper's anime/chibi finish, facing the player from the right side of the
      arena; four older relics and four older shards redrawn as larger, clearer bronze-and-magic icons.
- [x] Pass 2: three more playable foes (Fork Bomb, Type Mimic, Segfault Specter), two relics and two shards, reviewed
      together at their actual battle and Spellforge sizes.
- [x] Pass 3: the six remaining playable foes (Deadlock Golem, Kiln Warden, Root Daemon, Garbage Collector, Regex
      Sphinx, Stack Overflow Serpent) face the player and read clearly at battle size. All fifteen playable foes now
      share the finished character-art standard. The program run's second Deadlock Lock also faces the player.
- [x] Pass 3 icons: Ember Heart, Storm Bottle, Rime Crown, Amplify, Prism and Scatter repainted and checked in the
      relic row and card hand at real display size.
- [x] Pass 4: all sixteen new guardian placeholders repainted, with the Quine checked in a Root boss fight; three
      relics and six shards redrawn around clearer 32-pixel silhouettes and checked in their run layouts
      (`ArtUpdate.md`, `pipeline/art/sprite-polish-pass-4.json`).
- [x] Pass 5: all sixteen older enemy concepts repainted from their briefs, including the Hydra's separate mating
      body and head; five relics and six shards rebuilt around literal, readable objects and reviewed at game size
      (`ArtUpdate.md`, `pipeline/art/sprite-polish-pass-5.json`).
- [x] Pass 6: thirteen older shard icons with unclear effects rebuilt around distinct action silhouettes and reviewed
      at 32 pixels and in the Shardrun hand (`ArtUpdate.md`, `pipeline/art/sprite-polish-pass-6.json`).
- [x] Pass 7 shards: all thirty-eight remaining shard icons replaced with clearer effect silhouettes and reviewed at
      32 pixels and in five Shardrun hands (`ArtUpdate.md`, `pipeline/art/sprite-polish-pass-7.json`).
- [x] The Archives labels the Spellforge list “Shards”, exposes all 72 base entries, and resolves art for all 77 shard
      variants, including the five forged upgrades (`game/ui/archive_panel.gd`, `game/app/shardrun_views.gd`).
- [x] Program-card pass 9: all 71 base cards use finished high-resolution art. Twenty-seven share the exact Spellforge
      texture and six share another program design; 31 unique placeholders are repainted, seven finished designs
      retained, and 33 duplicate card files removed. All 139 records and refactors resolve correctly (ADR-0033).
- [ ] Continue through the fifty-five unchecked older relics in reviewable groups, keeping their meanings and colors.

### Profiles and Pip's Trial (ADR-0027)
- [x] Local profiles with names, preferred UI language, avatar, personal code language and difficulty, Trial flags,
      run snapshots and finished-run history. The title has a one-click picker, short creation/rename forms and a
      named delete confirmation; the title and run summary greet the player.
- [x] Old saves copied and byte-verified into the first profile, with the old folder retained and the name requested.
      `ROOTWARD_SAVES` continues to work; a corrupt profile cannot hide other players.
- [x] A short fixed Trial, now explicitly activated from Adventure's Pip's travels tab, replayable and skippable.
- [x] Pip's chapters, interactive lessons, real sandbox commands, defeat rewind, and a profile-specific `trial.json`.
- [x] English and Japanese Trial text, whole-run tests, a 10–15 minute timing check and screenshots at both sizes.

### Kernel Foundry front end (ADR-0032)
- [x] Approved station art behind real controls, an equipped live character and a Library / Character / Settings dock.
- [x] Subtle local lantern and lift-light variation, stopped immediately by the existing reduced-motion setting.
- [x] Adventure departure desk with existing playstyles, language, difficulty, resume, new descent, Pip's travels,
      records and field guide; replacement confirmations retained. The tutorial has its own optional tab.
- [x] Character class column (Artificer for now) and the existing skin carousel, with persistent avatar selection.
- [x] Front-end settings, profile management and an explicit Academy placeholder with the existing Verifier entry.
- [x] Live Library with search, rarity and role filters, code/refactor inspection and creature portraits; finished
      records with filters, detail and access to the commit log.
- [x] Keyboard focus through modals and rebuilt choices; English, Japanese and narrow-window screenshot review.
- [x] Menu crash regression: queue old utility bars after click dispatch, test repeated button-driven page changes,
      and exercise real mouse clicks plus descent / resume / Trial / Verifier scene handoffs in isolated saves.
- [x] Compact front-end panels, approximately one-third smaller in each dimension, with readable type, amber
      underline controls, side-by-side preferences and Academy plans, and a smaller wrapped skin-carousel stage.
      Pip's travels starts only by choice; ordinary descents no longer trigger a tutorial offer.
- [x] Compact contents as well as panels: 16-pixel body text, 20-pixel headings, 12–14-pixel captions, tighter
      padding and section gaps, and 32-pixel Library entries. Reviewed English, Japanese and 1280 × 720 layouts.
- [ ] Implement the Academy curriculum and additional classes. Shardrun menu redesign remains a later task.
- [x] Living Archive room (ADR-0034): separate generated background, reversible transition, illustrated collection
      navigation, remembered searches/selections and reset; creatures and bosses separated by live encounter pools
      with mode-specific layer filters, base stats and multipart companions. Shared art and run archives retained.

### Later
The World (towns, NPCs, quests, code-graded fights), the Codex, the stats drawer, Japanese throughout, importing the
player's characters from the old game's SQLite, and retiring the old repo (only with the player's go-ahead).
