import heapq


def huffman(bolts, battle):
    # Huffman's greedy step on a min-heap: pop the two weakest, push their fusion, until three are left. Each pop and
    # push is O(log n), and there are n - 3 rounds: O(n log n). The index breaks ties, so equal bolts keep their order.
    heap = [(bolt["power"], i, bolt) for i, bolt in enumerate(bolts)]
    heapq.heapify(heap)
    made = len(heap)
    while len(heap) > 3:
        a_power, _, a = heapq.heappop(heap)
        b_power, _, b = heapq.heappop(heap)
        fused = dict(b, power=a_power + b_power + 1)
        heapq.heappush(heap, (fused["power"], made, fused))
        made += 1
    return [bolt for _, _, bolt in sorted(heap)]
