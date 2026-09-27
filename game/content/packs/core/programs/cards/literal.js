function literal(bolts, battle) {
  // A constant in the code: one 9-power bolt, appended in O(1) (an array grows at its end without moving the rest).
  bolts.push({ power: 9, element: "none" });
  return bolts;
}
