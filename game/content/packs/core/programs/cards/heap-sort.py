def heap_sort(bolts, battle):
    # Heap sort: build a max-heap in place, then swap the strongest to the end and sift the new root down, again and
    # again. O(n log n) on every input, with no extra memory: it never meets quick sort's worst case.
    out = list(bolts)
    size = len(out)
    start = size // 2
    while size > 1:
        if start > 0:
            start -= 1
        else:
            size -= 1
            out[0], out[size] = out[size], out[0]
        root = start
        while 2 * root + 1 < size:
            child = 2 * root + 1
            if child + 1 < size and out[child + 1]["power"] > out[child]["power"]:
                child += 1
            if out[child]["power"] <= out[root]["power"]:
                break
            out[root], out[child] = out[child], out[root]
            root = child
    return out
