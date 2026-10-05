def gradient_ward(bolts, battle):
    # Compare attacking bolts in their existing order. Each strict rise pays one point from its higher bolt; equal
    # neighbours do not. Existing wards and stashed bolts do not take part in the sequence.
    result = [dict(bolt) for bolt in bolts]
    ids = list(range(len(result)))
    was_sorted = all(bolts[i - 1]["power"] <= bolts[i]["power"] for i in range(1, len(bolts)))
    attacks = [i for i, bolt in enumerate(result) if not bolt.get("block", False) and not bolt.get("stash", False)]
    if not attacks:
        return result

    sources = [attacks[i] for i in range(1, len(attacks)) if result[attacks[i]]["power"] > result[attacks[i - 1]]["power"]]
    if not sources:
        weakest = attacks[0]
        for i in attacks[1:]:
            if result[i]["power"] < result[weakest]["power"]:
                weakest = i
        sources = [weakest]

    wards = []
    gained = 0
    for source_id in sources:
        if gained >= 6:
            break
        i = ids.index(source_id)
        power = result[i]["power"]
        if power <= 0:
            continue
        if power == 1:
            # A one-power source can become a ward without adding another bolt.
            result[i]["block"] = True
            gained += 1
            continue

        if len(result) + len(wards) < 128:
            result[i]["power"] -= 1
            if was_sorted:
                while i > 0 and result[i - 1]["power"] > result[i]["power"]:
                    result[i - 1], result[i] = result[i], result[i - 1]
                    ids[i - 1], ids[i] = ids[i], ids[i - 1]
                    i -= 1
            wards.append({"power": 1, "element": result[i]["element"], "block": True})
            gained += 1
            continue

        # At the bolt limit, add the point to an existing ward. Never siphon if there is nowhere safe to put it.
        existing_id = next((ids[j] for j, bolt in enumerate(result) if bolt.get("block", False) and not bolt.get("stash", False) and bolt["power"] < 9999), None)
        if existing_id is not None:
            result[i]["power"] -= 1
            if was_sorted:
                while i > 0 and result[i - 1]["power"] > result[i]["power"]:
                    result[i - 1], result[i] = result[i], result[i - 1]
                    ids[i - 1], ids[i] = ids[i], ids[i - 1]
                    i -= 1
            existing_index = ids.index(existing_id)
            result[existing_index]["power"] += 1
            if was_sorted:
                while existing_index + 1 < len(result) and result[existing_index]["power"] > result[existing_index + 1]["power"]:
                    result[existing_index], result[existing_index + 1] = result[existing_index + 1], result[existing_index]
                    ids[existing_index], ids[existing_index + 1] = ids[existing_index + 1], ids[existing_index]
                    existing_index += 1
            gained += 1

    if wards:
        # New wards carry 1 power. Place them before the first stronger bolt so a weakest-first volley stays ordered.
        insertion = next((i for i, bolt in enumerate(result) if bolt["power"] > 1), len(result))
        result[insertion:insertion] = wards
    return result
