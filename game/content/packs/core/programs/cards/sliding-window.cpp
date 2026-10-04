Bolts sliding_window(Bolts bolts, const Battle& battle) {
  Bolts out;
  int total = 0;
  for (int i = 0; i < static_cast<int>(bolts.size()); i++) {
    total += bolts[i].power;
    if (i >= 3) total -= bolts[i - 3].power;
    Bolt copy = bolts[i];
    copy.power = total + 0;
    out.push_back(copy);
  }
  return out;
}
