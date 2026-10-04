def karatsuba(bolts, battle):
    # Karatsuba: x * y from THREE products of half-length numbers, not four. Split x = hx * 10^m + lx and
    # y = hy * 10^m + ly; then x * y = z2 * 10^2m + z1 * 10^m + z0, with z0 = lx * ly, z2 = hx * hy, and the cross term
    # z1 = (lx + hx) * (ly + hy) - z0 - z2 got from one more product. T(n) = 3 T(n / 2) + O(n) = O(n^1.58).
    def karatsuba(x, y):
        if x < 10 or y < 10:
            return x * y
        digits, v = 0, max(x, y)
        while v > 0:
            digits += 1
            v //= 10
        scale = 10 ** (digits // 2)
        hx, lx = x // scale, x % scale
        hy, ly = y // scale, y % scale
        z0 = karatsuba(lx, ly)
        z2 = karatsuba(hx, hy)
        z1 = karatsuba(lx + hx, ly + hy) - z0 - z2
        return z2 * scale * scale + z1 * scale + z0

    if len(bolts) < 2:
        return bolts
    order = sorted(range(len(bolts)), key=lambda i: -bolts[i]["power"])
    first, second = bolts[order[0]], bolts[order[1]]
    x = min(max(first["power"], 0), 99999)
    y = min(max(second["power"], 0), 99999)
    product = karatsuba(x, y) // 10
    if product <= 0:
        return bolts
    return bolts + [{"power": product, "element": first["element"]}]
