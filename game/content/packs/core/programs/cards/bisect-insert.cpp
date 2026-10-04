Bolts bisect_insert(Bolts bolts, const Battle& battle) {
  // bisect: halve the range until the place is found (O(log n)), then insert there. A sorted volley stays sorted.
  Bolts out = bolts;
  for (int k = 0; k < 2; k++) {
    int lo = 0;
    int hi = static_cast<int>(out.size());
    while (lo < hi) {
      const int mid = (lo + hi) / 2;
      if (out[mid].power <= 7) lo = mid + 1;
      else hi = mid;
    }
    out.insert(out.begin() + lo, Bolt{.power = 7, .element = "none"});
  }
  return out;
}
