# Hand-card concepts · v0.2

The four pristine cards use one shared Rootglass layout: Cinzel lettering, the slightly lower-left branching crest, the smooth halo, a centered rules plaque, and the same shard viewport. Halo ornament and palette are comparison axes; each card keeps the same hierarchy and sizing.

| Halo concept | Palette | SVG | Preview |
|---|---|---|---|
| Bezel studs | Ember Bronze | [SVG](01-hearth-medallion.svg) | [PNG](01-hearth-medallion-preview.png) |
| Astrolabe orbit | Moonstone | [SVG](02-astral-wheel.svg) | [PNG](02-astral-wheel-preview.png) |
| Corner etching | Violet Etch | [SVG](03-velvet-oracle.svg) | [PNG](03-velvet-oracle-preview.png) |
| Rootglass Halo · lead | Verdant | [SVG](04-rootglass-halo.svg) | [PNG](04-rootglass-halo-preview.png) |

[`palette-options.json`](palette-options.json) records the palette tokens and the halo/palette pairings. The SVG concepts carry `data-frame`, `data-halo`, `data-palette`, and `data-wear` labels to keep the choices separable for a future card-art builder. These are curated concept SVGs; the manifest is a design reference, not a live renderer or a change to the game UI.

Compare all four together in the [halo and palette study](palette-halo-study-preview.png) ([source SVG](palette-halo-study.svg)).

The [long-name example](05-long-name-example-preview.png) ([SVG source](05-long-name-example.svg)) uses the catalog's longest real shard name, `from sortedcontainers import SortedList+`, and its existing B-tree art. Its title wraps to two short lines between the cost gem and paradigm crest while keeping the same Rootglass frame.

## Wear studies

Each tier uses the same pristine Rootglass base. The nick series focuses on small triangular tears in the card's outer edge, with a matching geometric halo chip added only at higher wear. The scorch series grows from the existing faint mark. The tier sheets compare low, medium, and very worn side by side:

| Treatment | Comparison sheet | Low | Medium | Very worn |
|---|---|---|---|---|
| Outer-edge nicks | [SVG](worn/nick-tier-study.svg) · [PNG](worn/nick-tier-study-preview.png) | [PNG](worn/01-edge-nick-low-preview.png) | [PNG](worn/05-edge-nick-medium-preview.png) | [PNG](worn/06-edge-nick-very-worn-preview.png) |
| Warm scorch | [SVG](worn/burn-tier-study.svg) · [PNG](worn/burn-tier-study-preview.png) | [PNG](worn/04-soft-scorch-low-preview.png) | [PNG](worn/07-soft-scorch-medium-preview.png) | [PNG](worn/08-soft-scorch-very-worn-preview.png) |

The [parchment rub](worn/02-plaque-rub-preview.png) and [hairline scuffs](worn/03-hairline-scuffs-preview.png) remain as other low-intensity examples. Wear is still a visual-only exploration: no accumulation rate, randomness rule, or elemental interaction is selected, and the text, cost, shard art, and card behavior stay the same.

The [hand-hover study](hand-hover-study.svg) uses the Rootglass design at the proposed fight size. Cards rest with about 35 px below the viewport edge, then rise and enlarge on hover. All assets here are concepts; no production card UI or game behavior is changed.
