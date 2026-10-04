function recurrence(bolts, battle) {
  // Read the two preceding rows instead of recursively recomputing the recurrence.
  const rows = battle.dp || [];
  if ((battle.turn || 1) < 2 || rows.length === 0) return bolts;
  const total = rows[rows.length - 1] + (rows.length > 1 ? rows[rows.length - 2] : 0);
  const power = Math.floor(total / 2);
  return bolts.concat([{ power, element: "none" }]);
}
