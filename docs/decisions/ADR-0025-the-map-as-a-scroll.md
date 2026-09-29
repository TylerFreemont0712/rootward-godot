# ADR-0025: the layer map as a scroll, its rooms apart at a glance, and every guardian in sight

- Status: accepted
- Date: 2026-09-29
- Related: ADR-0022 (polish as presentation), ADR-0024 (guardians cycle by pool), old ADR-0013 (maps like Slay the
  Spire's)

## Context

The player found the Shardrun's map "a little too basic" and asked for something "more unique ... or at least more
similar to Slay the Spire": markers that are easier to tell apart, a smooth scroll to look at the rows above, and a
visual indicator of each layer's boss. The old map squeezed a layer into its panel as identical brown chambers with
11-pixel labels; fight, elite and cache were three near-identical ambers, and the guardian was a 62-pixel icon.

## Decision

- **The map is a scroll.** Rows sit a fixed 128 pixels apart (`MapCanvas.ROW_STEP`), so a layer is taller than its
  window. The view glides toward a target (exponential smoothing, the same curve at any frame rate) from the wheel, a
  touchpad pan, a drag, the scroll bar, Page Up/Down/Home/End, and a room taking focus or hovered in the sidebar. Shadows
  and a chevron mark the edges where it goes on. Each layer's scroll is remembered for the session, so a rebuilt screen
  glides on from where it was.
- **A new layer opens on its guardian** and pans down to the first row after 0.9 s (Slay the Spire's opening), skipped
  with reduced motion or at the first wheel or drag.
- **Every kind has a hue and an outline** (`UiTheme.ROOMS`, `MapMarkers.SHAPES`): fight a round shield (sand), elite a
  spiked star (red), rest a diamond (green), forge a hexagon (violet), cache a square (gold), the guardian a crowned disc
  (orange). The shape carries the kind for eyes that confuse hues. A legend names them; pointing at a legend entry rings
  every room of that kind.
- **Paths are dotted trails.** The way walked is solid amber, the next steps flow toward the open rooms, the rest are
  faint ink; a room no path can reach any more (`ShardrunViews.reachable`) dims.
- **Every guardian is visible.** The current layer's guardian stands at the top of the map as a large portrait with its
  name plate, which the paths climb to. A rail at the left stacks every layer with its guardian's portrait: beaten ones
  ticked, the current one lit, later ones in shadow but shaped (`ShardrunViews.guardians`, the same seeded draw as the
  fight, so the one shown is the one that waits).
- **Narrow windows** (the spellbook's workbench) drop the side panel for a legend strip along the map's foot.
- **Hallway foes draw at 90%** (`FoeView.HALLWAY_SCALE`): at full size they crowded the arena. A guardian fight's foes,
  the Golem's locks among them, keep their full size; the flag comes from the fight, not the size tier.

## Consequences

- Presentation only: no rule, state or reference result changed. The map's chamber and wall art stays in use only for
  the wall; the chamber pictures are unused.
- `MapView` (scrolling, input, legend), `MapCanvas` (placement and drawing), `MapMarkers` (shapes shared with the
  legend and the rail) and `GuardianRail` replace the one file.
- `ROOTWARD_SHOT_SCROLL` holds a map shot's view at a scroll, since the opening pan is timed in real seconds.

## Amendment (same day): the map in the middle

The player asked for the map to be the centre of the screen, the deck and the rooms ahead "a side menu that can be
opened rather than something that is permanently attached", a longer climb, and paths less straight or with a
programming touch.

- **A deck run's map fills the screen.** The deck no longer sits beside it: it lies face down at the map's foot and a
  click opens it in a modal (the fight's own deck panel: every card, its details and code on hover), as the header's
  Deck button now does outside fights too. Reward, rest and forge rooms keep the deck beside them, where it is used.
- **The route drawer** at the right holds the layer, the room pointed at, the rooms you can enter next (pointing finds
  one on the map, clicking goes there) and the legend. It folds away with its "Route" tab and stays as you left it;
  folded, the legend lies along the map's foot beside the deck.
- **A longer climb.** Rows are 196 pixels apart (a layer is two to two and a half windows tall) in a column at most 960
  pixels wide, centred.
- **Winding paths**: each trail snakes a little (a sideways wave that fades at both ends, its size and side from a hash
  of the path, so it never moves), and **a code editor's gutter** numbers the rows as lines up the left, lit up to the
  line you stand on, with the guardian at the `return`.
