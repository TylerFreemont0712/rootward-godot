Bolts scatter(Bolts bolts, const Battle& battle) {
  for (Bolt& bolt : bolts) bolt.target = "all";
  return bolts;
}
