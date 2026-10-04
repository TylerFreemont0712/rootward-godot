function sliceBolts(bolts, battle) {
  // slice(0, 4) is JavaScript's bolts[:4]: a new array of the first four items.
  return bolts.slice(0, 4).map((bolt) => ({ ...bolt, power: bolt.power + 2 }));
}
