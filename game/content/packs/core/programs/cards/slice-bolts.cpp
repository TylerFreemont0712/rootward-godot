Bolts slice_bolts(Bolts bolts, const Battle& battle) {
  // C++ has no slice syntax: keep the first four by shortening the vector.
  if (bolts.size() > 4) bolts.resize(4);
  for (Bolt& bolt : bolts) bolt.power += 2;
  return bolts;
}
