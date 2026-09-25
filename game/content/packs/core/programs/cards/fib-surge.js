function fibSurge(bolts, battle) {
  // Naive recursion: fib(k) calls fib(k-1) and fib(k-2), which call theirs, recomputing the same values again and
  // again: about 2^k calls. Each bolt i gains fib(i), capped at fib(16).
  const fib = (k) => (k < 2 ? k : fib(k - 1) + fib(k - 2));
  return bolts.map((bolt, i) => ({ ...bolt, power: bolt.power + fib(Math.min(i, 16)) }));
}
