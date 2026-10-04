Bolts range_source_plus(Bolts bolts, const Battle& battle) {
  // range(start, stop, step) counts from start in steps, stopping before stop: C++ has no range, so a loop.
  for (int power = 3; power < 15; power += 3) {
    Bolt counted;
    counted.power = power;
    bolts.push_back(counted);
  }
  return bolts;
}
