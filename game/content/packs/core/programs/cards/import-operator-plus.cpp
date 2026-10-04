Bolts import_operator_plus(Bolts bolts, const Battle& battle) {
  for (Bolt& bolt : bolts) bolt.power = std::plus<int>()(bolt.power, bolt.block ? 0 : 1);
  return bolts;
}
