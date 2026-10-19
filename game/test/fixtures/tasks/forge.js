function forge(materials) {
  materials = materials.slice().sort();
  if (materials.join(" ") === "iron wood") {
    return "hammer";
  }
  if (materials.join(" ") === "iron iron") {
    return "gear";
  }
  if (materials.join(" ") === "wood wood") {
    return "stick";
  }
  return "nothing";
}
