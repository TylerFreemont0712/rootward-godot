import heapq


def import_heapq(bolts, battle):
    # Runs before every strike card: a heap hands the volley over strongest first (nlargest pops the biggest in turn).
    return heapq.nlargest(len(bolts), bolts, key=lambda bolt: bolt["power"])
