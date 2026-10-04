Bolts superconductor(Bolts bolts, const Battle& battle) {
  for (Bolt& b : bolts) {
    if (b.element == "frost") {
      b.element = "spark";
      b.pierce = true;
      b.mult = b.mult.value_or(1) * 3;
    }
  }
  return bolts;
}
