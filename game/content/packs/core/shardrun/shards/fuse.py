def fuse(bolts, battle):
    wards = [b for b in bolts if b["ward"]]
    attacks = [b for b in bolts if not b["ward"]]
    if not attacks:
        return wards
    power = max(1, attacks[0]["power"])
    return [{**attacks[0], "power": power, "mult": sum(b["power"] * b["mult"] for b in attacks) / power}] + wards
