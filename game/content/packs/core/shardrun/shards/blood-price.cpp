Bolts blood_price(Bolts bolts, const Battle& battle) {
  for (Bolt& b : bolts) b.mult = b.mult.value_or(1) * 4;
  return bolts;
}
