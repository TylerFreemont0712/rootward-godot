Bolts tail_call(Bolts bolts, const Battle& battle) {
  // A tail call is the last thing a function does, so its frame can be reused: the callee costs no stack and no work.
  return bolts;
}
