# Paths and fantasy woodland ground source art — 2026-10-19

Created with the built-in ChatGPT Image Generation tool after the player asked for richer ground and connected path
materials. Both 1254×1254 source PNGs are retained unchanged. The game does not draw these sheets directly;
`pipeline/pixel/terrain.py` samples their rows into eight stable 40×40 variants per ground, locks each to the shared
palette, reconciles repeated edges, and generates the sixteen dual-grid edge shapes.

## Path materials

Source: [lanternroot-pathways-imagegen-2026-10-19.png](lanternroot-pathways-imagegen-2026-10-19.png).

- Row 1: brick path, patterns 1–4.
- Row 2: stone path, patterns 1–4.
- Row 3: wood path, patterns 1–4. Alternating plank directions are aligned by the terrain build.
- Row 4: another brick pattern family, used for additional stable brick variants.
- The existing continuous dirt path remains the dirt option; it retains its previously approved source and exposed-edge
  wear.

Exact prompt:

```text
Use case: stylized-concept. Asset type: source atlas for 40-pixel top-down RPG ground textures. Primary request: create one precise square 4-column by 4-row pixel-art terrain atlas with equal square cells and thin, uniform dark separators. Every cell is a seamless, top-down orthographic material swatch with no raised border; the game creates path edges separately from this material texture. Row 1: warm red-brown handmade brick paving with irregular worn bricks, subtle dark joints and tiny moss flecks. Row 2: cool grey-violet hand-cut stone slab paving, broad irregular slabs, fine seams, restrained lichen. Row 3: weathered honey-brown oak plank walkway, parallel broad wooden boards, occasional tiny pegs and restrained green moss in joints. Row 4: more pattern variation for the same warm handmade brick material as row 1, same hue and value range with different brick placement. Across each row, columns are four distinct but compatible pattern variants of that same material, with consistent texture density and average color. Style: crisp, readable cozy woodland-fantasy RPG pixel art matching a hand-authored 40x40 tile, chunky pixel clusters, hard pixel edges, nuanced but restrained detail, shared muted palette of Rootward's warm woodland town. Composition: exact 4x4 atlas, cells fill the full image, no margins beyond the separators. Materials/textures: each swatch repeats without a visible seam; details continue naturally at its outer edges. Constraints: no labels, text, symbols, numbers, perspective, cast shadow, scene, objects, plants larger than tiny moss flecks, gradients, vignette, border around individual paving. No extra rows or columns.
```

## Woodland materials

Source: [lanternroot-fantasy-ground-imagegen-2026-10-19.png](lanternroot-fantasy-ground-imagegen-2026-10-19.png).

- Row 1: dark root-woven loam (`root_floor`).
- Row 2: fern understory (`fern_moss`).
- Rows 3–4: two families of subtle firefly-specked glow moss (`glow_moss`).

Exact prompt:

```text
Use case: stylized-concept. Asset type: source atlas for 40-pixel top-down RPG woodland ground textures. Primary request: one precise square 4-column by 4-row pixel-art terrain atlas with equal square cells and thin uniform dark separators. Every cell is an orthographic ground material swatch, never a scene and never a raised tile. Row 1: deep warm root-floor loam, dark earthy ground woven with scattered thick golden-brown tree-root strands, small leaf fragments, fine soil and moss. Row 2: lush fern understory, richly varied greens with small readable fern fronds, leaf litter and a few tiny pale stones, no large plants. Row 3: ancient glow-moss ground, dark pine-green moss pads, muted warm amber and soft firefly-green pinprick spores, magical but subtle and readable, no bright glow bloom. Row 4: a second pattern family for the same ancient glow-moss material as row 3, same deep green base and subtle amber/firefly palette, varied moss clusters. Across each row, the four columns are distinct compatible texture variants with the same material, hue, brightness and detail density. Style: crisp hand-authored cozy woodland-fantasy RPG pixel art at 40x40 scale, top-down orthographic, chunky deliberate clusters, hard pixel edges, restrained fine texture, cohesive muted warm forest palette matching Rootward. Composition: exact 4x4 atlas, each cell fills its square; dividers are thin and uniform. Texture details continue naturally through the cell edges for seamless repeats. Constraints: no labels, text, characters, buildings, props, scene perspective, large mushrooms, large flowers, gradients, soft blur, glow bloom, vignettes, framed tiles, extra rows or columns.
```

## Integration and review

Each path uses the same continuous exposed-boundary rule as dirt: a single irregular rim follows only path-to-ground
edges, while a three-cell-wide run keeps its center unframed. All outdoor surfaces are palette-locked, alpha-checked
and covered by variant, border-compatibility, all-layer and incremental repaint tests. Runtime output is
`game/assets/overworld/tiles/terrain.png`; the terrain layout is `game/assets/overworld/tiles/terrain.json`.
