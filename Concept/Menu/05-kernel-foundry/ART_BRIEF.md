# Kernel Foundry · next art pass

Requested after reviewing the layout mockup: replace the simple scenery and character drawings with decent, richer art assets. Keep the compact layout, current palette, underground descent, and recognizable Shardrun interface.

## Visual contract

- Use the game palette from `game/ui/ui_theme.gd`: ground `#120e0a`, panels `#1a1410` / `#211a13`, borders `#3c2f21`, amber `#f2a541`, parchment `#e9dcc0`, muted text `#a58f6e`.
- Build an inhabited machine dungeon: worn stone, brass lift machinery, lanterns, workshops and root/cable pathways. Depth leads down toward the Kernel.
- Use stylized painted scenery or cel shading with large readable forms. Add intentional artistic detail, while keeping character rendering attainable at battle scale and consistent with the title.
- Preserve quiet areas for controls and code. Keep ornament, lamps and strong highlights clear of text and silhouettes.
- Keep existing shard art, card hand, program slots and code/work area recognizable.
- Use **Character → Skins** for a persistent cosmetic appearance. Keep one character identity across skins.

## Asset sequence when generation is available

1. A richer **title / lift-station backdrop**, 16:9, with the left side quiet for compact launch controls and the shaft descending on the right. Produce the backdrop without baked-in UI text.
2. A matching **descent-map environment**, a cutaway shaft with upper galleries, Heap and deeper Kernel foundations. Room markers and connectors remain separate UI elements, and every route progresses downward.
3. A matching **battle arena**, wide grounded floor, small cel-shaded hero at left and foes at right, a readable open central stage, clear top HUD region and lower interface area. Produce scenery separately from actors and UI.
4. A **character/skin style study** at actual battle scale, richer than the mock puppet while retaining a simple silhouette and plausible game asset construction. Reuse the same rendering on title, Character and battle.

Generate one cohesive art direction first and inspect it before making the remaining assets. Final images should be copied into this project and documented with prompts and provenance. This pass is awaiting the built-in generator's reported reset at **2026-10-01 22:56:51 JST**. No API/CLI fallback was used.
