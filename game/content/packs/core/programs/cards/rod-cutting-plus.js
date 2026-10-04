function rodCuttingPlus(bolts, battle) {
  // Rod cutting: best[n] is the most a rod of length n can be worth when cut into pieces, trying every first piece.
  // A piece is worth its price (a 3 is worth 4, a 5 worth 7, a 7 worth 10, a 2 worth 3); any other length is worth itself.
  // The strongest bolt is the rod. Its pieces become bolts, each as strong as that piece is worth.
  const price = new Map([[3, 4], [5, 7], [7, 10], [2, 3]]);
  const worth = (piece) => (price.has(piece) ? price.get(piece) : piece);
  let rod = -1;
  bolts.forEach((bolt, i) => {
    if (bolt.power > 0 && !bolt.block && (rod < 0 || bolt.power > bolts[rod].power)) rod = i;
  });
  if (rod < 0) return bolts.slice();
  const length = Math.min(bolts[rod].power, 30);
  const best = new Array(length + 1).fill(0);
  const cut = new Array(length + 1).fill(0);
  for (let n = 1; n <= length; n++) {
    best[n] = -1;
    for (let piece = n; piece > 0; piece--) {
      const value = worth(piece) + best[n - piece];
      if (value > best[n]) {
        best[n] = value;
        cut[n] = piece;
      }
    }
  }
  const pieces = [];
  let n = length;
  while (n > 0) {
    pieces.push(cut[n]);
    n -= cut[n];
  }
  const result = [];
  bolts.forEach((bolt, k) => {
    if (k !== rod) {
      result.push({ ...bolt });
      return;
    }
    for (const piece of pieces) result.push({ ...bolt, power: worth(piece) });
    if (bolt.power > length) result.push({ ...bolt, power: bolt.power - length });
  });
  return result;
}
