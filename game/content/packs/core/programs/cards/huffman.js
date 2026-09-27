function huffman(bolts, battle) {
  // Huffman's greedy step on a min-heap: pop the two weakest, push their fusion, until three are left. Each pop and
  // push is O(log n), and there are n - 3 rounds: O(n log n). The order number breaks ties, so equal bolts keep theirs.
  const heap = [];
  const less = (a, b) => a.power < b.power || (a.power === b.power && a.order < b.order);
  const swap = (i, j) => {
    const item = heap[i];
    heap[i] = heap[j];
    heap[j] = item;
  };
  const push = (item) => {
    heap.push(item);
    let i = heap.length - 1;
    while (i > 0 && less(heap[i], heap[Math.floor((i - 1) / 2)])) {
      swap(i, Math.floor((i - 1) / 2));
      i = Math.floor((i - 1) / 2);
    }
  };
  const pop = () => {
    const top = heap[0];
    const last = heap.pop();
    if (heap.length > 0) {
      heap[0] = last;
      let i = 0;
      while (true) {
        let least = i;
        if (2 * i + 1 < heap.length && less(heap[2 * i + 1], heap[least])) least = 2 * i + 1;
        if (2 * i + 2 < heap.length && less(heap[2 * i + 2], heap[least])) least = 2 * i + 2;
        if (least === i) break;
        swap(i, least);
        i = least;
      }
    }
    return top;
  };
  bolts.forEach((bolt, i) => push({ power: bolt.power, order: i, bolt }));
  let made = bolts.length;
  while (heap.length > 3) {
    const a = pop();
    const b = pop();
    const fused = { ...b.bolt, power: a.power + b.power + 1 };
    push({ power: fused.power, order: made, bolt: fused });
    made++;
  }
  heap.sort((x, y) => (less(x, y) ? -1 : 1));
  return heap.map((item) => item.bolt);
}
