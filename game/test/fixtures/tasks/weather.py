def weather(day):
    if day % 4 == 0:
        return "rain"
    if day % 4 == 2:
        return "cloud"
    return "sun"
