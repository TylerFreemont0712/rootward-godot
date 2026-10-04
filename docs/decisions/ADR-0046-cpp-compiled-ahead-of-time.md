# ADR-0046: C++ as a third spell language, compiled ahead of time

Accepted 2026-10-04. Track C of `docs/PHASE2.md`; extends ADR-0002 (the sandbox) and ADR-0015 (measured loops).

## Context

The player asked for C++ or C# in the Shardrun. Spells run as WebAssembly under wasmtime (ADR-0002), and Python and
JavaScript are interpreters there: each job sends the cards' source, and the interpreter loads it. C# has no working
WASI support in .NET today (removed from .NET 9, absent in .NET 10), and running it outside the sandbox is ruled out
(AGENT.md), so C++ it is. C++ must be compiled, and a compiler in the turn loop would make every preview wait.

## Decision

- **Compile ahead of time, not per turn.** Cards are content, not code the player types, so every card's C++ is
  compiled by `scripts/build-cpp.sh` with wasi-sdk 34 (pinned by SHA-256 in `scripts/fetch-sandbox.sh`, kept in the
  user cache, outside the game) into two modules: `program.cwasm` (program cards, and every mutant the Mutator can make
  of each, ADR-0026) and `spellforge.cwasm` (Spellforge's shards). A C++ job names its module and sends card ids; the
  harness finds each card's function in a generated table. A three-card program runs in about 12 ms (JavaScript 15).
- **One harness contract for three languages.** `game/sandbox/cpp/harness.cpp` reads the same input and prints the
  same result lines as `spell_harness.py` and `.js`; a small JSON layer prints numbers as JavaScript does, so the
  worked examples compare exactly. Each mode has its own bolt type (`program.hpp`: whole `power`, an optional `foe`,
  `block`; `spellforge.hpp`: fractional `power` and optional `target`/`pierce`/`ward`/`mult`).
- **Counting as the others count.** `CppSource` puts a loop counter at the start of each loop body and a call
  counter at the top of each function, on the line it measures; `#line` keeps `__LINE__` and compiler errors on the
  card's own numbering. A card is one function `Bolts name(Bolts bolts, const Battle& battle)`; `docs/CPP_CARDS.md` is
  how one is written.
- **Exceptions are on** (wasm exception handling, `-fwasm-exceptions` with the new encoding, run with `-W
  exceptions=y`), so a card's `std::out_of_range` is reported as `std::out_of_range: vector` against that card.
- **C++ is a full language or none.** Every card and shard has C++ (`ShardrunChecks.LANGUAGES`), every worked example
  runs in it (`scripts/validate.sh`), and the census lists its mutants. `scripts/try-cpp.sh <ids>` checks named cards
  in a private build, which is how the 212 ports were written side by side. Validation warns when the build is older
  than the cards (`CppSource.stale`).
- **On screen**, `CodeLanguage` names each language, its comment mark, its file and its run command (`./main` for the
  built `main.cpp`); the program and spell listings are written as C++ (`Bolts program(const Battle& battle)`, the seed
  as designated initializers).

## Consequences

- A card's C++ change needs `scripts/build-cpp.sh` (about 12 s with its object cache) before it plays; validation says
  so when it is stale.
- A C++ error names the card and the exception but not the line: C++ exceptions carry no source position.
- Player-written C++ (an Academy track, a Card Workshop) would need a compiler at play time; YoWASP's clang runs under
  wasmtime and can be measured when that comes.
- The download for a fresh checkout grows by wasi-sdk's 190 MB (in the cache).
