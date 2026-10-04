# Writing a card in C++

How a Shardrun program card or a Spellforge shard is written in C++ (ADR-0046). Every card already has a Python
(`<id>.py`) and a JavaScript (`<id>.js`) version beside its `<id>.jsonc`; the C++ one is `<id>.cpp` in the same
folder, and it must return exactly the bolts the other two return for every worked example in the `.jsonc`.

Check a card (or several) with `scripts/try-cpp.sh <id>...`: it builds only those cards, in a private folder, and
runs their worked examples. `C++ ok: N cards` is the goal. The game's own build is `scripts/build-cpp.sh`.

## The shape of a card

One function, named after the card's `function` field in snake_case (the Python name), that takes the volley by
value and the battle by const reference, and returns the next volley:

```cpp
Bolts amplify(Bolts bolts, const Battle& battle) {
  // One pass over the volley: every bolt gains 3 power. `bolts` is our own copy, so changing it in place is safe.
  for (Bolt& bolt : bolts) bolt.power += 3;
  return bolts;
}
```

- The function's signature is always its first line; helper functions, structs and constants may come before it
  (as they do in the JavaScript), all in the same file. Each card is built in a namespace of its own, so helper
  names never clash with another card's.
- No `#include` and no `using namespace std;`: the card's header already includes `<algorithm>`, `<cmath>`,
  `<functional>`, `<map>`, `<numeric>`, `<optional>`, `<queue>`, `<set>`, `<stdexcept>`, `<string>`,
  `<unordered_map>`, `<unordered_set>`, `<utility>` and `<vector>`. Write `std::` in full.
- Two spaces of indent, as the JavaScript cards have. A loop's `{` goes on the loop's own line (the build counts a
  loop's rounds by the line its body opens on; a loop with its brace on the next line is not counted). A loop of one
  statement may stay on one line: `for (Bolt& bolt : bolts) bolt.power += 3;`.
- Keep the card's comments (the first comment is its explanation in the game), its algorithm and its complexity: an
  O(n log n) card stays O(n log n), a recursive card stays recursive, a table stays a table. Prefer a plain loop to a
  `std::` algorithm with a lambda where the JavaScript loops, because loops are what the code walkthrough counts and
  what the player is learning to read. Use the standard library where the other versions use theirs (a sort is
  `std::stable_sort` with a comparator, a heap is `std::priority_queue`, a set is `std::set`).
- Mutation testing edits the text (` >= ` to ` > `, ` + 1` to ` - 1`, `max(` to `min(`, ` * 2` to ` * 1`, ` + ` to
  ` - `): write operators with spaces round them, as the other versions do.

## What a card sees

Program cards (`game/sandbox/cpp/program.hpp`):

```cpp
struct Bolt {
  int power = 0;
  std::string element = "none";   // "none", "fire", "frost", "spark", ...
  std::optional<int> foe;          // the foe it flies at (an index into battle.foes); unset: the front foe
  bool block = false;              // a ward: becomes your block instead of hitting anyone
};
using Bolts = std::vector<Bolt>;
```

Spellforge shards (`game/sandbox/cpp/spellforge.hpp`): power is a `double` (Fork makes 60%), and the other fields are
optional, kept only when the bolt had them: `bolt.ward.value_or(false)` reads one, `bolt.ward = true` sets it.

```cpp
struct Bolt {
  double power = 0;
  std::string element = "none";
  std::optional<std::string> target;  // "front", "back", "all", "strongest" or "weakest"
  std::optional<bool> pierce;
  std::optional<bool> ward;
  std::optional<double> mult;
};
```

Both (`game/sandbox/cpp/common.hpp`):

```cpp
struct Foe { std::string name; int hp, max, shield; std::vector<std::string> weak, resist; };
struct Me { int hp, max, block, mana; };
struct Battle {
  int turn;
  Me me;
  std::vector<Foe> foes;                // the living foes, front first
  std::vector<std::string> imports;     // a program run's imports in force ("math", "heapq", ...)
  std::map<std::string, int> globals;   // a program run's globals ("total")
};
```

## Matching the other languages exactly

- A JavaScript `{ ...bolt, power: x }` is a copy with one field changed: `Bolt copy = bolt; copy.power = x;`. A new
  bolt from nothing is `Bolt{.power = 3, .element = "none"}` (it has no `foe` and no `block`, as the JavaScript's
  `{ power: 3, element: "none" }` has none).
- Integer arithmetic: JavaScript and Python numbers in program cards are whole, but `Math.floor(a / b)` and Python's
  `a // b` round down where C++ `a / b` rounds toward zero; they differ only for negative numbers. Use
  `static_cast<int>(std::floor(double(a) / b))` when a value can be negative. `Math.round` is `std::floor(x + 0.5)`.
- Order matters: a JavaScript `Map` or `Set` iterates in insertion order and a Python `dict` too; `std::map` and
  `std::set` iterate in key order and `std::unordered_*` in no fixed order. When the order reaches the result, keep
  the insertion order yourself (a `std::vector` of keys beside a map).
- A stable sort is `std::stable_sort` (JavaScript's and Python's sorts are stable).
- Spellforge powers are doubles and are compared exactly with the other languages' results, so compute them in the
  same order (`bolt.power * 0.6`, not `bolt.power * 6 / 10`).
- A generator (`function*`, `yield`) becomes a small struct that keeps its own state and has a `next()`.
- An import card's `.jsonc` has a `line` per language (the line the program's listing shows at its top): add a
  `"cpp"` one, the include a C++ programmer would write for the same idea (`"#include <queue>"` for heapq,
  `"#include <algorithm>"` for bisect, `"#include <cmath>"` for math, `"#include <unordered_map>"` for a cache,
  `"#include <numeric>"` for itertools or operator, `"#include <valarray>"` for numpy). Its code is still a normal
  card function.
- When a card cannot be written without something the headers lack, stop and say what it needs; do not change the
  shared headers or the harness.
