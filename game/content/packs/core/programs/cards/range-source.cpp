Bolts range_source(Bolts bolts, const Battle& battle) {
  // range(start, stop, step) counts from start in steps, stopping before stop: C++ has no range, so a loop.
  for (int power = 2; power < 10; power += 2) {
    Bolt counted;
    counted.power = power;
    bolts.push_back(counted);
  }
  return bolts;
}
