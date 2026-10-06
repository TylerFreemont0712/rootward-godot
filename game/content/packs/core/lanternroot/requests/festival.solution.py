from bakery import loaves_for
from lamps import lamp_oil
from post import greeting


def festival_plan(guests):
    return {
        "loaves": loaves_for(len(guests)),
        "oil": lamp_oil(len(guests)),
        "letters": [greeting(name) for name in guests],
    }
