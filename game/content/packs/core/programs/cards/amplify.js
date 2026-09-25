function amplify(bolts, battle) {
  // One pass over the volley: every bolt gains 3 power.
  return bolts.map((bolt) => ({ ...bolt, power: bolt.power + 3 }));
}
