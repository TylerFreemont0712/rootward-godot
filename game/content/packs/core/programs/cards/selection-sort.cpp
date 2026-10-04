Bolts selection_sort(Bolts bolts, const Battle& battle) {
  // Selection sort: scan everything left for the weakest, swap it to the front, repeat. It scans the whole rest
  // every time, so a volley that is already sorted costs as much as a shuffled one (bubble sort stops early).
  for (int start = 0; start + 1 < static_cast<int>(bolts.size()); start++) {
    int pick = start;
    for (int i = start + 1; i < static_cast<int>(bolts.size()); i++) {
      if (bolts[i].power < bolts[pick].power) pick = i;
    }
    std::swap(bolts[start], bolts[pick]);
  }
  return bolts;
}
