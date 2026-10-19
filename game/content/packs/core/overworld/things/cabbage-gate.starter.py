def on_use(thing, player):
    if len(thing.keys) == 4:
        return {"set": {"open": True}, "say": "The gate swings open. Walk through."}
    return {"say": "The gate stays shut until your boots know all four ways."}
