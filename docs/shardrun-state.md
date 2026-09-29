# The Shardrun state

A run is one Dictionary, saved whole after every command (a snapshot, not an event log: the rules will keep changing,
and a snapshot stays readable where replayed events would not). `Shardrun.step(state, command, catalog)` returns a new
one, or a refusal. Keys are snake_case end to end, like the content. Optional keys are absent, not null.

```
version: 2
seed, language, difficulty: String
status: "map" | "battle" | "reward" | "rest" | "forge" | "won" | "lost" | "abandoned"
integrity, integrity_max: int
layer: int                                  index into config.layers
map: {nodes: [{id, row, col, kind}], edges: [[from, to]]}
position: String | null                     the room the Maintainer is in or just left
visited: [String]                           rooms entered on this layer, in order
playstyle: "spellbook" | "deck" | "program"
spells: [{id, name, capacity, shards: [shard id]}]
inventory: [shard id]                       a spellbook run's spare shards
deck: [shard id]                            a deck run's cards
relics: [relic id]
battle?: {
  kind: "fight" | "elite" | "boss", turn, mana, block, casts: int
  foes: [{uid, id, name, sprite, hp, max, shield, weak: [element], resist: [element], trait?, pattern?,
          intents: [intent], intent_index, stoked, nullified, flavor}]
  cast: [spell id]                          spells already cast this turn
  last_cast_ward?: bool
  draw, hand, discard, held: [shard id]     a deck run's piles; empty in a spellbook run
}
reward?: {chest?: {curse_chance}, cursed_relic?, shards?: [id], relics?: [id], spell?: {name, capacity}}
revision: int                               accepted commands so far
sandbox: bool                               a dev run: the dev commands work
log: [{kind, text, foe?, spell?, amount?, element?, bolt?, target?, pierce?, mult?, affinity?, blocked?}]
stats: {fights, turns, casts, damage, shards, relics, layers, mana_spent, bolts, fizzled,
        damage_by_spell: {spell id: int}, best_cast}
trial?: {active, done, step_id, chapter_id, completed: [step id], checkpoint: battle snapshot,
         failures, pending: [session event], hint, map_rows, map_columns, room_foes}
```

The log is what the last command did, in order; the stage plays it back as animation. Its entries are the old game's
(old ADR-0019), so a scatter is drawn as a scatter and a pierce as a lance.

Commands are listed at the top of `game/core/shardrun/shardrun_commands.gd` and `shardrun_dev.gd`.

Pip's Trial uses the same state and commands, saved separately as `trial.json` under the active profile. The only
extra command is `trial-next` for Pip's story beats. The Trial's JSONC names the event and any card/order/log checks
for each step. Its checkpoint is a copy of the fight entrance with its own checkpoint empty, so it cannot recurse.
A lost fight restores that copy; finishing or skipping marks the active profile's tutorial flags. Trial runs never
enter `history.jsonl`.
