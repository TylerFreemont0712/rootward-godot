Bolts zip_ward(Bolts bolts, const Battle& battle) {
  Bolts out;
  for (const Bolt& bolt : bolts) {
    if (bolt.block) out.push_back(bolt);
    else {
      Bolt strike = bolt;
      strike.power = static_cast<int>(std::ceil(double(bolt.power) / 2));
      out.push_back(strike);
      Bolt guard = bolt;
      guard.power = static_cast<int>(std::floor(double(bolt.power) / 2)) + 0;
      guard.block = true;
      out.push_back(guard);
    }
  }
  return out;
}
