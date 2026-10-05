def handoff_ward(bolts, battle):
    # Scheduler provenance is explicit: a plain one-power neutral bolt is not an idle unless it carries this mark.
    result = []
    gained = 0
    for bolt in bolts:
        out = dict(bolt)
        idle = out.pop("idle", False)
        power = out["power"]
        if idle and not out.get("stash", False) and not out.get("block", False) and power > 0 and gained + power <= 6:
            out["block"] = True
            gained += power
        result.append(out)
    return result
