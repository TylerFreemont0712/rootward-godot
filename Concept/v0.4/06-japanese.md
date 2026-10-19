# v0.4, part 3: everything in Lanternroot in Japanese

Written 2026-10-16 on the player's word: *"start getting a japanese for all the different lines, fix any japanese that
is stale or needs to be updated, and make it completely accessible for japanese."* The player's daughters will play in
Japanese.

## 1. What "completely" means here

When the profile's language is Japanese, everything a player of Lanternroot (the overworld, its editors and panels)
reads is Japanese. That covers:
- talk;
- quests: titles, summaries, steps and hints;
- tasks: names, titles, goals, hints, advice, the cases' descriptions, the glossary's meanings, the Builder's labels
  and choice labels, and the comments in starter code;
- items, tracks and places;
- things' names and hints;
- the editors' and panels' words;
- Hotaru's remarks;
- the messages from runs.

Code stays code: keywords, names, values, and the player's own code and its answers (their labels and titles). One
exception: where the game hands text to the player's code to show back (the music box's titles, the map's place names,
the credits' part names), it hands the Japanese, so their code shows Japanese.

## 2. The voice

The voice is `docs/TRANSLATION.md` and the overworld's existing overlays:
- **Hiragana first, with spaces between phrases**, for the youngest readers: `きみの くつ`, `ためしてみる`.
- **A complete adult edition when Kanji is selected:** ordinary kanji, natural phrasing and no spaces between
  Japanese phrases. This applies to dialogue, instructions, errors, labels and descriptions, not a small vocabulary.
- **Friendly plain speech:** `〜しよう`, `〜だよ`, `〜してね`.
- **The town's words:** くつ (boots), しゅうりやさん (the tinker), ルール, コード, キー, ほたる (Hotaru), and katakana
  for the people's names as the talk overlay already has them.
- **New words for this slice:**

  | English | Japanese |
  |---|---|
  | part (of the game) | パーツ |
  | Workbench | さぎょうだい |
  | menu | メニュー |
  | pocket menu | ポケットメニュー |
  | bag | かばん |
  | item | もちもの |
  | map | ちず |
  | minimap | ミニマップ |
  | options | オプション |
  | volume | おとの おおきさ |
  | music box | オルゴール |
  | track / tune | きょく |
  | clock | とけい |
  | day / evening / night | ひる / ゆうがた / よる |
  | progress | しんちょく |
  | credits | クレジット |
  | test / drill | テスト / ドリル |
  | function | かんすう |
  | stage | ステージ |
  | hint | ヒント |
  | Builder / Scribe | ブロックで つくる / コードを かく |
  | shop | おみせ |
  | coins | コイン |

## 2.1 Reading preference

Updated 2026-10-17 on the player's request for normal Japanese for an adult reader (ADR-0075).

Japanese character creation asks for **ひらがな** (the default) or **漢字**. The choice previews the whole creator
while preserving the typed name, model and Builder/Scribe style; completion saves it and cancellation restores the
previous reading. Settings → 文字とフォント offers the same choice at the top. The town's Options → More settings
reaches this page, including for existing characters.

Every Japanese overlay has its existing `to` edition and a complete `kanji` translation. Kanji mode uses standard
adult orthography and technical terms such as 辞書, 値, 関数, 引数 and 変更履歴, without forced parenthetical readings
or phrase-separating spaces. The characters keep their voices. The setting covers the full catalog, including the
town, lessons, menus, descriptions and the legacy game modes. It does not guess kanji from kana syllables.

The curated exact-reading catalog still supplies the town's hiragana edition; unknown compounds are preserved.
English remains the game's source language. Templates are selected before values are filled, and code, identifiers,
quoted examples and inserted values remain unchanged. The hiragana guarantee covers the town catalog; it does not
force unrelated Shardrun names or every legacy Japanese proper noun into kana.

## 3. The work

1. **The conductor: coverage that counts everything.** `overworld_locale_test` counts every string the overworld shows:
   - today: its scripts' `Text.t`/`Text.f` literals, talk, townsfolk, map texts;
   - added now: quests, tasks (every prose field, Builder labels, starter comments), items, tracks, places, things'
     names and hints, and the task harness's messages.

   A tool writes the missing strings in batches with their source, for the translators.
2. **The conductor: everything shown passes through `Text`.**
   - **Advice:** the advice template is translated, and *then* its placeholders are filled. Today it is filled first,
     so a translation can never match.
   - **Starter code:** the comment lines of starter code are translated line by line, `#`/`//` kept.
   - **Builder labels** and **case descriptions** go through `Text.t`.
   - **The full map's legend:** the ground names are translated; the colour names are the player's code and stay.
   - **Text handed to the player's code** is handed in Japanese (section 1).
3. **Haiku translators:** batches of missing strings. Each translator writes a new overlay file
   (`locales/ja/overworld-<batch>.jsonc`), so no two write the same file, and no key is in two files.
4. **Stale Japanese:** lines whose English changed since their Japanese was written (21 found by the final check:
   Marta, Seren, Orin, Nym, the noticeboard, the sergeant, Hotaru's boots beats). The old key is replaced by the new
   English, and the Japanese is updated to say what the new English says. A list pairs each old key with its new line
   (by talk file, node and line position).
5. **The check:**
   - `overworld_locale_test` passes: every string has Japanese.
   - No overlay has a key nothing shows (a stale key), checked by a new test.
   - Japanese screenshots of the editor, the menus, the bag, the music box, the Workbench, the tracker and a talk
     (`ROOTWARD_LANTERNTOWN=<moment>-ja`) are looked at.
   - A Luna checkpoint followed by a Sol review of Japanese samples, naturalness, voice and rendered UI.
