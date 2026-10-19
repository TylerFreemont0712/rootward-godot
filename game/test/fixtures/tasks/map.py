def map_colour(ground):
    colours = {
        "grass": "green",
        "flowers": "light green",
        "path": "tan",
        "cobble": "grey",
        "bridge": "brown",
        "floor": "brown",
        "rug": "red",
        "water": "blue",
        "hedge": "dark green",
        "wall": "dark grey",
        "void": "black",
        "building": "orange",
        "tree": "dark green",
        "thing": "purple",
    }
    return colours[ground]


def place_of(x, y, places):
    for place in places:
        if place["x"] <= x < place["x"] + place["w"] and place["y"] <= y < place["y"] + place["h"]:
            return place["name"]
    return ""
