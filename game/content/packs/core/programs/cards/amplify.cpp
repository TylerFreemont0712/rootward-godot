Bolts amplify(Bolts bolts, const Battle& battle) {
  // One pass over the volley: every bolt gains 3 power. `bolts` is our own copy, so changing it in place is safe.
  for (Bolt& bolt : bolts) bolt.power += 3;
  return bolts;
}
