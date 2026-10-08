# The walkable hamlet: a proposal for Lanternroot's open world

Written 2026-10-08. A proposal for the player to judge, in the same spirit as section 5 of `LANTERNROOT_DESIGN.md`.
Nothing here is built except the first slice's assets, which are already on disk and checked below.

## 1. Why Lanternroot's pull is thin

The town is a painted picture with a letter board beside it. Houses are buttons, the town never moves, and nobody in
it needs anything you can walk to. Its only reward is its own light, and the banner that says more villages are
"waiting" is a promise, not a place. A learner has no reason to come back on a quiet day, and no sense of going
somewhere. Open worlds pull because you want to go and see things: a lane you have not walked, someone who needs you,
a light that comes on because of you.

## 2. The idea

A small hamlet seen from above, three-quarters, where you walk its lanes with the arrow keys or WASD.

- **Houses are files.** Walking up to a house and stepping through its door opens the letter that asks for that
  function. Passing letters light lanterns in their houses, as now.
- **Villagers have needs.** A villager stands where their letter is and comes to meet you, so the letter board
  becomes people in the street: Mabel at the oven, Bramble with a basket, Wick on his rota.
- **Bridges are bridges.** A rope bridge spans a root-chasm and holds only when its import exists in your code.
- **Night is walked.** When the bell rings, the Night Watch's lantern-bearer walks the lanes. Every lantern it passes
  holds, or goes dark and a gremlin moves in. You can walk to a dark lantern and relight it.
- **The hamlet grows.** Each day opens a lane; a finished day opens a path into the next village (Mosslight, in the
  design's section 5.1), so the map is the progress.

## 3. The four pulls

| Pull | How the walk gives it |
|---|---|
| Exploration | Lanes, a chasm, a path that opens after day two, places you can only reach once a bridge holds. |
| People | Villagers come to you with needs, remember what you did, and send the next letter. |
| Visible progress | Lanterns and lanes light as tests pass; a dark lantern is a reason to walk back. |
| Return | A dawn that needs you; a night that can be watched; a village that is only reachable tomorrow. |

## 4. The assets, and what was checked

Checked on disk on 2026-10-08:

- **Kenney Tiny Town** (CC0, "Creative Commons Zero"): 132 tiles at 16 px, in `pipeline/sources/vendor/kenney-tiny-town`
  (a symlink to the ProgramMe vendor folder). Grass, paths, fences, walls, house parts and small props.
- **Kenney Roguelike Characters** (CC0): a spritesheet in `pipeline/sources/vendor/kenney-roguelike-characters`, for
  the walker and the villagers.
- **Kenney Tiny Dungeon** (CC0) in the same folder, for bridges and chasm props.
- **The painted houses and the town's layout**: `game/scenes/lanternroot/town_painter.gd` and
  `game/content/packs/core/lanternroot/town.jsonc`, which already place every house.

Not checked: how the 16 px tiles scale against the painted town's 132 by 86 houses (they will need a scale that suits
the window), and whether Tiny Town's look fits the game's painted anime finish. That is the first thing to judge.

For a later 3D version, the Blender MCP can search Poly Haven (CC0), Poly Pizza (licence per model) and Sketchfab
(licence per model). Each imported model needs its licence recorded before it ships.

Every copied asset needs a licence line in a manifest next to it, the way `pipeline/` already records sources.

## 5. How it fits the code

- The rules stay pure, in `game/core/lanternroot/`: reachability of a door from the walker's cell, which house a
  villager stands at, which lantern a night's watch darkens. They are tested without nodes.
- The walk is a scene: a `TileMapLayer` for ground and walls, a `CharacterBody2D` for the walker, `Area2D` doors that
  open the existing workbench, villagers as small nodes that carry a letter id.
- Content: `town.jsonc` gains each house's door cell and each villager's spot. No engine code is needed for a new
  letter or a new villager.

## 6. Slices

1. **Walk the hamlet.** One town (Python), the tiles, the walker, doors that open the existing letters, a button on
   the town screen ("Walk the hamlet") beside the painted town. Tests: every house has a reachable door; a walk to a
   door opens its letter. Screenshots at both sizes.
2. **Villagers with needs, and the dawn walk.** Villagers come to the walker; the night's lantern-bearer walks the lanes.
3. **Secrets and the second village.** A lane that opens after a day, and Mosslight's first path.
4. **A 3D walk** (only if slices 1 to 3 are judged): a VRM walker, the shared move library's walk, and props from the
   Blender MCP search, with their licences recorded.

## 7. Decisions for the player

- **Beside or instead.** Recommended: beside the painted town until the walk is judged. Replacing it removes what is
  there now.
- **The look.** Tiny Town's 16 px pixel art beside the painted anime finish may clash. Either the walk gets its own
  look (it is a different place: the roots seen from above), or the tiles are repainted in a pass with ComfyUI. ComfyUI
  and Blender must not run at once.
- **How much walking.** The mockup warns against a full explorable campus before the lessons work
  (`Concept/v0.2/Academy/Academy-Mockup.md`). The proposal keeps the land small: one hamlet first, then one village.
