# ADR-0034: The Library as the Living Archive

Accepted 2026-10-02.

The passage timing below is refined by [ADR-0036](ADR-0036-fitting-room-and-cinzel-default.md): one continuous
1.12-second sine in/out curve and a softer opening, retaining the opaque midpoint and input protection.

## Context

The player wants the Library to feel like a separate place, with different art, a transition in both directions,
easy catalogue navigation, and bosses separated from ordinary creatures with their encounter layers shown.
The earlier compact typography and the unchanged presentation of run menus remain requirements.

## Decision

- Open an opaque archive room within the title's existing modal lifecycle. A new painting of brass specimen
  cabinets, root-threaded shelves and a reading desk replaces the station visually. Real localized controls sit
  on top. The built-in imagegen prompt and provenance are in `finalMenuConcept/library/`; the production painting
  is `game/assets/menus/living-archive.png`. Missing art falls back to the room's solid background.
- Enter and return through a one-second procedural mist/sigil passage: 420 ms to conceal the old room,
  then 580 ms to reveal the new one. Teal mist, a brass magic circle and drifting sparks surround the reveal.
  The circle has concentric rings, a counter-rotating rune band, interlocking triangles, six vertex seals and a central glyph.
  The veil is fully opaque at the midpoint, when the room swaps. It owns mouse and keyboard focus until it clears,
  ignores repeated navigation, and restores station focus only after the return finishes. Reduced motion bypasses
  both. A clock we own supplies very subtle variation at the desk lamp and freezes immediately
  under reduced motion. Background controls remain blocked, and returning restores the same home/departure desk
  and its opener's keyboard focus without changing runs or saves.
- Start the passage in the click handler before constructing the catalogue; build the destination at the opaque
  midpoint. Warm the shader with an input-transparent draw during title loading. Shelf buttons resolve canonical
  art ids immediately but request textures only when their rows intersect the scroll viewport. Two threaded loads
  may be in flight, and at most one completed texture is retrieved per frame. A title-owned 32-entry cache retains
  artwork across shelf rebuilds and Library reopenings, with existing atlas/null fallbacks for absent assets.
  Disposing the cache consumes outstanding loader jobs. The headless dummy renderer loads one visible
  texture synchronously per frame because its texture initialization is not safe in loading threads. Selected
  dossier art and the room painting remain a small synchronous load concealed by the midpoint; reduced motion skips the passage and builds immediately.
- Integrate a larger 1520 × 760 catalogue directly into the room, with no outer window frame. A room title
  sits above the collection navigation, illustrated entries and wide reading pane. Soft shading behind the
  navigation keeps the painting visible while separating text from bright shelf details. Local typography uses
  18-pixel body text, 24-pixel headings and 14–16-pixel captions. Collections are Shards, Relics, Creatures, Bosses
  and Concepts. Search, Reset,
  rarity/role selectors and the two mode choices reuse real catalog data and canonical art. Each collection/mode
  remembers its query, selection and filters while the room is open. Long lists and source listings scroll inside
  the reading area; keyboard focus reveals list entries automatically.
- Build the bestiary from each mode's actual encounter pools. `ProgramRules.catalog_for` resolves Shardrun's
  guardian overrides and fourth layer; Spellforge reads its three original layers. Boss entries come from `boss`
  groups and ordinary creatures from `fight`/`elite` groups. Unused creatures from another mode's pool are omitted.
  Dossiers and the layer selector show actual layer numbers/names; multipart bosses list their companions.
  The same creature can appear on both shelves if future encounter data uses it in both roles.
- Annotate deep display copies. The catalogue and rules remain immutable. Health is explicitly the base value,
  since difficulty and depth alter it during a run. Existing code-language and refactor inspection stays intact.

## Consequences

The Library has its own visual identity without another scene loading path or a second copy of item art. Shared
run archives and battle screens keep their existing controls. A long dossier can still scroll, but its portrait,
identity and location share a row so the useful facts fit without excessive vertical space.

Tests cover mode-specific boss membership, layer filtering, multipart guardians, catalogue immutability, shelf
memory/reset, refactor retention, English/Japanese screen bounds, animated/reduced-motion focus restoration, blocked transition reentry and
station focus staying disabled until the return veil clears.
The actual mouse walkthrough includes an offscreen boss entry, revealed through the list's focus-following scroll.
Screenshot fixtures cover ordinary creatures, the Root guardian shelf, relics, both modes, Japanese and 1280 × 720.

A rendering probe traced the old click delay to loading all 71 shelf icons synchronously before creating the veil:
the panel alone took 1.09–1.24 seconds with Mesa llvmpipe. Visible-row loading reduced the same construction to
8–26 ms. With shader warm-up, the actual click handler takes under 1 ms and its first rendered transition frame
appears in 60–80 ms in the same software-rendering environment. These are local diagnostic measurements, not a
frame-rate guarantee for the player's hardware.
A regression checks that an offscreen row remains unloaded, visible art uses the canonical path, reopening reuses
its texture, empty searches remain safe, and the transition exists before any destination room is constructed.
