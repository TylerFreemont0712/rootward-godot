# ADR-0052: Graphics settings, and choosing the device the game draws on

- Status: accepted
- Date: 2026-10-05
- Related: ADR-0051 (borderless fullscreen, the frame cap), ADR-0035 (the control room), `game/app/graphics.gd`

## Context

Borderless fullscreen (ADR-0051) did not stop the green flicker when the player tabbed out. The player's laptop has two
GPUs: the AMD iGPU drives the screen and the NVIDIA GPU is for offload. Godot picks the discrete card, so every frame is
drawn on the NVIDIA GPU and copied across to the AMD-driven screen. Run on the player's real display (unfocused, with a
window covering the game), the NVIDIA path's picture was unstable between frames (a green region switching on and off),
and drawing on the AMD GPU (`--gpu-index 0`) or with the OpenGL renderer (which Mesa runs on the AMD GPU) was steady and
left the NVIDIA GPU idle. The cause is the cross-GPU copy, not the game's own drawing. The player also asked for real
screen options in place of the single fullscreen yes/no.

## Decision

- **Settings has a Graphics tab beside Display.** Display: window mode (windowed or borderless fullscreen), window size,
  screen (when there are several), interface size (0.8, 0.88, 1.0; the project's own scale is 0.88). Graphics: vsync (on,
  adaptive, off), frame limit (auto, 30 to 144, unlimited), slow down in the background, a frame-rate counter, and, under
  "needs a restart", the graphics device and the renderer.
- **The graphics device and the renderer are command-line choices to Godot**, which cannot change them while running. The
  saved choices (`gpu_index`, `renderer`) are applied by starting the game again: `Graphics.relaunch_if_needed` runs
  from the boot scene, compares the saved choice with the command line this run was started with, and starts the same
  game with `--gpu-index N` and `--rendering-method M` (OpenGL also gets `--rendering-driver opengl3`), then ends.
  `--rootward-relaunched` marks the second start so it never loops. A restart button in Settings does the same on
  demand. The device list is "automatic, 1st, 2nd, 3rd" because Godot cannot name the other devices before choosing one;
  the Settings page says which device the game is drawing on right now. An index past the last device falls back to
  automatic in Godot itself, but an unknown renderer name aborts, so only whitelisted names are ever passed.
- **A tool, a test, a headless run or the editor's own run is never relaunched** (a `res://` scene argument, `--headless`,
  `-s`, `--write-movie`, `--quit-after`, `--import`, the editor flags, or an active debugger).
- **Frames while the window is behind another one** are limited to 20 a second (Settings, on by default) through the
  window's focus signals in `Lifecycle`, and the frame limit is back on focus.
- **The automatic frame limit still fits the refresh rate** (ADR-0051); a limit the player picks is used as it is. The
  saved window size defaults to "as launched", so a tool that opens a window of its own size is left alone.
- On the player's machine the saved device was set to the AMD GPU.

## Consequences

- A change of device or renderer costs one extra start (about a second, a window opening and closing) the first time.
- The in-run options panel keeps its single Fullscreen switch; it uses the same `Settings.fullscreen`.
- Compatibility (OpenGL) is offered but not the default: the 3D hero (VRM, MToon) was only looked at in Forward+.
- If the flicker survives drawing on the AMD GPU, the cause is outside the game (the compositor or the driver).
