Bolts handoff_ward(Bolts bolts, const Battle& battle) {
  // Scheduler provenance is explicit: a plain one-power neutral bolt is not an idle unless it carries this mark.
  int gained = 0;
  for (Bolt& bolt : bolts) {
    const bool idle = bolt.idle;
    bolt.idle = false;
    if (idle && !bolt.stash && !bolt.block && bolt.power > 0 && gained + bolt.power <= 6) {
      bolt.block = true;
      gained += bolt.power;
    }
  }
  return bolts;
}
