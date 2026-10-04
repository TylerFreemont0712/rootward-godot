Bolts flash_freeze(Bolts bolts, const Battle& battle) {
  Bolts out;
  for (const Bolt& b : bolts) {
    if (b.element == "fire") {
      Bolt frozen = b;
      frozen.element = "frost";
      frozen.ward = true;
      frozen.mult = b.mult.value_or(1) * 3;
      out.push_back(frozen);
    } else {
      out.push_back(b);
    }
  }
  return out;
}
