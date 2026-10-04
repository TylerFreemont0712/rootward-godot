Bolts temper(Bolts bolts, const Battle& battle) {
  Bolts tempered;
  for (const Bolt& bolt : bolts) {
    double power = bolt.power;
    const double left_over = std::fmod(power, 5);
    if (left_over != 0) power = power + (5 - left_over);
    Bolt rounded = bolt;
    rounded.power = power;
    tempered.push_back(rounded);
  }
  return tempered;
}
