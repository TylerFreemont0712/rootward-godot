function towerOfHanoiPlus(bolts, battle) {
  // Tower of Hanoi: to move n disks from one peg to another, move the top n - 1 out of the way onto the spare peg,
  // move the biggest disk, then move the n - 1 back on top of it. T(n) = 2 T(n - 1) + 1 = 2^n - 1 moves.
  // Every move becomes a bolt of its disk's size + 1 (disk 1 is the smallest): the ruler sequence 2, 3, 2, 4 ...
  const moves = [];
  const hanoi = (n, source, target, spare) => {
    if (n === 0) return;
    hanoi(n - 1, source, spare, target);
    moves.push([n, source, target]);
    hanoi(n - 1, spare, target, source);
  };
  hanoi(5, 0, 2, 1);
  return bolts.concat(moves.map(([disk]) => ({ power: disk + 1, element: "none" })));
}
