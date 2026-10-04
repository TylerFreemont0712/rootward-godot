def stock_trader(bolts, battle):
    # Buy at every dip, sell at every peak: the profit is the sum of the rises from one bolt to the next. One pass.
    # The profit becomes a new bolt at the end of the volley.
    profit = 0
    for i in range(1, len(bolts)):
        if bolts[i]["power"] > bolts[i - 1]["power"]:
            profit += bolts[i]["power"] - bolts[i - 1]["power"]
    result = [dict(bolt) for bolt in bolts]
    if profit > 0:
        element = "none"
        result.append({"power": profit, "element": element})
    return result
