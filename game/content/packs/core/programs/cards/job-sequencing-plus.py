def job_sequencing_plus(bolts, battle):
    # Job sequencing with deadlines: every foe is a job, its deadline the tempo of its intent (a bolt takes a slot of
    # 4 operations) and its profit the damage it intends. Take the jobs by profit, biggest first, and keep one only if
    # the bolts that kill it still fit before its deadline. Bolts no job needed go to the first job kept.
    foes = battle.get("foes", [])
    if not foes:
        return bolts
    profit = [foe.get("intent", {}).get("damage", 0) * foe.get("intent", {}).get("hits", 1) for foe in foes]
    need = [foe["hp"] + foe.get("shield", 0) for foe in foes]
    order = sorted(range(len(foes)), key=lambda i: (-(profit[i] * 100 // max(1, need[i])), -profit[i], foes[i].get("intent", {}).get("tempo", 0), i))
    strongest = sorted(range(len(bolts)), key=lambda i: -bolts[i]["power"])
    aim = [-1] * len(bolts)
    kept = []
    used = 0
    for job in order:
        slots = foes[job].get("intent", {}).get("tempo", 0) // 4
        taken, total = 0, 0
        while used + taken < len(strongest) and total < need[job]:
            total += bolts[strongest[used + taken]]["power"]
            taken += 1
        if total >= need[job] and used + taken <= slots:
            for k in range(used, used + taken):
                aim[strongest[k]] = job
            used += taken
            kept.append(job)
    first = kept[0] if kept else order[0]
    return [dict(bolt, foe=first if aim[i] < 0 else aim[i]) for i, bolt in enumerate(bolts)]
