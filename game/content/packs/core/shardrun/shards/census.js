function census(bolts, battle) {
  const ordered = [...bolts].sort((a, b) => a.power - b.power);
  return ordered.map((bolt, place) => ({ ...bolt, power: bolt.power + place }));
}
