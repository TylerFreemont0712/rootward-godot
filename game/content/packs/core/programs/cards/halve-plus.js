function halvePlus(bolts, battle) {
  // The divide step by itself: the volley is cut at ceil(n / 2) and the card after this one runs on each half.
  // The cut is a rule, so a card can find it without being told: the first bolt of the right half is bolts[half].
  const half = Math.ceil(bolts.length / 2);
  return bolts.map((bolt, i) => (i === 0 || i === half ? { ...bolt, power: bolt.power + 1 } : bolt));
}
