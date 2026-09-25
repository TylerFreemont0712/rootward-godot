# Shardrun: one program, speed race

The Artificer's deck run begins with **one Program**. Build a left-to-right chain from the hand, cast it once, then end the turn. The Second Grimoire grants a second Program that can be built and cast on the same turn. Forges and guardian rewards do not grant extra casts in this mode. Spellforge still keeps its regular spellbook rules.

## Initiative

Every shard has an algorithmic complexity. A spell inherits the slowest tier in its chain: `O(1)`, `O(log n)`, `O(n)`, `O(n log n)`, or `O(n²)`. Enemy intents have the same scale. When a spell is cast, living enemies with strictly faster intents act first. Ties go to the player. Each enemy acts at most once per turn, so an early action does not repeat at End Turn. The preview and the enemy intent tag show the relevant tiers. Mana billing still uses actual work units; speed does not replace that cost.

The Null Wraith has an O(1) intent and a speed veil. Its veil ignores damage from spells slower than O(n). Early Return and Branch Gate offer fast answers; a speed relic can accelerate a longer chain.

## New algorithm shards

| Shard | Tier | Programming idea | Build role |
| --- | --- | --- | --- |
| Early Return | O(1) | bounded slicing | trim a volley to a fast first pair |
| Branch Gate | O(1) | conditional and early return | turn the first weak bolt into a ward, or a strong one into a piercing strike |
| Binary Pick | O(log n) | binary search | select a strong bolt from ascending power input; pairs with Census |
| Indexed Map | O(n) | indexed mapping | reward later bolts in a volley |
| Weakest Route | O(n) | mapping and targeting | direct attacks at a vulnerable foe |
| Reduce Sum | O(n) | reduction | trade volley size for one concentrated bolt |
| Memo Table | O(n) | hash set | reward repeated elements |
| Pairwise Loop | O(n²) | nested loops | grow every bolt with every comparison, at a steep speed cost |

Some promising chains: **Census → Binary Pick** for sorted search; **Fork → Indexed Map** for late bolt power; **Kindle → Memo Table** for repeated fire; **Fork → Pairwise Loop** for brute force against slow enemies; **Branch Gate** alone against the Wraith. The 24 new relics provide speed shifts, discounts, targeting payoffs, mixed ward and attack payoffs, and deck cycling options. Their descriptions state the exact conditions.

## Art

The relic atlas at `game/assets/concepts/relics.png` has 30 transparent concepts in a 6 by 5 grid. The shard atlas at `game/assets/concepts/shards.png` has 12 transparent concepts in a 4 by 3 grid. The 24 new relics and 8 new shards use cells through `Art.texture`; spare concepts remain available for later items. Both sheets were made with the built-in GPT image generator from prompts for distinct dark fantasy programming relics and algorithm shards, transparent gutters, no labels, and consistent lighting.
