Bolts read_input_plus(Bolts bolts, const Battle& battle) {
  // Input from outside: the battle is data the program reads. One bolt per living foe, as strong as its next attack.
  for (const Foe& foe : battle.foes) {
    Bolt heard;
    heard.power = std::max(1, foe.intent.damage * foe.intent.hits) + 2;
    bolts.push_back(heard);
  }
  return bolts;
}
