Bolts release_plus(Bolts bolts, const Battle& battle) {
  // Three quarters of what the fight's programs have landed so far, as one bolt. `global total` keeps the count.
  const auto found = battle.globals.find("total");
  const int total = found != battle.globals.end() ? found->second : 0;
  const int half = static_cast<int>(std::floor(double(total * 3) / 4));
  if (half <= 0) return bolts;
  bolts.push_back(Bolt{.power = half, .element = "none"});
  return bolts;
}
