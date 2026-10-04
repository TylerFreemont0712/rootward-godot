Bolts patience(Bolts bolts, const Battle& battle) {
  const int bonus = (battle.turn - 1) * 3;
  for (Bolt& bolt : bolts) bolt.power = bolt.power + bonus;
  return bolts;
}
