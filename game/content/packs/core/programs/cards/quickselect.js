function quickselect(bolts, battle) {
  // Quickselect: partition around a pivot, then recurse into the one side that holds the middle rank. Average O(n).
  const foes = battle.foes;
  if (foes.length === 0 || bolts.length === 0) return bolts;
  function kth(values, k) {
    const pivot = values[0];
    const lower = values.filter((v) => v < pivot);
    const equal = values.filter((v) => v === pivot);
    if (k < lower.length) return kth(lower, k);
    if (k < lower.length + equal.length) return pivot;
    return kth(values.filter((v) => v > pivot), k - lower.length - equal.length);
  }
  const median = kth(bolts.map((bolt) => bolt.power), Math.floor(bolts.length / 2));
  const need = (i) => foes[i].hp + foes[i].shield;
  let toughest = 0;
  let weakest = 0;
  for (let i = 1; i < foes.length; i++) {
    if (need(i) > need(toughest)) toughest = i;
    if (need(i) < need(weakest)) weakest = i;
  }
  return bolts.map((bolt) => ({ ...bolt, foe: bolt.power >= median ? toughest : weakest }));
}
