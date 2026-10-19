# ADR-0075: complete Japanese reading editions

Accepted 2026-10-17. Extends ADR-0047 and ADR-0070. Supersedes the small kana-to-kanji vocabulary switch described
in the original v0.4 reading preference.

## Context

The player wants Kanji mode to read as normal Japanese for an adult. Replacing a few common words leaves most of
the dialogue, lessons and menus in children's orthography. Kana also cannot identify a word's meaning reliably:
買った and 勝った require context. Reading preferences should be offered during character creation and remain
available from the menu.

## Decision

- Japanese overlay entries keep their existing `to` and gain a complete `kanji` translation. All 5,056 current
  entries across 40 files have both editions. Adult copy uses ordinary kanji, conventional technical terms and
  normal Japanese spacing. Characters retain their individual voices; Kanji does not force everyone into formal
  speech or add parenthetical readings to familiar words.
- `ContentLocale` returns the editions separately. `Text` selects the full English-keyed template before filling
  placeholders. Adult mode has no runtime kana-to-kanji substitutions. Inline Japanese can use an exact, unambiguous
  source mapping; unknown or ambiguous text stays as written.
- Both editions derive from immutable catalog text and are cached separately. Godot's automatic translation,
  formatted rules messages, catalog prose, cosmetics, Pip's Trial and the Foundry share the selected edition.
  Existing curated town hiragana readings remain in use. Code, identifiers and inserted values keep their spelling.
- Japanese character creation includes **ひらがな / 漢字**, with a live preview of the whole creator. Switching
  retains the typed name, model and programming style. The choice is staged until completion and saved in the
  profile; cancellation restores the previous mode. English creation retains its saved preference without showing
  the Japanese row.
- Settings → Fonts & text starts with the same reading selector. The town's Options → More settings reaches this
  page, so existing characters can change it at any time. Hiragana remains the default for existing profiles that
  have no preference.

## Consequences

- New Japanese entries need both complete translations. A corpus check requires equal key coverage and unchanged
  formatting slots and quoted code examples; town coverage also rejects stale English keys. The schema keeps
  `kanji` optional so old packs still load, falling back to their original Japanese.
- The second edition is editable content, not a growing runtime replacement dictionary. Editorial corrections
  belong with the English key and cannot silently rewrite part of an unknown name or compound.
- Scene tests cover creation, cancellation, profile reload, both settings directions and English creation. Native
  screenshots cover both creator editions, adult settings, quest instructions and the code editor.
