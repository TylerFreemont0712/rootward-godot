function lazyFork(bolts, battle) {
  const split = [];
  for (let i = 0; i < bolts.length - 1; i++) {
    split.push({ ...bolts[i], power: bolts[i].power * 0.6 });
    split.push({ ...bolts[i], power: bolts[i].power * 0.6 });
  }
  return split;
}
