# Lanternroot town art: a continuation brief

Written 2026-10-09 from ADR-0061 and the current Lanternroot map. This is a design brief for future art and layout
passes. The spatial beats below describe what is already in the town; all asset changes and new scenes are proposals.

## The visual story

Lanternroot should read as a safe, inhabited place that teaches by letting the player notice how it works. The player
steps out of a small home at the southern edge, follows paths toward people with small practical problems, and reaches
the Lantern Root at the town's center. From that shared square, two routes show what code can change: the north lamp
lane ends at Lumen's shrine, while the south lane reaches cottages, water, and Brannoc's forge. East, the Root Gate
holds the larger mystery in plain sight. Its darkened lamps and closed face give later lessons somewhere visible to
lead.

Keep the mood welcoming and specific: a working village that grew around an old tree, rather than a row of fantasy
buildings placed on a blank field. Let paths, thresholds, garden plots and residents explain each place before a
dialogue box does. Hotaru's small firefly glow is the first light the player learns to recognize; town lanterns can
answer that light as quests are completed.

## Existing spatial beats

The current map is the 56 by 40 Lanternroot v2 layout in `game/content/packs/core/overworld/maps/lanternroot.jsonc`.
It already has a central cobbled square, an eastward road toward the Root Gate, a north lamp lane to the shrine, and a
southern route past home, cottages, the pond and forge.

| Beat | What is already there | Art direction for a future polish pass |
|---|---|---|
| **The home doorstep** | The player starts near home on the south lane; a mailbox and small garden marks make this the opening threshold. | Keep the smallest, warmest facade in town. Use one lit window, a clear door and a short path that points north into the village. Leave room for the player and Hotaru to read at a glance. |
| **The Old Stones** | Morrow keeps the quiet burial garden on the western side, with tombstones, mushrooms, a sign and a fenced edge. | Lower the visual noise here. Use cool stone and leaf shadows, a few carefully placed flowers, and one repaired section of fence. The quiet should feel cared for, not abandoned or frightening. |
| **The Archive and work plots** | Vell's Archive and Mira's workshop sit among the north-west buildings; a fenced vegetable plot, cart and stacked supplies already suggest daily work. | Give the Archive a distinct book-window or shelf silhouette, and let the workshop show one gear or brass detail. Keep the shared wood, plaster and stone materials consistent with nearby homes. |
| **Lantern Square** | The Lantern Root anchors the cobbles; the noticeboard, well, benches, banners and stall make a meeting place for Pip, Orin, Fern and passers-by. | Keep an uncluttered walking ring around the tree. The tree is the strongest silhouette in the town, with its trunk and hanging lights readable before leaf texture. Place props in small groups that describe use, with open floor where people meet. |
| **The lamp lane** | A sign and six grouped lamps lead north-east to the Lantern Shrine, where Lumen tends the lights. | Make the lamps a visible sequence from square to shrine. The dark-to-lit quest should read from their warm pools and small color changes; give the shrine a calm, bright endpoint rather than another large building. |
| **The south lane and waterside** | Home and cottages sit along the south route; the pond, footbridge, orchard edge and forge lead toward Seren and Brannoc. | Shape the repeated cottages into personal homes with small, legible tells: a map in Pell's window, a sleeping glow at Seren's sill, and a doubled lock at Hollis's door. Let the pond edge and bridge break up the long grass run and make a quiet place to watch Hotaru. |
| **The Root Gate road** | The Warden and Hollis stand by the eastern approach to the sealed Root Gate. | Frame the approach with roots and older stone so the eye moves from the village's warm wood to this threshold. Keep the gate visibly closed until its future quest opens it. |

## Materials, light and pixel scale

- Work on the 16 px grid and inspect the world at its logical 320 by 180 view. People are 16 by 24 px; generated
  buildings and landmarks range from 32 to 144 px. A large asset needs a strong outline and readable door at its actual
  in-game size, not only on an enlarged sheet.
- Stay inside `pipeline/pixel/palette.json`: cream `plaster`, honey `wood` and `thatch`, cool `stone` and `cobble`,
  layered `leaf` and `grass`, clear blue `water`, amber `glow`, and the yellow-green `firefly` ramp. Keep the ink
  outline at `#2a1d2b`; shadows lean violet and the key light comes from the upper left.
- Keep color in deliberate clusters. The current ComfyUI landmarks have useful detail and variety, while their dense
  surface texture can compete with the simpler grass, terrain and hand-placed props. Favor large roof, wall, canopy and
  root shapes first; add only enough small marks to make a shop, shrine, archive or home recognizable.
- Make the time of day a scene treatment. Keep lantern glows and Hotaru's light as separate in-game effects so future
  day, dusk and night views can reuse the same building art. For night, let the existing `night` ramp cool the ground
  while lanterns keep their warm `glow` colors.
- Keep ground transitions in `pipeline/pixel/terrain.py` and character parts and foot-scale props in the `.sprite`
  workflow. Use ComfyUI for the larger silhouettes where it already helps: houses, landmarks, trees and larger props.

