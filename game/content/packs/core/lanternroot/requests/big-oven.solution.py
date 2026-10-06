def loaves_for(guests, per_loaf=4):
    loaves = guests // per_loaf
    if guests % per_loaf != 0:
        loaves += 1
    return loaves
