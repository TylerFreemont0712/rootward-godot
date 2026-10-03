# Decisions

One file per decision a later reader could reasonably question: context, options, decision, consequences.
The next number is **ADR-0041**.

- [ADR-0001](ADR-0001-godot-rewrite.md): Rootward is rewritten in Godot, Shardrun first.
- [ADR-0002](ADR-0002-sandbox-wasmtime-sidecar.md): player code runs as WebAssembly under wasmtime, one process per job.
- [ADR-0003](ADR-0003-shardrun-rules-port.md): the Shardrun rules are ported line for line, and proven by replay (superseded by ADR-0021).
- [ADR-0004](ADR-0004-content-as-jsonc.md): content is JSONC with code in real source files, checked by a small schema language.
- [ADR-0005](ADR-0005-asset-pipeline-and-3d-characters.md): one pipeline into Godot, and characters as real-time 3D.
- [ADR-0006](ADR-0006-screens-and-the-run-session.md): the screens are built in code, and one session owns the run.
- [ADR-0007](ADR-0007-characters-modelled-from-distance-fields.md): skins modelled in code from distance fields, with whole hands (superseded for Vesper by ADR-0008).
- [ADR-0008](ADR-0008-sprite-skins-and-spell-sprites.md): sprite skins from a video model, and spell sprites from the concept boards.
- [ADR-0009](ADR-0009-the-card-shardrun-and-spells-that-differ.md): the card Shardrun first, and spells whose shape depends on what they do.
- [ADR-0010](ADR-0010-the-verifier-and-battle-work-surface.md): code playback moves below the arena; its Verifier contract is superseded.
- [ADR-0011](ADR-0011-verifier-code-lab-and-spell-motion.md): Verifier becomes a code course; spell effects gain motion and fixed framing.
- [ADR-0012](ADR-0012-programs-paradigms-and-the-speed-race.md): the Shardrun becomes programs: paradigms, measured work, foes faster than your code.
- [ADR-0013](ADR-0013-the-card-table.md): cards as painted cards held in a hand, details beside them, the turn ending on the Program's run.
- [ADR-0014](ADR-0014-spell-animations-drawn-as-motion.md): spell animations drawn as motion in the pipeline, light and shade coloured in the game; the strikes retired.
- [ADR-0015](ADR-0015-the-code-walkthrough-and-measured-loops.md): the sandbox measures loops and recursion; the cast walks through the code.
- [ADR-0016](ADR-0016-a-deeper-shardrun.md): a deeper Shardrun: tiered relics of its own, roles on cards, a three-bolt seed, twice the cards, a git log.
- [ADR-0017](ADR-0017-the-speed-race-whole-and-the-golem-as-two-locks.md): Initiative, a speed per intent and a budget per layer as rules; the Golem as two locks; a program run's foes of its own.
- [ADR-0018](ADR-0018-imports-keywords-and-refactors.md): imports and fight state, keywords, every card's + as a refactor read as a diff, a picture for every card.
- [ADR-0019](ADR-0019-the-soundtrack-composed-as-scores.md): the soundtrack composed as scores, performed by YuE2, measured and picked.
- [ADR-0020](ADR-0020-sounds-made-on-their-animations.md): sounds made on their animations' beats; cues stand in for the music.
- [ADR-0021](ADR-0021-the-rules-are-the-games-own.md): the rules are the game's own; the reference results are re-recordable.
- [ADR-0022](ADR-0022-polish-as-presentation.md): readable trait and relic help, a live content archive, and shard-specific effects as presentation around proven rules.
- [ADR-0023](ADR-0023-art-polish-in-small-passes.md): enemy sprites use Vesper's character finish; relic and shard icons keep their pixel-art inventory language, reviewed in small groups.
- [ADR-0024](ADR-0024-the-root-and-a-guardian-pool.md): a fourth layer for program runs, the Root, and its guardian the Quine; guardians cycle by pool.
- [ADR-0025](ADR-0025-the-map-as-a-scroll.md): the layer map as a scroll, rooms apart by hue and outline, every layer's guardian in sight; hallway foes at 90%.
- [ADR-0026](ADR-0026-the-guardian-pool.md): the guardian pool built: five guardians a layer drawn by the seed, their rules in ProgramGuardians, GuardianLanding and RootCompiler, mutants made by mutation operators.
- [ADR-0027](ADR-0027-local-profiles-and-pips-trial.md): local player profiles with verified save migration; the guided Trial as a separate saved program run driven by content and session events.
- [ADR-0028](ADR-0028-vrm-skins-and-a-shared-move-library.md): skins as VRM models (godot-vrm, MToon, spring bones); one move library keyed from readable poses in Blender and retargeted onto every skin.
- [ADR-0029](ADR-0029-the-anime-look-and-normalised-skins.md): the ZZZ-style anime shaders (slot shades, SDF face, specular, LogC LUT, coloured ink), any VRM restyled into them, any rig normalised into a skin; reference skins stay local.
- [ADR-0030](ADR-0030-motion-dummy-held-casts-and-magic-circles.md): a motion dummy and lab for the moves; follow-through springs; casts held while their volley flies; magic circles drawn in the air in front of the caster; the wardrobe as a wheel.
- [ADR-0031](ADR-0031-motion-capture-under-the-moves.md): the moves play CC0 motion capture retargeted in Blender, our keys layered on it (offsets, owned bones); the light cast a finger snap; smooth playback; hand-offs that fade from the playing clip.
- [ADR-0032](ADR-0032-kernel-foundry-front-end.md): the approved lift station becomes the localized front end; Adventure, wardrobe, settings, Library, records and an Academy placeholder around unchanged run launch commands.
- [ADR-0033](ADR-0033-shared-card-art.md): matching program and Spellforge effects resolve to one canonical texture; remaining placeholders get finished originals, and duplicate files are retired.
- [ADR-0034](ADR-0034-living-archive-room.md): the Library opens into its own archive interior, with compact shelf navigation and mode-specific creature/boss dossiers derived from live encounter pools.

- [ADR-0035](ADR-0035-control-room-and-font-preferences.md): Settings inhabits a control room with left-hand tabs; five bundled font candidates update game themes live while the existing default and monospaced source remain available.

- [ADR-0036](ADR-0036-fitting-room-and-cinzel-default.md): Character becomes a fitting and rehearsal room using live skins, clips and circles on a local clock; Cinzel becomes the saved default and the passage gains a continuous soft opening.

- [ADR-0037](ADR-0037-cosmetic-loadout-and-fight-scale-rehearsal.md): every skin fitted to one figure height; a six-slot cosmetic loadout (idle, casts, circle style, bolt, impact) saved with the profile; four new moves and sheets; the Character room's practice ring as a real fight stage on its own clock, with carousels.

- [ADR-0038](ADR-0038-prompted-soundtrack-glass-circuit.md): a prompted "Glass Circuit" soundtrack replaces the composed one slot by slot, as the player approves each track.

- [ADR-0039](ADR-0039-stacking-magic-circles.md): the magic circle stacks one layer per shard (twelve kinds drawn from the card), its tier from the shard count (1-2, 3-4, 5, 6 = the grand circle); the generic per-card flourish retired.

- [ADR-0040](ADR-0040-shard-weave-during-code.md): optional Shard Weave constructs the circle from measured shard returns during the code walkthrough, independent of skin poses, and reuses it through the volley; selectable and previewable in Character.
