function importBisectPlus(bolts, battle) {
  // Runs after every source card: each bolt goes into its sorted place (a binary search), weakest first.
  const ordered = [];
  for (const bolt of bolts) {
    let low = 0;
    let high = ordered.length;
    while (low < high) {
      const middle = (low + high) >> 1;
      if (ordered[middle].power <= bolt.power) low = middle + 1;
      else high = middle;
    }
    ordered.splice(low, 0, bolt);
  }
  return ordered;
}
