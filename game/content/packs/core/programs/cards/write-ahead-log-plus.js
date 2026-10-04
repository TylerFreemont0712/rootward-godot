function writeAheadLogPlus(bolts, battle) {
  // Write-ahead logging: record the change before applying it. Every weak bolt (under 5 power) is logged into the index instead of flying.
  // A ward is a defence, not a weak attack, so it is left alone.
  const result = [];
  for (const bolt of bolts) {
    if (bolt.power < 5 && !bolt.block) result.push({ ...bolt, stash: true });
    else result.push({ ...bolt });
  }
  return result;
}
