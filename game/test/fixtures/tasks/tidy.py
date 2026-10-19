def total(bag):
    count = 0
    for stack in bag:
        count += stack["count"]
    return count


def tidy(bag):
    return sorted(bag, key=lambda stack: stack["item"])
