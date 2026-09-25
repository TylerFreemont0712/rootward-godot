function index_map(bolts, battle) {
  return bolts.map((bolt, i) => ({ ...bolt, power: bolt.power + 2 * i }));
}
