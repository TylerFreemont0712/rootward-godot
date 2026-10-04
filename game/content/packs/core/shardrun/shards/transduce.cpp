Bolts transduce(Bolts bolts, const Battle& battle) {
  for (Bolt& b : bolts) {
    if (b.power > 4) {
      b.mult = b.mult.value_or(1) * b.power / 4;
      b.power = 4;
    }
  }
  return bolts;
}
