# The plan: Rootward in Godot, Shardrun first

Decided by the player on 2026-09-24: a full rewrite in a new folder rather than an in-place migration. *"The only
thing that really needs to stick is the game concept … this is the time to do the rewrite … first we're going to be
focusing on the Shardrun piece, and making it as smooth as possible for our Blender/Godot/ComfyUI setup."* The World
comes after. The old game (`~/personal-project/ProgramMe`, tag `checkpoint-before-godot`) keeps running until this
one replaces it, and is the reference for how the spellbook Shardrun plays.

Each phase ends with tests green, screenshots of anything visible, this file ticked, and a commit.

## The Paradigm Update (2026-10-05)

Implementation follows [ParadigmUpdate.md](ParadigmUpdate.md), parts A and B, including the player's B14 choices.
Program runs only; Spellforge and existing card runs keep their catalogs and saved maps.

- [x] 0. Reproducible Beginner/JavaScript baseline, six paired seeds per paradigm, retained raw runs and report.
- [x] 1. Five law relics, fifteen focuses, explicit focus pick, basic swaps, weighted draft, trial and save compatibility.
- [x] 2. Index, Table, landed-hit memory and program-only sandbox input, remaining memory laws, preview equality.
- [x] 3. General next-card body primitive, half/quarter execution in all three languages, matching code listing.
- [x] 4. Paradigm/focus rewards, guaranteed own card, cross-paradigm elite offer, rarity pity and paid skips.
- [x] 5. Cycles per kill, complete formula tests, reward receipt, HUD and history.
- [x] 6. Program-only map overrides, extra fight, fixed Registry and weighted Issues; unchanged Spellforge maps.
- [x] 7. Seeded Registry stock, prices, purchases and services, Semver's shop screen.
- [x] 8. Sixteen consumable scripts, belt, fight effects and preview updates, drops and shop shelf.
- [x] 9. Thirty data-driven Issues, deferred effects and code-reading bets graded by real sandbox execution.
- [x] 10. Eighty new algorithms and their refactors, three languages, worked examples, Japanese and art subjects.
- [x] 11. Twenty-four new relics plus three script relics, with tested generic effect kinds.
- [x] 12. First-draft card and relic art, focus/script/Registry/Issue/map assets integrated and reviewed; the fantasy map backdrop is restored and the room markers carry only subtle programming details.
- [ ] 13. Paired updated probe and report complete; economy tuned. Follow-up remains for weak/strong paradigm and law targets, early fight length, other-paradigm deck share, and a controlled single-card ablation; see the balance report.

