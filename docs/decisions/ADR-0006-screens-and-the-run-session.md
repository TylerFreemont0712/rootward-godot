# ADR-0006: the screens, and one session that owns the run

- Status: accepted
- Date: 2026-09-25

## Context

Phase 5 makes the spellbook Shardrun playable. The old game split this between a Node server (its `ShardrunService`
kept the run in SQLite, ran spells in the sandbox, cached their runs and built "views") and a React client (screens,
the code view, the stage's playback of the log). Godot has no server: one process does all of it. The player asked for
a working copy that runs smoothly and can "take different directions", so the pieces should come apart cleanly: a new
screen, a new presenter for the hero, or the deck playstyle later should not mean rewriting the rest.

## Decision

- **`game/app/` is the glue** between the pure rules (`core/`), the sandbox (`sandbox/`) and the screens: it may do
  I/O and use threads, but it has no nodes except `Lifecycle` (and `Sound`'s players).
- **`ShardrunSession` is the only writer of a run.** It is the old service in-process: `command(request)` asks
  `Shardrun.step`, saves the new state, and returns `{before, state, replay}`; screens draw that and nothing else.
  Commands are serialized (`busy`), so two quick clicks cannot both start from the same state.
- **The cast lands exactly what its preview said** the way the old server made sure of it: `SpellRuns` keeps every
  spell run by its exact input (`language`, the spell's shards, the base bolt, the battle as shard code sees it), and
  a cast takes the very run its preview was computed from. Runs happen on a thread (`Background`), all spells of a
  turn in one sandbox job, started as soon as a battle state exists (`warm`). Only runs the code decided are kept; a
  timeout may be the machine's fault and is run again.
- **Saves** are one JSON snapshot per playstyle, `user://shardrun/<playstyle>.json`: the latest run, finished or not.
  Written to a temporary file and renamed (atomic). A save the current rules cannot continue is renamed aside, never
  deleted, and the title says so. `JsJson.parse` turns whole numbers back into ints, so a loaded run is the run that
  was saved.
- **Screens are built in code** on one-node scenes (`title.tscn`, `shardrun.tscn`), with one `Theme` built in code
  (`UiTheme`: the old CRT tokens, VT323 and IBM Plex Mono under the OFL) and small constructors (`Ui`, `Cards`).
  A screen reads as what it shows, a review sees every change as text, and the look lives in one file. The cost is
  less to click together in the Godot editor; a screen whose layout wants hand-tuning can become a `.tscn` later
  without touching the session.
- **One design canvas, 1920x1080** (`canvas_items` stretch, `expand` aspect): every size in the code is in that
  canvas, and the window scales it all together; a taller or wider window gets more room, never a cut-off edge. It
  was 1600x900 at first, which drew everything about 1.55 times as large on the player's maximized 2560x1440 screen.
  Screens whose content can outgrow the window (the title, the end of a run, the overlays) sit in a scroll container
  that centres them when they fit (`Ui.centered_scroll`), so a button can never end up out of reach.
- **The stage shows, it never decides.** `LogPlayer` plays the rules' log entry by entry (bolts, bursts, numbers,
  lunges, banners, hit-stop, shake) and keeps its own copy of the numbers on screen, so no bar gives a result away
  before its hit lands; the true state is drawn when the log has played. A player can click or press Space to skip.
- **The Maintainer on the stage is the 3D `StageCharacter`** in its own `SubViewport` with a clear background, and a
  2D picture stands in when there is no model. `HeroView` is the only thing that knows which, so a better model, a
  different character or sprites again is a change there alone.
- **Dev tools are content-free commands.** A sandbox run (offered when the game runs from the Godot binary, or with
  `ROOTWARD_DEV=1`) opens `DevDrawer`, which only sends the rules' dev commands; after one, the screen is drawn afresh
  rather than played, since a spawn replaces the whole fight.
- **Static services instead of autoloads**: `Game` (content, the session), `Settings`, `Sound`. Any scene can be opened
  alone (the editor, a screenshot, a test) and calls `Game.boot()` first; nothing depends on project settings.

## Consequences

- The screens can be driven like a player drives them: `test/scenes/shardrun_screen_test.gd` plays 120 commands
  through the real run screen and sandbox with the stage's animations off (`BattleStage.instant`), and
  `ShardrunBot` plays whole runs through the session in `test/app/`.
- `tools/shardrun_shot.tscn` sets a run up to any moment (a fight, a cast, a forge, the end) for
  `scripts/screenshot.sh`, in its own save folder, so the player's run is never touched.
- A fight the rules allow to go on forever (a thick hide every bolt glances off, a ward that blocks everything) goes on
  forever; the player can abandon it. The bot abandons after 50 turns.
- Quitting waits for a sandbox job still running (`Background.finish_all`, at most its wall-clock limit), and stops the
  music first so the audio server lets go of its streams (`Game.quit`).
