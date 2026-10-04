# Translating Rootward

Everything a player reads can be Japanese (ADR-0047). The game is written in English, and the Japanese lives in
overlays: `game/content/packs/core/locales/ja/*.jsonc`, each a list of `{"en": ..., "to": ...}` keyed by the English
text exactly as the game shows or writes it. `scripts/locale.sh ja --missing` lists what has no translation yet.

Who reads it: the player, and their daughters, who are learning to read Japanese. Write warm, short, natural
Japanese a child can follow: everyday kanji, a reading in full-width brackets for a rarer word the first time a
screen uses it (`遺物（いぶつ）`), the friendly plain voice of the station and Pip's Trial (`〜しよう`, `〜だよ`) for
guidance and narration, and short noun phrases for labels and buttons (`ターン終了`, `デッキ`).

## How text reaches the screen

- A label or button whose text is a whole key is translated by Godot (auto-translate): the code says
  `Text.t("Deck")` anyway, so every string is easy to find and `locale.sh` can count it.
- Text built from a format translates the format first: `Text.f("%d mana", [cost])`, overlay key `"%d mana"`.
- A sentence the rules wrote (the fight's log, a refusal message, a room's description) is shown with
  `Text.sentence(text)`, or `Text.sentences(text)` for several in one line. Its overlay entry is the rules' format,
  `"%s takes %d."`; the names inside (`%s`) are translated through their own entries.
- Code, ids, function names, file names (`main.py`), commands, numbers, `O(n log n)` and `ops` are never translated.
  Code views turn auto-translate off.
- The title and front-end rooms keep their own inline pairs, `FoundryUi.text("Adventure", "冒険")`.

## Rules for an entry

- `en` is the English exactly, every space and full stop included; `to` the Japanese.
- Keep every `%s` and `%d`. When Japanese wants them in another order, write numbered slots instead: `{1}` is the
  first `%s`/`%d` of the English, `{2}` the second (`"%s hits %s for %d."` -> `"{1}が{2}に{3}ダメージ。"`). A
  translation uses either `%` slots or numbered slots, never both.
- One English key, one translation, in one file: the loader rejects a duplicate key across files.
- Japanese uses `。` and `、`; `！` and `？` where the English exclaims or asks. No spaces between Japanese words; keep
  a space beside Latin letters or numbers only where it helps reading (`3 ops`).

## The glossary

| English | Japanese | | English | Japanese |
|---|---|---|---|---|
| bolt | ボルト | | volley | 一斉射（いっせいしゃ） |
| shard | シャード | | card | カード |
| spell | 呪文（じゅもん） | | program | プログラム |
| paradigm | パラダイム | | deck | デッキ |
| hand | 手札（てふだ） | | draw pile / discard | 山札（やまふだ） / 捨て札 |
| mana | マナ | | block | ブロック |
| Integrity | HP | | power | 威力（いりょく） |
| foe | 敵 | | guardian | 番人（ばんにん） |
| elite | 強敵 | | relic | 遺物（いぶつ） |
| layer / ring | 階層 / リング | | map | 地図 |
| rest | 休けい | | forge | 炉（ろ） |
| cache (room) | キャッシュ | | treasure | 宝 |
| turn | ターン | | end turn | ターン終了 |
| intent / incoming | 次の行動 / 攻撃予告 | | shield | シールド |
| ward | 防護 | | element | 属性（ぞくせい） |
| fire / frost / spark | 火 / 氷 / 雷 | | weak / resists | 弱点 / 耐性 |
| Initiative | 先手（せんて） | | tempo | 速さ |
| budget / time limit | 制限時間 | | work | 仕事量 |
| preview / prediction | 予想 | | cast | 唱える / 詠唱 |
| import | インポート | | refactor / upgrade | リファクタ / 強化 |
| run (a descent) | 冒険 | | the Maintainer (you) | メンテナー（きみ） |
| Spellforge | スペルフォージ | | Shardrun | シャードラン |
| win / defeat | 勝利 / 敗北 | | score / rank | スコア / ランク |
