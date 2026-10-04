Bolts alternating_current(Bolts bolts, const Battle& battle) {
  for (size_t i = 0; i < bolts.size(); i += 1) {
    bolts[i].mult = bolts[i].mult.value_or(1) * (i > 0 && bolts[i].element != bolts[i - 1].element ? 3 : 1);
  }
  return bolts;
}
