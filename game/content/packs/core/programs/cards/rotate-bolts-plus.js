function rotateBoltsPlus(bolts, battle) {
  // deque.rotate(k) in Python: the last k items come to the front, and k may be longer than the list.
  const copies = bolts.map((bolt) => ({ ...bolt }));
  if (copies.length === 0) return copies;
  const k = 2 % copies.length;
  return copies.slice(copies.length - k).concat(copies.slice(0, copies.length - k));
}
