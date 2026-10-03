# Prompt 2: Kurogane, the Ward Duelist (a defensive-security class)

Paste everything below the line into a fresh session, after Prompt 1 has landed. Written 2026-09-29.

---

Read AGENT.md, CLAUDE.md, WIP.md, docs/PLAN.md, docs/SHARDRUN_DESIGN.md (sections 1, 5 and 6 especially),
docs/NewEnemies.md, ADR-0012, ADR-0016, ADR-0017, ADR-0018, ADR-0021, ADR-0024 to ADR-0026, and
docs/shardrun-state.md. Then say in one short message what you are picking up, and proceed. Small slices: tests
green, lint clean, a commit after each slice, a screenshot of everything visible. Never push.

## Goal

Add the **second playable class**: **Kurogane, the Ward Duelist**, as a program-run class beside Vesper, the
Artificer. Kurogane is defence against Vesper's offence, and his theme is **defensive security**: he does not
attack systems, he protects one. His programs *branch*, validate, catch, and log. He teaches conditionals,
early return, input validation, exceptions, least privilege and defence in depth, the first things a beginner
security-minded programmer needs.

The class must be **its own playstyle in the fight, not Vesper with a new coat.** Vesper wins by building a
faster, bigger volley; Kurogane wins by reading what the foe is about to do and answering it.

Design bible entry (start here, refine it, and record what you change in the ADR): Kurogane's programs
**branch**. An `if` card takes the next card as its then-branch and the one after as its else-branch, shown as
real indented code (`if front_foe.attacks: ... else: ...`). **Exceptions are his resource**: damage his block
stops is kept as *Raised*; `except` cards catch it and turn it into counter-bolts at the attacker; `finally`
cards happen even if the program crashes. Archetypes: Counter (riposte on Raised), Fortress (block that
persists through `finally`), Guard Clauses (`return` early: short programs, fast tempo, Initiative).

## The security frame (defensive only)

Every card is a real defensive-security or defensive-programming idea, named and written as real code (Python
and JavaScript, with worked examples run in the sandbox by `scripts/validate.sh`). Kurogane's cards and relics
should be things a defender writes, for example:

- Guard clause / early return (reject bad input first), input validation and allow-lists, sanitising and
  escaping (a strike that cleans a volley), a rate limiter (a cap on bolts per turn that pays back tempo),
  least privilege (a card that spends less but can do less), a checksum or hash check (a card that verifies
  the volley is unchanged before it lands), a firewall rule set (ordered rules, first match wins: order
  matters again, in a new way), logging and audit (a card that records what happened and pays off later),
  `try` / `except` / `finally`, a timeout, a retry with backoff, defence in depth (layered blocks), a canary,
  and fail-closed versus fail-open as an actual choice.
- Foes tie in: the bestiary's bugs are attacks on code, and Kurogane's answers name them honestly (a
  malformed input, an unhandled exception, an unchecked bound, an unbounded loop, a resource leak). If a new
  foe or foe mechanic is needed to make the class shine, add it as data, in the bestiary's style, and keep the
  existing guardian pool intact.
- Keep it **defensive and educational**. No card teaches how to break into or attack a real system, and no
  payload strings or exploit code appear anywhere, in code, comments or flavour. Attackers are abstract
  "malformed input" and "bugs", drawn as the game's creatures. Each card's help text says what real defensive
  idea it is.

## What to build

1. **Class as data.** A class has its own card pool (about 20 to launch), a starter deck of 10, a starter
   relic, one unique mechanic, two or three archetypes, a character (sprite, portrait, spell palette) and the
   programming domain it teaches. The current paradigm draft becomes the class's opening: pick one of its
   archetypes, whose signature cards join the deck. Shared: neutral cards, most relics, foes, layers, the
   map. Add a `class` to the run state (with a default so old saves load, per `ShardrunSchemas`), a class
   picker before a run's draft (and per profile if Part 1 landed: remember the last class), and per-class
   run history and score.
