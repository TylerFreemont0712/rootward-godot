Bolts bubble_sort(Bolts bolts, const Battle& battle) {
  // Repeated passes, each swapping neighbours that are out of order; after pass k the k strongest are in place.
  // A pass with no swap means the volley is sorted, and it stops early.
  Bolts out = bolts;
  for (int end = static_cast<int>(out.size()) - 1; end > 0; end--) {
    bool swapped = false;
    for (int i = 0; i < end; i++) {
      if (out[i].power > out[i + 1].power) {
        std::swap(out[i], out[i + 1]);
        swapped = true;
      }
    }
    if (!swapped) break;
  }
  return out;
}
