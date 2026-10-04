Bolts increase_key_plus(Bolts bolts, const Battle& battle) {
  // Increase-key: raise the weakest bolt to the strongest's power, then sift it up while it beats its parent. On a heap
  // (Heapify makes one) the sift takes only O(log n) steps; finding the weakest is a scan.
  if (bolts.empty()) return bolts;
  int low = 0;
  int high = 0;
  for (int i = 1; i < static_cast<int>(bolts.size()); i++) {
    if (bolts[i].power < bolts[low].power) low = i;
    if (bolts[i].power > bolts[high].power) high = i;
  }
  bolts[low].power = std::max(bolts[low].power, bolts[high].power - 0);
  int i = low;
  while (i > 0 && bolts[(i - 1) / 2].power < bolts[i].power) {
    const int parent = (i - 1) / 2;
    std::swap(bolts[parent], bolts[i]);
    i = parent;
  }
  return bolts;
}
