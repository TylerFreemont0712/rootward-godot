# ADR-0051: Borderless fullscreen, and a frame cap that fits the screen

- Status: accepted
- Date: 2026-10-05
- Related: `game/app/settings.gd`

## Context

On the player's laptop (X11 under Cinnamon, an NVIDIA RTX 3070 Ti drawing for a screen the AMD iGPU drives, a 165 Hz
panel) the game made the machine run hard and, tabbing out of the fullscreen game, flashed garbage green frames. The
game set no frame cap and no vsync option, so it drew every refresh, 165 times a second, whenever it was open. The
player found that the green came from fullscreen.

## Decision

- **Fullscreen is a borderless window the size of the screen** the window is on, not
  `DisplayServer.WINDOW_MODE_FULLSCREEN`. The window manager's own fullscreen state lets the compositor hand the window
  straight to the display, and that path is what flashed. A borderless window stays composited like any other.
  Turning it off puts the window back where it was (or 1600x900, centred, if it started fullscreen). The option keeps
  its name and its saved key (`fullscreen`).
- **Frames are capped at `Settings.MAX_FPS` (90) or less, as a whole share of the refresh rate** (`Settings.frame_cap`:
  165 Hz -> 83, 144 -> 72, 60 -> 60). With vsync on, a cap that is not refresh / n makes some frames last one refresh
  and some two, which reads as judder, so 90 itself is wrong on a 165 Hz panel. It is rounded up so vsync, not the
  limiter, paces each frame. The cap is applied at boot and whenever the display mode is applied.

## Consequences

- Animation speed is unchanged: everything runs on `delta`, tweens and timers are time-based, and the only frame count
  in the game is the title's two-frame shader warm-up. A lower rate changes smoothness only.
- The cap is read from the screen the window is on when it is applied; moving the window to a screen with another
  refresh rate keeps the old cap until the display mode is applied again.
- Not done: throttling when the window loses focus (`Engine.max_fps` drop, or `OS.low_processor_usage_mode`). If the
  heat or the flicker comes back while tabbed out, that is the next step.
