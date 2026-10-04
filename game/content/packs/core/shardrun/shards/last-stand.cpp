Bolts last_stand(Bolts bolts, const Battle& battle) {
  const int factor = battle.me.hp * 2 <= battle.me.max ? 4 : 1;
  for (Bolt& b : bolts) b.mult = b.mult.value_or(1) * factor;
  return bolts;
}
