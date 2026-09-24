def guard_echo(bolts, battle):
    out = []
    for b in bolts:
        out.append(b)
        if not b["ward"]:
            out.append({**b, "ward": True, "power": b["power"] / 4})
    return out
