# Programming paths

Rootward teaches programming through two different play loops.

| Path | Practice | Player action | Progress |
| --- | --- | --- | --- |
| Artificer / Shardrun | Function composition | Arrange shard cards into spells and cast their Python or JavaScript code | Combat run and deck |
| Artificer / Spellforge | Reusable functions | Build a spellbook between battles | Combat run and spellbook |
| Verifier / Code Lab | Reading code and tracing algorithms | Inspect executable JavaScript, predict an intermediate value and exact stdout | Twelve lessons, three chapters, saved stars |

## Verifier loop

The code lab uses no cards, foes, guard, or mana. A lesson shows a real JavaScript program and an intermediate-state checkpoint. The player chooses the checkpoint value and types the exact console output. An execution board shows the algorithm stages and working set; clicking the next stage opens one clue on the trace tape. The program then runs in the same WASI sandbox used by Shardrun; the player's output is compared with actual stdout. The result explains the state and records one to three stars. A correct final output unlocks the next lesson. Traces and repeat attempts reduce the score but do not stop progress.

The first chapter covers array indexes, transformations, slice boundaries, and branching. The second covers shared references, copying, closures, and stacks. The third covers binary search, frequency tables, memoization, and breadth-first traversal. Lessons and their explanations live in `game/content/packs/core/verifier/course.jsonc`.

## Future paths

Refactoring could ask the player to preserve behavior across several inputs while reducing work. Scheduling could make event order visible as a timeline that the player rearranges. Each needs its own teaching interaction and should only share sandbox and UI infrastructure with the existing paths.
