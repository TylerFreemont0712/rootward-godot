Bolts siphon(Bolts bolts, const Battle& battle) {
  if (bolts.size() == 0) return bolts;
  size_t weakest = 0;
  for (size_t index = 0; index < bolts.size(); index++) {
    if (bolts[index].power < bolts[weakest].power) weakest = index;
  }
  Bolts warded;
  for (size_t index = 0; index < bolts.size(); index++) {
    Bolt bolt = bolts[index];
    if (index == weakest) {
      bolt.ward = true;
      bolt.power = bolt.power * 2;
    }
    warded.push_back(bolt);
  }
  return warded;
}
