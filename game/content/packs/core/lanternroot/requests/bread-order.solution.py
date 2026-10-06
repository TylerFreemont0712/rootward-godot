from bakery import loaves_for


def bread_order(guests_by_day):
    loaves = 0
    for guests in guests_by_day:
        loaves += loaves_for(guests)
    return loaves
