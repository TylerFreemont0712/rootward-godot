function amplifyPlus(bolts, battle) {
  // One pass over the volley: every bolt gains 4 power.
  return bolts.map((bolt) => ({ ...bolt, power: bolt.power + 4 }));
}
