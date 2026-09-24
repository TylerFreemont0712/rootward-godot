def prefix_charge(bolts, battle):
    total = 0
    out = []
    for b in bolts:
        total += b["mult"]
        out.append({**b, "mult": total})
    return out
