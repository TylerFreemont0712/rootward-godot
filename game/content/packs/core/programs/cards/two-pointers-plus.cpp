Bolts two_pointers_plus(Bolts bolts, const Battle& battle) {
  // Two indexes, one from each end, walking toward each other: every step fuses the pair they point at. O(n).
  Bolts out;
  int i = 0;
  int j = static_cast<int>(bolts.size()) - 1;
  while (i < j) {
    Bolt fused = bolts[j];
    fused.power = bolts[i].power + bolts[j].power + 1;
    out.push_back(fused);
    i++;
    j--;
  }
  if (i == j) out.push_back(bolts[i]);
  return out;
}
