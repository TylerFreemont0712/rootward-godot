Bolts enumerate_bolts(Bolts bolts, const Battle& battle) {
  // C++ has no enumerate, so the loop counts: the index is the loop variable.
  for (int i = 0; i < static_cast<int>(bolts.size()); i++) bolts[i].power += i;
  return bolts;
}
