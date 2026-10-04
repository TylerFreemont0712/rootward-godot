function karatsubaPlus(bolts, battle) {
  // Karatsuba: x * y from THREE products of half-length numbers, not four. Split x = hx * 10^m + lx and
  // y = hy * 10^m + ly; then x * y = z2 * 10^2m + z1 * 10^m + z0, with z0 = lx * ly, z2 = hx * hy, and the cross term
  // z1 = (lx + hx) * (ly + hy) - z0 - z2 got from one more product. T(n) = 3 T(n / 2) + O(n) = O(n^1.58).
  const karatsuba = (x, y) => {
    if (x < 10 || y < 10) return x * y;
    let digits = 0;
    for (let v = Math.max(x, y); v > 0; v = Math.floor(v / 10)) digits++;
    const scale = 10 ** Math.floor(digits / 2);
    const hx = Math.floor(x / scale);
    const lx = x % scale;
    const hy = Math.floor(y / scale);
    const ly = y % scale;
    const z0 = karatsuba(lx, ly);
    const z2 = karatsuba(hx, hy);
    const z1 = karatsuba(lx + hx, ly + hy) - z0 - z2;
    return z2 * scale * scale + z1 * scale + z0;
  };
  if (bolts.length < 2) return bolts;
  const order = bolts.map((_, i) => i).sort((a, b) => bolts[b].power - bolts[a].power || a - b);
  const first = bolts[order[0]];
  const second = bolts[order[1]];
  const x = Math.min(Math.max(first.power, 0), 99999);
  const y = Math.min(Math.max(second.power, 0), 99999);
  const product = Math.floor(karatsuba(x, y) / 8);
  if (product <= 0) return bolts;
  return bolts.concat([{ power: product, element: first.element }]);
}
