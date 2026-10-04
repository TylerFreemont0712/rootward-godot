Bolts headcount(Bolts bolts, const Battle& battle) {
  const int bonus = 2 * static_cast<int>(battle.foes.size());
  for (Bolt& bolt : bolts) bolt.power = bolt.power + bonus;
  return bolts;
}
