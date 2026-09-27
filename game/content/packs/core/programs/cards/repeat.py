def repeat(bolts, battle):
    # A loop of fixed length (k = 3), so O(k) whatever the volley's size: three copies of the last bolt.
    last = bolts[-1] if bolts else {"power": 4, "element": "none"}
    for _ in range(3):
        bolts.append(dict(last))
    return bolts
