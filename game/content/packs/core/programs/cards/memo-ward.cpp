Bolts memo_ward(Bolts bolts, const Battle& battle) {
  // Remember the best answer so far: the table holds what every program landed this fight, and the ward is as large
  // as the biggest row, never below 4.
  int best = 0;
  for (int row : battle.dp) best = std::max(best, row);
  bolts.push_back(Bolt{.power = std::max(4, best), .element = "none", .block = true});
  return bolts;
}
