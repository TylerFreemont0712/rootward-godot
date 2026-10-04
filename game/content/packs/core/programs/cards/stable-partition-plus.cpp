Bolts stable_partition_plus(Bolts bolts, const Battle& battle) {
  Bolts front;
  Bolts rest;
  for (const Bolt& bolt : bolts) {
    Bolts& group = bolt.power >= 4 && !bolt.block ? front : rest;
    group.push_back(bolt);
  }
  front.insert(front.end(), rest.begin(), rest.end());
  return front;
}
