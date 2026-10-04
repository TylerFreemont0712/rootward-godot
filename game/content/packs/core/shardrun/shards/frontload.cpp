Bolts frontload(Bolts bolts, const Battle& battle) {
  for (std::size_t i = 0; i < bolts.size(); i++) {
    bolts[i].mult = bolts[i].mult.value_or(1) * (i == 0 ? 4 : 0.5);
  }
  return bolts;
}
