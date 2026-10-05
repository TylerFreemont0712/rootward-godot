Bolts boundary_guard(Bolts bolts, const Battle&) {
  // A recursive call gets its own small boundary: sacrifice its weakest attack when there are at least two.
  std::optional<size_t> weakest;
  int attacks = 0;
  for (size_t i = 0; i < bolts.size(); i++) {
    if (bolts[i].block || bolts[i].stash) continue;
    attacks++;
    if (!weakest || bolts[i].power < bolts[*weakest].power) weakest = i;
  }
  if (attacks >= 2 && weakest) bolts[*weakest].block = true;
  return bolts;
}
