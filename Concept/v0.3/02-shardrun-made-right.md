# Path 2: the Shardrun, made right before it grows

The "solid" half of the question. The Shardrun has more content than it has evidence. This path fixes what is known to
be wrong, tests one balance idea properly, and sets the gates a second class should wait for. About two to three
sessions.

## 1. My read of the balance

The one controlled measurement (`docs/research/balance-probe/paradigm-update/report.md`, 30 matched seeds, a bot):

| Measure | Result | Target |
|---|---|---|
| Overall wins | 12 of 30 (40%) | 40 to 60% |
| Divide & Conquer | 5 of 6 | at most 75% |
| Dynamic Programming | 4 of 6 | 30 to 75% |
| Brute Force | 3 of 6 | 30 to 75% |
| Greedy | 0 of 6 | at least 30% |
| Search & Index | 0 of 6 | at least 30% |
| Act 1 ordinary fights | 1.56 turns | 2 to 4 |

**My hypothesis: the fights are too short, and short fights decide the paradigm spread.** A fight that ends on turn one
or two pays whatever deals damage at once and starves anything that sets up. Divide & Conquer splits and recurses into
damage on the same turn; Search & Index sorts on one turn and spends the sorted volley later, and Dynamic Programming's
table and memory pay over several turns. The free seed matters here: an empty program still casts 3 bolts of 3 power,
9 damage a turn, against a 33-health wisp.

**And the bot cannot see setup.** It looks one turn ahead. A paradigm built on "sort now, spend later" will look weak to
it whatever its real strength. The v0.2 audit (`Concept/v0.2/BalancePass.md`) rates Search the most cohesive pool in
the game, which is the opposite of the bot's 0 of 6. Six seeds per paradigm is also very few: the report's own Wilson
intervals are about thirty points wide.

So I would not buff Search or Greedy, or nerf Divide & Conquer, yet. Fix the fight length first, give the bot a
setup-aware policy, add some human runs, and then see what is left.

## 2. Must fix now

These do not need a simulation; they are wrong by inspection. Most are in `docs/CARD_AUDIT_2026-10-08.md`.

**Card bugs (code in all three languages):**
- Sweep and Sweep+ copy guard bolts to every foe, so block multiplies with the foe count.
- Fractional Knapsack and its refactor land their remainder on a foe the cut already killed.
- Hash Merge and its refactor fuse a ward with an attack of the same element, turning block into damage.
- Import Collections+ and Import Bisect+ are identical to their bases, so forging them does nothing.
- Permutations bills 2^6 for 6! orders; Pairwise squares its pair count. Their billing classes are wrong.
- Bloom Filter+ can be weaker than its base.
- From the 2026-10-08 review: Memo Ward blocks about three times its peer at cost 1; Pascal Row+ doubles the total;
  Release+ grows steady damage from 2x to 4x; Recurrence+ doubles every turn.

**Relic outliers (arithmetic, not opinion):**
- Dual Core doubles every bolt at full strength with no trade-off: +100%, against the legendary Superposition's +50%.
- Compiler -O3 adds 2 to every bolt: +67% on the seed, and it stacks with focus bonuses.
- Immutable State's block bank never decays, so it grows without limit.
- Checksum's +30% is easy to trigger with a basic card, and Coupon Code saves 50 to 150 cycles a visit. Both are
  mis-tiered.

**The sandbox's own rule** (decisions already in `PLAN.md`):
- Wrap the JavaScript harness in one function, so card code cannot replace its globals.
- Bill measured work that a card tampers with at the cap. A card that turns off its own counter should not get cheaper.

**Reduced motion** for the ordinary hit sheets: `SpellAnim` ignores the setting today.

## 3. The one balance experiment

Test the hypothesis in section 1 before anything else.

1. **Variants of Act 1 fight length**, one change each: Act 1 foe health +25% and +50%; the free seed at 2 bolts instead
   of 3; and both together at the milder settings.
2. **A setup-aware bot.** Before it plays a card, the bot asks whether the rest of its deck pays for that card's effect
   on a later turn (a sort needs a sorted consumer; a table needs a reader). That is a small change to the probe's
   policy, not a new bot. Keep the old policy as a control.
3. **More seeds.** Twelve per paradigm, not six, so a paradigm's rate means something.
4. **Read three numbers per variant:** Act 1 turns, the paradigm spread, and overall wins. Pick the variant that brings
   Act 1 to two to four turns with the narrowest spread, then tune paradigms only if one is still outside 30 to 75%.

This is the Slay the Spire approach in miniature: Mega Crit balanced about 200 cards with play data, because two people
cannot call a pool that size balanced by feel. Your pool is bigger.

## 4. Your runs are data too

The bot gives rates; only a person gives reasons. Five runs from you are worth more than thirty bot runs for design
questions (not for rates). After each run, five lines:

```
Paradigm and focus:          Layer reached / result:
What killed me, or why I won:
A card I wanted and never saw, or saw and never played:
One moment that was fun:
One moment that was confusing:
```

The game already writes `history.jsonl`. Add the counts Mega Crit leaned on: which cards were offered, taken or
skipped, and which foes dealt the damage. Then your own runs feed the same tables as the bot's.

## 5. A first run that a beginner can read

Not polish: legibility. The fight screen shows slots, `main.py`, operations, O(n), the work timeline, the code, the hand
and the circle at once (`shots/status/run-fight.png`).

- On a profile's first runs, hide the work timeline and the operation counts, and show the code panel collapsed to the
  line being run. Unfold each as the run explains it.
- One sentence under each panel the first time it matters ("This is your program. Cards you play become lines here.").
- Keep the full screen for anyone who has finished a run.

## 6. Carry less

- **The deck playstyle.** Roadmap decision 9 recommends retiring it once no run of it is underway. It is a third rule
  set to keep working. I agree with retiring it, and it is your call.
- **Spellforge.** Keep it working; add nothing. It is fixture-protected and stable, which is what it should be.
- **C++ parity.** Every card in three languages makes every fix three fixes. Keep C++ for the cards that have it, and
  let new cards ship in Python and JavaScript first.
- **The C-rated cards.** The v0.2 audit lists cards with no job in their own pool (Quick Sort and Introsort in Divide &
  Conquer, the pure sorts in Brute Force). Give each a consumer or merge it into a sibling. Do not add new cards to fix
  a pool's gap until the old ones have a job.

## 7. Gates before a second class

A second class doubles the balance surface, so it should wait until the first is steady:

- Every paradigm wins 30 to 75% for the setup-aware bot, over twelve seeds each.
- No card appears in more than 60% of winning decks (the roadmap's stage 6 rule).
- Act 1 ordinary fights last two to four turns.
- No high-severity bug is left open in the audit.
- You have played at least ten runs across at least four paradigms, with notes.

## 8. Sessions

1. **The must-fix list** (one session): card bugs in three languages, relic numbers, the two harness decisions, reduced
   motion for hit sheets. Tests, `validate.sh` and the mutants census after.
2. **The experiment** (one session): the variants, the setup-aware policy, twelve seeds, the report, and the chosen
   variant applied. You play five runs that week.
3. **Legibility and carrying less** (one session, optional): the beginner layout, the run counts in `history.jsonl`, the
   deck playstyle decision, the C-rated cards.
