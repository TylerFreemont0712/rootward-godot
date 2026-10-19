class_name OverworldScale
extends RefCounted
## The overworld's one scale (ADR-0064): a 40 px tile, a 1280 x 720 view (2x on a 2560 x 1440 panel, 32 x 18 tiles) and
## 64 x 96 people. The art pipelines read the same numbers from content/packs/core/overworld/scale.jsonc, and a test
## keeps the two equal. Nothing else writes a tile size.
##
## Art records the tile it was drawn for. Art made before ADR-0064 was drawn for 16 px tiles and is shown scaled up
## (`upscale`) until it is remade, so the town stays whole while it changes.

const TILE := 40
const VIEW := Vector2i(1280, 720)
const PERSON := Vector2i(64, 96)
const OLD_TILE := 16


## How much larger than drawn a picture made for `drawn_tile` is shown: 1 for this world's art, 2.5 for 16 px art.
static func upscale(drawn_tile: int) -> float:
	return float(TILE) / float(drawn_tile if drawn_tile > 0 else OLD_TILE)


## The tile a picture index says its art was drawn for: its `tile`, or 16 when it predates ADR-0064.
static func drawn_tile(entry: Dictionary) -> int:
	return int(entry.get("tile", OLD_TILE))
