Bolts counterweight(Bolts bolts, const Battle& battle) {
  int wards = 0;
  for (const Bolt& b : bolts) {
    if (b.ward.value_or(false)) wards += 1;
  }
  const int factor = 1 + wards;
  for (Bolt& b : bolts) {
    if (!b.ward.value_or(false)) b.mult = b.mult.value_or(1) * factor;
  }
  return bolts;
}
