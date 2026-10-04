function cursorPlus(bolts, battle) {
  // A cursor walks a sorted collection one item at a time: it takes the 4 weakest bolts from the index, in order.
  // A taken bolt must stay exactly as banked, so each brings a 2-power bolt of its element beside it.
  const index = battle.index || [];
  const result = bolts.slice();
  for (let i = 0; i < Math.min(4, index.length); i++) {
    result.push({ ...index[i], from_index: true });
    result.push({ power: 2, element: index[i].element });
  }
  return result;
}
