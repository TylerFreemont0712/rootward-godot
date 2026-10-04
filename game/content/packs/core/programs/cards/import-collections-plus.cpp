Bolts import_collections_plus(Bolts bolts, const Battle& battle) {
  // groups keeps the first-seen order; where maps each key to its place in groups.
  Bolts groups;
  std::map<std::tuple<std::string, int, bool>, size_t> where;
  for (const Bolt& bolt : bolts) {
    const auto key = std::make_tuple(bolt.element, bolt.foe.value_or(0), bolt.block);
    if (!where.count(key)) {
      where[key] = groups.size();
      groups.push_back(bolt);
    } else {
      groups[where[key]].power += bolt.power;
    }
  }
  return groups;
}
