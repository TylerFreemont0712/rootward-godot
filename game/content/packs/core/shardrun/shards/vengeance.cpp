Bolts vengeance(Bolts bolts, const Battle& battle) {
  const Me& me = battle.me;
  if (me.hp * 2 > me.max) return bolts;
  for (Bolt& bolt : bolts) bolt.power = bolt.power + 4;
  return bolts;
}
