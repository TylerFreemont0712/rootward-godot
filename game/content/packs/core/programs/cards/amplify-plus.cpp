Bolts amplify_plus(Bolts bolts, const Battle& battle) {
  // One pass over the volley: every bolt gains 4 power. `bolts` is our own copy, so changing it in place is safe.
  for (Bolt& bolt : bolts) bolt.power += 4;
  return bolts;
}
