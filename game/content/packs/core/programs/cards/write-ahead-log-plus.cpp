Bolts write_ahead_log_plus(Bolts bolts, const Battle& battle) {
  // Write-ahead logging: record the change before applying it. Every weak bolt (under 5 power) is logged into the index instead of flying.
  // A ward is a defence, not a weak attack, so it is left alone.
  for (Bolt& bolt : bolts) {
    if (bolt.power < 5 && !bolt.block) bolt.stash = true;
  }
  return bolts;
}
