# Bug hunt findings

Audit date: 2026-10-01. Stopped at the user's request; no fixes made.

Reviewed combat and guardian rules, commands, program execution and previews, saves/profiles, the Trial, Verifier, card controls, menus, and presentation code. Findings below distinguish **reproduced** behavior from **code-trace** findings. Line numbers refer to the working tree reviewed, including changes that were already present.

Validation completed: **258 tests passed** across 44 suites; content validation checked 375 worked examples in each language with **0 errors and 0 warnings**. Lint found the issue listed at the end. Additional temporary probes exercised rules and UI using isolated test saves. Initial filesystem/display restriction failures were excluded from the findings. This is a review checkpoint, not a claim that every possible bug has been found.

Priority: **High** = incorrect combat, inventory, persistence, or access to gameplay; **Medium** = misleading results or broken UI behavior; **Low** = incomplete presentation or a quality-check failure.

## Combat and inventory

### 1. Repeated spell IDs can duplicate and destroy cards — High, reproduced

- **Faulty code:** `game/core/shardrun/shardrun_commands.gd:97–106`, `132–134`, `204–207`.
- **Issue:** `_spells_by_id()` checks list length and membership but not uniqueness. Listing spell `a` twice and omitting `b` passes validation. A reproduced arrangement changed `[kindle]` / `[fork]` into `[fork]` / `[fork]`, despite the multiset check passing. Both arrangement and composition use this helper.
- **Change needed:** Require every existing spell ID exactly once before checking cards or assigning lists.

### 2. Program previews skip faster enemies' actions — High, reproduced

- **Faulty code:** `game/core/programs/program_rules.gd:660–665`; compare casting at `282–290`.
- **Issue:** Preview resolves bolts immediately, whereas casting first lets faster foes act. A faster shield intent produced a preview of **10 damage** and an actual cast of **0**. Healing, shield expiry, summons, and lethal attacks can cause similar differences.
- **Change needed:** Simulate the same pre-cast enemy actions and death checks on the preview's state copy, using shared cast-resolution logic.

### 3. Program previews omit defensive relic rewards — Medium, reproduced

- **Faulty code:** `game/core/programs/program_rules.gd:665–676`; casting applies additional effects at `314–315`.
- **Issue:** Preview reports only block from `resolve()`. With Try/Finally and Runic Loom, it reported **0 block** while casting granted **6**.
- **Change needed:** Include cast-defense and after-cast relic effects when calculating preview block; distinguish block gained from the final block balance if necessary.

### 4. Forcing a shielded Thunk subtracts its shield twice — High, reproduced

- **Faulty code:** `game/core/programs/guardian_landing.gd:190–206`, `260–264`.
- **Issue:** The lazy-body branch subtracts shield before multiplying pending damage, then passes the blocked amount to `_land()`, which subtracts it again. A 20-power bolt against 5 shield and no pending damage dealt **13**, rather than `floor((20 − 5) × 1.25) = 18`.
- **Change needed:** Separate already-adjusted damage from shield bookkeeping so shield reduces the hit once.

### 5. Overflow bypasses guardian landing rules and can desynchronize HP — High, reproduced with a mixed-foe fixture

- **Faulty code:** `game/core/programs/program_rules.gd:602–624`.
- **Issue:** Load Balancer's overflow directly subtracts HP, bypassing normal trait/body handling. Overflow into a Call Stack Colossus reduced HP from **295 to 285** while its frames still summed to **295**; the next frame push recalculated HP from those unchanged frames. Other guardian checks are also bypassed by this path.
- **Change needed:** Route overflow through an explicitly defined guardian-aware damage path that preserves body state and defeat effects.

### 6. Overflow absorbed by shields is counted as damage dealt — Medium, reproduced

- **Faulty code:** `game/core/programs/program_rules.gd:508–511`, `612–617`.
- **Issue:** `_flow()` consumes spill on both shield and HP, and its caller counts all consumed spill as damage. Killing a 1-HP foe and spilling 10 into the next foe's shield reported **11 damage**, although only **1 HP** was removed. This also inflates score and damage globals.
- **Change needed:** Return separate HP damage, shield absorption, and remaining spill values; accumulate only HP damage as `dealt`.

