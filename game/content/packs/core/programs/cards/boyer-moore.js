function boyerMoore(bolts, battle) {
  // Boyer-Moore majority vote: one pass and one counter find the only element that could hold more than half the
  // volley, without counting each element. A second pass confirms it. If one does, every bolt becomes that element.
  let candidate = null;
  let count = 0;
  for (const bolt of bolts) {
    if (count === 0) {
      candidate = bolt.element;
      count = 1;
    } else if (bolt.element === candidate) {
      count++;
    } else {
      count--;
    }
  }
  let votes = 0;
  for (const bolt of bolts) {
    if (bolt.element === candidate) votes++;
  }
  if (votes * 2 <= bolts.length) return bolts;
  return bolts.map((bolt) => ({ ...bolt, element: candidate, power: bolt.power + 1 }));
}
