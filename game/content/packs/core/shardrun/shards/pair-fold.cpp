Bolts pair_fold(Bolts bolts, const Battle& battle) {
  Bolts out;
  for (std::size_t i = 0; i < bolts.size(); i += 2) {
    const Bolt& a = bolts[i];
    // Compared as optionals, as the JavaScript compares: two bolts without a ward match, as do two with the same one.
    if (i + 1 < bolts.size() && a.ward == bolts[i + 1].ward) {
      const Bolt& b = bolts[i + 1];
      const double power = std::max(1.0, a.power);
      Bolt folded = a;
      folded.power = power;
      folded.mult = (a.power * a.mult.value_or(1) + b.power * b.mult.value_or(1)) / power;
      out.push_back(folded);
    } else {
      out.push_back(a);
      if (i + 1 < bolts.size()) out.push_back(bolts[i + 1]);
    }
  }
  return out;
}