### 7. Mutator bonus hits are missing from damage totals — Medium, reproduced

- **Faulty code:** `game/core/programs/guardian_landing.gd:363–382`; `game/core/programs/program_rules.gd:519–525`, `316–320`.
- **Issue:** Restoring a mutant applies an extra hit in `finish()`, after the resolver's damage accumulator has been calculated. A 30-damage program removed **40 HP** but returned **30 damage**. Preview damage, statistics, best-cast accounting, and globals therefore disagree with the actual hit.
- **Change needed:** Include damage applied during guardian finalization in the resolver's totals and downstream accounting.

### 8. Dead cards still generate cards and spend globals — High, reproduced

- **Faulty code:** `game/core/programs/program_deck.gd:64–83`; `game/core/programs/program_rules.gd:343`, `315`; `game/core/programs/program_relics.gd:212–220`.
- **Issue:** Unreachable cuts the executed steps, but post-cast effects iterate every selected card. A program whose last two cards were dead code still generated **2 Lambda cards** from Higher Order and cleared `global total` from **17 to 0** through Release. Block-per-card, JIT tracking, and mutant restoration also receive the full selected list instead of the executed list.
- **Change needed:** Carry the actual executed card sequence into execution-dependent effects. Keep paying mana and disposing of selected cards according to the intended dead-code rules.

### 9. A faster summon changes the meaning of a program's target indices — Medium, reproduced with a mixed-foe fixture

- **Faulty code:** `game/core/programs/program_guardians.gd:251–264`; `game/core/programs/program_rules.gd:282–287`, `390–415`.
- **Issue:** The sandbox calculates numeric targets from the pre-cast foe list. A faster Malloc then inserts a Heap Block before a foe behind her, and resolution interprets those numbers against the new list. A bolt aimed at foe index 1 hit the new block instead of the Tally Wisp originally at index 1.
- **Change needed:** Preserve the target identities from the sandbox input, or explicitly translate indices after structural changes before resolving bolts.

## Program previews and code presentation

### 10. Imports and dead code make valid previews look unfinished — Medium, code trace

- **Faulty code:** `game/scenes/shardrun/fight/program_code.gd:128–140`, `76–96`; execution filtering is at `game/app/spell_runs.gd:188–191`.
- **Issue:** `_for()` requires one trace step for every selected card. Imports are excluded from execution steps, and Unreachable removes dead steps, so valid results for either case fail this check. The code panel discards the finished view and can remain on “Running it in the sandbox…” / “… ops”.
- **Change needed:** Match previews against the expected executed steps, with a separate identity/revision check for the complete selected program.

### 11. The program listing shows original code while the sandbox executes mutants — Medium, code trace

- **Faulty code:** `game/app/program_views.gd:101–105`; `game/ui/code/program_source.gd:62–65`. Mutant execution is applied at `game/app/spell_runs.gd:103–106`.
- **Issue:** The main program listing and walkthrough read unchanged catalog source. Card hover details use a mutated copy, but the listing does not. Players can watch original operators highlighted while the actual program runs different operators.
- **Change needed:** Build the displayed program source from the battle's effective card code, including mutations, and show the change consistently.

### 12. Prediction hiding still exposes the final predicted volley — Medium, code trace

- **Faulty code:** `game/app/program_views.gd:40–65`; `game/scenes/shardrun/fight/program_code.gd:88`, `100–110`.
- **Issue:** Turning off predictions only removes `view.result`; trace steps still contain the predicted bolt count, power, and elements, and `_show_final_volley()` displays those before casting. This also affects difficulties that hide predictions.
- **Change needed:** Gate pre-cast volley results on `revealed`, while allowing the actual cast replay to show its execution results.

### 13. The displayed speed class disagrees with effective stage complexity — Medium, code trace

