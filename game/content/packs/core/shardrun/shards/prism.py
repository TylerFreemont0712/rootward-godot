def prism(bolts, battle):
    split = []
    for bolt in bolts:
        for element in ["fire", "frost", "spark"]:
            split.append({**bolt, "element": element, "power": bolt["power"] * 0.4})
    return split