Every slice must pass tests, lint, executable content validation and locale coverage before its completion box is ticked.

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
(`docs/SHARDRUN_DESIGN.md`), and the learning mode, now Lanternroot (ADR-0055, `docs/LANTERNROOT_DESIGN.md`; it replaced the Academy).
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
- [x] Casts draw a different flourish for split, sort, search, merge, element, guard and import cards (replaced by the
      circle's layers, ADR-0039).
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
- [x] The Academy placeholder replaced by Lanternroot (ADR-0055; see its phase below).
- [ ] Additional classes. Shardrun menu redesign remains a later task.
- [x] Living Archive room (ADR-0034): separate generated background, reversible transition, illustrated collection
      navigation, remembered searches/selections and reset; creatures and bosses separated by live encounter pools
      with mode-specific layer filters, base stats and multipart companions. Shared art and run archives retained.

- [x] Integrate the Library catalogue into the room at 1520×760, with wider reading/navigation areas and a smooth
      mist/sigil passage in both directions. The opaque midpoint hides the swap; input stays blocked until reveal.

- [x] Detail the Library passage with a layered magic circle; begin feedback before destination construction,
      load only visible shelf icons in the background and retain a bounded canonical-art cache across reopenings.

- [x] Settings control room with its own painting, subtle lighting, reversible passage and left-hand tabs.
      Six saved/live font choices (current default plus five candidates), source spacing retained, English/Japanese
      and small-window review, persistent preferences and focus-safe resets (ADR-0035).

- [x] Cinzel default with versioned preservation of explicit Original preferences; paradigm text reduced about 10%,
      Settings shade extended through sliders/Back, and a continuous soft-opening room passage (ADR-0036).
- [x] Dedicated Character fitting room with its own painting, explicit skin equip, live native clip rehearsal,
      local slow motion/pause/loop/frame inspection, cast/circle tiers/elements, zoom and 3D viewing angles.
      Existing class/skin assets and production spell circles reused; additional classes remain later work.
- [x] Restore the original skin carousel in the first/default right-hand Skins tab. Compact left-hand roster uses
      the planned class names and small symbols; future classes stay unavailable. Preserve the wheel animation
      while refreshing the live actor, with preview-only card clicks and English/Japanese layout review.

### Cosmetic loadout and fight-scale rehearsal (ADR-0037)
- [x] Every skin fitted to one measured figure height (Vesper's); the 3D skins drawn about 14% smaller in a fight.
- [x] A six-slot loadout (idle, light cast, heavy cast, circle, bolt, impact) in content, saved with the profile,
      worn in fights; moves a skin cannot play fall back to its own.
- [x] Four new moves (Lantern Bearer, Rune Trace, Skyward Call, Root Seal), three new circle styles, a thorn bolt
      and three heavy impacts (Starfall, Root Eruption, Judgment Pillar).
- [x] The practice ring as a real fight stage on a local clock, with practice targets; Moves and Spells carousels
      with live previews, browse-to-try and Wear this.
- [ ] Tune the new moves and looks by play (a lantern light in the idle hand, snap/strike sounds per cast).

### Stacking magic circles (ADR-0039)
- [x] The circle's tier from the spell's shard count (1-2, 3-4, 5, 6), one layer per shard in play order, twelve
      kinds of layer chosen from the card's role and id, in every circle style; the per-card generic flourish retired.
- [x] The fitting room offers 1-6 shards and Light/Heavy; circle sheet modes for stacks and a cast over time.
- [ ] Sound designer: `sfx-cast-layer` (called once per layer, pitch rising), and a listen to the new tier timing.

### Circle construction during code (ADR-0040)
- [x] Optional Shard Weave in both cast slots, keeping the existing animations and defaults.
- [x] Exact shard-return callbacks construct one persistent circle during Program and Spellforge walkthroughs;
      skin-independent placement, paced practice/code-off playback, skip and reduced-motion support.
- [x] Character Moves carousel construction preview, Wear this persistence, and live practice-ring playback.

### Work and construction timeline (ADR-0041)
- [x] Draw each function's layer throughout its walkthrough, sharing progress with the measured work counter;
      imports and repeated calls retain their own construction, and Character uses the same progress API.
- [x] Play recorded faster foes during the code walkthrough when work exceeds their tempo; consume actions once,
      preserve recorded outcomes and ties, and interrupt construction on lethal damage.
- [x] Remove axis/cross glare lines from magic circles; keep ring pulses and local particles.

### Visible stroke construction and Script Loom (ADR-0042)
- [x] Diagnose the actual saved cast selection and full-circle glow/arrival effects that hid partial construction.
- [x] Add a unique Script Loom alternate to both cast slots, with sectors drawn by function progress and a moving
      writing tip; reuse the finished seal at release, independent of skin and the worn circle style.
- [x] Hold unfinished geometry still and suppress prebuilt disc/arrival rings in Shard Weave; original automatic
      casts retain their selection and timing. Check actual clipped geometry and live fight phases.
- [x] Character card/practice previews and English/Japanese notes clearly show the new option and both-slot equip.

### Later
The World (towns, NPCs, quests, code-graded fights), the Codex, the stats drawer, Japanese throughout, importing the
player's characters from the old game's SQLite, and retiring the old repo (only with the player's go-ahead).

### Construction as the cast, and Ring Bloom (ADR-0043)

- [x] Shard Weave is the default cast in both slots; the older moves stay selectable.
- [x] Script Loom and Ring Bloom are circles in Spells, and a centred style worn there draws every constructed circle.
- [x] Ring Bloom: a core and one whole ring more per shard to six, each turning a little into place.
- [ ] Play-test the ring timing at the real code speeds, and decide whether the hero should make a gesture at release.

### Spell animations in Spells (ADR-0044)

- [x] Shard Weave and Script Loom out of Moves; Spells lists Shard Weave, Script Loom and Ring Bloom among the circles.
- [x] Every spell is built during the code walk; the worn move looses the sealed circle.
- [x] Circles face the foes about 12% further; previews settle before they show; Ring Bloom gets rune bands and motifs.
- [ ] Play-test the move timing after the seal (0.45 s) with each of the five moves.


### Phase 2, track A: clear the ground (`docs/PHASE2.md`)

Started 2026-10-04. The bug ids (P2-nn) are PHASE2.md section 6.

- [x] The Verifier course removed from the game; the Academy starts fresh (ADR-0045). Old settings on the Verifier
      open the Shardrun; a player's old course save is left on disk, unread. The leftover probe scripts deleted.
- [x] Card Shardrun kept: no mode is removed (the player, 2026-10-04).
- [x] The preview is the cast: both call `ProgramRules.play`, the preview on a copy; faster foes act and relics add
      their block in the preview too, and it warns when a faster foe ends the run first (P2-01, P2-02).
- [x] Landing totals: a forced Thunk's shield counts once (P2-03); overflow passes over any foe with landing rules of
      its own, to the next plain foe or wasted (P2-04); overflow a shield absorbs is not damage (P2-05); a restored
      mutant's hit counts as dealt (P2-07).
- [x] Dead code after the Unreachable's `return` makes no cards, spends no global, earns no block per card and runs
      no Mutator tests (`ProgramRules.ran_cards`, P2-06); bolts keep their aim when a faster foe summons or swaps
      before the program lands (`ProgramRules.reaim`, P2-08).
- [x] The fight's and the map's keys wait while a menu or panel covers them (P2-11).
- [x] The sandbox's output cap holds for a program that prints past it and exits within one poll (P2-21).
- [x] Saves: a snapshot with fields of the wrong shape is set aside, not loaded (P2-12); a save that cannot be
      written is reported in a toast and the run menu, and the save before it is kept (P2-13); a history line cut by a
      crash no longer swallows the next finished run (P2-15).
- [x] Spellforge's map: a spell's shard chips drew their (now large) pictures at full size, filling the spellbook and
      squeezing the map to half its width with the room legend over it; chips cap their pictures at chip size, the
      spells take only the height they need and the shard inspector follows them (P2-47).
- [ ] More Spellforge passes as its screens are played (the player, 2026-10-04: both modes stay, each for its own
      reason).
- [x] Everything on screen in Japanese (ADR-0047): `Text` and the overlays; 466 of 466 interface strings, 135 of 137
      rule sentences (the other two are covered line by line), every screen checked in Japanese (P2-24, P2-35).

### Phase 2, track C: C++ (ADR-0046)

- [x] The spike: wasi-sdk 34 with wasm exceptions under wasmtime 49; a three-card program in 12 ms, identical bolts.
- [x] The runtime, harness, instrumenter, build (`scripts/build-cpp.sh`) and checker (`scripts/try-cpp.sh`).
- [x] All 139 program cards and 77 Spellforge shards in C++, every worked example passing; import lines; the census.
- [x] On screen: the language's name, `main.cpp`, `./main`, C++ colours, the program and spell listings as C++.
- [ ] A C++ badge for the run button (the Python and JavaScript ones are pictures); C++ in Lanternroot, later.

### Lanternroot: the town that is your program (ADR-0055)

Started 2026-10-06. The Academy was scrapped at the player's request and a new mode built in its place.

- [x] The concept and its design (`docs/LANTERNROOT_DESIGN.md`): letters ask for functions, lanterns light when their
      tests pass, files are houses, imports are bridges, the Night Watch reruns every test each night.
- [x] Pure rules (`core/lanternroot/`): letters by day and prerequisite, starters, change orders sharing a lantern,
      the Night Watch, yesterday's files, workshops of the player's own, the layout read from the code, advice.
- [x] The watch in the sandbox, Python and JavaScript twins: one run per suite, prints per case, the player's file and
      line for errors, a never-ending case costing only its own letter.
- [x] Content: four days, ten letters (one change order), starters and solutions in both languages, proven by tests.
- [x] The screen: the drawn town, the letter board, the workbench (editor, examples, hints, results), the night walk,
      the dawn report, the welcome; the title's Academy button opens it.
- [x] Japanese for every screen and letter; screenshots of each moment in both languages.
- [ ] Play-test the first four days with the player and the daughters; tune the letters' wording and hints.
- [ ] The almanac (every night a commit, a diff per house) and storms (seeded property tests that pin what they find).
- [ ] Mosslight, the next village: data structures; travelling merchants (work budgets) for Emberdeep after it.
- [ ] Pip's lanterns: Parsons letters for the youngest, Japanese first.


### 2026-10-08: the forge, the strikes, Token Stream, the content pass and the moves
- [x] The forge (ADR-0056): four doors beside the anvil (melt, refactor, widen, bind), each stage framed in its colour.
      Melting shows the deck as cards and covers the chosen one with a rune circle before it breaks away; refactoring
      turns the card into its `+` in place. The rules are unchanged.
- [x] Each element strikes with its own blow (ADR-0057): hit-ember (fire), hit-rime (frost), hit-arc (spark), drawn
      without a GPU by `pipeline/sprites/spells.py`.
- [x] Token Stream (ADR-0058): a circle where each card's function name lifts out of the code and flies into it.
- [x] Clarity and balance pass (ADR-0059): about 100 program card edits, 22 relic and shard summaries, costs and one
      relic number; Japanese updated; 1036 worked examples pass. Open items are in `docs/CARD_AUDIT_2026-10-08.md`.
- [x] Move smoothing, measured in the live Blender: the cast snaps, the finger ramps and the guard's entry are longer or
      softer (commit 8fbf10d). [ ] Bezier keys with auto-clamped handles and 60 fps export. [ ] The spikes left in
      cast-skyward and cast-slam, to be judged in the motion lab.
- [ ] The walkable hamlet (`docs/WALKABLE_HAMLET.md`): a proposal only; slice 1 waits for the player's choice of beside
      or instead.
- [ ] Code bugs from the audit: Sweep's guards, Hash Merge's key, Fractional Knapsack's remainder, Import Collections+
      and Import Bisect+ (no real upgrade), and the billing of Permutations and Pairwise.

### 2026-10-08 (later): the legendary looks
- [x] The orrery circle, a constellation bolt and a black-hole impact (ADR-0060, `docs/LEGENDARY_LOOKS.md` v3.5): a cast is a
      volley of riders, each on a seeded route of four or five stars that converges on one point of the foe, drawn from the
      orrery's final star; the impact opens once per foe per cast. Reduced motion drops the rings, bursts, sparks and arms.
      Commits c6766a9 (programs), 4e4d9c2 (fight), 64e2b1f (cosmetics and carousel), 6446a68 (docs).
- [x] Program bolts carry their card and role in Python, JavaScript and C++; the harness bills and reads tags from copies
      taken at start; the launcher captures its own built-ins.
- [ ] Decision: the harness's scope. A card can still replace the harness's globals for its own job. Wrap the harness in one
      function, or give each program its own process.
- [ ] Decision: measured work a card hides (`sys.settrace(None)`, a replaced loop counter). Bill tampered runs at the cap, or fail them.
- [ ] Forged result lines: a later card can print a result for an earlier spell. One process per program closes it.
- [ ] Reduced motion for the ordinary hit sheets: `SpellAnim` does not read `Settings.reduced_motion`.
- [ ] The inflow arms are not seen on screen in any frame so far: treat them as unverified.
- [ ] Gating of the legendary looks is open (none yet).


### 2026-10-10: the Lanternroot town overhaul (ADR-0062, `Concept/v0.3/09-lanternroot-town-overhaul.md`)
- [x] The brief's design pass: nine read-only specialists and a reality check; their decisions are the concept's section 2.
- [x] The outdoor base is 512 x 288: 5x on the player's 2560 x 1440 laptop panel, 3x at 1920 x 1080, float-guarded. Interior zoom stays 2.0.
- [x] Characters at 25 x 35: 52 parts redrawn by hand, the frame landed atomically (`characters.py`, `overworld_art.gd`, the walker's anchor, the preview zooms). Pixel unit tests 20 of 20; the pixel lint is clean.
- [x] Outdoor props: a detail pass on 20 props (fences and gates, lamp posts, barrels, benches, signposts, and more); `stonewall` is kept for the Old Stones and not yet placed.
- [x] The town is 80 x 56 in seven districts with the layout's gates and people; the southern forest is thinned to four rows; the content test passes 10 of 10.
- [x] ComfyUI pictures: three cottages (80 x 80), the inn, shop and shrine (96 x 96), the Lantern Root, the well, the stall, the laundry and the oaks. The garden gate was rejected (near-opaque squares).
- [x] Menus are compact (13 overlays; sizes measured at 1920 x 1080 and 2560 x 1440). The pause card is 44.6% tall, above the 40% target, because its save note wraps.
- [x] The noticeboard is a four-line sign; "Take the letters" is cut from the town. The letters workbench is kept as a title mode.
- [x] The first programmable things: the cabbage-plot gate (solid until open; opens when the boots know all four keys) and the crossroads signpost (its words come from its code). Space uses the thing ahead, X edits its code. Flow tests 6 of 6; the thing-run and town-things suites pass.
- [x] Tests that pinned the old town now read the start and the noticeboard from the map; the quest order and the focus mechanism are updated without weakening an assertion.
- [x] Full suite: 1017 cases with 1 error and 2 failures, all three pre-existing: the Shardrun loot screen (it depends on uncommitted `room_panel.gd`), the program-upgrades test (ten v0.2 cards have no upgrade), and the overworld Japanese gap.
- [ ] Japanese for the overworld: 274 of 461 strings have no entry (the locale test; was 223 before this work).
- [ ] Dusk lighting (deferred: it changes the whole look; the player's call).
- [ ] Nix's cottage, or Hollis's house with Nix's lock (the player's call); Nix is in the drill yard now.
- [ ] Re-render home at 80 x 80 (the first house the player sees; the player's call).
- [ ] The render cache is a symlink into the old repo's `ProgramMe/assets/.art-cache`; the new renders went there. The player decides whether the link stays.
- [ ] Later things: the Old Stones gate, the Root Gate door, `on_step`, a programmable bridge and lamps.
- [ ] The shop's door looks centred at 5x in the talk shot; recheck in play.
- [ ] Commit: none made. The overworld files carry the player's uncommitted work from earlier sessions, so committing would sweep it in.

### 2026-10-13: the cast's sprite sheets, and Lanternroot at 40 px (ADR-0063, ADR-0064)
- [x] The cast pipeline (`scripts/cast.sh`, `pipeline/animation/`): Blender blockouts on one body, turned three ways, restyled by ComfyUI, held to the blockout's outline, a registered cut; `CharacterSheet` and the walker draw either layout.
- [x] Sheets for all seventeen at 64 x 96, reviewed (`Concept/v0.3/animation/cast/overview.png`); the back views' faces fixed with a nape on every hair style.
- [x] One scale (`OverworldScale`, `scale.jsonc`): 40 px tiles, a 1280 x 720 view (nearest whole scale), 64 x 96 people; art indexes record their tile and older art is scaled up on load.
- [x] Interiors at the town's scale, drawn alone on black (`black` in the palette for the void).
- [x] Ground tiles redrawn in code at 40 px (periodic noise, dither-only variation, Voronoi cobbles, 2 px rims).
- [x] ComfyUI buildings, landmarks and trees re-cut at 40 px from their cached renders (`scripts/world.sh adopt`, 21 pictures).
- [x] The background-object pipeline: spec in tiles, Blender blockout in the town's 3/4 view (a shear), ComfyUI restyle held to it, registered cut, lock, lint, a review beside a person; `pipeline/world/README.md` and the `rootward-world-art` skill. Tests 17 of 17.
- [~] Props, trees, furniture and Hotaru remade through it: 11 props and 6 pieces of the home's furniture done. Left: fences, gates and lamps (need frames), the cabbage rows, the forest trees, rocks, sacks, the rug and doormat (flat), the lantern, Hotaru.
- [ ] A layout pass for two-tile people (doors, lanes, the home interior).
- [ ] Modern menus at full resolution.
- [x] The creator uses cast-style layers when available, with the full legacy parts catalogue as the fallback.

### 2026-10-13 (evening): the character screen anew, the creator on the new kit, and a solid soundtrack (ADR-0067)
- [x] The character select screen rebuilt from scratch: the characters stand on the town's cobbles in a row at the town's
  scale, the chosen one in a lantern pool with Hotaru, a details panel (name, class, quest step, counts, Play, Progress,
  Delete), a New spot as a silhouette, and an empty state for a first character (`CharacterSelectLineup`,
  `CharacterStand`; 10 cases; `game/tools/select_shot.tscn`, `shots/select/`). The player's three old characters were
  moved to `overworld-backup-2026-10-13/` beside their save folder.
- [x] At this checkpoint the creator offered what the 64 x 96 parts kit drew (tunic or robe, short or long hair, wide
  hat, and colours), with one size on every tab; this rendering was rolled back on 2026-10-17.
- [x] The music pipeline: the ComfyUI route performs the composed score (it used to play its own planner's), packages,
  `master.py` and `listen.py` working again, safe partial renders and a lock (63 Python tests). The concept
  `Concept/v0.3/13-soundtrack-solid.md`; a new `title` and four Lanternroot tracks (front door, town, indoors, coding)
  performed (two takes each), measured, picked by their numbers and mastered into the game, with the overworld choosing
  the place's track and falling back to `music-rest`.
- [ ] The player listens and swaps any pick (`pipeline/cache/music/index-menu-and-lanternroot.html`, then `pick` and `master.py`).
- [ ] Japanese for the new screen's strings (waiting on the player: locale files are content; see WIP).
- [x] At this checkpoint the Esc menu and Progress panel showed the 64 x 96 sheet; both now show the flat player sheet
  used by the overworld (the 2026-10-17 rollback below).
- [x] The art audit (three Haiku agents, `shots/audit/`) and its fixes: every building and prop the town draws now has a 40 px world-pipeline picture (27 old 16 px ones remade or re-cut, the anvil remade; 66 world pictures), with two pipeline features (`unlit` for a lamp's dark and lit frames, `_` in ids) and things that take code checked per tile; the bridge's and the desk lantern's `sink` set again for the new pictures through the Studio's Publish; the warden's broken left-facing frame replaced by its other candidate. Hotaru redrawn as a small fairy at the world's scale (32 x 32 frames, the player's call) with a new portrait. Look: `shots/art/plot.png`, `pond.png`, `square.png`, `home.png`, `new-pictures.png`, `shots/hotaru/compare.png`.
- [x] The code editors compact (the player's ask, 2026-10-14): the boots and lesson editors use `OverworldStyle.editor_theme()` (code 20, text 19, small 17, title 26), bigger panels (1660 x 1090), tighter blocks and results; visible code lines about 12 → 28 (boots) and 24 (lessons). Hints for Scribe: a Hints toggle opens a 400-wide column beside the code (the panel keeps its size, the code at least 70% of it) with foldable sections from `CodeGlossary` (what the function gets, what it gives back, words you can use; hints, not answers). Tests: `code_glossary_test` 9, `code_editors_test` 10. Look: `shots/code/after-*.png`.
- [x] Decided by the player (2026-10-14): the painted portraits stay and the letters screen's town stays drawn shapes.

### 2026-10-16: the player's character as layers (ADR-0065; prototype reverted 2026-10-17)
- [x] `CharacterSheet` keeps aligned sheets for appearance layers; `Walker` draws each piece separately and changes their
      order by facing. The cast-style base has head (including one face), torso, arms and legs; hair, clothes, hats and
      held items remain independent layers.
- [x] The creator shows only high-resolution choices present in the 64 x 96 kit: short/long hair, tunic/robe, wide hat,
      and skin/eye/hair/cloth colors. The previous 25 x 35 player choices are removed from `looks.jsonc`.
- [x] Old saved player choices normalize to the kit's default hair/outfit; the player renderer never falls back to the
      25 x 35 parts. NPCs retain their exact cast art and legacy fallback.
- [x] A held item has a `hand` attachment and passes behind the figure when facing up; both parts indexes carry the rule.
- [x] Four synchronized step poses move arms and legs in all four facings; body layers bob together, held items follow
      their hand attachment, and the walker returns to standing at arrival.
- [x] The face appears once on the head layer, with a separate hair layer. Legacy fringe and iris colors map to the
      selectable hair and eye ramps, and the face has eye glints and a small mouth; reviewed in the creator and
      four-facing layer preview.
- [ ] Deferred with the reverted prototype: additional parts and inventory equipment need a new reviewed art approach.

### 2026-10-17: restore the single-sheet player
- [x] After visual review found overlapping face and hair layers and unreliable walking poses, the player returned to
      one composed 25 x 35 sprite sheet with directional step frames. The creator preview and in-world walker use the
      same flat sheet; NPCs keep their exact 64 x 96 cast art when available.
- [x] Removed the player layer renderer and generated layer kit. Customization choices are composed into one sheet
      again, so there is only one rendered player model.

### 2026-10-17: authored male/female player sheets (ADR-0071)
- [x] Replaced the player path with native 64 x 96 complete sheets: four directions, eight walk frames and four idle
      frames per direction, including a short blink. No player fallback to the retired 25 x 35 art.
- [x] Creation offers male or female, name and Builder/Scribe. Removed appearance parts, colours and accessories;
      old appearance saves still load with the new default model.
- [x] Walking keeps its animation phase across grid steps and settles to idle when stopped. The creator, lineup,
      progress panel and town share the same authored art.
- [x] Replaced Sergeant Brisk's sprite using the commander's portrait as reference and protected it from cached cast
      regeneration. Saved sources, prompts, registration metadata and an interactive animation review.
- [x] Focused checks: 31 cases covering player sheets, motion, creation, selection, progress and Japanese labels pass.
- [x] All 601 project scripts parse, scoped lint passes, and creator, town and lineup screenshots are reviewed.

### 2026-10-17: walking pace, town art and connected timber fences (ADR-0072)
- [x] Relaxed the player's walk clip from 16 to 12 fps and grid step from 0.20 to 0.25 seconds; kept continuous gait.
- [x] Refreshed the Lantern Tree, sealed Root Gate and timber kit through registered, palette-locked imagegen art.
      Sixteen fence connection shapes share one material and post; wide gates preserve a single opening.
- [x] Fence drags latch their axis, preview the final joins, reuse existing pieces and update corners/junctions.
      Placement, neighbor corrections and later move/delete/swap corrections share one undo transaction.
- [x] Gate preview states match town display; gate sockets and placement checks prevent sideways connections.
- [x] Saved sources/prompts/before art, reproducible import/cut instructions and an interactive comparison.
- [x] Native screenshots, scoped Godot parse/lint, palette/alpha cuts and all 23 world specs checked.
      Automated tests were not run for this pass; evidence is recorded in WIP.

### 2026-10-17: quest evidence and a growing journal (ADR-0073)
- [x] Slightly faster 0.22-second tile movement while retaining the authored 12 fps animation cadence.
- [x] Dedicated extra-arrow boots milestone, valid directional table evidence and repair on saved-program refresh.
      Existing programmable-thing first-action behavior is preserved.
- [x] Independent step completion, accurate counts/pips and first-incomplete instructions in any order; old dialogue,
      lesson and task snapshots preserve newly earned flags. Clear early boots and gate instructions.
- [x] Clickable HUD quest and initial pocket-menu access. Compact active-quest card hides future quests; Pip's progress
      coding task unlocks an expanded active/history journal driven by the player's progress function.
- [x] English/Japanese UI copy and native screenshots; scoped lint and 120 focused cases in 11 suites pass
      (0 errors/failures/skips/orphans), including the real opening, boots and gate flows.

### 2026-10-17: occupied gates swing (ADR-0074)
- [x] Ordinary gates rest closed, open a quarter turn for player/NPC occupancy, and close after the last user leaves.
      Wide gates use their full footprint; physical foot tiles keep the leaf clear while walking out.
- [x] Nine native gate designs with thirteen registered poses, fixed hinges, solid wooden panels, paired wide leaves,
      iron/brass hardware and reduced-motion support. Existing programmed locks and saves keep their behavior.
- [x] Catalog/placement previews rest closed; Studio incremental redraws retain or remove the correct gate nodes.
- [x] Pipeline tests, all nine spec checks, palette/alpha cuts, scoped lint and gate/Studio checks pass.
- [x] Native screenshots and interactive art review checked; all 607 scripts parse. Full regression recorded in WIP:
      2,027 cases, with 3 errors/24 failures outside the gate change; the gate suite passes 10/10 without orphans.

### 2026-10-17: adult Japanese and a creation-time reading choice (ADR-0075)
- [x] Complete `kanji` translations for all 5,056 Japanese catalog entries in 40 files. Normal orthography and
      spacing across dialogue, quests, lessons, errors, menus, items and legacy descriptions; 2,446 editions differ.
      Authored technical glossary uses 引数, 戻り値, 条件, 真偽値 and 配列 rather than children's circumlocutions.
- [x] Select whole templates before inserting values, with immutable cached editions shared by UI controls,
      catalogs, cosmetics, Trial and Foundry. Unknown/ambiguous inline prose stays intact; no runtime kana guesses.
- [x] Japanese creation offers Hiragana/Kanji, preserves name/model/style while previewing, saves on completion and
      restores on cancellation. The reading selector leads Settings → Fonts & text and remains reachable from town.
- [x] Profile, creator, menu, opening and translation regression: 93 cases in 10 suites pass without errors, failures,
      skips or orphans. Final copy and glossary checks recorded in WIP; scoped lint passes.
- [x] Native screenshots of both creator editions, adult settings, quest instructions, dialogue and code hints.
      Translation guide, reading concept, ADR and learning log updated; twelve unused locale keys removed.

### 2026-10-18: building sizes and asset update requests (ADR-0076)

- [x] All buildings and props, including imported art, resize directly through handles or Width/Depth in Objects.
      Original-size reset, undo/redo, drafts and Publish preserve the authored reference; masks, doors and linked
      return warps follow the new footprint. Gate animation sheets, previews and selection scale consistently.
- [x] Right-click catalog/placed art → Needs updating; persistent asset list with notes, prompt and Mark reviewed.
      Catalog badges, Needs updating view and Asset updates button make the review queue available while editing.
- [x] Restylable blockouts can queue prompted replacement variants through the existing world pipeline, retaining
      shared style and negative prompts. Imported/exact art keeps its brief for later. Source specs stay intact.
- [x] Final focused regression 68/68; pipeline tests 25/25 and all 206 specs current. All 26 changed scripts parse
      and pass lint; native resize, right-click, imported-review and prompt screenshots checked. Broader Studio
      regression: 190 cases, two existing command/quest serialization failures, recorded in WIP.

### 2026-10-18: Land variety and area clearing (ADR-0077)

- [x] Nineteen outdoor surfaces in the shared lower Land workspace, driven by terrain content; eight authored variants
      per surface. Four edge-aware path materials, root floor, fern moss and glow moss join the existing grounds.
      Stable coordinate choices preserve appearance through reload and undo.
- [x] Compatible dual-grid mask borders, palette/hard-alpha art and all eighteen layers across two 64-bit corner masks.
      Chunk repainting matches full bakes; terrain-only rebuild avoids changing other assets.
- [x] Objects → Select area (Q), including occupied ground, with All/Props/Trees filters, live count/footprints,
      Shift-add, cancel, Delete and group undo. Named/programmed objects retain the existing confirmation.
- [x] Affected regression 128/128 in nine suites; pipeline 27/27; fourteen scripts parse/lint. Native terrain and
      tree-clearing screenshots reviewed; all grounds fit beside Land tools. No source
      town trees or placements removed automatically; the player chooses and publishes their edits.

### 2026-10-19: Studio lower workspace and terrain refinement

- [x] Follow-up: meadow's empty layouts use matching ImageGen turf; paths sample one continuous ImageGen material
      with shared texture collars and exposed-edge wear. Every compatible path mask side joins exactly across
      variants. Nine terrain pipeline tests and twelve GroundLayer cases pass; wide/close native screenshots reviewed.
- [x] Objects' catalog shelf has room for two card rows. Land's tools, brush sizes, Map size and ground swatches use
      that same lower workspace; the left column stays focused on selection and overlays.
- [x] Three meadow variants are flower-free, Grass uses deeper green shades, and Forest floor keeps its leaf-litter
      patterns with greener tones. Terrain-only build and palette lint are clean; native Studio screenshots reviewed.

### v0.35 Studio follow-up: workspaces, construction and world areas

Specification: [`Concept/v0.35/README.md`](../Concept/v0.35/README.md), detailed Luna execution guide and packet checklist.
This follow-up is prioritized before old S10/S11; historical phase completion below is unchanged.

- [x] 2026-10-19: detailed implementation package written against the current code. Includes shared workspace/input
      routing, concrete People & Doors and Build packets, modular building schemas/compiler/material sockets/managed
      interiors, and new outdoor areas/reference-safe map growth/routes/districts/saved-coordinate handling.
- [x] F01: shared shelf integration, tab state, input/focus priority and safe gesture cancellation. Complete
      2026-10-19: `studio_mode_test` 11, `studio_catalog_panel_test` 18; native People workspace screenshots reviewed.
- [x] P01: People/entrance/start panels and draft-aware read-only indexes. Complete 2026-10-19: `studio_people_test`
      12, including edits, filter counts, undo/redo, draft reload, map switch, room creation and no canonical writes.
- [x] P02/P03: reviewed placement transactions and completed link states/arrival preview. Fixed allocator-hash undo,
      compatible saved-group restoration and cancelled-transition Redo; verified rollback/restart, schedules, grouped
      Revert/Publish, map start, stale link checks, input isolation, actual draft/published arrivals and EN/JA views.
      Hidden People shelf refresh is deferred; one-pass indexing and real-town benchmarks roughly halve placement time.
      Final affected regression: 189 cases/15 suites, zero errors/failures/skips/orphans; named logs in `shots/studio-review/`.
      Full run remains red: 2,097 cases, 5 errors/33 assertions before final fixture/fence corrections; README records
      corrected cases and residual content/catalog, Shardrun, reading and quest-test problems.
- [x] P04: existing room creation/opening/furnishing and unlinked room handling. Linked interiors expose **Furnish room**; unlinked new room drafts stay visible, support Locate and uniquely matched Reconnect with fresh snapshot checks, and block Revert while inbound links remain. Room suite 25/25 and draft-index suite 4/4 pass; scoped lint passes.
- [x] P05: draft-aware dialogue/quest jumps and authored person details; Back to person, active document history,
      missing/unreadable dialogue guards and structured entrance diagnostics in rows/overlays. Focused acceptance:
      People 18/18, plus 49 doors/index/mode/quests cases in the earlier run. Native EN/JA and 1280×720 views reviewed;
      evidence and the corrected initial test-fixture failure are recorded in `shots/studio-p05/` and the README.
- [x] P06: mounted People & Doors delivery A, fixture Publish/empty-draft reload and linked building slide/resize
      return acceptance. Effective targeted coverage 120 cases/10 suites across named runs; final Rooms 25/25 and
      new walkthrough 2/2. Fixed empty-history typed-array and Japanese link-format errors. Native EN/JA evidence
      and ordinary geometry history limits: `shots/studio-p06/evidence.txt`. Full project suite not rerun.
- [x] B01: Build enabled with shared, scoped construction cards, two complete rows, independent search/scroll and
      canonical templates. Exact category/family metadata separates 30 buildings, 51 boundaries, 9 gates and 37
      furniture entries; Paint floor opens existing indoor Land tools. Effective focused coverage 55 cases across
      named runs, scoped lint and EN/JA native review. Logs/screenshots: `shots/studio-b01/`.
- [ ] B02–B06: existing building sizing/door contract, boundaries/gates, room furnishing, map controls and acceptance.
- [ ] M01–M08: rectangular modular shells, assembled roofs, owned partitioned interiors and full compatibility.
- [ ] W01–W07: new outdoor areas, reference index, coordinated expansion, paired routes, districts and save migration.

Early requested slice (2026-10-19): Land resizing grows maps to 128 × 128 tiles with bounded edge controls. The map
picker's New area flow creates a named, editable outdoor draft with a configurable start and opens it in Land; the
existing People & Doors tools can connect entrances, and Publish reviews the new map file. The full W01–W07 packet
remains open for districts, coordinated reference/save migration and paired route creation.

Implementation and evidence are tracked in [`05-delivery-checklist.md`](../Concept/v0.35/05-delivery-checklist.md),
with exact commands and screenshot paths in `WIP.md` and the v0.35 README. F01/P01–P06 and B01 are complete;
construction continues with B02. New art is not part of the People & Doors specification. A
separate user-requested refresh of Lanternroot's buildings is tracked in `WIP.md` and the v0.35 architecture concept.

### Lanternroot Studio: the town's editor inside the game (spec `Concept/v0.3/10-lanternroot-studio.md`, ADR-0066 in S0)

- [x] S4 update (2026-10-18, ADR-0076): direct per-placement sizing and persistent art feedback supersede the
      original remake-only sizing restriction below. Every building and prop now has resize handles and fields;
      prompt-driven regeneration remains a separate queue action for assets with restylable blockouts.
- [~] S0 Foundations: the toggle (`Settings.studio`, `ROOTWARD_STUDIO`), Play F1 / Edit F2, camera and overview, overlays, selection and inspection, `StudioDoc`, the canonical JSONC writer and drafts in `load_world`. Done: the Settings toggle; F1/F2 with Edit pausing play and keeping game keys out (mode tests, 6 cases); top bar, tools, inspector, status bar, pan, O, Home, Tab, picking, overlays (grid, footprints, solid, doors, labels, player ring); `StudioDoc` (7 cases); the map writer with round-trip tests; drafts in `load_world(root, drafts)` and their isolation. Done since: the catalog's canonical writer (`JsoncWriter.catalog_text`, `StudioDoc` kind "catalog"), `catalog.jsonc` round-tripping byte for byte. Open: writers for quests, talk and townsfolk, Publish for the catalog, and a pixel comparison of the `shots/studio/` screenshots.
- [x] S1 Arrange: commands with undo and redo, snapped and free placement, duplicate, copy and paste, delete, flip, editable inspector, drafts across restarts. Interactive acceptance is complete: movement ghost, placement, object edits, history controls, and draft persistence across restarts are connected. Focused tests are green. Desktop performance: the player tested it on their own desktop and reports it fine (2026-10-13); the Xvfb harness's 8.6 FPS (Vulkan DRI3 warning, no GPU) measured the harness, not the game.
- [~] S2 Publish: map checks, diff in words, backups, safe writes, reload, revert, conflicts and three-way rebase. The map publish loop and mounted Publish UI are implemented and covered by focused and integrated tests. Done: structured object/cell problems from `OverworldMap.build`; map publish, conflict/rebase, backups/rollback, clean-session reload and modal input isolation; final combined Studio and neighboring overworld run 172/172 green (report_913), inspected screenshots. Open: duplicate loader/rules problem presentation; program, placeholder and quest-reference checks wait for S4, S8 and S9.
- [x] S3 The catalog: `catalog.jsonc` and its test, the Sims-style panel (categories, search, filters, thumbnails, source badge), place mode, eyedropper. Done: the compact slice (filter, preview card, Delete selected, the right-click menu opening at the cursor); the catalog coverage test over every picture folder and the townsfolk (`game/test/content/catalog_test.gd`: a picture without an entry fails; 38 pictures at 40 px, 27 old); the pure `StudioCatalog` (coverage, tree, families, footprint classes, recent) and the filter's chips and views (45 cases); the full panel of spec 6 (view and category tabs with search, subcategory tabs, filter chips, one row of cards with thumbnail, name, footprint and source badge; Recent and On this map; 25 cases); thumbnails made at run time and kept in memory (about 0.2 ms each, so no disk cache); Shift-drag rows as one undo step (`StudioRow`, `StudioWork.place_row`; 14 cases). All Studio, catalog and neighbouring overworld suites 273/273 green; `shots/studio/catalog.png`, `browser.png`, `context.png` inspected. Open for the player: the review of the catalog's tree (spec 13.5).
- [x] Catalog asset expansion (2026-10-15, player requested): 90 new placeable objects, catalog 82→172; 31 street/boundary, 28 furniture, 14 nature, 15 farm/work, two buildings. Three Luna agents; 86 ComfyUI blockout restyles and four explicitly requested ChatGPT sources. Correct material/orientation wall families, walkable rugs/crops, Animal care/Farm tools/Workstations subcategories. Editable specs, complete ChatGPT prompts, source images, registration and review tools: `pipeline/world/expansion/README.md`. All 90 specs current; catalog/world-art suites 7/7 green; contact sheets and three catalog screenshots inspected.
- [x] Modular boundary placement (2026-10-16): ordinary drags preview and place walls, fences, rails and gates on release as one undo step, with automatic horizontal/vertical pieces. Other props retain Shift-drag rows. Variants can be selected before placement and during a pending drag. Four thin wall materials have all four corners; three gate styles, the base fence and stone wall have both orientations. Exact Blender geometry can bypass diffusion through `restyle: false`, with the normal palette cut and reviews. Cell collision remains unchanged. Review: `shots/studio/boundaries.png`.

- [x] S4 Resize: variants, footprint handles, remake queue through `scripts/world.sh make`, placeholders. Done: variants (`[` and `]`, feet kept, "Ivy, 2 of 4"); footprint handles on a selected thing whose original has a blockout, dragged to a size, asked ("Remake barrel at 2 × 1?"), drafted at once: its catalog entry and its source's family in the catalog's own draft (`StudioCatalogSession`, the `set_entry` command, catalog lines in the diff), the thing with the new art and size, drawn as its source's picture stretched (`OverworldArt.stand_ins`) and hatched; a remake of a remake is one of the original, and dragging back restores it; the queue in `user://studio/remakes.json` and Run remakes (the tools column, `StudioRemakes`: specs written into `pipeline/world/objects/`, the pipeline in the background, its output line by line, done or failed by exit code and `world.json`, the new picture drawn without a restart via `OverworldArt.forget`); Publish carries the catalog, and a waiting remake is a warning (`StudioPublish.remakes_waiting`). Tests: `StudioRemake` 8, catalog commands and diff, `StudioRemakes` 4 (fake pipeline), catalog Publish 3, the resize flow 3 (mounted). Only blockout props and furniture can be remade (every building and tree is an adopted re-cut; the 6 x 6 cottage of the acceptance needs a cottage blockout first). Acceptance: the barrel remade at 2 x 1 for real (the Studio's spec, `scripts/world.sh make --only barrel-2x1`, the review `Concept/v0.3/world/barrel-2x1.png`, its catalog entry published through Publish), its placeholder hatched in `shots/studio/remake.png`, the real picture replacing the placeholder without a restart (scene test with the real picture); the in-game button ran the fake pipeline in tests, not the real one from a running game; a 6 x 6 cottage needs a cottage blockout first. Placement lag fixed alongside: about 830 ms per edit before, about 15 ms now, frames after it under 9 ms.
- [x] S5 Land: brushes, line, rectangle, fill, legend growth, `GroundLayer.repaint`, map size. Done: the Land tab (top bar; B brush with sizes 1 2 3 5, Shift-drag line, R rectangle, G fill, E pick the ground under the cursor; ground swatches from the terrain atlas, outdoors grass, path, cobble, water and flowers, indoors floor, wall and void); a stroke shows as the brush moves and is one undo step (`StudioLandTool`, `StudioWork.paint`); the legend grows a free character for a ground it lacks; water under something solid is a warning; `GroundLayer` baked in 320 px pieces with `repaint` of the ring round the changed cells, byte-equal to a whole bake (8 cases), about 1.5 ms a 5 x 5 stamp, and the town's whole bake down from about 0.7 s to 0.23 s; Map size (four edges, the new cells' ground, what falls off listed, doors from other maps counted) as one change (`StudioLand.resize`, a batch with `shift`) that moves things, the start, this map's links and the player, while other maps' doors into it follow in their own drafts, also on undo and redo. Pure core `StudioLand` (38 cases), `set_rows`, batch `shift`, `StudioHistory.peek_*`; the mounted tests (4 cases) cover the spec's acceptance: a 5-wide cobble road through grass drawn live within a frame of each move, and the map grown by 4 columns on the left moving every thing 4 cells right, published into a content copy whose files show it.
- [x] S6 People, doors and interiors: townsfolk placement, door handles, link door, make interior, warps, start. Done: the catalog's People (every townsperson, their cast sheet's front frame as the card) and Markers (Warp, Start, built in, not in catalog.jsonc); a person stands in one place in the whole town: placed again on their map they move, placed from another map they are asked about, then leave it in the same change, and undo puts them back (a batch's `elsewhere` and `elsewhere_undo`, applied to the other map's draft after the batch, its undo and its redo); R turns them; the inspector shows their talk file (Open) and the quest steps that mention them (`StudioDoors.mentions`). Doors: a selected building's door is a handle on its bottom row, dragged along it, and whatever led to the cell below the old door (the room's way out) follows; Link door and Link warp (`StudioLink`: any map in the picker, a click on an open cell, the facing from a menu at the cursor; the link written in the door's own map as one change; Esc goes back); a new warp goes straight on to linking; Unlink and Go there. Make interior: a new room 11 x 8 by default (the player's call; Map size changes it), named after the building, with walls, floor and the doormat's warp, linked both ways, and shown to furnish; it is a new map with a draft of its own (`StudioSession.create`, `is_new`) until Publish creates its file (the hash of "" as its base, no backup, a rollback removes it), Revert throws it away, undo only unlinks it (Publish then warns that no door leads into the room). The map picker in the top bar lists every map, rooms and new ones marked; the start is an amber flag on its cell, dragged to move it, its facing and the map's name in the inspector when nothing is selected. Leaving Edit in a room that is only a draft plays the draft, and a save that names a missing map now goes home instead of starting over. Tests: `StudioDoors` 27, `studio_rooms_test` 9 (the spec's acceptance: Pell's cottage's room made, furnished, walked out of and into on Play draft, published, the new file with both links), `studio_people_test` 9, plus commands, diff, files, sessions and rules. Look: `shots/studio/studio-doors.png`, `studio-room.png`, `studio-link.png`, `studio-people.png`.
- [x] S7 The developer inspector: live state, event log, teleport, flags, quest steps, re-run a thing's code. Done: F3 in Play shows `StudioDebug` on the right (the town and the quest card move aside, nothing covered). **See:** the player's place; every quest with its steps; the flags; the things on the map with their fields; the lessons; the boots' code; an event log (talk opened and closed, flags set and cleared, quest steps done and undone, each thing's code run with its input, output, errors and time through `ThingHost.ran`, warps, pokes, content reloaded) with filters by kind. **Poke** (only on Play draft's test state; the real save is never poked): teleport by Ctrl-click, set and clear flags, Done and Reopen per step, Jump here per quest, Reset a thing, Run… a thing's code again with inputs edited as JSON (a look only, nothing kept), Reload content, and Watch files (reloads when a content file changes). Pure rules `DebugPokes` (complete, reopen, jump, flag and step changes) and `DebugLog` (41 tests); overworld hooks `state`, `poke_state`, `teleport`, `things`, `talk`; a Talk links overlay (who talks with which file). Tests: `studio_debug_test` 8 (the acceptance: Light the lane jumped to, the lane's lamps drawn dark, the cabbage gate's run in the log with its result). Look: `shots/studio/studio-debug.png`, `studio-debug-events.png`. Triggers on the overlay wait for things with on_step (S8).
- [x] S8 Things that take code, unlocks, links between things. Done: `unlocked_by` on a program (the quests' condition language; `TownThings.unlocked`; a locked thing is a plain prop: no prompt, Space and X do nothing of its own); Make it a thing (the inspector's button on a plain prop, `StudioThingDialog`: id suggested, name, when its code runs (on_use, on_step, on_change), links, unlocked by a flag, raises, fields as JSON, three hints with defaults, Python and JavaScript starters from a template), `StudioWork.make_thing` (one change in the map) and `StudioThings` (the thing's file and starters as drafts in `drafts/files.json`; Play draft runs them; Publish reviews and creates or changes them, a file made meanwhile is a conflict, a drafted thing no prop uses is a warning). `studio_things_test` 3 (the acceptance: a barrel unlocked by met-innkeeper is silent before and answers after, and publishes its three files). Links (the wiring idea): a program's hook may be on_use (Space), on_step (the player arrives on one of its cells: a plate, not solid) or on_change (a thing that links to it changed its fields; its code reads `thing.source`: {id, fields, changed}); `program.links` names the things a change reaches. Rules in `TownWires` (hooks, step and change targets, the source, problems: links to nothing, to itself, to a thing that does not answer on_change, a solid plate; 26 tests); the sandbox harnesses pass `thing.source` and name the hook's functions; `ThingHost.run_hook` queues a link's or a step's run behind the one on its way; `ThingTown` follows links at most `MAX_CHAIN` (8) deep, each thing once a chain, locked things skipped; Space runs only on_use things. The Studio: the dialog's hook and links, the inspector lists links, and the overlay "Talk, plates, wires" outlines plates and draws each link as a wire. `studio_wires_test` 3 (stepping on a plate opens its linked gate; the log shows both runs). Look: `shots/studio/studio-thing.png`, `studio-wires.png`. Left: editing an existing thing's files in the Studio (only new things are made), and a click-to-link picker (links are typed ids).
- [x] S9 The quest editor: steps, conditions, where it happens, how it is shown, flags browser, talk editor. Done: the Quests tab (`StudioQuestPanel`, with `StudioQuestList`, `StudioConditionEditor`, `StudioFlagBrowser`, `StudioTalkEditor`, `StudioQuestUi`, `StudioQuestEdit`) over the town: **Quests** in order (status words, add, move, remove), each quest's title, summary, giver and what it waits for, and its steps (text, hint, the done condition as kinds — flag, not, flag and not, count, all of — read back in words, a pin: a map and a cell, the schema's new optional `at`; up, down, remove, add); **Flags**: every flag with where it is set (talk nodes, things, lessons, the game itself) and read (quest steps, talk starts and choices, unlocks), orphans marked, a search, and jump-to (a quest step, a talk node, a thing on its map); **Talk**: a file's start rules, its nodes, a node's lines (speaker, mood, text), the flags it sets, its choices, next and open, and `Talk.problems` under it. Each edit is a command on its doc (`StudioDoc` kinds "quests" and "talk", path commands set_at, insert_at, remove_at) with the panel's own undo and redo (Ctrl+Z inside the tab), and the doc's text goes into the file drafts (`StudioQuestWork`), so Publish reviews and writes quests.jsonc and the talk files, and Play draft plays them. Writers `JsoncWriter.quests_text` and `talk_text` round-trip quests.jsonc and 18 of the 22 talk files byte for byte; archivist, hotaru-first-action, noticeboard and oracle are hand-formatted and are written in the standard layout the first time they are published (same data). Pure: `StudioQuests` (condition words, the flag index, orphans; 21 tests). Tests: `studio_quests_test` 6 (the acceptance: a step added to Hello, Lanternroot that needs a new flag set by talking to Pip; Play draft; the tracker shows the step and talking to Pip completes it; Publish writes both files and the world loads them), writers 10, commands +15, docs +4. Look: `shots/studio/studio-quests.png`, `studio-quests-flags.png`, `studio-quests-talk.png`. Left: Pick on map for a pin (x and y fields for now), renaming a quest or a node, and the tracker pointing at a pin.
- [ ] S10 Heights: elevation, cliff edges, stairs.
- [ ] S11 The players' build mode (house and yard, saved in the save file).

### v0.4: the game you build from inside the game (spec `Concept/v0.4/`, ADR-0068)

The player's brief of 2026-10-15: many more programming tasks, each one building a part of the game itself, an
inventory, a small map, a richer tracker and a simpler character select. Conducted with Haiku task workers, Sonnet for
the story and the UI, a Haiku checkpoint and an Opus final check.

- [x] The engine: tasks in content (stages, judges, hints, cloze blocks), one harness (`tasks.py`, `tasks.js`),
      `TaskRun`, `Tasks`, `TaskJudges`, `Parts`, `Bag`, the state's new fields, content loading, `PartsRuntime`,
      `TaskHost`, the `has` condition and the tracked quest.
- [x] Ten tasks with references, block answers, judges and tests: shortcuts, menu, options, volume, music, bag, map,
      progress, clock and credits.
- [x] The story: the menu quest in chapter 1, chapter 2's eight quests, the givers' talk and Hotaru's beats (`03-story.md`).
- [x] The HUD: the tracker with the giver, a bar, the count and a direction; the minimap; the full map; Track in the
      log; the character select made basic.
- [x] The editor, the Workbench and the part-built banner; the pocket menu, the menu's own list, Options with a volume
      curve, the music box, the bag and the credits.
- [x] The art: sixteen item icons, the music box and Pell's map table, through the world pipeline.
- [x] The level pass: the new assets placed, pickups and places; the overworld wired end to end; acceptance
      (chapter2_acceptance 9, chapter2_town 5); screenshots; Haiku checkpoint; Opus final check.
- [ ] Later (`Concept/v0.4/01` sections 16 and 18): the Studio's "Build part" poke, gear marks in the menu and the log,
      more life round the square, the volume's pad nudge, the bag's later stages.

#### Chapter 3, the town keeps time (`Concept/v0.4/05`, ADR-0069), and Japanese (`06`, ADR-0070)

The player's brief of 2026-10-16: chapter 3 with as many tests and lessons as can be written, and the town
completely accessible in Japanese. Conducted with Haiku workers for tasks, story, UI, level and translation.

- [x] The engine: `args_after`, day and coins, five versions, schedules and the shop in content, the runtime's tables
      (glow, weather, hours) and live calls (count, price, can_buy, total, tidy, changed), and the town's wiring
      (rewards, the tally board, the lockbox, the drill board, the shop, rain, people's hours, Hotaru's glow).
- [x] Eleven tasks with references, block answers, judges and tests: count, glow, drills, locks, forge, stones,
      weather, hours, shop, tidy and history.
- [x] The story: eleven quests (14 to 24), the givers' talk, Orin's opening and ending, Hotaru's glow beat, Fern's
      wait for the rain.
- [x] The UI: Nym's shop, the bag's coins, total and tidy, the Workbench's history, the rain layer, Hotaru's
      brightness. The level: seven schedules, the shop's prices, three props.
- [x] Japanese: every string the town shows counted (`OverworldStrings`), starter comments, templates, case
      descriptions, the stale entries re-keyed, a term table and a consistency pass; wave 1 (1384 strings) and wave 2
      (the chapter 3 strings).
- [x] Acceptance: `chapter3_acceptance` 9, `chapter3_town` 8; screenshots of the shop, the bag, rain and the props.
- [ ] Left (`Concept/v0.4/07-handoff.md`): the whole suite rerun, lint and validate, Japanese screenshots, a Haiku
      checkpoint and an Opus final check.
