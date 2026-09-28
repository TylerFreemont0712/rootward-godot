function stablePartitionPlus(bolts, battle) {
    const front = [], rest = [];
    for (const bolt of bolts) {
        const group = bolt.power >= 4 && !bolt.block ? front : rest;
        group.push({...bolt});
    }
    return [...front, ...rest];
}
