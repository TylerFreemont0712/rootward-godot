function nQueens(bolts, battle) {
  // N-Queens by backtracking: a queen on every row of an 6 x 6 board, none sharing a column or a diagonal. The
  // squares each queen attacks are bitmasks, so a branch that has no free square is never walked: it is pruned.
  const size = 6;
  const full = (1 << size) - 1;
  let solutions = 0;
  function place(cols, left, right, row) {
    if (row === size) {
      solutions++;
      return;
    }
    let free = full & ~(cols | left | right);
    while (free) {
      const bit = free & -free;
      free ^= bit;
      place(cols | bit, ((left | bit) << 1) & full, (right | bit) >> 1, row + 1);
    }
  }
  place(0, 0, 0, 0);
  const out = bolts.map((bolt) => ({ ...bolt }));
  for (let i = 0; i < solutions; i++) out.push({ power: 7, element: "none" });
  return out;
}
