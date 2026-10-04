Bolts prefix_charge(Bolts bolts, const Battle& battle) {
  double total = 0;
  for (Bolt& b : bolts) {
    total += b.mult.value_or(1);
    b.mult = total;
  }
  return bolts;
}
