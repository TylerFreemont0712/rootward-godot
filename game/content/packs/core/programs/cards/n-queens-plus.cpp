Bolts n_queens_plus(Bolts bolts, const Battle& battle) {
  // N-Queens by backtracking: a queen on every row of an 8 x 8 board, none sharing a column or a diagonal. The
  // squares each queen attacks are bitmasks, so a branch that has no free square is never walked: it is pruned.
  const int size = 8;
  const int full = (1 << size) - 1;
  int solutions = 0;
  std::function<void(int, int, int, int)> place = [&](int cols, int left, int right, int row) {
    if (row == size) {
      solutions++;
      return;
    }
    int free = full & ~(cols | left | right);
    while (free) {
      const int bit = free & -free;
      free ^= bit;
      place(cols | bit, ((left | bit) << 1) & full, (right | bit) >> 1, row + 1);
    }
  };
  place(0, 0, 0, 0);
  for (int i = 0; i < solutions; i++) {
    Bolt queen;
    queen.power = 2;
    bolts.push_back(queen);
  }
  return bolts;
}
