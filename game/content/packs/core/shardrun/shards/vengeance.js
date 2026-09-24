function vengeance(bolts, battle) {
  const me = battle.me;
  if (me.hp * 2 > me.max) return bolts;
  return bolts.map((bolt) => ({ ...bolt, power: bolt.power + 4 }));
}
