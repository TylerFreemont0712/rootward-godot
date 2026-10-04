function catalanPlus(bolts, battle) {
  // Bottom up: catalan[m] = sum of catalan[i] * catalan[m - 1 - i], built from catalan[0] = 1 to the turn's number
  // (1, 2, 5, 14, 42). The table stops at 5, so the bolt is never larger than 42.
  const n = Math.min(Math.max((battle.turn ?? 1) + 1, 0), 5);
  const catalan = [1];
  for (let m = 1; m <= n; m++) {
    let total = 0;
    for (let i = 0; i < m; i++) {
      total += catalan[i] * catalan[m - 1 - i];
    }
    catalan.push(total);
  }
  return [...bolts, { power: catalan[n], element: "none" }];
}
