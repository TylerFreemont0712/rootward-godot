def bit_shift_plus(bolts, battle):
    # x << 1 slides every bit one place left: it doubles x. Keeping only the low bits (& 63) is overflow: past the
    # top the value wraps around to the bottom.
    return [dict(bolt, power=(bolt["power"] << 1) & 63) for bolt in bolts]
