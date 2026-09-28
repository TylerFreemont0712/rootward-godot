def merge_strike(bolts, battle):
    # A tournament of merges: pair the bolts up, fuse each pair (+20%, +40% with `import math`), and repeat on the
    # survivors until one is left. n bolts take n - 1 merges in log2(n) rounds. The one bolt flies at the foe with the
    # most HP.
    if not bolts:
        return bolts
    growth = 14 if "math" in battle.get("imports", []) else 12
    level = [dict(bolt) for bolt in bolts]
    while len(level) > 1:
        merged = []
        for i in range(0, len(level) - 1, 2):
            power = (level[i]["power"] + level[i + 1]["power"]) * growth // 10
            merged.append(dict(level[i], power=power))
        if len(level) % 2 == 1:
            merged.append(level[-1])
        level = merged
    foes = battle["foes"]
    toughest = 0
    for i in range(1, len(foes)):
        if foes[i]["hp"] > foes[toughest]["hp"]:
            toughest = i
    return [dict(level[0], foe=toughest)]
