# Path 3: a second class, Kurogane the Ward Duelist

The brief already exists and is good: `docs/prompt2.md` (the full build), with the design-bible entry in
`docs/SHARDRUN_DESIGN.md` section 5.2. This page does not repeat it. It says when to build him, what to prove first,
what to cut, and what the alternatives are.

## 1. Why Kurogane is still the right second class

- **He plays differently.** Vesper wins by building a faster, bigger volley. Kurogane wins by reading what the foe is
  about to do and answering it. A second class that plays like the first is not worth its cost.
- **He teaches the beginner's ideas.** `if`, `else`, early `return`, `try`, `except` and `finally` are the first ideas
  of programming, and the Academy's chapter 1 teaches the same ones. An Academy stamp can then explain his cards (path 1,
  section 8). Vesper teaches algorithms, which come later.
- **The foes reuse his rules.** A Raised counter and a retaliation hook are rule primitives the bestiary can use too.
- **The defensive-security theme is honest and useful**: validation, allow-lists, least privilege, defence in depth,
  fail-closed. All defensive, as the brief requires.

## 2. When: after path 2's gates

A second class doubles the balance surface. Vesper is not yet inside the targets (paradigms from 0% to 83% wins in the
bot, Act 1 fights too short). Adding Kurogane now means tuning two classes against a run whose pacing is about to
change. Wait for path 2's gates (`02-shardrun-made-right.md`, section 7), which should take two to three sessions.

The one part worth doing earlier is the brief's slice 1, **classes as data with a picker**, with Vesper the only class
and nothing changed for players. It is pure plumbing, it removes "Artificer" as a hard-coded assumption, and it costs
little.

## 3. Prove branching is fun before building 150 files

The riskiest idea is the branch card: an `if` card that takes the next card as its then-branch and the one after as
its else-branch. It changes the five-slot program into a small tree, the code panel into indented code, and the preview
into "both branches, and which was taken". Before engine work:

1. **A one-file prototype.** `Concept/v0.2/Shards-Relics/Concepts/prototype_cards.py` already sketches card bodies in
   the program-card shape, but has no fight to play them in. Add a small one beside it: a foe with health and a
   telegraphed intent, your health and block, a hand of eight Kurogane cards with branch, Raised and `except`, and play
   ten fights by hand in the terminal. If choosing branches against a telegraphed intent is not interesting there, it
   will not be interesting with art.
2. **What the prototype must answer.** Is a branch a real choice, or does one branch always win? Does Raised create
   turns where blocking is the right attack? Does early `return` make short programs worth playing, or is it a trap?

That is one evening of work, and it decides whether the class is worth two weeks.

## 4. What to cut from the first playable

The brief's slice 3 is right to start small. I would cut further:

- **One archetype, Counter**, not three. Fortress and Guard Clauses come after Counter is fun.
- **Twenty cards in Python and JavaScript.** C++ when the class is settled (the README's decision 3).
- **A placeholder sprite and one cast effect** (the parry). Spell animations "lavish and varied" come in the class's
  last slice, under path 4's budget, not first.
- **Available from the start**, as the brief's default.

## 5. What his fight should feel like

Some sketches, to test in the prototype, not a card list:

- `if foe.attacks:` with a guard in the then-branch and a strike in the else-branch: the foe's intent is the input,
  which the game already telegraphs. Reading the intent becomes writing the condition.
- **Raised as a resource**: block that stops damage stores it; `except Raised:` spends it as a riposte at the attacker.
  Turns where you invite the attack become good turns.
- **Guard clauses**: `return` early when a condition holds. The program ends sooner, so it is faster: measured work,
  tempo and Initiative already reward that, which is a satisfying link to Vesper's rules.
- **`finally`** runs even when the program times out. A safety net that teaches exactly what `finally` is for.
- **First match wins**: a firewall card with ordered rules, so card order matters again, in a new way.

## 6. The alternatives

| Class | For | Against | Verdict |
|---|---|---|---|
| Kurogane, Ward Duelist | Most different play; beginner ideas; pairs with the Academy | Branch cards are new engine work | **Second** |
| Sai, Storm Cartographer (graphs) | The biggest spell show (chain lightning across a crowd) | Wants multi-foe encounters the run does not have much of yet; graphs are an advanced topic | Third |
| Pip and Acorn, a gentle class | For the daughters; reuses the Academy's Acorn and errand commands | A gentler Artificer, not a new playstyle | **After path 1's youngest track**, if the daughters take to it |
| Oren, Ember Alchemist (async) | Delayed effects are a strong mechanic | Async is hard to teach first | Later |

If the daughters are the priority this season, Pip and Acorn could come before Kurogane: it is mostly a gentler set of
existing rules plus the Academy's errands, and it needs no new primitive.

## 7. Sessions

- Classes as data and the picker: about half a session, any time.
- The prototype: one evening, before anything else of his.
- The minimum playable (primitives, starter deck, starter relic, Counter's cards in two languages, a placeholder): two
  to three sessions, after path 2's gates.
- Fortress and Guard Clauses, art, the parry and riposte effects, Japanese, C++: two to three more.
- The balance report: the brief's "with and without the best combination" rule is right; keep it.
