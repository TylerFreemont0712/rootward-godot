function medianOfMedians(bolts, battle) {
  // Median of medians: selection in guaranteed O(n). Cut the powers into groups of five, take each group's median,
  // then the median of those medians as the pivot: at least three tenths of the powers lie on each side of it, so the
  // side we recurse into is always much smaller, however the volley is ordered. The middle rank, n // 2, is the same
  // median Quickselect finds. The first bolt of that power is the pivot, and every bolt at or above it flies at the
  // toughest foe, the rest at the weakest.
  const foes = battle.foes || [];
  if (foes.length === 0 || bolts.length === 0) return bolts;
  const select = (values, k) => {
    // the k-th smallest of values, counting from 0
    if (values.length <= 5) return values.slice().sort((a, b) => a - b)[k];
    const medians = [];
    for (let start = 0; start < values.length; start += 5) {
      const group = values.slice(start, start + 5).sort((a, b) => a - b);
      medians.push(group[Math.floor(group.length / 2)]);
    }
    const pivot = select(medians, Math.floor(medians.length / 2));
    const lower = values.filter((v) => v < pivot);
    const equal = values.filter((v) => v === pivot);
    if (k < lower.length) return select(lower, k);
    if (k < lower.length + equal.length) return pivot;
    return select(values.filter((v) => v > pivot), k - lower.length - equal.length);
  };
  const median = select(bolts.map((bolt) => bolt.power), Math.floor(bolts.length / 2));
  const need = (i) => foes[i].hp + (foes[i].shield || 0);
  let toughest = 0;
  let weakest = 0;
  for (let i = 1; i < foes.length; i++) {
    if (need(i) > need(toughest)) toughest = i;
    if (need(i) < need(weakest)) weakest = i;
  }
  let marked = false;
  return bolts.map((bolt) => {
    const aimed = { ...bolt, foe: bolt.power >= median ? toughest : weakest };
    if (!marked && bolt.power === median) {
      aimed.pivot = true;
      marked = true;
    }
    return aimed;
  });
}
