# ADR-0011: Verifier code lab and spell motion

- Status: accepted
- Date: 2026-09-25
- Related: ADR-0002, ADR-0008, ADR-0010

## Context

The Verifier's count/role contract reused the Artificer's cards and battle too closely. The player wanted a genuine
programming course and spell effects that move and transform instead of static pictures travelling toward foes. A
cast also changed the arena's framing when the code work surface changed height or the stage scaled for impact.

## Decision

- Verifier becomes a separate journey and course screen. Twelve ordered lessons in three chapters teach data flow,
  state, and algorithms. Players predict an intermediate value and type exact stdout. They may reveal an incremental
  trace tape. The lesson code runs in the existing JavaScript WASI sandbox, and actual stdout grades the final answer.
  Correct outputs unlock the next lesson. Saved stars reward accurate first predictions and fewer hints.
- Shardrun and Spellforge remain Artificer paths with Python and JavaScript, card/spellbook construction, and the three
  existing battle looks. The old Verifier deck, contract rule, and combat bonuses are removed.
- Spell flights gain a drawn energy ribbon that follows the actual arc, with fire curls, frost crystals, spark forks,
  or arcane motes. Bursts and strikes gain expanding element-specific vector motifs over the existing animated sprite
  sheets. A heavy impact uses a small shake instead of scaling the entire arena. The code work surface keeps its
  measured height while code is shown, so the stage does not resize between code and spell playback.

## Consequences

Verifier progress is saved separately from combat runs. It requires the JavaScript sandbox. New lessons can be added
as content, while new teaching interactions can be built on the course screen without changing combat rules.
