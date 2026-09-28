function importCollectionsPlus(bolts, battle) {
    const groups = new Map();
    for (const bolt of bolts) {
        const key = JSON.stringify([bolt.element, bolt.foe ?? 0, bolt.block ?? false]);
        if (!groups.has(key)) groups.set(key, {...bolt});
        else groups.get(key).power += bolt.power;
    }
    return [...groups.values()];
}
