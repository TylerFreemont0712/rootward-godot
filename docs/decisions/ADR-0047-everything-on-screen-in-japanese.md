# ADR-0047: Everything on screen in Japanese, through one Text

Accepted 2026-10-04. Track A's last slice in `docs/PHASE2.md` (A4); extends ADR-0004 (content as JSONC, Japanese
overlays keyed by the English) and resolves PHASE2 P2-24 and P2-35.

## Context

The content was already Japanese (808 of 808 strings) and the front end carried inline pairs
(`FoundryUi.text("Adventure", "冒険")`), but the run screens, the fight's log, refusals, rooms, the Archives and the
guardian explanations were English only. The player's daughters are meant to play in Japanese, and the player asked
that "anything that can be in Japanese should be translated and properly rendered when Japanese is chosen".

## Decision

- **One overlay format for everything.** The interface's strings join the content's: `locales/ja/*.jsonc`, lists of
  `{en, to}` keyed by the English exactly (`interface-*.jsonc` for screens, `log.jsonc` for the rules' sentences).
- **`Text` registers every pair with Godot's TranslationServer** when a profile's language is set, so a Label or
  Button whose whole text is a key translates itself and re-translates when the language changes. Code views turn
  auto-translation off. Every interface string is still written `Text.t("...")`, so it can be found and counted.
- **Formats translate before they are filled**: `Text.f("%d mana", [cost])`. A Japanese translation that needs the
  values in another order numbers its slots (`{2}に{1}`).
- **The rules keep their English.** The rules write their log and refusals in English (they are saved, and compared
  against reference results). The screen translates a sentence with `Text.sentence`, which matches it against the
  overlays' formats (`%s takes %d.`) and translates the names inside it through their own entries.
- **Coverage is measured**: `scripts/locale.sh ja --missing` counts content, interface keys (found in `Text.t/f`
  calls) and the rules' sentences (found in their source), as it counted content before.
- **The voice and the glossary** are in `docs/TRANSLATION.md`: warm, simple Japanese a child can read, a reading in
  brackets for a rarer word, one term for each game word (ボルト, 番人, 遺物（いぶつ）, …).

## Consequences

- A new screen string is written `Text.t("...")` with its entry in an overlay, or it shows in English (and
  `locale.sh` lists it).
- A rules sentence edited in English stops matching its translation until the overlay is updated; the screen falls
  back to English rather than breaking.
- Comments built from summaries wrap Japanese by display width (a full-width character counts two columns).
