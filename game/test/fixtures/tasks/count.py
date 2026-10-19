def count(lanterns):
    lit = 0
    for lantern in lanterns:
        if lantern["lit"]:
            lit = lit + 1
    return lit
