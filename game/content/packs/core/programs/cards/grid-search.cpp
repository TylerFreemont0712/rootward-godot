Bolts grid_search(Bolts bolts, const Battle& battle) {
  // Grid search: try every cell of a 4 x 4 grid, one loop inside another. Cell (i, j) becomes a bolt of power
  // i * j // 2 + 1, added after the volley: the kind of sweep that tunes a model's two settings.
  for (int i = 0; i < 4; i++) {
    for (int j = 0; j < 4; j++) {
      Bolt cell;
      cell.power = (i * j) / 2 + 1;
      bolts.push_back(cell);
    }
  }
  return bolts;
}
