int fib(int k) {
  return k < 2 ? k : fib(k - 1) + fib(k - 2);
}

Bolts fib_surge(Bolts bolts, const Battle& battle) {
  // Naive recursion: fib(k) calls fib(k-1) and fib(k-2), which call theirs, recomputing the same values again and
  // again: about 2^k calls. Each bolt i gains fib(i), capped at fib(16).
  for (int i = 0; i < static_cast<int>(bolts.size()); i++) bolts[i].power += fib(std::min(i, 16));
  return bolts;
}
