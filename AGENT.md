# AGENT.md: the working agreement for any AI agent on Rootward

Rootward is a programming roguelite in Godot 4.7.2 (typed GDScript, desktop, no server). Every spell is real code the
player's shards are made of, run in a sandbox. This repository is a **rewrite**: the TypeScript game in
`~/personal-project/ProgramMe` (tag `checkpoint-before-godot`) is the reference for behaviour and the source of
content and art, but nothing in its code or docs binds this one except the game's concept and what the player loves.

The player is the sole player and the maintainer, and is using the game to become a better programmer. Their
daughters are meant to play it too, in Japanese. The game and the codebase are both learning artifacts.

## 1. Read order at the start of a session
1. This file and `CLAUDE.md`.
2. `WIP.md` at the root if it exists: the player's list, and the focus of the session. Never commit it.
3. `docs/PLAN.md`: the phases, and the first unfinished one is the work.
4. The ADRs in `docs/decisions/` for the parts being touched, and `docs/LEARNING_LOG.md`.
5. `git log --oneline -20` and `git status`.

Then say in one short message what you are picking up, ask any blocking question in the same message, and proceed.

## 2. Core rules
- **Real execution or nothing.** Shards and challenges run in the sandbox (`game/sandbox/`); grades come from tests.
  A spell's preview is a real run, and the cast lands exactly what its preview said.
- **Data-driven.** Shards, relics, foes, layers, balance numbers, art and audio prompts are data (`game/content/`,
  `pipeline/`). New content never needs engine code; if it does, add the primitive, not a one-off.
- **Pure, seeded rules.** `game/core/` holds the rules: no nodes, no I/O, no `randf()`, only `Rng`. Scenes render
  state and send commands; they never decide outcomes.
- **Sandbox invariants.** Player code never runs outside the sandbox, which has no filesystem beyond what a job is
  given, no network, a time limit and a memory cap. No telemetry.
- **Protect what the player loves.** The Shardrun is the main mode, now as programs (ADR-0012): a paradigm drafted,
  cards that are real algorithms played in order into one Program, its measured work racing the foes' tempo. Its rules
  are new and have their own tests. Spellforge (the spellbook) and the card run it grew from keep the rules ported
  faithfully and proven against fixtures from the TypeScript engine. Experiments go behind an option or their own
  playstyle.
- **Small slices.** Every step leaves tests green and the game launchable. Commit after each meaningful step with a
  conventional message. Never push unless asked.
- **Strict quality.** Typed GDScript (untyped declarations are errors), small files, clear names, tests first for
  `core/` and `sandbox/`. Verify Godot APIs against the 4.7 docs or the engine itself; do not guess.
- **Assets are optional.** Every picture, model and sound has a fallback, and a missing file never breaks a screen.
- **Look at it.** Anything visible is checked with a screenshot (`scripts/screenshot.sh`) before it is called done.
- **Teaching mode.** `# LEARN:` comments where a decision or a language feature is non-obvious, with an entry in
  `docs/LEARNING_LOG.md`.
- **Report faithfully.** Failing tests are shown, skipped work is named, and a report from the player that could have
  more than one cause is measured before it is fixed.
- **Ask only** when a choice changes what the player will see or play, or when an action is destructive.

## 3. Definition of done
Tests green headless (`scripts/test.sh`), lint clean (`scripts/lint.sh`), screenshots of anything visible, the
phase's checklist ticked in `docs/PLAN.md`, docs and an ADR for any decision a later reader could question, a commit,
and a short summary: what changed, how it was verified, what is next.

## 4. Things not to do
- Do not write the player's solutions for them; hints, not answers.
- No multiplayer, accounts, cloud sync, monetization, mobile, or real-time combat.
- Do not commit `WIP.md`. Do not touch the old repo except to read it and to run its code for fixtures.
- Never stop the player's running launcher (port 7331) of the old game.
- Never run ComfyUI and Blender at the same time: the GPU has 8 GB.

## 5. Session end
Tick `docs/PLAN.md`, update the learning log, write what was built into `WIP.md` (uncommitted), commit, and tell the
player what to open or run to see it.
