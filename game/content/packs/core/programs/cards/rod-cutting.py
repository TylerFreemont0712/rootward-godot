def rod_cutting(bolts, battle):
    # Rod cutting: best[n] is the most a rod of length n can be worth when cut into pieces, trying every first piece.
    # A piece is worth its price (a 3 is worth 4, a 5 worth 7, a 7 worth 10); any other length is worth itself.
    # The strongest bolt is the rod. Its pieces become bolts, each as strong as that piece is worth.
    price = {3: 4, 5: 7, 7: 10}
    live = [i for i, bolt in enumerate(bolts) if bolt["power"] > 0 and not bolt.get("block")]
    if not live:
        return list(bolts)
    rod = max(live, key=lambda i: bolts[i]["power"])
    length = min(bolts[rod]["power"], 30)
    best, cut = [0] * (length + 1), [0] * (length + 1)
    for n in range(1, length + 1):
        best[n] = -1
        for piece in range(n, 0, -1):
            value = price.get(piece, piece) + best[n - piece]
            if value > best[n]:
                best[n] = value
                cut[n] = piece
    pieces, n = [], length
    while n > 0:
        pieces.append(cut[n])
        n -= cut[n]
    result = []
    for k, bolt in enumerate(bolts):
        if k != rod:
            result.append(dict(bolt))
            continue
        for piece in pieces:
            result.append(dict(bolt, power=price.get(piece, piece)))
        if bolt["power"] > length:
            result.append(dict(bolt, power=bolt["power"] - length))
    return result
