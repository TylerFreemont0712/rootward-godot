def literal_plus(bolts, battle):
    # A constant in the code: one 12-power bolt, appended in O(1) (a list grows at its end without moving the rest).
    bolts.append({"power": 12, "element": "none"})
    return bolts
