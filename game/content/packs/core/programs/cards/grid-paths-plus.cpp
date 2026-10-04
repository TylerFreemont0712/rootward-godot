Bolts grid_paths_plus(Bolts bolts, const Battle& battle) {
  // Paths across a 5 x 5 grid: each corner is reached from the square above or the one on its left, so
  // paths(r, c) = paths(r - 1, c) + paths(r, c - 1). Naive recursion solves the same square again and again
  // (exponential). With functools.cache in force every square is solved once and then looked up in a map.
  const bool memo = std::find(battle.imports.begin(), battle.imports.end(), "functools") != battle.imports.end();
  std::map<int, int> cache;
  std::function<int(int, int)> paths = [&](int r, int c) {
    if (r == 0 || c == 0) return 1;
    const int key = r * 100 + c;
    if (memo && cache.count(key)) return cache[key];
    int total = 0;
    for (int move = 0; move < 2; move++) {
      total += paths(r - (1 - move), c - move);
    }
    if (memo) cache[key] = total;
    return total;
  };
  bolts.push_back(Bolt{.power = paths(5, 5) / 10, .element = "none"});
  return bolts;
}
