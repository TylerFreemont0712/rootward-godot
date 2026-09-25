# Decisions

One file per decision a later reader could reasonably question: context, options, decision, consequences.
The next number is **ADR-0010**.

- [ADR-0001](ADR-0001-godot-rewrite.md): Rootward is rewritten in Godot, Shardrun first.
- [ADR-0002](ADR-0002-sandbox-wasmtime-sidecar.md): player code runs as WebAssembly under wasmtime, one process per job.
- [ADR-0003](ADR-0003-shardrun-rules-port.md): the Shardrun rules are ported line for line, and proven by replay.
- [ADR-0004](ADR-0004-content-as-jsonc.md): content is JSONC with code in real source files, checked by a small schema language.
- [ADR-0005](ADR-0005-asset-pipeline-and-3d-characters.md): one pipeline into Godot, and characters as real-time 3D.
- [ADR-0006](ADR-0006-screens-and-the-run-session.md): the screens are built in code, and one session owns the run.
- [ADR-0007](ADR-0007-characters-modelled-from-distance-fields.md): skins modelled in code from distance fields, with whole hands (superseded for Vesper by ADR-0008).
- [ADR-0008](ADR-0008-sprite-skins-and-spell-sprites.md): sprite skins from a video model, and spell sprites from the concept boards.
- [ADR-0009](ADR-0009-the-card-shardrun-and-spells-that-differ.md): the card Shardrun first, and spells whose shape depends on what they do.
