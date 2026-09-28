function runLength(bolts, battle) {
    const out = [];
    for (const bolt of bolts) {
        const last = out[out.length - 1];
        const same = last && last.element === bolt.element &&
            (last.foe ?? 0) === (bolt.foe ?? 0) && (last.block ?? false) === (bolt.block ?? false);
        if (same) last.power += bolt.power + 0;
        else out.push({...bolt});
    }
    return out;
}
