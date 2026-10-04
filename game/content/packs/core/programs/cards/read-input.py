def read_input(bolts, battle):
    # Input from outside: the battle is data the program reads. One bolt per living foe, as strong as its next attack.
    heard = []
    for foe in battle.get("foes", []):
        intent = foe.get("intent", {})
        heard.append({"power": max(1, intent.get("damage", 0) * intent.get("hits", 1)), "element": "none"})
    return bolts + heard
