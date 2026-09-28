function importCopy(bolts, battle) {
    for (let i = bolts.length - 1; i >= 0; i--) {
        if (!bolts[i].block) {
            const echo = {...bolts[i]};
            echo.power = Math.ceil(echo.power / 2);
            return [...bolts, echo];
        }
    }
    return bolts;
}
