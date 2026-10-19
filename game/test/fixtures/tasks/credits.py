def credits(maker, parts):
    lines = ["The Makers"]
    lines.append("Made by " + maker)
    for part in parts:
        lines.append("Built: " + part)
    return lines
