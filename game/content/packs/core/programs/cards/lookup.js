function lookup(bolts, battle) {
  // A lower bound finds the first indexed power large enough; never take a slot twice.
  const index = battle.index || [];
  const foes = battle.foes || [];
  if (index.length === 0) return bolts;
  const need = foes.length > 0 ? foes[0].hp + (foes[0].shield || 0) : 0;
  let lo = 0;
  let hi = index.length;
  while (lo < hi) {
    const mid = Math.floor((lo + hi) / 2);
    if (index[mid].power < need) lo = mid + 1;
    else hi = mid;
  }
  const used = new Set();
  const result = bolts.slice();
  for (let count = 0; count < 1; count++) {
    let pick = lo;
    while (pick < index.length && used.has(pick)) pick++;
    if (pick === index.length) {
      pick = index.length - 1;
      while (pick >= 0 && used.has(pick)) pick--;
    }
    if (pick < 0) break;
    used.add(pick);
    result.push({ ...index[pick], from_index: true });
  }
  return result;
}
