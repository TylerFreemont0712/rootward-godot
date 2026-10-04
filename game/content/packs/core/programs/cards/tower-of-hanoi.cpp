struct HanoiMove {
  int disk;
  int source;
  int target;
};

void hanoi(int n, int source, int target, int spare, std::vector<HanoiMove>& moves) {
  if (n == 0) return;
  hanoi(n - 1, source, spare, target, moves);
  moves.push_back(HanoiMove{n, source, target});
  hanoi(n - 1, spare, target, source, moves);
}

Bolts tower_of_hanoi(Bolts bolts, const Battle& battle) {
  // Tower of Hanoi: to move n disks from one peg to another, move the top n - 1 out of the way onto the spare peg,
  // move the biggest disk, then move the n - 1 back on top of it. T(n) = 2 T(n - 1) + 1 = 2^n - 1 moves.
  // Every move becomes a bolt of its disk's size + 1 (disk 1 is the smallest): the ruler sequence 2, 3, 2, 4 ...
  std::vector<HanoiMove> moves;
  hanoi(4, 0, 2, 1, moves);
  for (const HanoiMove& move : moves) {
    Bolt bolt;
    bolt.power = move.disk + 1;
    bolts.push_back(bolt);
  }
  return bolts;
}
