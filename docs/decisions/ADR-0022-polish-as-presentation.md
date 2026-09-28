# ADR-0022: polish as presentation around the program rules

- Status: accepted
- Date: 2026-09-28
- Related: ADR-0014, ADR-0018, `docs/ROADMAP.md` stage 6

## Context

The player could see a foe's Deadlock and Weakness names and a relic icon but could not read what they meant in place.
The title offered few ways to inspect the game's growing catalog. Enemy art had large transparent margins and fixed
sizes, making small foes hard to see at a larger window. Cast effects were shared by all program cards. New card art
needed to fit the game's bronze machinery and colored magic.

## Decision

- `HoverInfo` owns a short delayed, viewport-clamped CanvasLayer window for an enemy property or an owned relic. It
  follows the source, also opens on keyboard focus, and dies with it. The Archives glossary uses the same trait
  descriptions, so the short hover and longer browsing stay consistent.
- The Archives reads the current catalog at opening time and filters it by playstyle, role and text. Base program
  cards expose their + and both code languages in the detail pane; upgrades stay out of the top-level list.
- Shard flourishes listen to the code playback's resolved card. Their sort, split, search, element and other motifs
  are cosmetic; sandbox results and hit timing still come from the existing program run. Reduced motion suppresses
  the flourish and the new screen transition.
- Foe sprites crop transparent margins when loaded and size from the stage's available height and width. The discard
  pile scales its whole button on hover so the picture and count keep their alignment.
- The new cards use the import hooks and keyword rules from ADR-0018. Their own images, plus replacement pictures for
  Fork and Higher Order, are recorded with prompts and paths in `pipeline/art/polish-images.json`.

## Consequences

The catalog has 71 base program cards and 139 program card records including upgrades. It gains three Imports,
three elemental Constants and six other combination cards, each with tested Python and JavaScript functions and
Japanese content strings. The Archives always shows future data-driven additions without another menu edit. The new
flourishes can change independently of combat rules.
