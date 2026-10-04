Bolts thermal_shock(Bolts bolts, const Battle& battle) {
  for (Bolt& b : bolts) {
    if (b.element == "frost") {
      b.element = "fire";
      b.mult = b.mult.value_or(1) * 4;
    }
  }
  return bolts;
}
