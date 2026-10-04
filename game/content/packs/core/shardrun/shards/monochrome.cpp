Bolts monochrome(Bolts bolts, const Battle& battle) {
  bool coherent = !bolts.empty() && bolts[0].element != "none";
  for (const Bolt& b : bolts) {
    if (b.element != bolts[0].element) coherent = false;
  }
  for (Bolt& b : bolts) b.mult = b.mult.value_or(1) * (coherent ? 2 : 1);
  return bolts;
}
