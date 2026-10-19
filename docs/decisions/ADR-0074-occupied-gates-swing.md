# ADR-0074: Gates swing while their passage is occupied

Accepted 2026-10-17. Extends ADR-0072's registered gate art.

## Context

Ordinary gates displayed their open frame permanently. The player requested solid timber doors at rest, a quarter
turn when a character enters their tile, and a return to rest after the character leaves. Both orientations and
wide entrances must behave consistently for the player and townspeople.

## Decision

- Gate world specs carry `swing: {axis, material}` through the normal cut into `world.json`. Any prop with this
  metadata uses `TownGate`; future door/gate assets can opt into the same behavior. Ordinary gates must already be
  walkable (`solid: false`). Closed appearance never blocks entry into such a passage.
- `TownMapView` collects every Walker's destination tile and, while moving, the tile containing their feet.
  Destination occupancy starts opening before contact; physical occupancy holds the leaf until the user clears it.
  Any occupied cell of the full footprint holds the gate open. It closes only after the last user leaves.
- `TownGate` animates through registered frames in 0.16 seconds, with eased selection and continuous reversal.
  Reduced motion selects the endpoint immediately. Only the gate sprite changes; walking never rebuilds the map.
- Programmed gates retain `TownThings` state and collision, including the cabbage-gate lesson and its saved state.
  Solid or programmed gates cannot accidentally become automatic passages. Building doorway warps are unchanged.
- `build_gate_art.gd` creates nine native vector gate designs with thirteen poses each. Wood has solid planks,
  timber frames, braces, iron hinges and brass latches; the existing iron variant retains bars. Posts remain fixed
  and every piece rotates in the ground plane around the same hinge. Horizontal doors open into screen depth;
  vertical doors open into a front-facing panel. Wide doors use paired leaves without a middle post.
- The generator saves registered source PNGs and endpoint SVGs under `Concept/v0.3/Update/gate-swing/`. Normal
  world cuts enforce palette and hard alpha. Shared canvases include room for the swing. Catalog and placement
  previews select the closed endpoint; lamps retain their lit preview.

## Consequences

Occupancy is transient rendering state and needs no save migration or new sandbox behavior. A gate's visible wood
stays the same size through its swing. Existing Studio incremental redraws remove and replace gate tracking with
their object nodes, while unchanged gates keep their animation. All new gate art is repository-native geometry.
