# ADR-0027: local profiles and a saved guided Trial

- Status: accepted
- Date: 2026-09-29
- Related: ADR-0006 (one session owns each run), ADR-0012 (program runs), ADR-0013 (the card table)

## Context

Several people use one local installation. Its former `user://shardrun/` folder and global language choice made their
runs and preferences indistinguishable. A first guided Shardrun must also belong to one person and must not replace
their ordinary run or enter their finished-run history.

## Decision

- Each local player owns `user://profiles/<id>/` (or `<ROOTWARD_SAVES>/profiles/<id>/` when that override is set).
  `profile.json` holds an opaque id, display name, preferred UI language (`en` or `ja`), avatar skin, creation and last
  play dates, code language and difficulty overrides, and Trial flags. Run snapshots and `history.jsonl` remain the
  unchanged `SaveStore` format inside that folder; `SaveStore` still receives its root in its constructor.
- A small `active.json` at the profiles root remembers the last player. The title presents the players directly, with
  one-click switching and a short name, UI language and avatar form. Profile names are trimmed, length-limited and
  compared after case and full/half-width folding. The current player's code language and difficulty are applied on
  selection. The visible catalog can be translated from the same Japanese content overlay as before; rules retain
  their English catalog.
- When the profiles root is empty, old run files are copied from `user://shardrun/` (or the old `ROOTWARD_SAVES` root).
  Every copy is compared byte for byte before the new profile is published. The profile asks for its player's name on
  first launch. A later launch confirms the copied files still exist; their contents may have advanced through play.
  The old folder is left intact. A corrupt profile metadata file is skipped so other people can still play.
- The Trial is a separate `trial.json` snapshot under the same player folder. It carries the real program-run state
  plus `trial: {step_id, chapter_id, checkpoint, failures, ...}`. A JSONC content file names chapters, steps, UI
  anchors, English text keys, session events that advance a step, and generic forced setup. Japanese text uses the
  normal English-keyed overlay. The session still submits real commands to the real rules and sandbox; the trial
  layer observes accepted events and stores progress in the snapshot. A lost fight restores its saved fight checkpoint.
  Skipping or completing the Trial updates that player's flags and never appends to `history.jsonl`.

## Consequences

- A player can have an ordinary run and a Trial underway at once, without either overwriting the other.
- The profile's preferred UI language is distinct from the run's Python/JavaScript language. Existing global display
  and audio settings remain machine-wide; the per-player overrides are code language and difficulty.
- The Trial's story and pacing are content and can be revised without changing combat rules or existing saves.
