function* spring() {
  // A generator: it pauses at each yield and carries on from there the next time it is asked. It never ends.
  while (true) yield { power: 3, element: "none" };
}

function generator(bolts, battle) {
  const source = spring();
  return bolts.concat([source.next().value, source.next().value]);
}
