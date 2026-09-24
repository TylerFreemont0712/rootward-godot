function siphon(bolts, battle) {
  if (bolts.length === 0) return bolts;
  let weakest = 0;
  bolts.forEach((bolt, index) => {
    if (bolt.power < bolts[weakest].power) weakest = index;
  });
  return bolts.map((bolt, index) => (index === weakest ? { ...bolt, ward: true, power: bolt.power * 2 } : bolt));
}
