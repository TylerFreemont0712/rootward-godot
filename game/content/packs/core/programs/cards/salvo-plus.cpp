Bolts salvo_plus(Bolts bolts, const Battle& battle) {
  // A rising run of six bolts, after whatever came before.
  Bolts rising;
  for (int p = 2; p <= 7; p++) rising.push_back(Bolt{.power = p, .element = "none"});
  bolts.insert(bolts.end(), rising.begin(), rising.end());
  return bolts;
}
