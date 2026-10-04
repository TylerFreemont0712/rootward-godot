Bolts grow(int depth, int leaves) {
  Bolts node = {Bolt{.power = 5 - depth, .element = "none"}};
  if (depth == leaves) return node;
  Bolts left = grow(depth + 1, leaves);
  Bolts right = grow(depth + 1, leaves);
  node.insert(node.end(), left.begin(), left.end());
  node.insert(node.end(), right.begin(), right.end());
  return node;
}

Bolts recursion_tree_plus(Bolts bolts, const Battle& battle) {
  // grow(depth) makes one node and calls itself twice for the level below, until the leaves (depth 3, or 4 with
  // `import math`): 1 + 2 + 4 nodes, visited root first. Each node is a bolt, stronger near the root.
  const auto& imports = battle.imports;
  const int leaves = std::find(imports.begin(), imports.end(), "math") != imports.end() ? 4 : 3;
  Bolts tree = grow(0, leaves);
  bolts.insert(bolts.end(), tree.begin(), tree.end());
  return bolts;
}
