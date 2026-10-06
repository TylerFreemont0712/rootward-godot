def watch_rota(names, nights):
    rota = []
    for night in range(nights):
        rota.append(names[night % len(names)])
    return rota
