Bolts seek_weakest(Bolts bolts, const Battle& battle) {
  for (Bolt& bolt : bolts) bolt.target = "weakest";
  return bolts;
}
