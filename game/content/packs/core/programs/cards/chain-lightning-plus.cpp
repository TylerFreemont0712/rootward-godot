Bolts chain_lightning_plus(Bolts bolts, const Battle& battle) {
  const int count = static_cast<int>(battle.foes.size());
  if (count == 0) return bolts;
  Bolts out;
  int target = 0;
  for (const Bolt& bolt : bolts) {
    if (bolt.block) {
      out.push_back(bolt);
    } else {
      Bolt spark = bolt;
      spark.power = bolt.power + (bolt.element == "spark" ? 4 : 0);
      spark.element = "spark";
      spark.foe = target % count;
      out.push_back(spark);
      target++;
    }
  }
  return out;
}
