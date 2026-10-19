# ADR-0065: The player's look as layers of the cast's style

Proposed 2026-10-13; the first art kit is a prototype, now expanded to separate base anatomy and the initial outfit and hair choices. Builds on ADR-0063 (the cast) and ADR-0064
(the 40 px world, 64 x 96 people).

**Status: reverted 2026-10-17 after visual review.** A temporary single-sheet 25 x 35 rollback was followed by the
complete 64 x 96 male/female animation sheets in [ADR-0071](ADR-0071-authored-player-animation.md). This record is kept
as a history of the prototype; its runtime layer renderer and part kit have been removed.

## Context

The townspeople are ComfyUI sprite sheets, one per look (ADR-0063), and the player's start look has one too. The old
creator offered many 25 x 35 hair, outfit and accessory parts that no longer match the cast's 64 x 96 art. ComfyUI
cannot run while the game plays, and one sheet per combination is far too many to make ahead.

## Decision

- **Every part is a layer of the cast's style.** `pipeline/animation/parts.py` makes each part like a cast sheet: a
  Blender blockout of a reference figure wearing it (the start look's tunic and short hair, with only the part's slot
  changed; the body alone in a plain undersuit, bald), turned four ways, restyled by ComfyUI, held to the blockout's
  outline. Parts that share a figure share its render.
- **Cut by where the part shows.** Blender tags every object with its layer (body, outfit, face, hair, hat, item) and
  renders, for each view, a mask of where that layer shows with every other object a holdout. After growing a mask to
  preserve its outline, the export removes pixels covered by higher layers, so hair and accessories cannot be baked
  into both lower and upper layers. The player's head and face are kept together from the reviewed cast sprite, and its
  matching short hair is cut into a separate recolourable layer. Outfit-made legs and boots (trousers, armour) belong
  to the outfit.
- **Recoloured by ramps.** Each layer is locked only to its own slots' default ramps (`palette.json` `slots`, all
  different) and a few fixed ramps (`parts.json` `lock`: hair to the hair ramp, outfits to the cloth slots and metal),
  so the game swaps each slot's shades for the ramp the look chooses, as the old parts did (four shades now). Locking a
  layer to every ramp of the figure made brown hair snap to the boots' brown in places, which then did not recolour.
- **Layered in the game.** `CastLook` keeps each part as its own `CharacterSheet` and creates a flattened texture only
  for screens that need one picture. `Walker` gives each piece its own sprite, places every piece on the same ground row,
  and orders them for the current facing. Parts indexes declare attachment points and facing-specific depth, so the
  held item can sit behind the body from the back. Each layer shares the same stop, four walk poses and settled idle
  timing. Arms and legs alternate, the torso and head bob together, and held entities follow the hand attachment.
  Older cast sheets without step columns keep their idle fallback.
- **Only offer parts in the cast kit.** The creator lists a hair, outfit or accessory only when a matching 64 x 96
  layer is available. The current options are short or long hair, a tunic or robe, and an optional wide hat, with skin,
  eye, hair and cloth colors. Older saved part choices normalize to the new defaults; they are never drawn at the old
  scale on the player.

## Alternatives

- **One sheet per combination.** Thousands of renders.
- **Render the player's look on demand.** Needs ComfyUI and a GPU while playing, and minutes per change.
- **Hand-placed parts at 64 x 96.** Fifty parts in four facings is months of pixel work.

## Consequences

- The creator intentionally has fewer part choices until their cast-style layers are built. Add each choice to
  `looks.jsonc` only after its part exists in the 64 x 96 kit and its four facing previews have been reviewed.
- A layer is what one render drew; a different outfit under long hair may show small seams where the reference's outfit
  was narrower. Judge it in `Concept/v0.3/animation/parts/preview.png`.
- The base figure has separate head, torso, arms and legs; facial features are part of the head, so the character has
  one face. Hair, clothes, hats and future held items remain separate layers. The four walk poses are derived from the
  aligned part art, alternate over each tile in all four facings, and settle back to standing on arrival. Outfit hems
  follow the torso bob while outfit-specific cloth movement can gain authored poses later.
- The creator offers skin, eye, hair and cloth colors, two hairstyles, two outfits and an optional hat. It does not yet
  equip held items from the bag; the held-item layer already has a `hand` attachment for that inventory work.
