# ADR-0001: Rootward is rewritten in Godot, Shardrun first

- Status: accepted
- Date: 2026-09-24

## Context

Rootward was a TypeScript monorepo: a Node server with SQLite, a React client, sandboxes built on QuickJS and Pyodide,
and characters as sprite sheets rendered from Blender. The player decided to move to Godot (*"this is going to
probably develop into a larger game … start with godot as a full-time"*), and then, at the start of the work, to do
it as a rewrite in a new folder rather than a migration in place: *"the only thing that really needs to stick is the
game concept … this is the time to do the rewrite … first we're going to be focusing on the Shardrun piece, and
making it as smooth as possible for our Blender/Godot/ComfyUI setup."*

## Decision

- A new repository, `~/personal-project/Rootward`, holds one Godot 4.7.2 project in `game/`. The old repository is
  untouched: it stays the running game and the reference until this one replaces it.
- **Typed GDScript** throughout, with untyped declarations as errors. C# would rule out a web export later and slows
  iteration; GDScript is Godot's best-supported language.
- **No server.** A single-player desktop game. Rules, content, the sandbox and saves live in the one process.
- **Shardrun first**, the spellbook playstyle before the deck; the World later. The spellbook's rules are ported
  faithfully and proven by **differential tests**: small TypeScript scripts run the old engine with fixed seeds and
  write JSON fixtures that the GDScript tests must reproduce exactly. Everything else (screens, presentation,
  characters, the asset pipeline) is designed fresh for Godot.
- **One naming scheme**: snake_case in content and in runtime state, so state saves as the JSON it is.
- **Tests**: gdUnit4 6.2.1, run headless by `scripts/test.sh`. **Lint**: gdtoolkit 4.5.0 through `uvx`.
  **Screenshots**: `scripts/screenshot.sh` renders a scene on the real GPU under a private Xvfb display.
- ADR numbering restarts here. The old ADRs (ProgramMe `docs/decisions/ADR-0001` to `ADR-0034`) remain the record of
  why the old game plays as it does, and are cited as "old ADR-00NN".

## Consequences

- Until parity, there are two games; the player keeps playing the old one.
- The fixtures outlive the old engine: once written, they pin the rules even after the old repo is retired.
- A hidden byte in the old engine surfaced at once: `randomFor` hashed `seed + "\0" + stream` with a NUL separator,
  which a terminal shows as a space. Godot strings cannot hold a NUL, so `Rng.random_for` hashes the three parts in
  sequence, which is the same FNV-1a computation. The fixture test caught it on the first run.
