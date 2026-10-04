Bolts weave(Bolts bolts, const Battle& battle) {
  for (size_t i = 0; i < bolts.size(); i++) {
    Bolt& b = bolts[i];
    b.ward = i % 2 == 0;
    b.mult = b.mult.value_or(1) * (i % 2 == 0 ? 2 : 1);
  }
  return bolts;
}
