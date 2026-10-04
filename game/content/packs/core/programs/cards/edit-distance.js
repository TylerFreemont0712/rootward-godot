function editDistance(bolts, battle) {
  // Edit distance between two sorted sequences: the bolts' powers and the foes' HP. table[i][j] is the fewest edits
  // (swap one value for another, drop a bolt, drop a foe) turning the first i bolts into the first j foes. Walking
  // it back pairs bolts with foes in order; a paired bolt flies at its foe. A bolt with no foe to pair with flies at the front.
  const foes = battle.foes || [];
  if (foes.length === 0) return bolts.slice();
  const mine = [];
  bolts.forEach((bolt, i) => {
    if (!bolt.block) mine.push(i);
  });
  mine.sort((a, b) => bolts[a].power - bolts[b].power || a - b);
  const need = foes.map((foe) => foe.hp + (foe.shield || 0));
  const order = foes.map((_, j) => j).sort((a, b) => need[a] - need[b] || a - b);
  const n = mine.length;
  const m = order.length;
  const table = [];
  for (let i = 0; i <= n; i++) table.push(new Array(m + 1).fill(0));
  for (let i = 1; i <= n; i++) table[i][0] = i;
  for (let j = 1; j <= m; j++) table[0][j] = j;
  for (let i = 1; i <= n; i++) {
    for (let j = 1; j <= m; j++) {
      const swap = bolts[mine[i - 1]].power === need[order[j - 1]] ? 0 : 1;
      table[i][j] = Math.min(table[i - 1][j - 1] + swap, table[i - 1][j] + 1, table[i][j - 1] + 1);
    }
  }
  const aim = new Map();
  let i = n;
  let j = m;
  while (i > 0 && j > 0) {
    const swap = bolts[mine[i - 1]].power === need[order[j - 1]] ? 0 : 1;
    if (table[i][j] === table[i - 1][j - 1] + swap) {
      aim.set(mine[i - 1], order[j - 1]);
      i--;
      j--;
    } else if (table[i][j] === table[i - 1][j] + 1) {
      i--;
    } else {
      j--;
    }
  }
  return bolts.map((bolt, k) => {
    if (bolt.block) return { ...bolt };
    if (aim.has(k)) return { ...bolt, foe: aim.get(k) };
    return { ...bolt, foe: 0 };
  });
}
