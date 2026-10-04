Bolts ward_plus(Bolts bolts, const Battle& battle) {
  // A linear search for the strongest bolt; it becomes your shield, 4 stronger.
  if (bolts.empty()) return bolts;
  int best = 0;
  for (int i = 1; i < static_cast<int>(bolts.size()); i++) if (bolts[i].power > bolts[best].power) best = i;
  bolts[best].power += 4;
  bolts[best].block = true;
  return bolts;
}
