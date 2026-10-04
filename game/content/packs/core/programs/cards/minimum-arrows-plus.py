def minimum_arrows_plus(bolts, battle):
    # Minimum arrows to burst the balloons: each bolt, strongest first, pierces the foes in a line. What it does not
    # spend on one foe flies on into the next, 1 stronger at each foe, until it runs out.
    foes = battle.get("foes", [])
    if not foes:
        return bolts
    remaining = [foe["hp"] + foe.get("shield", 0) for foe in foes]
    result = []
    for i in sorted(range(len(bolts)), key=lambda i: -bolts[i]["power"]):
        bolt = bolts[i]
        power = bolt["power"]
        live = [j for j in range(len(foes)) if remaining[j] > 0]
        if bolt.get("block"):
            result.append(dict(bolt))
        elif not live:
            result.append(dict(bolt, foe=len(foes) - 1))
        else:
            for rank, j in enumerate(live):
                if rank == len(live) - 1 or power <= remaining[j]:
                    result.append(dict(bolt, power=power, foe=j))
                    remaining[j] -= power
                    break
                result.append(dict(bolt, power=remaining[j], foe=j))
                power += 1 - remaining[j]
                remaining[j] = 0
    return result
