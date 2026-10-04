function lcs(bolts, battle) {
  // Longest common subsequence of this volley's powers and the last program's landed volley (the diff behind
  // `git diff`). table[i][j] is the LCS length of the first i bolts and the first j landed powers; walking it back
  // from the corner finds which bolts matched. Ward bolts are not attacks, so they are left out.
  const last = battle.last_volley || [];
  const mine = [];
  bolts.forEach((bolt, i) => {
    if (!bolt.block) mine.push(i);
  });
  if (mine.length === 0 || last.length === 0) return bolts.slice();
  const table = [];
  for (let i = 0; i <= mine.length; i++) table.push(new Array(last.length + 1).fill(0));
  for (let i = 1; i <= mine.length; i++) {
    for (let j = 1; j <= last.length; j++) {
      if (bolts[mine[i - 1]].power === last[j - 1]) table[i][j] = table[i - 1][j - 1] + 1;
      else table[i][j] = Math.max(table[i - 1][j], table[i][j - 1]);
    }
  }
  const matched = new Set();
  let i = mine.length;
  let j = last.length;
  while (i > 0 && j > 0) {
    if (bolts[mine[i - 1]].power === last[j - 1]) {
      matched.add(mine[i - 1]);
      i--;
      j--;
    } else if (table[i - 1][j] >= table[i][j - 1]) {
      i--;
    } else {
      j--;
    }
  }
  return bolts.map((bolt, k) => (matched.has(k) ? { ...bolt, power: bolt.power + 2 } : { ...bolt }));
}
