# ADR-0004: content is JSONC with code in real source files, checked by a small schema language

- Status: accepted
- Date: 2026-09-24

## Context

The old game's content was YAML validated by zod. Godot reads JSON natively and has no YAML parser. The YAML carried
real knowledge in its comments (why a balance number is what it is, which ADR a rule comes from), and every shard held
its Python and JavaScript in block strings inside the YAML.

## Options

1. **Plain JSON.** Native, but loses every comment, and a shard's code becomes one long string of `\n`s that nobody can
   read or edit.
2. **Keep YAML** and write a YAML parser in GDScript: a real parser for a large spec, and a new source of bugs.
3. **Godot resources** (`.tres`), edited in the inspector: good for art, awkward for 77 shards of code and prose, and
   diffs are noisy.
4. **JSONC** (JSON plus `//` and `/* */` comments and trailing commas), with each shard's code in its own `.py` and
   `.js` file beside its data.

## Decision

Option 4.

- `game/content/balance.jsonc`, and per pack `game/content/packs/<pack>/`: `pack.jsonc`, `shardrun/run.jsonc`,
  `shardrun/shards/<id>.jsonc` with `<id>.py` and `<id>.js`, `shardrun/relics/<id>.jsonc`, `shardrun/foes/<id>.jsonc`,
  and `locales/<locale>/*.jsonc` (lists of `{en, to, note?}`, keyed by the English text).
- `Jsonc` blanks comments and trailing commas out with spaces, so the JSON parser's error line is still the file's.
- `Schema` is a small zod in GDScript (text, id, tag, int, number, bool, enum, list, object, record, tagged union,
  optional, default); `ShardrunSchemas` holds the old schemas' rules and defaults, and `ShardrunChecks` the checks
  between files. A file must be named after its id.
- `tools/content/convert.ts` converted the old YAML once, walking the YAML syntax tree so every comment moved with its
  field. From now on the JSONC is the source.
- `scripts/validate.sh` loads and checks everything and runs every shard's worked examples in the sandbox (154
  examples, both languages, two sandbox jobs, about 0.2 s). `scripts/locale.sh ja [--missing]` reports translation
  coverage.

## Proof

The loader builds exactly the catalog the old engine built from its YAML, defaults included
(`test_the_catalog_is_the_old_engines`), and the broken-content test shows a schema error, a parse error with its
line, an unknown reference and a missing language each being reported.

## Consequences

- A shard's code is an ordinary file: an editor highlights it, a traceback's line number is its line number, and the
  in-game code view can show the same file.
- An export must include `*.jsonc`, `*.py` and `*.js` (Godot does not import them as resources); decided with exports.
- Content's short decimals parse exactly in Godot; its JSON parser is only inexact at 17 significant digits
  (ADR-0003).
