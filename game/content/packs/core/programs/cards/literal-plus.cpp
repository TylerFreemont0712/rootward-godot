Bolts literal_plus(Bolts bolts, const Battle& battle) {
  // A constant in the code: one 12-power bolt, appended in O(1) (a vector grows at its end without moving the rest).
  bolts.push_back(Bolt{.power = 12, .element = "none"});
  return bolts;
}
