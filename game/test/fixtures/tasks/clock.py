def time_of_day(minute):
    if minute < 360:
        return "night"
    if minute < 720:
        return "morning"
    if minute < 1080:
        return "afternoon"
    if minute < 1260:
        return "evening"
    return "night"


def clock_text(minute):
    hours = minute // 60
    mins = minute % 60
    return str(hours) + ":" + str(mins).zfill(2)
