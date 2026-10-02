# ADR-0035: A control room and selectable game lettering

Accepted 2026-10-02.

The font default and reset behavior below are superseded by [ADR-0036](ADR-0036-fitting-room-and-cinzel-default.md):
Cinzel is now the default; Original remains an explicit saved choice.

## Context

The player wants Settings to inhabit its own screen, like the Library, with its categories down the left. They
also want to try four or five more thematic typefaces throughout the game while retaining the current default.
Font changes should save, preview immediately and preserve the programming game's readable source code.

## Decision

- Settings opens an opaque 1920 × 1080 control-room interior inside the title's existing overlay lifecycle.
  A generated painting of root-wrapped copper instruments, lanterns and a garden window has its own very subtle
  light shader. Its 1520 × 760 preferences area is integrated into the room, with no outer modal frame. Display,
  Fonts & text, Audio and Spell playback are left-hand tabs; each page scrolls independently if needed.
  Existing persistence, display, volume and playback controls are reused. The Library's warmed, input-blocking
  magic-circle passage starts immediately and conceals construction at its midpoint in both directions.
  Reduced motion bypasses transitions and freezes lighting. Back/Escape restores the opener and station state.
- `Settings.font_style` persists a validated id. Fresh installs, old saves without the field, and invalid values
  select `default`: the existing IBM Plex Mono UI and VT323 title/numeric lettering. The five candidates are
  Cinzel (engraved), Alegreya (storybook), Lora (journal), Spectral (scholar) and Exo 2 (instruments).
  Their unmodified fonts are bundled from Google Fonts with SIL Open Font Licenses and source/hash provenance
  under `game/ui/fonts/`; no network or installed Latin face is required at runtime.
- Regular and semibold use a FontVariation weight for variable faces, and separate shipped files for Spectral.
  Japanese uses an available Noto Serif CJK JP fallback for the four serif faces and Noto Sans CJK JP for Exo 2,
  then the existing system fallback behavior. The original default's fallback chain stays intact.
- Change live Theme resources in place: the shared game theme and weakly registered front-end copies receive
  new font references while retaining each screen's sizes, spacing and colors. Rebuilding scenes would destroy
  filters, the current tab, run state or focus. New scenes and custom drawings use the same selected `ui_font`.
- Introduce a separate `code_font` role that always retains IBM Plex Mono. Source, diffs, text editors and code
  comments explicitly use it; general rich text, tooltips, menus, card identity and narrative use the selected
  face. Run layouts and game rules are unchanged. The picker makes this distinction visible in its live preview.
- Each of the six choices displays its own face. Selecting one immediately applies and saves it, preserving
  keyboard focus through the safe deferred rebuild. A live sample includes a heading, paragraph, stats, action
  label, source and Japanese/symbol text. Restore current font returns to the original lettering.

## Consequences and validation

The player can compare lettering throughout a journey without a restart. Decorative faces can change wrapping;
room controls have generous widths and independent scroll regions while code retains fixed character spacing.
Japanese glyphs rely on the machine's existing system fallbacks, as before. The shared theme changes globally;
font-specific overrides are confined to the picker samples and code roles.

Tests cover bundled candidates, live shared/front-end theme identity, preserved sizes/code spacing, saved font
round trips and legacy/invalid values, every choice through the actual Settings page, room handoff and focus
restoration. The rendered walkthrough clicks all six choices and reset in animated and reduced-motion modes.
Screenshots review the new room, Cinzel/Alegreya previews, Japanese at 1280 × 720, Library with Spectral and
Adventure with Exo 2, and a Shardrun fight with Alegreya and monospaced source. Painting prompt/provenance are in `finalMenuConcept/settings/` (built-in imagegen skill).

Validation: the 290-case full game suite passed; the final three font regressions passed after the source-role
check was added. The rendered walkthrough passed 159 actual mouse clicks. Changed scripts pass lint/format;
whole-repository lint still reports the pre-existing long line in archive_panel.gd:130.
