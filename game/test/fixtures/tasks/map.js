function mapColour(ground) {
  const colours = {
    grass: "green",
    flowers: "light green",
    path: "tan",
    cobble: "grey",
    bridge: "brown",
    floor: "brown",
    rug: "red",
    water: "blue",
    hedge: "dark green",
    wall: "dark grey",
    void: "black",
    building: "orange",
    tree: "dark green",
    thing: "purple",
  };
  return colours[ground];
}

function placeOf(x, y, places) {
  for (const place of places) {
    if (place.x <= x && x < place.x + place.w && place.y <= y && y < place.y + place.h) {
      return place.name;
    }
  }
  return "";
}
