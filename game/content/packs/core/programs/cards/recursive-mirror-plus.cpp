void mirror(const Bolts& bolts, Bolts& out, int index) {
  if (index < 0) return;
  Bolt copy = bolts[index];
  copy.power = static_cast<int>(std::ceil(bolts[index].power / 1.0));
  out.push_back(copy);
  mirror(bolts, out, index - 1);
}

Bolts recursive_mirror_plus(Bolts bolts, const Battle& battle) {
  Bolts out = bolts;
  mirror(bolts, out, static_cast<int>(bolts.size()) - 1);
  return out;
}