- **Faulty code:** `game/core/programs/program_rules.gd:160–167`, `645`; `game/scenes/shardrun/fight/program_code.gd:89`.
- **Issue:** Speed labels use cards' base complexity, while work and guardian damage use effective stage complexity, including worst cases and relic overrides. Quick Sort on the sorted seed is charged as quadratic but the program speed label remains `O(n log n)`.
- **Change needed:** Derive the completed preview's speed label from its effective stages; retain a clearly described nominal label only while results are pending.

## Trial and gameplay controls

### 14. Returning from the Trial can redirect ordinary Continue into the Trial — High, code trace with session binding reproduced

- **Faulty code:** `game/scenes/shardrun/shardrun_screen.gd:222`, `453`; `game/ui/trial_coach.gd:107`; `game/scenes/title/title.gd:279–286`, `537`.
- **Issue:** Return-to-title actions leave `Game.trial_active` set. Ordinary Continue opens the same run scene without clearing it, and that scene chooses `Game.trial_session` at `shardrun_screen.gd:27`. The reproduced scene binding selected the Trial instead of the ordinary session.
- **Change needed:** Explicitly select the intended run context when leaving/resuming the Trial and when continuing an ordinary journey.

### 15. Trial completion and retry hints do not refresh within the same step — Medium, reproduced

- **Faulty code:** `game/ui/trial_coach.gd:29–39`; completion keeps the same ID at `game/core/trial_rules.gd:192–195`.
- **Issue:** The coach rerenders only when `step_id` changes. Marking the final step done did not show Return to title; changing the loss hint without changing the step did not show the hint. “Say that again” happens to force a refresh.
- **Change needed:** Refresh when visible state such as completion, hints, or completed-step information changes, without resetting review navigation unnecessarily.

### 16. Trial event detection drops the start of each command's log — Medium, reproduced

- **Faulty code:** `game/core/trial_rules.gd:82–85`; logs reset per command at `game/core/shardrun/shardrun.gd:97–98`.
- **Issue:** `_command_event()` treats logs as cumulative and starts reading at the previous log's length. A previous two-entry log followed by a new timeout entry produced **no log kinds**. Predicates requiring or excluding timeout and other events can therefore misclassify the action.
- **Change needed:** Read the complete new command log rather than slicing it using the preceding command's length.

### 17. Battle shortcuts remain active beneath modal menus — High, reproduced

- **Faulty code:** `game/scenes/shardrun/fight/fight_view.gd:345–366`; `game/scenes/shardrun/shardrun_screen.gd:381–412`.
- **Issue:** Overlays block mouse input but do not suspend battle keyboard input. Pressing **E** while the run menu was open advanced turn **1 to 2**, with the menu still open. Number keys can likewise cast beneath an overlay.
- **Change needed:** Consume gameplay keys or disable the underlying fight's input while a modal panel is open; retain the overlay's own navigation and close controls.

### 18. Changing the prediction option leaves the current UI stale — Medium, reproduced

- **Faulty code:** `game/ui/options_panel.gd:54–58`; `game/scenes/shardrun/shardrun_screen.gd:405–418`.
- **Issue:** The option changes `Settings.predictions`, but closing Options never refreshes the fight view. Disabling it left the existing **3 bolts / 9 damage** preview visible until another action refreshed the screen. Enabling it has the inverse delay.
- **Change needed:** Notify the active fight of prediction-setting changes and refresh its presentation immediately.

## Saves and profiles

### 19. Malformed run snapshots pass save validation — High, reproduced

- **Faulty code:** `game/app/save_store.gd:67–76`.
- **Issue:** Validation checks version and the presence of a short list of keys, without their types or required gameplay fields. A snapshot with `map = null` and no `integrity` was accepted as usable. Subsequent screen/rule access can fail instead of safely rejecting the save.
- **Change needed:** Validate field types, allowed values, required combat/status-specific structures, and cross-field invariants before warming or presenting a loaded run.

### 20. Failed saves still report successful progress — High, reproduced

- **Faulty code:** `game/app/shardrun_session.gd:65–67`, `83–85`, `110–117`; write handling at `game/app/save_store.gd:38–40`, `94–96`.
- **Issue:** Session methods ignore save/history errors and return success. An unwritable save destination returned an error from `save_run()` while `start()` still returned `ok: true`. The menu continues to assure the player that every move is saved. Write/flush failures also need checking before a temporary file replaces the previous save.
- **Change needed:** Propagate persistence failures, make unsaved progress visible, preserve the last good snapshot, and offer a retry or other defined recovery behavior.

