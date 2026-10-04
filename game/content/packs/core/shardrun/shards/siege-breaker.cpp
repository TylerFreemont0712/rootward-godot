Bolts siege_breaker(Bolts bolts, const Battle& battle) {
  const bool ready = battle.foes.size() > 0 && battle.foes[0].shield > 0;
  for (Bolt& b : bolts) {
    if (ready && !b.ward.value_or(false)) {
      b.target = "front";
      b.pierce = true;
      b.mult = b.mult.value_or(1) * 2;
    }
  }
  return bolts;
}
