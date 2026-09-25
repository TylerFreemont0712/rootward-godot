def fib_memo(bolts, battle):
    # Memoised bottom up: build the table fib[0..16] once, each entry the sum of the two before it, then look it up
    # for each bolt. The same answer as the naive recursion, in O(n).
    fib = [0, 1]
    while len(fib) < 17:
        fib.append(fib[-1] + fib[-2])
    return [dict(bolt, power=bolt["power"] + fib[min(i, 16)]) for i, bolt in enumerate(bolts)]
