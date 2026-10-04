Bolts grid_search_plus(Bolts bolts, const Battle& battle) {
  // Grid search: try every cell of a 5 x 5 grid, one loop inside another. Cell (i, j) becomes a bolt of power
  // i * j // 2 + 1, added after the volley: the kind of sweep that tunes a model's two settings.
  for (int i = 0; i < 5; i++) {
    for (int j = 0; j < 5; j++) {
      Bolt cell;
      cell.power = (i * j) / 2 + 1;
      bolts.push_back(cell);
    }
  }
  return bolts;
}
