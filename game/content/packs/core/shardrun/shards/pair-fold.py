def pair_fold(bolts, battle):
    out = []
    for i in range(0, len(bolts), 2):
        a = bolts[i]
        if i + 1 < len(bolts) and a["ward"] == bolts[i + 1]["ward"]:
            b = bolts[i + 1]
            power = max(1, a["power"])
            out.append({**a, "power": power, "mult": (a["power"] * a["mult"] + b["power"] * b["mult"]) / power})
        else:
            out.extend(bolts[i:i + 2])
    return out
