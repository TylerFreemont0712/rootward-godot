function gridPathsPlus(bolts, battle) {
  // Paths across a 5 x 5 grid: each corner is reached from the square above or the one on its left, so
  // paths(r, c) = paths(r - 1, c) + paths(r, c - 1). Naive recursion solves the same square again and again
  // (exponential). With functools.cache in force every square is solved once and then looked up in a Map.
  const memo = (battle.imports || []).includes("functools");
  const cache = new Map();
  const paths = (r, c) => {
    if (r === 0 || c === 0) return 1;
    const key = r * 100 + c;
    if (memo && cache.has(key)) return cache.get(key);
    let total = 0;
    for (const [dr, dc] of [[1, 0], [0, 1]]) {
      total += paths(r - dr, c - dc);
    }
    if (memo) cache.set(key, total);
    return total;
  };
  return [...bolts, { power: Math.floor(paths(5, 5) / 10), element: "none" }];
}
