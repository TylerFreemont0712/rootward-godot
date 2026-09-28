function stablePartition(bolts, battle) {
    const front = [], rest = [];
    for (const bolt of bolts) {
        const group = bolt.power >= 6 && !bolt.block ? front : rest;
        group.push({...bolt});
    }
    return [...front, ...rest];
}
