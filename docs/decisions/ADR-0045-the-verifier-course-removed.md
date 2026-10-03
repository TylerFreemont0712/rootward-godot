# ADR-0045: The Verifier course is removed; the Academy starts fresh

Accepted 2026-10-04. Supersedes the Verifier parts of ADR-0010 and ADR-0011, and the plan in
`docs/ACADEMY_DESIGN.md` for the Academy to absorb it. Track A of `docs/PHASE2.md`.

## Context

The Verifier was a twelve-lesson code-reading course in JavaScript: trace a value, then predict a program's exact
output, graded by running it in the sandbox (ADR-0011). After the Kernel Foundry front end (ADR-0032) it was reached
only through the Academy's "in preparation" panel, as "Open existing Verifier course". It kept its own look (plain
dark panels, not the station's), one global save (`user://verifier-course.json`, shared by every profile and outside
`ROOTWARD_SAVES`) and no test suite. The player: it "isn't cutting it right now … doesn't really fit the Academy
piece, so honestly I'd like for it to be removed entirely to make way for other features."

## Decision

- The Verifier is removed from the game: its scene and trace board (`scenes/verifier/`), its course rules
  (`core/verifier_course.gd`), its lessons (`content/packs/core/verifier/`), `Game.VERIFIER`, the `"verifier"`
  playstyle, and the Academy panel's button. The Academy shows its "in preparation" panel alone until the Academy's
  foundation (PHASE2 track D) is built.
- The Academy is built fresh rather than absorbing the Verifier. Predict and Trace exercises are made inside the
  Academy's own lesson screen, in the station's look, saved per profile. The removed code stays in git history (the
  commit before this ADR) if any part of it helps.
- A settings file saved while the Verifier was the chosen playstyle loads as the Shardrun (`Settings.load_file`).
- A player's old `verifier-course.json` is left where it is and no longer read: it is their data, and nothing in the
  game deletes it.

## Consequences

- The Academy has nothing playable until track D lands; the player chose that over keeping the old course meanwhile.
- Two open bugs close with it: the course's progress shared between players (PHASE2 P2-18) and its screen standing
  apart from the station's look (P2-33).
- ADR-0010 and ADR-0011 stay as written, as the history of why the Verifier was built.
