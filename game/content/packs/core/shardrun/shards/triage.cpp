Bolts triage(Bolts bolts, const Battle& battle) {
  for (Bolt& bolt : bolts) bolt.target = "strongest";
  return bolts;
}
