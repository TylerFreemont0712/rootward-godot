Bolts pascal_row_plus(Bolts bolts, const Battle& battle) {
  // A table built from smaller answers: each row comes from the one above, every entry the sum of the two over it.
  std::vector<int> row = {1};
  for (int r = 0; r < 6; r++) {
    std::vector<int> next = {1};
    for (size_t i = 0; i + 1 < row.size(); i++) next.push_back(row[i] + row[i + 1]);
    next.push_back(1);
    row = next;
  }
  for (int value : row) bolts.push_back(Bolt{.power = value, .element = "none"});
  return bolts;
}
