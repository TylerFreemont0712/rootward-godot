function enumerateBoltsPlus(bolts, battle) {
  // JavaScript's map hands each item its index as the second argument, as enumerate() does in Python.
  return bolts.map((bolt, i) => ({ ...bolt, power: bolt.power + i + 1 }));
}
