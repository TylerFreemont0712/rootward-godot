function slidingWindowPlus(bolts, battle) {
    const out = [];
    let total = 0;
    for (let i = 0; i < bolts.length; i++) {
        total += bolts[i].power;
        if (i >= 3) total -= bolts[i - 3].power;
        out.push({...bolts[i], power: total + 2});
    }
    return out;
}
