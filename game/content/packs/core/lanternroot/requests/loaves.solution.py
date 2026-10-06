def loaves_for(guests):
    loaves = guests // 4
    if guests % 4 != 0:
        loaves += 1
    return loaves
