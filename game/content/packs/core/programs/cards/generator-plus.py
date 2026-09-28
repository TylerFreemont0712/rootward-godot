def spring():
    # A generator: it pauses at each yield and carries on from there the next time it is asked. It never ends.
    while True:
        yield {"power": 3, "element": "none"}


def generator_plus(bolts, battle):
    source = spring()
    return bolts + [next(source), next(source), next(source)]
