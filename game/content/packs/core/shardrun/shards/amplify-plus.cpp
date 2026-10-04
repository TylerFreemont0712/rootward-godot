Bolts amplify_plus(Bolts bolts, const Battle& battle) {
  for (Bolt& bolt : bolts) bolt.power = bolt.power + 5;
  return bolts;
}
