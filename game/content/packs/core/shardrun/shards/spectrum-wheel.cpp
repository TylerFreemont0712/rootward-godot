Bolts spectrum_wheel(Bolts bolts, const Battle& battle) {
  const std::vector<std::string> colors = {"fire", "frost", "spark"};
  for (size_t i = 0; i < bolts.size(); i++) bolts[i].element = colors[i % 3];
  return bolts;
}
