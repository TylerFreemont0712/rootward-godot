Bolts double_tap(Bolts bolts, const Battle& battle) {
  if (bolts.empty()) return bolts;
  bolts.insert(bolts.begin(), bolts[0]);
  return bolts;
}
