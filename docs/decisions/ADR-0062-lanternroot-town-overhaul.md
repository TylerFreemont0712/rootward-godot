# ADR-0062: Lanternroot's town overhaul, and the first programmable things

Accepted 2026-10-10 (in progress). Amends ADR-0061 (the view, the frame size and the town's size). The concept and the
decisions with their reasons are in `Concept/v0.3/09-lanternroot-town-overhaul.md`; the design reports and the build
lanes are summarised there.

## Context

The player wants level 1 to be the place where most of the programming starts. The postboard is not the interaction
they want: the first programs should change how the town works while the player plays, the way the boots already change
movement. They also asked for a bigger town, a little smaller views, reworked gates and small things (ComfyUI first),
more compact menus, and characters a little bigger with more pixels, so spiky hair reads.

## Decision

- **Outdoor view: a 512 x 288 base** (`PixelView.BASE`). The player plays fullscreen on a 2560 x 1440 laptop panel, where
  the old 400 x 225 base gave 6x. The new base gives 5x there (tiles 80 px, down from 96), and 3x at 1920 x 1080. The fit
  is guarded against a float just under an exact fit (`PixelView._fit`), and the world size gets the same guard.
- **Interior zoom stays 2.0.** An interior tile is 160 px on the laptop (was 192) and 96 px at 1080p.
- **Characters are 25 x 35** (5:7, the 20 x 28 proportions 1.25x bigger). All parts are redrawn by hand, not resampled.
  The frame lands atomically: `characters.py`, `overworld_art.gd`, the walker's feet anchor (`floori`, so -12, not a half
  pixel), and the preview zooms (creator 8, card 5, progress 4, the pause figure 3).
- **The town is 80 x 56 tiles** in seven districts. Art is footprint x 16 px; gates are two tiles. The southern forest is
  thinned to a boundary of four rows. Nix is a person in the drill yard, with no cottage yet (the player's call).
- **ComfyUI** makes the cottages (80 x 80, three distinct houses), the inn, the shop and the shrine (96 x 96), and the
  post changes for the Lantern Root, the well, the stall, the laundry and the oaks. A garden gate render failed (a
  near-opaque square) and was rejected; the hand-placed gate is used. The approved hall, archive, smithy, workshop and
  Root Gate are unchanged.
- **Menus are compact**, against the targets in the concept (small menus at most 24% of the width and 40% of the height;
  dialogue 1100 px; the code editors are bound by line count). The Settings page is untouched.
- **Programmable things, the first slice.** A prop with an `id` and a `program` answers Space (the existing act key, the
  same path as talking and reading). Its code runs once per press in one sandbox job (`hooks.py`, `hooks.js`,
  `thing_run.gd`), and it may change only the fields the program declares (for a gate, `open`) and return words for
  Hotaru. X opens its code in the Scribe panel. The first two things are the cabbage-plot gate (solid until `open`; the
  starter opens it when the boots know all four keys) and the crossroads signpost (its words come from its code).
  State is saved under `things` in the overworld save, with no version bump. Two flags take part in the quest:
  `first-action` (any successful answer) and `<id>-open` (`cabbage-gate-open`).
- **The noticeboard is a four-line sign.** Its "Take the letters" route is cut. The letters workbench (ADR-0055) remains a
  title mode.

## Consequences

- The boots table for the 80 x 56 town takes about 110 ms in Python and 46 ms in JavaScript. Its output is 205 KB, so
  `BootsRun` raises the sandbox output cap to 512 KB explicitly (the default was 256 KB).
- A saved town cell that is no longer walkable (after a re-layout) is moved to the start on load. A restore on an open
  gate keeps the gate open (`lessons.gd` passes the open cells).
- Tests read the town's start and the noticeboard from the loaded map, not from fixed cells.
- Japanese is behind: 274 of 461 overworld strings have no Japanese entry (the locale test fails, as it did before this
  work, and the new lines add to the gap). The Japanese lane comes next.
- The pixel render cache (`pipeline/cache/art`) is a symlink into the old repo's `ProgramMe/assets/.art-cache`, so the
  new renders were written there. The player should decide whether that link stays.
- Not yet: dusk lighting, a cottage for Nix, the Old Stones gate, the Root Gate door, a second hook (`on_step`), and the
  programmable bridge and lamps.

## Open

- The shop's door looks centred at 5x in the talk shot (2560 x 1440). Recheck it in play.
- The gate and the sign are the first two things. Their hints and starters need the player's review for tone and
  difficulty, and the first-action beat's wording was changed once after play.
