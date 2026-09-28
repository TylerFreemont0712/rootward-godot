def repeat_plus(bolts, battle):
    # A loop of fixed length (k = 4), so O(k) whatever the volley's size: four copies of the last bolt.
    last = bolts[-1] if bolts else {"power": 4, "element": "none"}
    for _ in range(4):
        bolts.append(dict(last))
    return bolts
