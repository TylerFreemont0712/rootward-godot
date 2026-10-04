Bolts fortify(Bolts bolts, const Battle& battle) {
  int attacks = 0;
  for (const Bolt& b : bolts) {
    if (!b.ward.value_or(false)) attacks += 1;
  }
  const int factor = 1 + attacks;
  for (Bolt& b : bolts) {
    if (b.ward.value_or(false)) b.mult = b.mult.value_or(1) * factor;
  }
  return bolts;
}
