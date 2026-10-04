Bolts ward(Bolts bolts, const Battle& battle) {
  // A linear search for the strongest bolt; it becomes your shield, 2 stronger.
  if (bolts.empty()) return bolts;
  int best = 0;
  for (int i = 1; i < static_cast<int>(bolts.size()); i++) if (bolts[i].power > bolts[best].power) best = i;
  bolts[best].power += 2;
  bolts[best].block = true;
  return bolts;
}
