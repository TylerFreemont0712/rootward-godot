# Decisions

One file per decision a later reader could reasonably question: context, options, decision, consequences.
The next number is **ADR-0017**.

- [ADR-0001](ADR-0001-godot-rewrite.md): Rootward is rewritten in Godot, Shardrun first.
- [ADR-0002](ADR-0002-sandbox-wasmtime-sidecar.md): player code runs as WebAssembly under wasmtime, one process per job.
- [ADR-0003](ADR-0003-shardrun-rules-port.md): the Shardrun rules are ported line for line, and proven by replay.
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
