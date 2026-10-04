long long karatsuba_product(long long x, long long y) {
  if (x < 10 || y < 10) return x * y;
  int digits = 0;
  for (long long v = std::max(x, y); v > 0; v /= 10) digits++;
  long long scale = 1;
  for (int i = 0; i < digits / 2; i++) scale *= 10;
  const long long hx = x / scale;
  const long long lx = x % scale;
  const long long hy = y / scale;
  const long long ly = y % scale;
  const long long z0 = karatsuba_product(lx, ly);
  const long long z2 = karatsuba_product(hx, hy);
  const long long z1 = karatsuba_product(lx + hx, ly + hy) - z0 - z2;
  return z2 * scale * scale + z1 * scale + z0;
}

Bolts karatsuba(Bolts bolts, const Battle& battle) {
  // Karatsuba: x * y from THREE products of half-length numbers, not four. Split x = hx * 10^m + lx and
  // y = hy * 10^m + ly; then x * y = z2 * 10^2m + z1 * 10^m + z0, with z0 = lx * ly, z2 = hx * hy, and the cross term
  // z1 = (lx + hx) * (ly + hy) - z0 - z2 got from one more product. T(n) = 3 T(n / 2) + O(n) = O(n^1.58).
  if (bolts.size() < 2) return bolts;
  std::vector<int> order(bolts.size());
  std::iota(order.begin(), order.end(), 0);
  std::stable_sort(order.begin(), order.end(), [&](int a, int b) { return bolts[a].power > bolts[b].power; });
  const Bolt& first = bolts[order[0]];
  const Bolt& second = bolts[order[1]];
  const long long x = std::min(std::max(first.power, 0), 99999);
  const long long y = std::min(std::max(second.power, 0), 99999);
  const int product = static_cast<int>(karatsuba_product(x, y) / 10);
  if (product <= 0) return bolts;
  Bolt made;
  made.power = product;
  made.element = first.element;
  bolts.push_back(made);
  return bolts;
}
