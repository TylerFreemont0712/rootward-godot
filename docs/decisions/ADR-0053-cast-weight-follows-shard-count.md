# ADR-0053: Cast weight follows shard count

Accepted 2026-10-05.

## Context

The light or heavy cast animation was selected from volley size and total damage. That made many small programs use
the heavy animation whenever they produced a large or powerful volley, so the animation did not communicate the
size of the spell the player assembled.

## Decision

- One or two executed shards use the light cast; three or more use the heavy cast.
- When a code trace is available, count its completed shard calls and the imports actually used. Without a trace, count
  the shards in the cast spell.
- Do not use damage, bolt count, or damage type to select the gesture.
- Keep circle tier and layer order governed by shard count as already decided in ADR-0039.

## Consequences

The animation now reflects the work the spell actually used. A high-damage spell made from one or two shards remains
a light cast, while a low-damage spell made from three or more shards is heavy. If execution stops early, unvisited
shards do not make the cast heavy. Circle appearance and combat results are unchanged.
