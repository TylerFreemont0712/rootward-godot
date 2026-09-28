def recursion_tree_plus(bolts, battle):
    # grow(depth) makes one node and calls itself twice for the level below, until the leaves (depth 3, or 4 with
    # `import math`): 1 + 2 + 4 nodes, visited root first. Each node is a bolt, stronger near the root.
    leaves = 4 if "math" in battle.get("imports", []) else 3

    def grow(depth):
        node = [{"power": 5 - depth, "element": "none"}]
        if depth == leaves:
            return node
        return node + grow(depth + 1) + grow(depth + 1)

    return bolts + grow(0)
