def monochrome(bolts, battle):
    coherent = bool(bolts) and bolts[0]["element"] != "none" and all(b["element"] == bolts[0]["element"] for b in bolts)
    return [{**b, "mult": b["mult"] * (2 if coherent else 1)} for b in bolts]
