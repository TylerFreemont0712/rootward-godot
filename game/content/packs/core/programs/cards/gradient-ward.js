function gradientWard(bolts, battle) {
  // Compare attacking bolts in their existing order. Each strict rise pays one point from its higher bolt; equal
  // neighbours do not. Existing wards and stashed bolts do not take part in the sequence.
  const result = bolts.map((bolt) => ({ ...bolt }));
  const ids = result.map((_, i) => i);
  const wasSorted = bolts.every((bolt, i) => i === 0 || bolts[i - 1].power <= bolt.power);
  const attacks = [];
  for (let i = 0; i < result.length; i++) {
    if (!result[i].block && !result[i].stash) attacks.push(i);
  }
  if (attacks.length === 0) return result;

  const sources = [];
  for (let i = 1; i < attacks.length; i++) {
    if (result[attacks[i]].power > result[attacks[i - 1]].power) sources.push(attacks[i]);
  }
  if (sources.length === 0) {
    let weakest = attacks[0];
    for (const i of attacks.slice(1)) {
      if (result[i].power < result[weakest].power) weakest = i;
    }
    sources.push(weakest);
  }

  const wards = [];
  let gained = 0;
  for (const sourceId of sources) {
    if (gained >= 6) break;
    let i = ids.indexOf(sourceId);
    const power = result[i].power;
    if (power <= 0) continue;
    if (power === 1) {
      // A one-power source can become a ward without adding another bolt.
      result[i].block = true;
      gained++;
      continue;
    }

    if (result.length + wards.length < 128) {
      result[i].power--;
      if (wasSorted) {
        while (i > 0 && result[i - 1].power > result[i].power) {
          [result[i - 1], result[i]] = [result[i], result[i - 1]];
          [ids[i - 1], ids[i]] = [ids[i], ids[i - 1]];
          i--;
        }
      }
      wards.push({ power: 1, element: result[i].element, block: true });
      gained++;
      continue;
    }

    // At the bolt limit, add the point to an existing ward. Never siphon if there is nowhere safe to put it.
    const existingId = ids[result.findIndex((bolt) => bolt.block && !bolt.stash && bolt.power < 9999)];
    if (existingId !== undefined) {
      result[i].power--;
      if (wasSorted) {
        while (i > 0 && result[i - 1].power > result[i].power) {
          [result[i - 1], result[i]] = [result[i], result[i - 1]];
          [ids[i - 1], ids[i]] = [ids[i], ids[i - 1]];
          i--;
        }
      }
      let existingIndex = ids.indexOf(existingId);
      result[existingIndex].power++;
      if (wasSorted) {
        while (existingIndex + 1 < result.length && result[existingIndex].power > result[existingIndex + 1].power) {
          [result[existingIndex], result[existingIndex + 1]] = [result[existingIndex + 1], result[existingIndex]];
          [ids[existingIndex], ids[existingIndex + 1]] = [ids[existingIndex + 1], ids[existingIndex]];
          existingIndex++;
        }
      }
      gained++;
    }
  }

  if (wards.length > 0) {
    // New wards carry 1 power. Place them before the first stronger bolt so a weakest-first volley stays ordered.
    const insertion = result.findIndex((bolt) => bolt.power > 1);
    result.splice(insertion < 0 ? result.length : insertion, 0, ...wards);
  }
  return result;
}
