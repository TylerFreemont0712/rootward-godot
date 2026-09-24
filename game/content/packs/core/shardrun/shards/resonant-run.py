def resonant_run(bolts, battle):
    out = []
    previous = None
    streak = 0
    for b in bolts:
        streak = streak + 1 if b["element"] == previous else 1
        previous = b["element"]
        out.append({**b, "mult": b["mult"] * streak})
    return out
