def greedy_ward(bolts, battle):
    # Sort the bolts strongest first and take them until the goal is met (10 block): O(n log n) for the sort. Greedy
    # stops as soon as the goal is reached, even when a smaller set would have done.
    order = sorted(range(len(bolts)), key=lambda i: -bolts[i]["power"])
    chosen = set()
    total = 0
    for i in order:
        if total >= 10:
            break
        chosen.add(i)
        total += bolts[i]["power"]
    return [dict(bolt, block=True) if i in chosen else dict(bolt) for i, bolt in enumerate(bolts)]
