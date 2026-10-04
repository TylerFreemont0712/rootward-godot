Bolts backdraft(Bolts bolts, const Battle& battle) {
  for (Bolt& b : bolts) b.mult = b.mult.value_or(1) * (b.element == "fire" ? 3 : 1);
  return bolts;
}
