function chainLightning(bolts, battle) {
    const count = battle.foes.length;
    if (!count) return bolts;
    const out = [];
    let target = 0;
    for (const bolt of bolts) {
        if (bolt.block) out.push({...bolt});
        else {
            const power = bolt.power + (bolt.element === "spark" ? 2 : 0);
            out.push({...bolt, power, element: "spark", foe: target % count});
            target++;
        }
    }
    return out;
}
