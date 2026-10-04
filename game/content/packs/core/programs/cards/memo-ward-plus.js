function memoWardPlus(bolts, battle) {
  // Remember the best answer so far: the table holds what every program landed this fight, and the ward is as large
  // as the biggest row, never below 6.
  const best = Math.max(0, ...(battle.dp || []));
  return [...bolts, { power: Math.max(6, best), element: "none", block: true }];
}
