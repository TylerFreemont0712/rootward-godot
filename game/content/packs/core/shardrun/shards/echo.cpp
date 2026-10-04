Bolts echo(Bolts bolts, const Battle& battle) {
  Bolts twice = bolts;
  for (const Bolt& bolt : bolts) twice.push_back(bolt);
  return twice;
}
