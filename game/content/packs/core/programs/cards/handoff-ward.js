function handoffWard(bolts, battle) {
  // Scheduler provenance is explicit: a plain one-power neutral bolt is not an idle unless it carries this mark.
  let gained = 0;
  return bolts.map((bolt) => {
    const out = { ...bolt };
    const idle = out.idle === true;
    delete out.idle;
    if (idle && !out.stash && !out.block && out.power > 0 && gained + out.power <= 6) {
      out.block = true;
      gained += out.power;
    }
    return out;
  });
}
