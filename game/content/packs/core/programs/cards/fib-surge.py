def fib_surge(bolts, battle):
    # Naive recursion: fib(k) calls fib(k-1) and fib(k-2), which call theirs, recomputing the same values again and
    # again: about 2^k calls. Each bolt i gains fib(i), capped at fib(16).
    def fib(k):
        return k if k < 2 else fib(k - 1) + fib(k - 2)
    return [dict(bolt, power=bolt["power"] + fib(min(i, 16))) for i, bolt in enumerate(bolts)]
