Bolts pairwise(Bolts bolts, const Battle& battle) {
  // Two nested loops over the volley: every pair (i, j) with i < j fuses. n(n-1)/2 new bolts, O(n^2) work.
  // A single bolt has no pair, so it makes nothing.
  Bolts out;
  for (size_t i = 0; i < bolts.size(); i++) {
    for (size_t j = i + 1; j < bolts.size(); j++) {
      const Bolt& a = bolts[i];
      const Bolt& b = bolts[j];
      int power = a.power + b.power;
      if (a.element != b.element) power = static_cast<int>(std::floor(double(power) * 3 / 2));
      const Bolt& stronger = a.power >= b.power ? a : b;
      out.push_back(Bolt{.power = power, .element = stronger.element});
    }
  }
  return out;
}
