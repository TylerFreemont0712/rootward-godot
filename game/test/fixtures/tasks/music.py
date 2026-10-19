def titles(tracks):
    names = []
    for track in tracks:
        names.append(track["title"])
    return names


def next_track(index, count):
    return (index + 1) % count
