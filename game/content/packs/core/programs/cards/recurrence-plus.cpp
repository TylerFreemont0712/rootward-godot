Bolts recurrence_plus(Bolts bolts, const Battle& battle) {
  // Read the two preceding rows instead of recursively recomputing the recurrence.
  const auto& rows = battle.dp;
  if (battle.turn < 2 || rows.empty()) return bolts;
  const int total = rows.back() + (rows.size() > 1 ? rows[rows.size() - 2] : 0);
  const int power = total + static_cast<int>(std::floor(double(total) / 3));
  bolts.push_back(Bolt{.power = power, .element = "none"});
  return bolts;
}
