def volume(slider):
    slider = max(slider, 0)
    slider = min(slider, 10)
    return slider / 10
