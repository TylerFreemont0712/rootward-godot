# Step 1 — People & Doors

## 1. Scope and experience

People & Doors is the workspace for **who stands here, where an entrance leads, and where the player starts**.
It organizes current capabilities and makes their effects legible. It does not introduce NPC schedules, appearance
generation, a second dialogue engine or a new kind of map transition.

Lower shelf sections: **People | Entrances | Player start**. Keep the world visible, with ordinary inspection on the
right. Left tools are Select, Place (when a card is chosen), door/talk overlays and navigation. Use the same shelf
area as Objects and Land. No person catalog appended down the left column.

### People view

- Search by person ID, displayed name or title; filters All, On this map, Elsewhere, Unplaced.
- A card shows existing character art/fallback, name, title, placement state and location. Read from townsfolk data
  plus draft-aware maps, not an independently persisted people list.
- Card action **Locate** opens/selects its existing placement. **Place here** starts the existing person ghost.
  For duplicates, show an error state with every placement and Locate actions; do not silently pick the first.
- Click valid ground to commit once. R changes facing. Same-map placement relocates the existing NPC as one undo.
  Cross-map placement names the source map/cell and asks the existing move confirmation; cancel changes nothing.
- A scheduled NPC card says “Scheduled — placement is their authored location.” Runtime simulation is paused in
  Edit; do not present a temporarily simulated position as a duplicate authored placement. Provide a read-only
  schedule summary/link to diagnostics. Moving a schedule's work anchor is covered below.

### Entrances view

- List buildings and warps for the current map. Filters All, Linked, Unlinked, Problems. A building has one
  entrance in this release. A warp is a transition marker; it must have a destination to become a persistent object.
- Row: source type/name/cell, target map/cell/facing or “Closed — no destination,” validation status, Locate.
- Actions: Link/change destination, Go to destination, Make interior (unlinked building only), Unlink (building only).
  A linked building offers Open interior only when its target is actually an interior map; do not rename all links rooms.
- Place transition marker uses the current warp placement/link workflow. Keep a pending warp in preview until
  a destination is accepted, or guarantee cancellation removes its provisional object and history atomically.
- Linked arrows and arrival marker are overlays. Hide them on Play. Distinguish unlinked, invalid and valid by
  icon/text as well as color. Invalid destination text includes the map/cell and concrete cause.

### Player start view

- Show the current map's start and facing. Locate centers it. Set start uses the existing start ghost.
- Reject off-map/blocked cells and transitions that would immediately warp. One click is one undoable map edit.
- Label this “Map start”; it is not a command to erase or overwrite an existing character save position.

## 2. Existing APIs and data

Reuse `StudioWork.place_person(id, cell, facing, free, confirmed)`, `set_start(cell, free)`, `link(sid, target)`,
`unlink(sid)`, `make_interior(sid, size)` and `slide_door(sid, door)` after reading their return values.
Reuse `StudioLink.begin`, `check`, `click`, `face`, `cancel`. `StudioDoors.standing`, `mentions`, `front_of`,
`door_along`, `make_interior` and `retarget` are existing pure helpers.

Targets remain `{map, at: [x,y], facing}`. Person objects remain the existing `kind: person` format. Do not persist
view filters, copied townsfolk definitions, resolved destination names or global session SIDs in map objects.

Current door constraints matter: a building door is an offset on its bottom footprint row. Do not offer north/east/
west entrances that `StudioDoors.front_of` and return-link movement cannot represent. Step 3 retains south entries.

## 3. P01 — Mount the workspace and read-only indexes

**Prerequisite:** F01. **Files:** top bar/mode/tools, catalog filtering as needed; NEW
`game/scenes/studio/studio_people_panel.gd`; NEW pure `game/core/studio/studio_people_index.gd` if indexing does not
fit `StudioDoors`. Use a small typed API rather than connecting every button directly to map dictionaries.

1. Add `people` to active tab routing and instantiate the panel once.
2. Build people/entrance/start view models from raw draft maps and townsfolk. Include map ID and session-local
   reference resolved fresh on action. Do not hold a raw object index across deletion, undo or map reload.
