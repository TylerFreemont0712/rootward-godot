def kadane(bolts, battle):
    # Kadane: the best run ending here is this bolt alone, or this bolt added to the best run ending just before; a
    # run whose score falls to zero or below is dropped. Scores are power minus 3, so weak bolts count against a run.
    # The best run seen fuses into one bolt of its whole power, 1 stronger for every bolt in it. O(n).
    if not bolts:
        return bolts
    best, best_from, best_to = None, 0, 0
    here, start = 0, 0
    for i, bolt in enumerate(bolts):
        if here <= 0:
            here, start = 0, i
        here += bolt["power"] - 3
        if best is None or here > best:
            best, best_from, best_to = here, start, i
    run = bolts[best_from:best_to + 1]
    strongest = run[0]
    for bolt in run:
        if bolt["power"] > strongest["power"]:
            strongest = bolt
    fused = dict(strongest, power=sum(bolt["power"] for bolt in run) + len(run))
    return bolts[:best_from] + [fused] + bolts[best_to + 1:]
