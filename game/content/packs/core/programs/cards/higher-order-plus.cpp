Bolts higher_order_plus(Bolts bolts, const Battle& battle) {
  // A function that makes functions: map a small lambda over the volley now, and two more are written for later.
  auto step = [](Bolt bolt) {
    bolt.power = bolt.power + 2;
    return bolt;
  };
  // std::transform is C++'s map: it calls step on every bolt and writes what it returns back in place.
  std::transform(bolts.begin(), bolts.end(), bolts.begin(), step);
  return bolts;
}
