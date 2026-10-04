Bolts fib_memo(Bolts bolts, const Battle& battle) {
  // Memoised bottom up: build the table fib[0..16] once, each entry the sum of the two before it, then look it up
  // for each bolt. The same answer as the naive recursion, in O(n).
  std::vector<int> fib = {0, 1};
  while (fib.size() < 17) fib.push_back(fib[fib.size() - 1] + fib[fib.size() - 2]);
  for (int i = 0; i < static_cast<int>(bolts.size()); i++) bolts[i].power += fib[std::min(i, 16)];
  return bolts;
}
