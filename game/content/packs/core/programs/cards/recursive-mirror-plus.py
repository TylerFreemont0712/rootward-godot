def recursive_mirror_plus(bolts, battle):
    out = list(bolts)
    def mirror(index):
        if index < 0:
            return
        out.append(dict(bolts[index], power=(bolts[index]["power"] + 0) // 1))
        mirror(index - 1)
    mirror(len(bolts) - 1)
    return out
