Bolts slice_bolts_plus(Bolts bolts, const Battle& battle) {
  // C++ has no slice syntax: keep the first four by shortening the vector.
  if (bolts.size() > 4) bolts.resize(4);
  for (Bolt& bolt : bolts) bolt.power += 3;
  return bolts;
}
