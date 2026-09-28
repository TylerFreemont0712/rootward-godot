function importOperatorPlus(bolts, battle) {
    return bolts.map(bolt => ({...bolt, power: bolt.power + (bolt.block ? 0 : 1)}));
}
