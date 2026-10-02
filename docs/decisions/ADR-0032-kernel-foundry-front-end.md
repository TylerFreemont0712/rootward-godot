# ADR-0032: Kernel Foundry as the front end

Accepted 2026-10-02.

## Context

The player approved the underground lift station in `finalMenuConcept/main-menu.png` and asked for it to become the
main menus. Adventure and learning need separate entrances. The run's battles, map, forge and reward menus are a
later design task; this change must preserve their presentation and launch contracts.

## Decision

- Compose the front end on a centred, uniformly scaled 1920 × 1080 canvas. An optional clean station painting and
  transparent wordmark sit behind real Godot controls. The equipped skin is a live `HeroView` beside the lift,
  rather than a character painted into the background. Prompts and source provenance live in `finalMenuConcept/`.
- Duplicate the shared theme for these scenes. Front-end subclasses reuse the skin wheel, persistent settings and
  archive inspection without changing their shared versions or the run UI.
- Adventure opens a compact departure desk: existing playstyles, language, difficulty, new descent, resume,
  records and field guide. Pip's travels has a separate optional tab with an explicit start/continue action;
  starting an ordinary descent does not display a tutorial offer. Existing session commands and replacement
  confirmations remain responsible for starting a run. Opening a menu or tutorial tab never starts one.
- Character separates class from skin. Artificer is the only implemented class; its existing carousel holds the
  shipped and local skins. Equipping persists the profile's avatar and keeps the wardrobe open.
- Academy clearly says it is in preparation, with the existing Verifier course available when its runtime is
  installed. Planned learning activities are labelled as plans, without invented progress or rewards.
- The station Library browses live shards, relics, creatures and concepts. Search, rarity and shard role filters
  feed the existing real code and refactor inspection. Records shows actual finished history and links its commit
  log; an empty profile has a useful empty state.
- English and Japanese labels use the profile locale. Modal menus disable background keyboard focus and restore
  the opener. Rebuilding a choice preserves focus. Warm light varies locally at the lanterns and lift core;
  reduced motion immediately stops the shader clock, actor motion and menu transitions.

## Alternatives

Keeping generated labels in the background would make language, focus, save state and skin changes impossible.
Changing the global theme or shared menus would also restyle Shardrun before its design work. A full 3D station
would introduce a larger art and camera task than the approved concept requires.

## Consequences

The compact revision reduces the large panels' width and height by roughly one-third. It keeps normal text at
16 pixels on the design canvas, with 20-pixel headings and 12–14-pixel captions. Panel padding is 14 × 10 pixels,
ordinary controls are 28 pixels tall, and Library entries are 32 pixels tall. It puts language and difficulty alongside each other, uses a rarity
picker, and arranges the Academy's plans horizontally. Scrolling belongs inside long library/history contents;
the outer pages fit without scrolling. A wrapper measures the scaled carousel stage, while the shared run
wardrobe keeps its existing geometry. Buttons use warm translucent highlights and amber underlines rather than
boxed rows. Small confirmation dialogs keep enough room for their actions and warnings.

The approved painting anchors the composition across front-end pages. New classes and the Academy curriculum
still need implementation; their menus accurately expose that limit. Some inherited catalog descriptions remain
English. The Shardrun screens and rules are unchanged.

`scripts/menu-shots.sh` captures home, resume, Adventure, overlays, Japanese and a 1280 × 720 wardrobe in isolated
saves. The front-end tests cover launch separation, modal focus, avatar persistence, motion settings, creature
search and art, choice focus, the optional Trial tab and role-filtered refactors.

Menu rebuilds detach old controls and queue their deletion: the locale button can rebuild its own parent while its
click signal is still being emitted. Direct method calls alone cannot verify that lifetime. The regression suite
exercises button signals, and `scripts/menu-navigation.sh` clicks the real controls on a private display and checks
scene handoffs with motion enabled and disabled. It uses separate profiles and settings for each process; set
`ROOTWARD_NAVIGATION_QUIT=1` to verify the explicit Quit button in a separate process.
