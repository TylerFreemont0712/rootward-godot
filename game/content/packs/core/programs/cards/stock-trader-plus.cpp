Bolts stock_trader_plus(Bolts bolts, const Battle& battle) {
  // Buy at every dip, sell at every peak: the profit is the sum of the rises from one bolt to the next. One pass.
  // The profit becomes a new bolt at the end of the volley.
  int profit = 0;
  for (int i = 1; i < static_cast<int>(bolts.size()); i++) {
    if (bolts[i].power > bolts[i - 1].power) profit += bolts[i].power - bolts[i - 1].power;
  }
  if (profit > 0) {
    int best = 0;
    for (int i = 1; i < static_cast<int>(bolts.size()); i++) {
      if (bolts[i].power > bolts[best].power) best = i;
    }
    const std::string element = bolts[best].element;
    bolts.push_back(Bolt{.power = profit, .element = element});
  }
  return bolts;
}
