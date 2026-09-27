function pascalRow(bolts, battle) {
  // A table built from smaller answers: each row comes from the one above, every entry the sum of the two over it.
  let row = [1];
  for (let r = 0; r < 5; r++) {
    const next = [1];
    for (let i = 0; i < row.length - 1; i++) next.push(row[i] + row[i + 1]);
    next.push(1);
    row = next;
  }
  return bolts.concat(row.map((value) => ({ power: value, element: "none" })));
}
