function hashMerge(bolts, battle) {
  // One pass with a hash map (element -> bolt): same-element bolts fuse, +1 for each bolt swallowed. Everything
  // after this card has fewer bolts to work through.
  const groups = new Map();
  for (const bolt of bolts) {
    const key = bolt.element;
    if (groups.has(key)) groups.set(key, { ...groups.get(key), power: groups.get(key).power + bolt.power + 1 });
    else groups.set(key, { ...bolt });
  }
  return Array.from(groups.values());
}
