def cascade(bolts, battle):
    stepped = []
    for index, bolt in enumerate(bolts):
        stepped.append({**bolt, "mult": bolt["mult"] + index + 1})
    return stepped
