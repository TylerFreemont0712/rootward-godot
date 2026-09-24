function headcount(bolts, battle) {
  const bonus = 2 * battle.foes.length;
  return bolts.map((bolt) => ({ ...bolt, power: bolt.power + bonus }));
}
