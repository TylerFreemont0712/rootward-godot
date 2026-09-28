function zipWardPlus(bolts, battle) {
    const out = [];
    for (const bolt of bolts) {
        if (bolt.block) out.push({...bolt});
        else {
            out.push({...bolt, power: Math.ceil(bolt.power / 2)});
            out.push({...bolt, power: Math.floor(bolt.power / 2) + 2, block: true});
        }
    }
    return out;
}
