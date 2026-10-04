Bolts round_robin(Bolts bolts, const Battle& battle) {
  // Deal the bolts to the foes in turn: bolt i goes to foe i mod (number of foes).
  const int count = static_cast<int>(battle.foes.size());
  if (count == 0) return bolts;
  for (int i = 0; i < static_cast<int>(bolts.size()); i++) bolts[i].foe = i % count;
  return bolts;
}
