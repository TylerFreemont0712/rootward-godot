function roundRobin(bolts, battle) {
  // Deal the bolts to the foes in turn: bolt i goes to foe i mod (number of foes).
  const count = battle.foes.length;
  if (count === 0) return bolts;
  return bolts.map((bolt, i) => ({ ...bolt, foe: i % count }));
}
