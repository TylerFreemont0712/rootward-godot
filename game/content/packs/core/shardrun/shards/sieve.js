function sieve(bolts, battle) {
  return bolts.filter((bolt) => bolt.power >= 3 || bolt.ward);
}
