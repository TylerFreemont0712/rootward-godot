def literal(bolts, battle):
    # A constant in the code: one 9-power bolt, appended in O(1) (a list grows at its end without moving the rest).
    bolts.append({"power": 9, "element": "none"})
    return bolts
