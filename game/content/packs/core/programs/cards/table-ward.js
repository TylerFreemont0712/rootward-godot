function tableWard(bolts, battle) {
  // Read the table's last row (what the latest program landed) and turn a share of it into block, never below 3.
  const rows = battle.dp || [];
  const last = rows.length > 0 ? rows[rows.length - 1] : 0;
  return [...bolts, { power: Math.max(3, Math.floor(last / 3)), element: "none", block: true }];
}
