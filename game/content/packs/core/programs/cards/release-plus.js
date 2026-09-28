function releasePlus(bolts, battle) {
  // Three quarters of what the fight's programs have landed so far, as one bolt. `global total` keeps the count.
  const half = Math.floor((((battle.globals || {}).total || 0) * 3) / 4);
  if (half <= 0) return bolts;
  return bolts.concat([{ power: half, element: "none" }]);
}
