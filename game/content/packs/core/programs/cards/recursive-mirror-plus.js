function recursiveMirrorPlus(bolts, battle) {
    const out = [...bolts];
    function mirror(index) {
        if (index < 0) return;
        out.push({...bolts[index], power: Math.ceil(bolts[index].power / 1)});
        mirror(index - 1);
    }
    mirror(bolts.length - 1);
    return out;
}
