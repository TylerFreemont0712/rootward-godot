def median_pulse(bolts, battle):
    # Sort indices, not the volley: the lower-index member wins a tie and the original order stays intact.
    result = [dict(bolt) for bolt in bolts]
    attacks = [i for i, bolt in enumerate(result[:16]) if not bolt.get("block") and not bolt.get("stash")]
    if not attacks:
        return result
    attacks.sort(key=lambda i: result[i]["power"])
    result[attacks[len(attacks) // 2]]["power"] += 2
    return result
