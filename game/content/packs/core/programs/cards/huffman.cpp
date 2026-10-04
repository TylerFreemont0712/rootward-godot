// One entry in the heap: the bolt, its power to order by, and the order number that breaks ties.
struct Item {
  int power;
  int order;
  Bolt bolt;
};

// std::priority_queue keeps its largest item on top; with this comparison "larger" means weaker (lower power, then
// lower order number), so the weakest bolt is on top and the queue is a min-heap.
struct Stronger {
  bool operator()(const Item& a, const Item& b) const {
    return a.power > b.power || (a.power == b.power && a.order > b.order);
  }
};

Bolts huffman(Bolts bolts, const Battle& battle) {
  // Huffman's greedy step on a min-heap: pop the two weakest, push their fusion, until three are left. Each pop and
  // push is O(log n), and there are n - 3 rounds: O(n log n). The order number breaks ties, so equal bolts keep theirs.
  std::priority_queue<Item, std::vector<Item>, Stronger> heap;
  for (int i = 0; i < static_cast<int>(bolts.size()); i++) heap.push(Item{bolts[i].power, i, bolts[i]});
  int made = static_cast<int>(bolts.size());
  while (heap.size() > 3) {
    const Item a = heap.top();
    heap.pop();
    const Item b = heap.top();
    heap.pop();
    Bolt fused = b.bolt;
    fused.power = a.power + b.power + 1;
    heap.push(Item{fused.power, made, fused});
    made++;
  }
  // Popping what is left hands the bolts back weakest first.
  Bolts out;
  while (!heap.empty()) {
    out.push_back(heap.top().bolt);
    heap.pop();
  }
  return out;
}
