Bolts crowd_surge(Bolts bolts, const Battle& battle) {
  const int factor = std::max(1, static_cast<int>(battle.foes.size()));
  for (Bolt& b : bolts) {
    if (!b.ward.value_or(false)) b.mult = b.mult.value_or(1) * factor;
  }
  return bolts;
}
