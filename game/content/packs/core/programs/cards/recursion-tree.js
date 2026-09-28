function recursionTree(bolts, battle) {
  // grow(depth) makes one node and calls itself twice for the level below, until the leaves (depth 2, or 3 with
  // `import math`): 1 + 2 + 4 nodes, visited root first. Each node is a bolt, stronger near the root.
  const leaves = (battle.imports || []).includes("math") ? 3 : 2;
  function grow(depth) {
    const node = [{ power: 5 - depth, element: "none" }];
    if (depth === leaves) return node;
    return node.concat(grow(depth + 1), grow(depth + 1));
  }
  return bolts.concat(grow(0));
}
