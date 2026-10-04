function sortByKeyPlus(bolts, battle) {
  // sorted(key=...) compares the keys, here a pair: element first (none, fire, frost, spark), then power.
  // The sort is stable: the original index breaks ties, so equal bolts stay in the order they came in.
  const elements = ["none", "fire", "frost", "spark"];
  const rank = (bolt) => (elements.includes(bolt.element) ? elements.indexOf(bolt.element) : elements.length);
  return bolts
    .map((bolt, i) => ({ bolt, i }))
    .sort((a, b) => rank(a.bolt) - rank(b.bolt) || a.bolt.power - b.bolt.power || a.i - b.i)
    .map((item) => ({ ...item.bolt }));
}
