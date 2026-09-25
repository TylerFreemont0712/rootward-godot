function greedyAssign(bolts, battle) {
  // Greedy: strongest bolts first, weakest foes first; keep adding bolts to a foe until they would kill it, then
  // move on. Fast and usually good, not always optimal. The sort makes it O(n log n).
  const foes = battle.foes;
  if (foes.length === 0) return bolts;
  const strongest = bolts.slice().sort((a, b) => b.power - a.power);
  const need = (i) => foes[i].hp + foes[i].shield;
  const order = foes.map((_, i) => i).sort((a, b) => need(a) - need(b));
  const out = [];
  let k = 0;
  for (const i of order) {
    let left = need(i);
    while (left > 0 && k < strongest.length) {
      out.push({ ...strongest[k], foe: i });
      left -= strongest[k].power;
      k++;
    }
  }
  for (const bolt of strongest.slice(k)) out.push({ ...bolt, foe: order[order.length - 1] });
  return out;
}
