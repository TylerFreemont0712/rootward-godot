def runoff_echo(bolts, battle):
    # Each strict rise produces a small echo; the cap keeps an already wide volley manageable.
    result = [dict(bolt) for bolt in bolts]
    attacks = [bolt for bolt in bolts if not bolt.get("block") and not bolt.get("stash")]
    echoes = []
    for before, after in zip(attacks, attacks[1:]):
        if len(result) + len(echoes) >= 128 or len(echoes) >= 3:
            break
        if after["power"] <= before["power"]:
            continue
        echo = {"power": 1, "element": after["element"]}
        if "foe" in after:
            echo["foe"] = after["foe"]
        echoes.append(echo)
    return result + echoes