2. **The primitives, once, as rules in `game/core/programs/`.** Branching cards (a card with child slots, and
   the code view drawing real indentation), a *Raised* counter and a retaliation hook, `finally` (runs even
   when the program times out or crashes), and early `return` (a program that ends sooner is a faster
   program: measured work, tempo and Initiative all honour it). Pure, seeded, plain-data state, all
   randomness through `Rng`. The preview is the cast: identical in both, both branches previewed, and the
   branch actually taken shown on the cast.
3. **Kurogane's cards, relics and starter relic**, with worked examples in both languages, a "+" refactor for
   each card (read as a diff at the forge), keywords, roles on every card, Japanese text for all of it.
4. **The character.** Concept art is in `Concept/newCharacters/anime-heavy/01-kurogane-ward-duelist.png`.
   Follow the sprite-skin pipeline (ADR-0008, `pipeline/sprites/README.md`): an idle and a cast, in the fight
   and the wardrobe. Small, cute, simple character sprites are the house style. A placeholder is fine at
   first; a missing picture never breaks a screen. Never run ComfyUI and Blender at once.
5. **Spell animations and sound (go all out, lavish and varied).** Kurogane's casts should look different
   from Vesper's: a parry, a riposte, a shield lattice, a ward that hardens on a caught exception. Follow
   ADR-0014 and ADR-0020 for how an effect is drawn and sounded on its beats.
6. **Balance, by the probe, not by feel.** Extend the probe or bot to play Kurogane, and report win rates per
   archetype next to Vesper's. The maintainer's read on Vesper is "feast or famine": some combinations make
   the game too easy and without them it is too hard. So for every Kurogane archetype, also report the win
   rate *without* its best combination, and flag any single card or pair that moves the win rate by more than
   twenty points. Aim for a smoother curve than Vesper's, and report what you find.
7. **Tests first** for the new rules (branching, Raised, finally, early return, both previews), for the class
   data and validators, and the fixtures re-recorded on purpose if a shared rule changed
   (`ROOTWARD_GOLDEN=update`, reviewed diff committed with the change). Vesper's runs must not change unless a
   shared rule had to; if one does, say so and show the diff.
8. **Docs.** An ADR (next number in docs/decisions/README.md) for the class system and the branching rules,
   `docs/SHARDRUN_DESIGN.md` section 5 updated to what was built, docs/PLAN.md ticked, `# LEARN:` comments
   and a learning-log entry (try/except/finally and early return are worth teaching in the log itself).

## Slice order

1. Class as data and the picker, with Vesper as the only class and nothing changed for players.
2. The primitives (branch, Raised, finally, early return) with tests, before any card uses them.
3. A first playable Kurogane: starter deck, starter relic, four or five cards, placeholder art, one archetype.
4. The pool and archetypes, art, animations, sound, Japanese.
5. The probe and the balance report; tune; final screenshots and summary.

## Verify

- `scripts/test.sh` green and `scripts/lint.sh` clean (`game/ui/archive_panel.gd:130` may still have a
  120-column error from the maintainer's uncommitted work: leave it alone unless it has since been committed).
- `scripts/validate.sh` runs every new card's worked examples in the sandbox in both languages.
- `scripts/locale.sh ja --missing` reports zero missing.
- Screenshots: the class picker, a Kurogane fight mid-branch, a Raised counter and its riposte, a `finally`
  after a timeout, the code panel with indentation, the forge diff for one of his cards, in both languages.
- Report faithfully: what changed, how it was verified, the balance numbers, and what is next.

## Ask me first (one message, only what changes what I will see)

1. The class name and flavour: keep "Ward Duelist" with the swordsman look, or lean harder into the security
   theme (a "gatekeeper" or "sentinel" feel)? (Default: keep the duelist, security in the cards.)
2. Should Kurogane share the paradigm draft, or draw from archetypes of his own (Counter, Fortress, Guard
   Clauses)? (Default: his own archetypes, three offered at the start.)
3. Does Kurogane unlock from the start, or after a first win with Vesper? (Default: available from the start.)

Otherwise use the defaults above.
