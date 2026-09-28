function fibMemoPlus(bolts, battle) {
  // Memoised bottom up: build the table fib[0..20] once, each entry the sum of the two before it, then look it up
  // for each bolt. The same answer as the naive recursion, in O(n).
  const fib = [0, 1];
  while (fib.length < 21) fib.push(fib[fib.length - 1] + fib[fib.length - 2]);
  return bolts.map((bolt, i) => ({ ...bolt, power: bolt.power + fib[Math.min(i, 20)] }));
}
