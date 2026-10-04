Bolts reserve_tap(Bolts bolts, const Battle& battle) {
  const int bonus = static_cast<int>(std::floor(double(battle.me.block) / 4));
  for (Bolt& b : bolts) {
    if (!b.ward.value_or(false)) b.mult = b.mult.value_or(1) + bonus;
  }
  return bolts;
}
