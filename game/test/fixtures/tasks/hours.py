def where(person, hour):
    if hour < 7 or hour >= 22:
        return "home"
    if hour < 18:
        return "work"
    return "inn"
