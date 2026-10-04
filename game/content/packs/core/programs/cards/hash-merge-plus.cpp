Bolts hash_merge_plus(Bolts bolts, const Battle& battle) {
  // One pass with a hash map (element -> bolt): same-element bolts fuse, +2 for each bolt swallowed. Everything
  // after this card has fewer bolts to work through.
  // An unordered_map has no order of its own, so the fused bolts live in a vector in the order their element first
  // came, and the map points each element at its bolt's place there.
  Bolts merged;
  std::unordered_map<std::string, size_t> groups;
  for (const Bolt& bolt : bolts) {
    const std::string& key = bolt.element;
    auto found = groups.find(key);
    if (found != groups.end()) {
      Bolt& group = merged[found->second];
      group.power = group.power + bolt.power + 2;
    } else {
      groups[key] = merged.size();
      merged.push_back(bolt);
    }
  }
  return merged;
}
