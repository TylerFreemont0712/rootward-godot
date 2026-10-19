# v0.4: the game you build from inside the game

Written 2026-10-15. The player asked for many more programming tasks, each one building a part of the game itself:
the menu key, the menu, options, a volume slider, a soundtrack picker and an inventory. They also asked for a small map,
a richer quest tracker and a simpler character select. They wanted it to feel like "creating the game from in the game",
and said to go a little overboard.

| File | What |
|---|---|
| [01-the-game-you-build.md](01-the-game-you-build.md) | The design: Parts, the chapter's nine new quests, every part's function, stages, cases and judges, the menus, the HUD (tracker, minimap, full map), day and night, art, the engine, tests and acceptance, and the decisions made for the player |
| [02-task-format.md](02-task-format.md) | The exact task format (files, stages, Builder blocks, reasons, judges), the harness protocol, and the engine's interfaces the workers build against |
| [03-story.md](03-story.md) | Chapter 2, "The Workshop Inside": the beats, the givers and the dialogue outline (written by the story worker) |
| [04-handoff.md](04-handoff.md) | Who builds what: the waves, the workers' models, file ownership, and what done means |
| [05-chapter-3.md](05-chapter-3.md) | Chapter 3, "the town keeps time": eleven quests and tasks, the engine additions, the story beats, and section 6 "As built" |
| [06-japanese.md](06-japanese.md) | The town completely in Japanese: what "completely" means, the voice, the glossary and the work plan |
| [07-handoff.md](07-handoff.md) | Handoff of 2026-10-16: where chapter 3 and the Japanese stand, what is left in order, and the open choices |

## Status

- 2026-10-15: spec written; building.
- 2026-10-16: built (see `01-the-game-you-build.md` section 18 for where it differs). Ten parts, nine new quests, the
  HUD, the menus and the art; checked by a Haiku checkpoint and an Opus final review.
- 2026-10-16: chapter 3 and the Japanese built and wired (ADR-0069, ADR-0070). The checks left are in `07-handoff.md`.
