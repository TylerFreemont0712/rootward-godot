# ADR-0023: art polish in small, reviewable passes

- Status: accepted
- Date: 2026-09-28
- Related: ADR-0008, ADR-0018, ADR-0022

## Context

Several early foes were 64-pixel concepts enlarged across the arena. Their shape and color were readable, but the
pixel edges and sparse detail stood beside Vesper's finished anime/chibi sprite. Some old relic and shard icons were
similarly tiny and hard to distinguish at their real display size. The player asked for several small passes and for
foes to face the player.

## Decision

- Repaint foes using their current sprites for identity and Vesper's profile for linework, shading and character
  finish. They stand on the right of the arena and face screen left; the shared foe schema permits an optional
  `mirror` flag when the best pose needs to be flipped in game.
- Repaint relic and shard icons using their old shape and color, with the newer card icons as the pixel-art material
  reference. Their strong silhouette matters more than minute detail because they can be shown at 30 to 40 pixels.
- Work in small named passes. Capture battle screenshots for foes and inventory screenshots for icons before accepting
  each group. Record the subjects, prompt templates and output paths in `pipeline/art/sprite-polish-pass-1.json`.

## Consequences

The first pass changes six foes, four relics and four shards. The second changes three foes, two relics and two
shards (`pipeline/art/sprite-polish-pass-2.json`). The third changes the six remaining playable foes, three older
relics and three older shards (`pipeline/art/sprite-polish-pass-3.json`). All fifteen playable foes now share the
finished character-art standard and face the player. They keep their ids and behavior. Older inventory icons and
unused enemy concepts stay on the checklist for later passes. The second Deadlock Lock's old mirror setting was
removed after a program battle review showed it turning away from the player. Any future sideways sprite can use the
same `mirror` content field without adding a special case to the renderer.
