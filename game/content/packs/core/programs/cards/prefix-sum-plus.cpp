Bolts prefix_sum_plus(Bolts bolts, const Battle& battle) {
  // Running totals: each bolt carries the sum of every bolt up to and including it.
  int total = 0;
  for (Bolt& bolt : bolts) {
    total += bolt.power;
    bolt.power = total;
  }
  return bolts;
}
