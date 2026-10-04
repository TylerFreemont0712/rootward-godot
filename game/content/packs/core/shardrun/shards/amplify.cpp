Bolts amplify(Bolts bolts, const Battle& battle) {
  for (Bolt& bolt : bolts) bolt.power = bolt.power + 3;
  return bolts;
}
