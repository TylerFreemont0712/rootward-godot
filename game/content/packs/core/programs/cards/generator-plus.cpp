struct Spring {
  // A generator: it pauses at each yield and carries on from there the next time it is asked. It never ends.
  // C++ has no yield in a plain function, so the generator is a small struct: what it must remember between one
  // next() and the following lives in its fields (this one needs none), and next() runs on to the next yield.
  Bolt next() {
    return Bolt{.power = 3, .element = "none"};
  }
};

Bolts generator_plus(Bolts bolts, const Battle& battle) {
  Spring source;
  bolts.push_back(source.next());
  bolts.push_back(source.next());
  bolts.push_back(source.next());
  return bolts;
}
