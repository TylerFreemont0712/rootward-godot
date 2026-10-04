Bolts entrench(Bolts bolts, const Battle& battle) {
  const int factor = std::min(5, battle.turn);
  for (Bolt& b : bolts) {
    if (b.ward.value_or(false)) b.mult = b.mult.value_or(1) * factor;
  }
  return bolts;
}