### 21. Loading later sessions erases earlier corrupt-save warnings — Medium, code trace

- **Faulty code:** `game/app/save_store.gd:45–46`; `game/app/game.gd:112–125`; warning display at `game/scenes/title/title.gd:166–168`.
- **Issue:** All combat sessions and the Trial share one `SaveStore`. Each load clears `problem`, so an unreadable program save's warning is erased by later successful or absent saves. The title only reads the final shared value.
- **Change needed:** Preserve load diagnostics per save/session, or collect all load warnings during boot and show the relevant ones.

### 22. A truncated history line also loses the next completed run — Medium, reproduced

- **Faulty code:** `game/app/save_store.gd:85–95`.
- **Issue:** Appending does not check whether the previous file ends with a newline. After writing a crash-truncated JSON prefix, appending a valid record joined both into one invalid line; `load_history()` returned no records. This contradicts the stated behavior that a truncated line loses only itself.
- **Change needed:** Separate or quarantine an incomplete final line before appending the next record.

### 23. Verifier progress is shared across players — High, code trace

- **Faulty code:** `game/core/verifier_course.gd:6`, `21–24`, `36–44`.
- **Issue:** The course uses one global `user://verifier-course.json` instead of the active profile folder. Switching players shares unlocks and stars; deleting a profile does not remove its course progress. `ROOTWARD_SAVES` does not isolate this file either.
- **Change needed:** Store/load course progress under the active player's save root, with migration for the old global file and reset/reload on player changes.

### 24. Editing a Shibu/local-skin profile silently resets its avatar — Medium, reproduced

- **Faulty code:** `game/ui/profile_panel.gd:23–26`, `35`.
- **Issue:** The editor offers only Vesper and Emberfox, though the wardrobe supports Shibu and local skins. A profile stored as Shibu opened with Vesper selected, so saving a name/language edit overwrites its avatar.
- **Change needed:** Populate the editor from the supported skin list, or preserve the current avatar unless the player explicitly changes it.

### 25. Profile metadata validation does not protect startup from malformed nested fields — High, code trace

- **Faulty code:** `game/app/profile_store.gd:24–27`; consumers include `game/app/game.gd:79–82` and `game/core/profile_rules.gd:52–54`.
- **Issue:** A profile is considered valid when its ID and name are valid, even if `settings` is a string, timestamps are missing, or nested tutorial data has the wrong type. Loading casts `settings` to a Dictionary, and sorting directly accesses `created_at`. Such metadata can interrupt startup instead of being skipped as promised.
- **Change needed:** Validate/default all metadata consumed by selection, ordering, and menus before listing or activating a profile.

## Rendering and presentation

### 26. New guardian events do not update the animated battle state — Medium, code trace

- **Faulty code:** `game/scenes/shardrun/fight/log_player.gd:297–382`; event producers include `game/core/programs/program_guardians.gd:233–243`, `258–266`, and `game/core/programs/guardian_landing.gd:240–250`.
- **Issue:** Playback has no handler for summons or state-changing guardian notes. A caught throw reduces block and enemy HP through a `note`; INT_MAX healing uses an `absorb` event without a healing amount; summons contain no foe snapshot for playback to add. Numbers and enemy visibility remain wrong until the final state refresh, and hits at a newly summoned target cannot be shown normally.
- **Change needed:** Emit sufficient structured state changes and handle them in playback so summons, catches, healing, and guardian transitions remain synchronized with the rules.

### 27. Crashed casts do not animate their mana expenditure — Medium, code trace

- **Faulty code:** `game/scenes/shardrun/fight/log_player.gd:349–352`; costs are logged at `game/core/shardrun/shardrun_battle.gd:99–105` and `game/core/programs/program_rules.gd:293`.
- **Issue:** A failed cast pays mana and emits `fizzle`, but playback only shows a popup/sound and never reduces `shown.mana`. It displays the old mana balance until refresh. The same event kind is also used for malformed bolts, where `amount` is a bolt count rather than a cost.
- **Change needed:** Give failed-cast events an explicit cost field and apply it during playback, without charging the separate malformed-bolt events again.

