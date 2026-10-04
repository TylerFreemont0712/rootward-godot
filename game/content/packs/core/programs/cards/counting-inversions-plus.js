function countingInversionsPlus(bolts, battle) {
  // Counting inversions with merge sort. When two sorted halves merge, a right bolt that jumps ahead of the left
  // bolts still waiting is weaker than every one of them: that many stronger bolts stood before it. A left bolt taken first is stronger than the right bolts already merged, so it counts the weaker bolts after it.
  // Each bolt gains its count and the volley keeps its order. O(n log n), not the O(n^2) of comparing every pair.
  const gain = bolts.map(() => 0);
  const sort = (places) => {
    if (places.length <= 1) return places;
    const middle = Math.floor(places.length / 2);
    const left = sort(places.slice(0, middle));
    const right = sort(places.slice(middle));
    const merged = [];
    let i = 0;
    let j = 0;
    while (i < left.length || j < right.length) {
      if (j === right.length || (i < left.length && bolts[left[i]].power <= bolts[right[j]].power)) {
        gain[left[i]] += j;
        merged.push(left[i]);
        i++;
      } else {
        gain[right[j]] += left.length - i;
        merged.push(right[j]);
        j++;
      }
    }
    return merged;
  };
  sort(bolts.map((_, i) => i));
  return bolts.map((bolt, i) => ({ ...bolt, power: bolt.power + gain[i] }));
}
