# ADR-0033: shared art for matching card effects

- Status: accepted
- Date: 2026-10-02
- Related: ADR-0018, ADR-0023

## Context

The program Shardrun had 71 separate base-card images, 57 still at 32 × 32 pixels, even though Spellforge's 72
icons had already received polish passes. The player asked to finish low-resolution cards such as Repeat and Two
Pointers and to reuse matching Spellforge art instead of maintaining two assets for one visual operation.

## Decision

- A program card may declare `icon`, a validated texture id under `shardrun/card-` or `shardrun/shard-`.
  `ShardrunViews.art` resolves this before the older `art` base-card alias. Cards without it retain their existing
  lookup and missing-image fallback. All callers, including the hand, chips, card lists and station Library, use
  that resolver; no run layout changes are needed.
- Reuse the exact finished Spellforge texture when its subject expresses the card's operation. Numeric strength,
  source versus shape, and algorithmic work remain on the real card; they do not require a second painted flame,
  duplicating arrow, sorting action or shield. A same-named card with a different operation is mapped by meaning:
  program Charge uses Arc's spark conversion, not Spellforge Charge's multiplier battery.
- Twenty-seven base cards share Spellforge textures. Six more share another program card's picture because their
  visual operation matches: linear/binary selection, naive/memoized Fibonacci, exhaustive/DP subset selection,
  pivot partition, and recursive branching. Refactored cards resolve to their base's canonical picture too.
- Repaint 31 remaining unique placeholders with the built-in image generator. Preserve the bronze/jewel material
  language, use broad silhouettes readable at 32–64 pixels, and retain the full transparent generated originals
  for large inspection. Seven already finished program-specific images are retained.
- Delete the 33 obsolete duplicated card images and their import records, and retire their legacy pipeline jobs.
  Retire the remaining legacy 32-pixel program jobs too, so a broad old pipeline run cannot overwrite the finished
  originals. The live catalog references one physical image for each shared design.
- Keep exact prompts, source paths, original hashes, canonical mappings and review captures in
  `pipeline/art/program-icons-pass-9.json`. `program_icons.py` records candidates, makes review boards, copies
  accepted originals without repainting them, and checks resolution, transparency and provenance.

## Alternatives

Copying Spellforge PNGs into each card filename would look correct but retain duplicate files that could drift.
Hard-coding a cross-mode mapping in the renderer would hide art decisions in engine code. Upscaling the old
32-pixel images would preserve their missing detail rather than supply the requested finished art.

## Consequences

The 139 program-card records resolve to 61 finished textures, with 38 program-specific PNGs and 23 shared
Spellforge PNGs. Save ids, code, effects, costs, roles and complexity are unchanged. Existing saves need no migration.
The art tests check shared Resource identity, every refactor, path validation, asset existence and minimum
resolution. Review boards compare old and final icons at 32, 64 and 128 pixels; screenshots verify real controls.
