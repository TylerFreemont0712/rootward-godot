Bolts rebuke(Bolts bolts, const Battle& battle) {
  for (Bolt& b : bolts) {
    if (b.ward.value_or(false)) {
      b.ward = false;
      b.mult = b.mult.value_or(1) * 2;
    }
  }
  return bolts;
}
