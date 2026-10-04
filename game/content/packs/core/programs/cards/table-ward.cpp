Bolts table_ward(Bolts bolts, const Battle& battle) {
  // Read the table's last row (what the latest program landed) and turn a share of it into block, never below 3.
  const int last = battle.dp.empty() ? 0 : battle.dp.back();
  const int share = static_cast<int>(std::floor(double(last) / 3));
  bolts.push_back(Bolt{.power = std::max(3, share), .element = "none", .block = true});
  return bolts;
}
