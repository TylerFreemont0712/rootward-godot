Bolts lambda_card(Bolts bolts, const Battle& battle) {
  auto stronger = [](Bolt bolt) { bolt.power += 2; return bolt; };
  for (Bolt& bolt : bolts) bolt = stronger(bolt);
  return bolts;
}