3. Sort people by displayed name then stable ID; entrances by source cell y/x then source index. Preserve the
   selected item and scroll position on refresh. Refresh on command, undo/redo, map change and new room creation.
4. Implement filters/search and empty states (“No unplaced people”; “No entrances on this map”). Selection/Locate
   changes UI only. Surface missing talk/unknown NPC data without crashing the entire panel.
5. Use a dirty/index revision to refresh after data changes, not a full scan every frame. Close/hide must disconnect
   unnecessary listeners and retain in-memory filter state.

**Exit:** disabled tab becomes a useful live inventory; draft edits made in Objects appear immediately, and filter
counts stay correct through undo/reload. No canonical files change from browsing it.

## 4. P02 — Placement, move and start actions

1. Card selection calls the existing person template/placement path; reuse `StudioArrange` and `StudioGhost`.
   The new panel must receive placing-state changes so the correct card is marked.
2. Use the existing fit rules and existing explicit override policy. Do not invent a People-only bypass for water,
   blocked arrival or duplicate NPC identity. A uniqueness violation is never accepted by a free-placement key.
3. Same-map relocate updates the existing SID, at/facing and selection; it never creates an extra person object.
4. Cross-map move uses confirmation and the transaction contract in guide §5. Test rejecting a stale source,
   failed destination build and cancelled confirmation; both maps must remain unchanged in each failure.
5. Scheduled NPC movement: inspect current scheduler's interpretation of `work`. If moving within Lanternroot,
   update the corresponding authored work anchor in the same transaction, leaving home/inn untouched. This requires
   the schedules document adapter described in W01; implement that adapter here if needed. It may be reused later.
   Moving a scheduled NPC to a different map is blocked with a specific explanation in v0.35, because current
   schedule anchors are Lanternroot-only coordinate pairs. Static NPCs may move between maps normally.
6. Set start dispatches `set_start`; handle facing using the existing map field command path. Commit cell+facing as
   one action when chosen together. Never move NPCs or saved characters as a side effect.
7. Release placement after one person/start placement. Escape/tab switch cancels its preview. Selection and hints
   update through the same callbacks as Objects rather than assuming the old catalog is visible.

**Exit:** uniqueness, schedule interpretation and coordinated undo are correct. The authored roster equals the
existing roster; this packet does not create arbitrary new NPC definitions.

## 5. P03 — Link editor and arrival preview

State sequence: `idle → choose_target_map → choose_target_cell → choose_facing → committed`; Escape at any stage
returns to source map/selection and `idle`. A failed target stays in choose-target state with an inline explanation.

1. Add link/change actions to selected entrance and inspector. Delegate source validation to `StudioLink.begin`.
2. Show a compact persistent instruction with source name/map, destination map picker, Cancel and target validity.
   While linking, world clicks select arrival cells; they cannot drag, paint, delete, start another link or place.
3. Render source/target markers and a facing arrow; choose facing using the existing menu. Retain current target
   facing when changing a link unless explicitly changed. Validate again immediately before commit.
4. Reject off-map, nonwalkable, blocked, self-triggering warp/door arrivals, missing map and stale source SID.
   Targets are cells where a person can stand after arriving, not the transition cell that would send them back.
5. Link is one-way. State that explicitly in the UI. Existing Make interior creates the paired return separately;
   paired outdoor routes are W04. Do not auto-create an unrequested reverse link on an arbitrary target cell.
6. Unlink closes a building but does not delete its room, destination objects or furniture. For a warp, offer Delete
   transition through the existing delete/confirmation workflow; never save a destination-free warp.
7. Go to destination is read-only navigation, validating and selecting/marking the arrival point. Broken links remain
   inspectable with Repair action even when navigation is impossible.

**Exit:** all link stages cancel safely, destination validation is shared with Publish, and a valid target is actually
used on Play draft with the chosen facing and no immediate return loop.

## 6. P04 — Interior workflow

