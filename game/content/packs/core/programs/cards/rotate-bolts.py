def rotate_bolts(bolts, battle):
    # deque.rotate(k) turns the whole ring k places to the right: the last k items come to the front.
    from collections import deque
    ring = deque(dict(bolt) for bolt in bolts)
    ring.rotate(1)
    return list(ring)
