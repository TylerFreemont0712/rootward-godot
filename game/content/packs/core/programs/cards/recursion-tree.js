function recursionTree(bolts, battle) {
  // grow(depth) makes one node and calls itself twice for the level below, until the leaves (depth 2): 1 + 2 + 4
  // nodes, visited root first. Each node is a bolt, stronger near the root.
  function grow(depth) {
    const node = [{ power: 5 - depth, element: "none" }];
    if (depth === 2) return node;
    return node.concat(grow(depth + 1), grow(depth + 1));
  }
  return bolts.concat(grow(0));
}
