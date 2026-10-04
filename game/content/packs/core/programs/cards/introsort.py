def introsort(bolts, battle):
    # Introsort: quick sort that counts how deep it recurses. Past 2 * floor(log2 n) levels the pivots have been going
    # badly (a volley already sorted does that to a first-bolt pivot), so that piece is heap-sorted instead: O(n log n)
    # whatever the order. It is what C++'s std::sort does. A bolt is the number power * 4096 + place, so every bolt
    # compares differently and equal powers keep their order.
    limit, size = 0, len(bolts)
    while size > 1:
        limit += 2
        size //= 2

    def heap_sort(keys):
        heap = list(keys)

        def sift_down(root, end):
            while 2 * root + 1 < end:
                child = 2 * root + 1
                if child + 1 < end and heap[child + 1] > heap[child]:
                    child += 1
                if heap[child] <= heap[root]:
                    break
                heap[root], heap[child] = heap[child], heap[root]
                root = child

        for start in range(len(heap) // 2 - 1, -1, -1):
            sift_down(start, len(heap))
        for end in range(len(heap) - 1, 0, -1):
            heap[0], heap[end] = heap[end], heap[0]
            sift_down(0, end)
        return heap

    def sort(keys, depth):
        if len(keys) <= 1:
            return keys
        if depth == 0:
            return heap_sort(keys)
        pivot, rest = keys[0], keys[1:]
        weaker = [key for key in rest if key < pivot]
        stronger = [key for key in rest if key > pivot]
        return sort(weaker, depth - 1) + [pivot] + sort(stronger, depth - 1)

    ordered = sort([bolt["power"] * 4096 + i for i, bolt in enumerate(bolts)], limit)
    return [bolts[key % 4096] for key in ordered]
