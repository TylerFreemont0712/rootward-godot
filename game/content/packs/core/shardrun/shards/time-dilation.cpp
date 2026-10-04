Bolts time_dilation(Bolts bolts, const Battle& battle) {
  const int bonus = std::min(25, battle.turn * battle.turn);
  for (Bolt& b : bolts) b.mult = b.mult.value_or(1) + bonus;
  return bolts;
}
