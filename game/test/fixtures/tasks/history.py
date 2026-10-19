def changed(old, latest):
    lines = []
    for i in range(max(len(old), len(latest))):
        if i >= len(old) or i >= len(latest):
            lines.append(i + 1)
            continue
        if old[i] != latest[i]:
            lines.append(i + 1)
    return lines
