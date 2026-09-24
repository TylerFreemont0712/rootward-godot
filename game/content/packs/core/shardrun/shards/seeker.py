def seek_weakest(bolts, battle):
    return [{**bolt, "target": "weakest"} for bolt in bolts]
