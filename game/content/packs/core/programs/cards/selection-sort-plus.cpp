Bolts selection_sort_plus(Bolts bolts, const Battle& battle) {
  // Selection sort: scan the unsorted suffix for its weakest bolt, swap it to the front, then repeat. It scans the
  // whole suffix every time, so even an already sorted volley takes quadratic work.
  for (int start = 0; start + 1 < static_cast<int>(bolts.size()); start++) {
    int pick = start;
    for (int i = start + 1; i < static_cast<int>(bolts.size()); i++) {
      if (bolts[i].power < bolts[pick].power) pick = i;
    }
    std::swap(bolts[start], bolts[pick]);
  }
  return bolts;
}
