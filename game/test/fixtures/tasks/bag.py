def add(bag, item):
    for stack in bag:
        if stack["item"] == item:
            stack["count"] += 1
            return bag
    bag.append({"item": item, "count": 1})
    return bag


def remove(bag, item):
    for stack in bag:
        if stack["item"] == item:
            stack["count"] -= 1
            if stack["count"] == 0:
                bag.remove(stack)
            return bag
    return bag
