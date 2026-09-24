def spectrum_wheel(bolts, battle):
    colors = ["fire", "frost", "spark"]
    return [{**b, "element": colors[i % 3]} for i, b in enumerate(bolts)]
