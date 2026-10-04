function memoWard(bolts, battle) {
  // Remember the best answer so far: the table holds what every program landed this fight, and the ward is as large
  // as the biggest row, never below 4.
  const best = Math.max(0, ...(battle.dp || []));
  return [...bolts, { power: Math.max(4, best), element: "none", block: true }];
}
