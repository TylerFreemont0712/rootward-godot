Bolts prism(Bolts bolts, const Battle& battle) {
  Bolts split;
  for (const Bolt& bolt : bolts) {
    for (const std::string element : {"fire", "frost", "spark"}) {
      Bolt shard = bolt;
      shard.element = element;
      shard.power = bolt.power * 0.4;
      split.push_back(shard);
    }
  }
  return split;
}