## ComfyUI update order

The current `pipeline/pixel/manifest.json` provides reproducible, palette-locked entries and two candidates for most
assets. Use it as the source of truth for prompts, seeds, selected candidate and output size. The free local workflow is
ComfyUI plus the existing palette-lock and lint steps; keep Blender closed while ComfyUI is running, as required by
`CLAUDE.md`.

1. **Root Gate (`ow-landmark-rootgate`)** — the current art shows a dark, open cave mouth, but the map and Warden's
   story say the gate is sealed. Rework the macro shape into a closed stone-and-root threshold: a visible barred or
   rooted face, a clear central seam, and only a faint glow behind it. Save an opening animation and the bright root
   interior for the future quest.
2. **Lantern Root (`ow-landmark-lanterntree`)** — keep the broad, ancient silhouette, but make a few hanging paper
   lanterns distinct against the canopy and let the trunk remain the square's visual center. Reduce leaf-level noise
   where it merges with the outline; leave animated glow to the scene effect.
3. **The village building family** — review `ow-building-home`, `ow-building-cottage`, `ow-building-inn`,
   `ow-building-archive`, `ow-building-hall`, `ow-building-shrine`, `ow-building-shop`, `ow-building-workshop` and
   `ow-building-smithy` together. Keep one camera angle, one bottom door baseline, shared shadow direction and common
   timber/plaster/stone language. Give each place one accent that supports its role: red awning for the inn, book mark
   for the Archive, warm entry lamp for the shrine, brass detail for the workshop, forge glow for the smithy.
4. **Town-edge trees and orchard** — compare `ow-tree-oak`, `ow-tree-birch`, `ow-tree-apple` and their `*2` candidates
   in the full map. Use silhouette and height variation to make the woods feel like a boundary and the apples feel
   planted; avoid repeating identical crowns as a continuous wall.

For each change, render one focused family, keep its seed and pick in the manifest, and compare the candidates beside
the current art. Run the existing `scripts/pixel.sh --lint`, then inspect the building contact sheet and the town and
square screenshots at the real game scale. Check the door against the map footprint, confirm the palette and hard
alpha, and look for path blockage or visual tangles where walkers pass behind an asset. Capture a fresh full-town view
before accepting a visual change. Keep prompts and all source images local; no paid services or outside asset packs are
part of this brief.

## Future town concepts

These are future scenes or quest treatments grounded in the existing map and cast; they are not present features.

### The Lane of Little Lamps

Build on the existing north-east lane and **Light the lane** quest. Before the lesson, each lamp is a distinct dark
shape along the path. As the player's `light_all(lamps)` works, the lamps turn on one by one, giving the route a clear
visual pulse that ends at Lumen's shrine. A small sign and a resting spot make the sequence easy to read without
crowding the path. Use the current lamppost and shrine assets as the base for the scene.

### Cottages by the answering pond

Turn the existing south lane into a short, lived-in loop past the cottages, orchard edge, pond and bridge. Each doorway
has one recognizable personal clue, and the water is a quiet stage for Hotaru's future `glow(t)` lesson: fireflies at
the bank answer her pattern in small reflections across the pond. Keep water and glow colors separate so the pattern
reads as a few deliberate lights, not a field of extra texture. Seren, Pell and Brannoc already give this route
neighbors with different kinds of work.

### The sealed Root Gate

Extend the existing Warden encounter into a later transition from the town to the roots below. The first approach
shows an old, closed threshold with a simple root motif. After the player composes the earlier programs, the root
pattern joins into one continuous line and the seal opens; only then reveal the chamber beyond. Keep this as the town's
long-view promise, so the current sealed image has a purpose from the beginning.

## Art-pass completion cues

- From the square, the Lantern Root is the first read; the lamp lane, south route and Gate road remain easy to tell
  apart by their silhouettes and warm/cool cues.
- The Root Gate visibly agrees with its sealed state, and each building's door lands on its map footprint.
- Homes feel related, while residents' homes, shops and lesson landmarks remain distinct at 16 px scale.
- Green space stays walkable and calm, with purposeful clusters at paths, gardens and the pond edge rather than uniform
  texture across every open cell.
- A new in-game screenshot shows the changed assets at the actual world scale and preserves clear walking routes.

## References

- `AGENT.md` and `CLAUDE.md` — project rules, asset workflow and visual verification.
- `docs/decisions/ADR-0061-lanternroot-overworld.md` — town and pixel-art decisions.
- `Concept/v0.3/05-lanternroot-overworld.md` — town tone, pipeline and lived-in details.
- `Concept/v0.3/06-overworld-handoff.md` — art-source evidence and the current visual workflow.
- `Concept/v0.3/07-lanternroot-quests.md` — the lane, pond-light and Root Gate quest ideas.
- `game/content/packs/core/overworld/maps/lanternroot.jsonc` and `pipeline/pixel/manifest.json` — current layout and
  ComfyUI asset entries.
