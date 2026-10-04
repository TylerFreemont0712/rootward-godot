def cursor(bolts, battle):
    # A cursor walks a sorted collection one item at a time: it takes the 3 weakest bolts from the index, in order.
    # A taken bolt must stay exactly as banked, so each brings a 2-power bolt of its element beside it.
    index = battle.get("index", [])
    result = list(bolts)
    for i in range(min(3, len(index))):
        result.append(dict(index[i], from_index=True))
        result.append({"power": 2, "element": index[i]["element"]})
    return result
