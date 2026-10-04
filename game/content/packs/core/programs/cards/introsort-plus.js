function introsortPlus(bolts, battle) {
  // Introsort: quick sort that counts how deep it recurses. Past 2 * floor(log2 n) levels the pivots have been going
  // badly (a volley already sorted does that to a first-bolt pivot), so that piece is heap-sorted instead: O(n log n)
  // whatever the order. It is what C++'s std::sort does. A bolt is the number power * 4096 + place, so every bolt
  // compares differently and equal powers keep their order.
  let limit = 0;
  for (let size = bolts.length; size > 1; size = Math.floor(size / 2)) limit += 2;
  const heapSort = (keys) => {
    const heap = keys.slice();
    const siftDown = (start, end) => {
      let root = start;
      while (2 * root + 1 < end) {
        let child = 2 * root + 1;
        if (child + 1 < end && heap[child + 1] > heap[child]) child++;
        if (heap[child] <= heap[root]) break;
        [heap[root], heap[child]] = [heap[child], heap[root]];
        root = child;
      }
    };
    for (let start = Math.floor(heap.length / 2) - 1; start >= 0; start--) siftDown(start, heap.length);
    for (let end = heap.length - 1; end > 0; end--) {
      [heap[0], heap[end]] = [heap[end], heap[0]];
      siftDown(0, end);
    }
    return heap;
  };
  const sort = (keys, depth) => {
    if (keys.length <= 1) return keys;
    if (depth === 0) return heapSort(keys);
    const pivot = keys[0];
    const rest = keys.slice(1);
    const weaker = rest.filter((key) => key < pivot);
    const stronger = rest.filter((key) => key > pivot);
    return sort(weaker, depth - 1).concat([pivot], sort(stronger, depth - 1));
  };
  const ordered = sort(bolts.map((bolt, i) => bolt.power * 4096 + i), limit);
  return ordered.map((key) => bolts[((key % 4096) + 4096) % 4096]);
}
