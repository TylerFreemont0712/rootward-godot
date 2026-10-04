function kWayMerge(bolts, battle) {
  // A heap stores only the head of each rising run: merging k sorted streams costs log k per bolt.
  const runs = [];
  bolts.forEach((bolt, i) => {
    if (runs.length === 0 || bolt.power < bolts[runs[runs.length - 1][runs[runs.length - 1].length - 1]].power) runs.push([]);
    runs[runs.length - 1].push(i);
  });
  const heap = [];
  const less = (a, b) => bolts[runs[a.r][a.pos]].power < bolts[runs[b.r][b.pos]].power ||
    (bolts[runs[a.r][a.pos]].power === bolts[runs[b.r][b.pos]].power && runs[a.r][a.pos] < runs[b.r][b.pos]);
  function push(item) {
    heap.push(item);
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
  runs.forEach((_, r) => push({ r, pos: 0 }));
  const result = [];
  while (heap.length > 0) {
    const item = pop();
    const bolt = bolts[runs[item.r][item.pos]];
    result.push({ ...bolt, power: bolt.power + runs.length });
    item.pos++;
    if (item.pos < runs[item.r].length) push(item);
  }
  const strongestFirst = false;
  return strongestFirst ? result.reverse() : result;
}