1. Expose **Make interior** only for an unlinked building. Use `StudioWork.make_interior` and its existing default
   11 × 8 room unless the user explicitly chooses supported dimensions. Do not change old room templates globally.
2. On success show **Open room** and the generated map ID/title; opening selects the new room in the map picker.
   Picker and entrance list refresh immediately. Failure leaves source unchanged and explains the cause.
3. Preserve existing undo semantics: undoing Make interior removes the entrance link but retains the new room draft
   and furniture. Label it “Unlinked room draft”; offer Reconnect/Locate. Revert/delete of that draft checks references
   and confirms its loss. Do not claim room deletion is part of source-link undo.
4. Door dragging uses `slide_door`; incoming room return links follow. Recheck the exterior landing cell and doorway
   after moving/resizing a building. Invalid existing links show problems; an invalid new move is rejected.
5. Furniture placement stays Objects in this step; offer a clear **Furnish room** navigation action. B04 adds scoped
   furniture in Build. Preserve the active map and avoid accidentally reopening the exterior when changing tabs.
6. Warn about disconnected new room drafts during Publish using existing validation; do not silently attach or
   discard them. Reopen after app restart must find them through existing new-map draft discovery.

## 7. P05 — Dialogue, quests and readable diagnostics

1. Person inspector shows name/title/ID, authored location/facing, talk file ID, quest references and schedule note.
   Fields whose authoritative definition is not editable in this phase remain visibly read-only.
2. **Edit dialogue** switches to Quests and invokes existing `quest_panel.show_talk(talk_id)` after the panel is open.
   Add a thin navigation method in StudioMode if needed. A Back to person affordance remembers map+person ID,
   resolving it afresh on return. Do not use `OS.shell_open` as the primary editor.
3. Quest references jump to existing `show_quest`. Missing talk data has a diagnostic and safe disabled action;
   creating a new talk/NPC schema is outside this packet. Avoid inferring quests solely by matching prose strings.
4. Add door status diagnostics to entrance rows and map overlay using structured problem codes. Clicking a problem
   locates source, not a guessed nearby object. Use shared runtime/Publish checks for actual link validity.
5. Preserve text focus and correct undo owner across People → Talk → Back. Ctrl+Z inside dialogue edits dialogue;
   returning to People resumes map/transaction history without undoing a hidden file.

## 8. P06 — Acceptance and regression evidence

Use isolated content/draft/save directories as in existing `studio_rooms_test.gd`. Never move the player's actual
NPCs or publish fixture rooms into the source town just to prove this feature.

| Case | Required result |
|---|---|
| Place an unplaced static NPC | One authored placement, chosen facing, correct card state; undo/redo once |
| Relocate same NPC twice on same map | No duplicates; each click is one move/history entry |
| Move static NPC between maps | Confirmation; both maps update together; source/destination restart and undo safe |
| Move scheduled NPC inside town | Placement + work anchor coordinated; home/inn preserved |
| Move scheduled NPC to another map | Explicit supported-scope error; no changed map or schedule |
| Link building to free room cell | Correct target/facing on Play draft; reload retains it |
| Link to water, blocked prop, warp or off-map | Invalid preview and no committed mutation |
| Cancel at every link stage, switch tabs, delete source | Returns safely; no wrong-map command, orphan preview or provisional warp |
| Make room, furnish, undo source link | Room/furniture retained; reconnect works; orphan draft is visible |
| Slide exterior door, resize building | Return destination follows; undo/redo restores both maps |
| Open dialogue, edit, return | Same person selected, correct history, existing dialogue engine plays edit |
| Start marker | Valid map start saves; saved character is not reset |
| Publish conflict/failure and Revert | No partial paired mutation; canonical files unchanged on rejected publish |
| Japanese and narrow viewport | Labels fit/scroll; controls do not obscure world clicks |

Extend existing core doors, scene people, rooms and mode tests. Add panel/index/transaction cases for new behavior.
Screenshots: People shelf with placed/unplaced states; link target preview; furnished room/return marker; Japanese view.
P06 is complete only after the full story in delivery checklist A works through the actual mounted UI.
