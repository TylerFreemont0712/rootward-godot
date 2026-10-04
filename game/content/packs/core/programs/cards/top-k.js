function topK(bolts, battle) {
  // Keep only k candidates in a min-heap; its root is the weakest survivor.
  const heap = [];
  const less = (a, b) => bolts[a].power < bolts[b].power || (bolts[a].power === bolts[b].power && a > b);
  function push(index) {
    heap.push(index);
    let i = heap.length - 1;
    while (i > 0) {
      const parent = Math.floor((i - 1) / 2);
      if (!less(heap[i], heap[parent])) break;
      [heap[i], heap[parent]] = [heap[parent], heap[i]];
      i = parent;
    }
  }
  function pop() {
    const root = heap[0];
    const last = heap.pop();
    if (heap.length > 0) {
      heap[0] = last;
      let i = 0;
      while (i * 2 + 1 < heap.length) {
        let child = i * 2 + 1;
        if (child + 1 < heap.length && less(heap[child + 1], heap[child])) child++;
        if (!less(heap[child], heap[i])) break;
        [heap[i], heap[child]] = [heap[child], heap[i]];
        i = child;
      }
    }
    return root;
  }
  let discarded = 0;
  for (let i = 0; i < bolts.length; i++) {
    push(i);
    if (heap.length > 4) discarded += bolts[pop()].power;
  }
  const result = [];
  while (heap.length > 0) result.push({ ...bolts[pop()] });
  if (result.length > 0) result[0].power += discarded;
  return result;
}