### 28. The wardrobe overflows horizontally and hides controls — Medium, reproduced geometry

- **Faulty code:** `game/ui/skin_selection.gd:26–66`, `114`; `game/ui/ui.gd:78–85`.
- **Issue:** Every shipped/local skin is placed in one unwrapped row, and the containing overlay disables horizontal scrolling. On this installation's six skins, the panel measured **2442 logical pixels** across a **2182-pixel** viewport, leaving its right-hand content outside the visible area.
- **Change needed:** Wrap the skin cards, use a responsive grid, or provide horizontal scrolling while keeping Close reachable.

### 29. A partial anime skin bypasses the promised character fallback — Medium, code trace

- **Faulty code:** `game/characters/anime_skin.gd:31–41`; `game/characters/character.gd:63–68`, `80–85`.
- **Issue:** Finding `skin.json` is enough to report a usable skin. Character creation then loads its model and immediately calls `instantiate()` without checking that the JSON/model is valid or the resource is a PackedScene. An incomplete optional skin folder therefore causes a script error instead of falling back to the available hero presentation.
- **Change needed:** Validate skin metadata and model resources before accepting/instantiating the skin; use the normal fallback when either is unavailable.

### 30. Japanese player selection is only partly applied to gameplay — Low, incomplete presentation / code trace

- **Faulty code:** `game/scenes/shardrun/shardrun_screen.gd:83`, `182`, `199`, `212`; `game/scenes/shardrun/draft_view.gd:29–34`, `36`, `82`; `game/scenes/verifier/verifier_screen.gd:71–83`.
- **Issue:** Japanese selection is honored in the title, Trial narration, and Archives, but ordinary gameplay presentation reads English `session.catalog` and hardcoded English UI strings. Existing translated card/relic/layer content is not used by those views. The rules correctly retain English data; the missing part is the display layer.
- **Change needed:** Connect localized display data and UI text to gameplay views while preserving the English rules catalog.

## Sandbox

### 31. A fast process can exceed the output limit and still succeed — Medium, reproduced

- **Faulty code:** `game/sandbox/sandbox.gd:112–123`; pipe draining at `139–143`.
- **Issue:** The collector exits when the child process has finished before checking its collected output against the limit. A JavaScript probe printing 6000 characters with a 1 KB limit returned `ok` with output silently truncated to 1024 bytes. This makes output-limit enforcement depend on timing and can cause validation to evaluate incomplete output as a successful run.
- **Change needed:** Check output limits before the process-completion exit, enforce bounds during pipe reads, and report an output-limit failure whenever truncation occurs.

## Existing check failure

### 32. Archive search formatting fails lint — Low, reproduced

- **Faulty code:** `game/ui/archive_panel.gd:130`.
- **Issue:** The long `haystack` assignment exceeds the configured 120-character line limit, so `scripts/lint.sh` fails. This line was already modified before this audit.
- **Change needed:** Split the assignment/format arguments across lines using the repository's formatter conventions.

## Audio

### 33. Sound voices are stolen oldest-first, so a long sound can be cut short — Low, code trace

- **Faulty code:** `game/app/sound.gd`, `play()` and `_next_voice` (12 voices handed out in rotation).
- **Issue:** When a 13th sound starts while all 12 voices are still ringing, it takes over the oldest voice and cuts that sound mid-ring, whatever its importance. A long sound (a tier-4 cast release of about 2 s, a critical blow's tail, a shatter) could be cut by a burst of glyph and card ticks, and a sudden cut can click. Not observed in play, and a plain volley of twenty bolts needs only about 5 voices; a busy turn with casts, element layers, glyph ticks and popups at once is the likely way to hit it. Not measured.
- **Change needed:** Prefer a free voice. If none is free, steal the one with the least left to ring, never a long cast or critical sound, and fade the stolen voice out quickly to avoid a click. Cheaper partial fix: raise `VOICES` from 12 to 24.
