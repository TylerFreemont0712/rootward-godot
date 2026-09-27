def lis_strike(bolts, battle):
    # length[i]: the longest rising sequence ending at bolt i, built from every earlier j (O(n²)); `before` remembers
    # the step taken, so the sequence can be walked back from its end.
    n = len(bolts)
    if n == 0:
        return bolts
    length = [1] * n
    before = [-1] * n
    for i in range(n):
        for j in range(i):
            if bolts[j]["power"] < bolts[i]["power"] and length[j] + 1 > length[i]:
                length[i] = length[j] + 1
                before[i] = j
    end = 0
    for i in range(1, n):
        if length[i] > length[end]:
            end = i
    chosen = set()
    while end >= 0:
        chosen.add(end)
        end = before[end]
    bonus = len(chosen)
    return [
        dict(bolt, power=bolt["power"] + bonus, foe=0) if i in chosen else dict(bolt, block=True)
        for i, bolt in enumerate(bolts)
    ]
