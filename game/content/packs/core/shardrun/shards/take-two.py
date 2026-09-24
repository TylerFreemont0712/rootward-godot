def take_two(bolts, battle):
    return [{**b, "mult": b["mult"] * 2} for b in bolts[:2]]
