function patience(bolts, battle) {
  const bonus = (battle.turn - 1) * 3;
  return bolts.map((bolt) => ({ ...bolt, power: bolt.power + bonus }));
}
