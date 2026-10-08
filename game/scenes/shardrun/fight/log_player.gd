class_name LogPlayer
extends RefCounted
## Plays what a command did (the rules' log, old ADR-0019) on the stage, entry by entry: bolts fly and land, foes
## lunge, numbers rise. It keeps the numbers the screen shows (`shown`) in step with what has landed so far, so no bar
## gives a result away before its hit arrives; the screen draws the true state once the log has played.

## The numbers on screen changed (Integrity, block, a foe's HP).
signal numbers_changed
## An already-recorded early attack reached zero Integrity; the visual code walk stops where it was interrupted.
signal code_interrupted

## Flight times by how a bolt flies: straight, a lance that pierces, a rain on everyone, a seeker that picks a target.
const FLIGHT := {"missile": 250.0, "lance": 140.0, "rain": 380.0, "seeker": 320.0}
const BOLT_KINDS: Array[String] = ["hit", "absorb", "glance", "locked", "ward", "wasted"]
## What a cast logs after itself, before the next thing happens: its bolts, and what fizzled or burned on the way.
const CAST_PARTS: Array[String] = ["hit", "absorb", "glance", "locked", "ward", "wasted", "defeat", "fizzle", "curse"]
## A blow at least this big (or this share of the foe's health) lands as a critical, with its own animation.
const CRITICAL_AMOUNT := 18
const CRITICAL_SHARE := 0.45
## A volley spreads its launches over about this long, one bolt every `max` ms at most and `min` at least.
const VOLLEY := {"spread": 1300.0, "max": 190.0, "min": 45.0}
## A light cast's circle is called by a snap of the fingers and writes itself this much faster than a heavy one's (a
## bigger circle, more layers to set, is hurried less, so each layer can still be seen arrive: ADR-0039).
const SNAP_SPEED := 1.5
const SNAP_SPEEDS: Array[float] = [1.5, 1.5, 1.3, 1.15]
## A heavy cast gathers at least this long, whatever its circle: a small circle is written more slowly, not hurried.
const HEAVY_GATHER := 1.0
## How long after the circle is sealed the worn move looses the volley, in seconds.
const RELEASE_AFTER_SEAL := 0.45
## Without a code walk (including practice), each shard gets a readable construction beat.
const SHARD_BEAT_MS := 450.0
## The longest a cast waits (in real time) for its bolts to land before it lets the log move on regardless: a guard
## against an animation that never finishes, never a pace.
const LANDING_CAP_MS := 8000

var stage: BattleStage
## {integrity, integrity_max, block, mana, foes: {uid: foe}} as currently drawn.
var shown: Dictionary = {}
## The log lines played so far, for the battle log.
var lines: Array[Dictionary] = []
## The cards of each spell, {spell id: Array[Dictionary]}: what its circle stacks (one layer per card).
var cast_cards: Dictionary = {}
## Completed shard calls measured in the replay, {spell id: count}; absent for practice or logs without a replay.
var cast_steps: Dictionary = {}
## Procedural circles follow source execution order; legacy cast cards keep their original slot order.
var construction_cards: Dictionary = {}
var replay_element := "none"
## The cast's magic circle while its volley flies: every bolt is born on it (null when effects are off).
var _circle: MagicCircle
## Bolts launched and not landed yet. The cast's playback ends when this is back to zero, so every hit is on the bars
## before the screen draws the true state.
var _in_flight := 0
var _construction_spell := ""
var _construction_started := false
var _resolved_shards := 0
var _import_sources: Dictionary = {}
var _failed_spell := ""
var _early_groups: Array[Dictionary] = []
var _early_unlocked := 0
var _early_cursor := 0
var _early_consumed := 0
var _early_playing := false
## The cast being played (LegendaryCast): its serial, whether it is heavy, its falling blows, its constellation volley,
## the aim of each foe and the holes that have opened. A bolt that waits behind a falling blow rides with the cast it
## was launched in, and reads that cast's own state. The wait is capped by LANDING_CAP_MS, so that cast may have
## closed by then: the bolt then joins its closed volley while that still flies, or gets a new one that closes later.
var _legendary := LegendaryCast.new(0)


func _init(on_stage: BattleStage, before: Dictionary) -> void:
	stage = on_stage
	shown = numbers_of(before)


static func numbers_of(state: Dictionary) -> Dictionary:
	var battle: Dictionary = state.get("battle", {})
	var foes := {}
	for foe: Dictionary in battle.get("foes", []):
		foes[foe.uid] = foe.duplicate(true)
	return {
		"integrity": int(state.get("integrity", 0)),
		"integrity_max": int(state.get("integrity_max", 1)),
		"block": int(battle.get("block", 0)),
		"mana": int(battle.get("mana", 0)),
		"foes": foes,
	}


func play(entries: Array) -> void:
	if _failed_spell != "" and _constructs(false):
		if not _construction_started:
			begin_construction(_failed_spell, replay_element)
			await _pace_construction()
		await _finish_failed_construction()
		_failed_spell = ""
	var index := _early_consumed
	while index < entries.size():
		var entry: Dictionary = entries[index]
		lines.append(entry)
		if entry.kind == "cast":
			var volley: Array = []
			var next := index + 1
			while next < entries.size() and entries[next].kind in CAST_PARTS:
				volley.append(entries[next])
				next += 1
			await _cast(entry, volley)
			for played: Dictionary in volley:
				lines.append(played)
			index = next
			continue
		await _one(entry)
		index += 1
	# The log is over: no bolt of its last cast is coming, so that cast's volley closes, and frees itself once its
	# riders are done.
	_legendary.close()


## Schedule only the command's recorded prefix. The rules keep foe order even when their tempos differ; the queue
## must preserve that order because shields, damage and death may depend on it. Readiness never invents outcomes.
func prepare_early(entries: Array) -> void:
	var pending: Array[Dictionary] = []
	var threshold := -1
	for entry: Dictionary in entries:
		if entry.kind in ["cast", "fizzle", "timeout"]:
			break
		if entry.kind == "tempo":
			if threshold >= 0:
				_early_groups.append({"threshold": threshold, "entries": pending})
				pending = []
			threshold = int(entry.amount)
		pending.append(entry)
		if entry.kind == "loss":
			break
	if threshold >= 0:
		_early_groups.append({"threshold": threshold, "entries": pending})


func count_work(work: int) -> void:
	while _early_unlocked < _early_groups.size() and work > int(_early_groups[_early_unlocked].threshold):
		_early_unlocked += 1
	_start_early()


func _start_early() -> void:
	if not _early_playing and _early_cursor < _early_unlocked:
		_play_early()


func _play_early() -> void:
	_early_playing = true
	while _early_cursor < _early_unlocked and stage.is_inside_tree():
		for entry: Dictionary in _early_groups[_early_cursor].entries:
			lines.append(entry)
			_early_consumed += 1
			await _one(entry, true)
		_early_cursor += 1
	_early_playing = false


## Skipping finishes measured work at once, but attacks that already started must land before the cast is released.
func drain_early() -> void:
	_early_unlocked = _early_groups.size()
	_start_early()
	while _early_playing and stage.is_inside_tree():
		await stage.get_tree().process_frame


## Whether the first cast wears the optional circle constructed by the code's shard resolutions.
func uses_construction(entries: Array) -> bool:
	for entry: Dictionary in entries:
		if entry.kind == "cast":
			return _constructs(heavy_cast(entries))
	return _failed_spell != "" and _constructs(false)


## Three or more executed shards make a heavy cast; one or two make a light cast, regardless of volley size.
func heavy_cast(entries: Array) -> bool:
	for entry: Dictionary in entries:
		if entry.kind != "cast":
			continue
		return _cast_shard_count(String(entry.get("spell", ""))) >= 3
	return false


func _cast_shard_count(spell_id: String) -> int:
	if cast_steps.has(spell_id):
		var imports: Array = _import_sources.get(spell_id, [])
		return int(cast_steps[spell_id]) + imports.size()
	return (cast_cards.get(spell_id, []) as Array).size()


## The trace counts executable calls, while held imports run at the top of the source. Keep that distinction local
## to procedural construction so the original cast remains unchanged and a rehearsal's demo cards stay sequential.
func configure_replay(before: Dictionary, replay: Dictionary, catalog: Dictionary, entries: Array) -> void:
	if replay.is_empty():
		return
	var spell_id := String(replay.spell_id)
	var run: Dictionary = replay.get("run", {})
	var steps: Array = run.get("steps", [])
	if run.has("steps"):
		cast_steps[spell_id] = steps.size()
	var last: Dictionary = steps.back() if not steps.is_empty() else {}
	replay_element = VolleyMeter.dominant(last.get("elements", {}))
	_failed_spell = spell_id
	var cast_seen := false
	for entry: Dictionary in entries:
		if entry.kind == "cast" and entry.get("spell", "") == spell_id:
			_failed_spell = ""
			cast_seen = true
		elif cast_seen and entry.kind in BOLT_KINDS:
			replay_element = String(entry.get("element", "none"))
			break
	if before.get("playstyle", "") != "program":
		return
	var held: Array = cast_cards.get(spell_id, [])
	var ordered: Array[Dictionary] = []
	var sources: Array[String] = []
	for source_id: String in ProgramDeck.imports(before, catalog):
		var source: Dictionary = catalog.shards.get(source_id, {})
		var module := String(source.get("module", source_id))
		for card: Dictionary in held:
			if ProgramDeck.is_import(String(card.id), catalog) and String(card.get("module", card.id)) == module:
				ordered.append(card)
				sources.append(source_id)
	for card: Dictionary in held:
		if not ProgramDeck.is_import(String(card.id), catalog):
			ordered.append(card)
	construction_cards[spell_id] = ordered
	_import_sources[spell_id] = sources


## Every spell builds its circle while the code walks (ADR-0044); the worn moves are the gesture that looses it.
func _constructs(_heavy: bool) -> bool:
	return true


## Start before the code walks, keeping the hero idle and the circle on the stage rather than on its hand.
## Where the spell's circle stands, in global coordinates, for a Token Stream to fly into; zero before it exists.
func circle_point() -> Vector2:
	return _circle.global_position if is_instance_valid(_circle) else Vector2.ZERO


func begin_construction(spell_id: String, element: String, _heavy := false) -> void:
	_construction_spell = spell_id
	_construction_started = true
	_resolved_shards = 0
	stage.hero.play(stage.hero.move_clip("idle"))
	_circle = stage.magic_circle(_construction_cards(spell_id), element, 1.0, true)


## Exact slots matter: the same shard can run twice, and an unvisited or failing function must not invent a layer.
func resolve_shard(index: int) -> void:
	var sources: Array = _import_sources.get(_construction_spell, [])
	_resolve_layer(sources.size() + index)


func trace_shard(index: int, progress: float) -> void:
	var sources: Array = _import_sources.get(_construction_spell, [])
	var layer := sources.size() + index
	if _construction_started and layer == _resolved_shards and is_instance_valid(_circle):
		_circle.trace_shard(layer, progress)


func trace_import(source_id: String, progress: float) -> void:
	if not _construction_started or not is_instance_valid(_circle):
		return
	var sources: Array = _import_sources.get(_construction_spell, [])
	var first := sources.find(source_id)
	if first < 0:
		return
	var last := first
	while last + 1 < sources.size() and sources[last + 1] == source_id:
		last += 1
	var written := progress * (last - first + 1)
	for index in range(first, last + 1):
		var share := clampf(written - (index - first), 0.0, 1.0)
		if index > first and share <= 0.0:
			break
		_circle.trace_shard(index, share)


## Only imports held in this spell add a layer. A module already in force can be shown by its base card's source
## line even when the held shard is its upgraded variant; configure_replay maps that representative by module.
func resolve_import(source_id: String) -> void:
	if not _construction_started:
		return
	var sources: Array = _import_sources.get(_construction_spell, [])
	while _resolved_shards < sources.size() and sources[_resolved_shards] == source_id:
		_resolve_layer(_resolved_shards)


func _construction_cards(spell_id: String) -> Array:
	return construction_cards.get(spell_id, cast_cards.get(spell_id, []))


func _resolve_layer(index: int) -> void:
	var cards := _construction_cards(_construction_spell)
	if not _construction_started or index != _resolved_shards or index >= cards.size():
		return
	_resolved_shards += 1
	if is_instance_valid(_circle):
		_circle.construct_shard(index)


func _pace_construction() -> void:
	var cards := _construction_cards(_construction_spell)
	var imports := (_import_sources.get(_construction_spell, []) as Array).size()
	var steps := clampi(int(cast_steps.get(_construction_spell, cards.size() - imports)), 0, cards.size() - imports)
	var count := imports + steps
	for index in count:
		_resolve_layer(index)
		if index + 1 < count:
			await stage.wait(SHARD_BEAT_MS)


func _finish_failed_construction() -> void:
	if is_instance_valid(_circle):
		_circle.finish_construction()
		await stage.wait(_circle.construction_time_left() * 1000.0)
		if is_instance_valid(_circle):
			_circle.close()
	_circle = null
	_construction_started = false
	_construction_spell = ""


func _cast(entry: Dictionary, volley: Array) -> void:
	_legendary.close()
	var heavy := _cast_shard_count(String(entry.get("spell", ""))) >= 3
	_legendary = LegendaryCast.new(stage.next_cast_serial(), heavy)
	var bolts := volley.filter(func(e: Dictionary) -> bool: return e.kind in BOLT_KINDS)
	var element: String = bolts[0].get("element", "none") if not bolts.is_empty() else "none"
	shown.mana -= int(entry.get("amount", 0))
	numbers_changed.emit()
	var construction := _constructs(heavy)
	if not construction:
		stage.hero.play_cast(heavy)
	stage.hero.flash(Color(UiTheme.element(element), 0.3), 0.4)
	# The program runs. A heavy cast's circle writes itself in the air in front of the Maintainer while she gathers the
	# power, and her strike lands on it as it completes; a light cast is a snap of her fingers, and the circle appears
	# on the snap. Either way the circle follows the spell's shards (ADR-0039): its tier from how many there are, one
	# layer for each, set in the order they were played; it stays while the volley flies, and every bolt leaves it.
	# One or two executed shards use a light cast; three or more use a heavy cast. Damage never changes the gesture.
	var cards: Array = cast_cards.get(entry.get("spell", ""), [])
	var tier := CircleLayers.tier_for(cards.size())
	if construction:
		if not _construction_started or _construction_spell != String(entry.get("spell", "")):
			begin_construction(String(entry.get("spell", "")), element, heavy)
			await _pace_construction()
		else:
			# A faster foe may have hurt the hero after the code walk; this cast still uses an idle pose.
			stage.hero.play(stage.hero.move_clip("idle"))
		if is_instance_valid(_circle):
			_circle.finish_construction()
		# The worn move looses the sealed circle (a move is a gesture; the circle is the spell, ADR-0044).
		stage.hero.play_cast(heavy)
		stage.hero.release_in(RELEASE_AFTER_SEAL)
	elif heavy:
		_circle = stage.magic_circle(cards, element, gather_speed(tier))
		stage.hero.release_in(_circle.form_time() if _circle != null else 0.38)
	else:
		await stage.wait(stage.hero.release_left() * 1000.0)
		_circle = stage.magic_circle(cards, element, snap_speed(tier))
		if _circle != null:
			_circle.spark_from(stage.hero.hand_point())
	if tier >= 2 or heavy:
		var feet := stage.hero.position + Vector2(stage.hero.size.x * 0.5, stage.hero.size.y)
		stage.spell("cast-ground", feet, element, stage.hero.figure_height() / 390.0)
	if heavy:
		stage.dim(0.38, 0.3)
	if construction:
		var sealing := _circle.construction_time_left() if is_instance_valid(_circle) else 0.0
		await stage.wait(maxf(sealing, RELEASE_AFTER_SEAL) * 1000.0)
	elif _circle == null:
		Sound.play("sfx-cast-tier-2", 0.8)
		stage.cast_flash(element, heavy)
		if heavy:
			stage.vortex(element, 0.62)
		await stage.wait(380.0)
	else:
		await stage.wait(_circle.form_time() * 1000.0)
	for part: Dictionary in volley:
		if part.kind in ["fizzle", "curse"]:
			await _one(part)
	var feet: Array[Vector2] = []
	for hit: Dictionary in bolts:
		var view: FoeView = stage.foes.get(hit.get("foe", ""))
		if view != null and not view.foot_point() in feet:
			feet.append(view.foot_point())
	if feet.size() >= 2:
		stage.sweep(feet, element)
	var gap := clampf(VOLLEY.spread / maxf(1.0, bolts.size()), VOLLEY.min, VOLLEY.max)
	if heavy:
		gap *= 1.35
	# LEARN: the bolt's place in the cast, not `volley.find(hit)`: two identical bolts would find one place, and one path.
	for index in volley.size():
		var hit: Dictionary = volley[index]
		if not hit.kind in BOLT_KINDS:
			continue
		_in_flight += 1
		_launch(hit, _flight(hit), volley, index)
		await stage.wait(gap)
	# The program has finished: its circle closes and the Maintainer lets go of it while the last bolts fly.
	if is_instance_valid(_circle):
		_circle.close()
	_circle = null
	_construction_started = false
	_construction_spell = ""
	stage.hero.end_cast()
	# LEARN: wait for the landings themselves, not for a guess at how long they take. A heavy cast's later bolts wait
	# for the blow falling on their foe, every blow waits for its brackets to slam, and hit-stops stretch all of it; a
	# fixed wait let the log move on with hits still to come, and the screen then drew the true state over a bar that
	# still showed the foe alive.
	var deadline := stage.clock_ms() + LANDING_CAP_MS
	while _in_flight > 0 and stage.is_inside_tree() and stage.clock_ms() < deadline:
		await stage.get_tree().process_frame
	# A beat after the last blow, before the foes answer.
	await stage.wait(400.0)
	if heavy:
		stage.dim(0.0, 0.4)


## The blow a bolt of this element lands with (ADR-0014's sheets): fire, frost and spark each strike in their own way,
## and anything else keeps the bracket slam.
static func blow_sheet(element: String) -> String:
	match element:
		"fire":
			return "hit-ember"
		"frost":
			return "hit-rime"
		"spark":
			return "hit-arc"
	return "hit-compile"


## How fast a heavy cast's circle of `tier` writes itself: in a gather of at least HEAVY_GATHER seconds.
static func gather_speed(tier: int) -> float:
	var form := float(MagicCircle.TIERS[clampi(tier, 0, MagicCircle.TIERS.size() - 1)].form)
	return form / maxf(form, HEAVY_GATHER)


## How fast a light cast's circle of `tier` writes itself, on the snap.
static func snap_speed(tier: int) -> float:
	return SNAP_SPEEDS[clampi(tier, 0, SNAP_SPEEDS.size() - 1)]


func _launch(hit: Dictionary, flight: float, volley: Array, index: int) -> void:
	# LEARN: the cast, its circle and the bolt's origin are taken before any await. A bolt that waits behind a falling blow
	# still joins the cast it was launched in, and rides from the point it left even when its circle frees itself during
	# the wait. The cast is taken, not its volley: a volley is made lazily and may be freed and replaced during the wait.
	# Its heavy flag and falling blows live on the cast too, so the bolt reads its own cast's state after its await.
	var cast := _legendary
	var arrive := _land.bind(hit, volley, cast)
	var constellation := LegendaryCast.worn_draw(stage, "bolt") == "constellation"
	var circle: MagicCircle = _circle if is_instance_valid(_circle) else null
	# Born on the cast's circle, so a volley pours out of it rather than out of her hand; it flares as each one leaves.
	var from := stage.hero.hand_point()
	var from_node: CanvasItem = stage.hero
	if circle != null:
		from = circle.launch_point()
		from_node = circle
		circle.pulse()
	var origin := Callable()
	if constellation:
		origin = cast.origin_of(circle, LegendaryCast.global_of(from_node, from))
	if hit.kind == "ward":
		var body := stage.hero.body_point()
		# A ward flies at 0.6 of the bolt's flight, as an ordinary ward does.
		if constellation:
			cast.ride(stage, origin, LegendaryCast.global_of(stage.hero, body), hit, index, flight * 0.6, arrive)
			return
		stage.fly(from, body, hit.get("element", "none"), flight * 0.6, arrive, true)
		return
	var view: FoeView = stage.foes.get(hit.get("foe", ""))
	if view == null:
		_land(hit, volley, cast)
		return
	# The foe's aim is taken at this cast's first launch to it, before any wait: its riders and its hole share it.
	var aim := cast.target_of(
		String(hit.foe), func() -> Vector2: return LegendaryCast.global_of(view, view.target_point())
	)
	# LEARN: the foe's points are read before the first await, as the origin is. A new fight frees every foe view, so
	# the view may be gone when the wait ends, so the bolt flies on the points it launched with and reads no view after.
	var target := view.target_point()
	var foot := view.foot_point()
	var width := view.sprite_width()
	var pending: Variant = cast.crashed.get(hit.foe)
	# LEARN: validity first. `is` on an object that has been freed is a script error that stops this function, and the
	# falling blow frees itself when its animation ends: a bolt launched after that never flew, and its damage never
	# reached the bar. is_instance_valid is safe on anything, freed or not an object at all.
	if is_instance_valid(pending) and pending is SpellAnim:
		# The foe's falling blow lands first; the bolts after it fly once it has.
		await SpellAnim.landed_of(pending as SpellAnim)
	# A black hole is the blow itself: a heavy first blow must not fall back to the falling code's hit-heavy.
	var impact := LegendaryCast.crash_sheet(stage)
	if cast.heavy and not cast.crashed.has(hit.foe) and impact != "":
		# A heavy cast's first blow on a foe does not fly: it arrives as the worn impact (blocks of code falling on it
		# from above by default, a star, roots, a pillar of light), anchored at its feet.
		cast.crashed[hit.foe] = true
		var crash := stage.spell(impact, foot, hit.get("element", "none"), 0.9 + minf(0.5, width / 400.0))
		if crash != null:
			cast.crashed[hit.foe] = crash
			await SpellAnim.landed_of(crash)
			stage.hit_stop(80.0)
		# A blow, not a bolt: no rider is added for it, since this return leaves before the constellation branch.
		_land(hit, volley, cast, true)
		return
	if constellation:
		cast.ride(stage, origin, aim, hit, index, flight, arrive)
		return
	var power := LegendaryCast.power_of(hit)
	stage.fly(from, target, hit.get("element", "none"), flight, arrive, false, power)


## A bolt reaches its mark. A hit first plays its blow (brackets slamming on the foe) and lands on the frame they meet;
## `crashed` when a heavy blow already fell there. `cast` is the cast the bolt was launched in.
func _land(hit: Dictionary, volley: Array, cast: LegendaryCast, crashed := false) -> void:
	var element: String = hit.get("element", "none")
	var struck := false
	if hit.kind == "hit" and not crashed:
		var aimed: FoeView = stage.foes.get(hit.get("foe", ""))
		if aimed != null:
			var weight := float(hit.get("amount", 0)) / maxf(1.0, float(shown.foes.get(hit.foe, {}).get("max", 1)))
			# A big blow lands as a critical: drawn in first, then breaking open with two shockwaves, a longer stop and
			# a shake; the rest slam their brackets, larger for more damage.
			var critical := int(hit.get("amount", 0)) >= CRITICAL_AMOUNT or weight >= CRITICAL_SHARE
			var hole := cast.open_hole(stage, hit, aimed, critical)
			if hole != null:
				# The foe's first non-critical blow this cast: the hole lands on its impact, as a sprite's blow lands on its own.
				struck = true
				await hole.landed()
				Sound.play("sfx-hit-heavy", 0.8)
			else:
				var blow: SpellAnim = LegendaryCast.blow_sprite(stage, aimed, element, critical, weight)
				if blow != null:
					struck = true
					await SpellAnim.landed_of(blow)
			if struck:
				stage.hit_stop(95.0 if critical else 30.0)
				if critical:
					stage.shake(0.8)
	match hit.kind:
		"ward":
			shown.block += int(hit.amount)
			# The honeycomb (about 224 px tall as drawn) covers the Maintainer from hat to boots.
			var cover := stage.hero.figure_height() * 1.05 / 224.0
			if (
				stage.spell(
					"ward-hex", stage.hero.body_point() - Vector2(0, stage.hero.figure_height() * 0.07), "ward", cover
				)
				== null
			):
				stage.ward_glow()
				Sound.play("sfx-ward-hex", 0.7)
			stage.popup(
				stage.hero.body_point() - Vector2(0, 60), Text.f("+%d block", [int(hit.amount)]), UiTheme.TEAL, 28
			)
		"hit":
			var foe: Dictionary = shown.foes.get(hit.foe, {})
			var view: FoeView = stage.foes.get(hit.foe)
			var amount := int(hit.amount)
			if not foe.is_empty():
				foe.hp = maxi(0, int(foe.hp) - amount)
				foe.shield = maxi(0, int(foe.shield) - int(hit.get("blocked", 0)))
			if view != null:
				var weight := float(amount) / maxf(1.0, float(foe.get("max", amount)))
				view.show_foe(foe)
				view.recoil(1.0 + weight * 2.0)
				if not struck and not crashed:
					stage.burst(view.target_point(), element, 1.0 + minf(weight * 2.0, 1.2))
				stage.popup(view.top_point(), _hit_text(hit), _hit_colour(hit), 30 + mini(amount, 30))
				if weight >= 0.25 or amount >= 25:
					stage.shake(weight + 0.3)
					stage.hit_stop(70.0)
				# A blow that played its animation played that animation's sound, so the two cannot disagree (a
				# critical picture under a light hit's sound); only a blow shown without one sounds here.
				if not struck and not crashed:
					Sound.play("sfx-hit-compile", 0.8, randf_range(0.95, 1.08))
			for later: Dictionary in volley:
				if later.kind == "defeat" and later.foe == hit.foe and int(foe.get("hp", 1)) == 0:
					_defeat(later)
		"absorb":
			var view: FoeView = stage.foes.get(hit.foe)
			if view != null:
				stage.popup(view.top_point(), Text.sentence(String(hit.get("word", "nullified"))), UiTheme.SHARD, 24)
			Sound.play("sfx-gulp", 0.7)
		"glance":
			var view: FoeView = stage.foes.get(hit.foe)
			if view != null:
				stage.popup(view.top_point(), Text.t("glance"), UiTheme.MUTED, 24)
			Sound.play("sfx-ricochet", 0.7)
		"locked":
			# A deadlock held (ADR-0017): the bolt rings off a lock whose partner this program never touched.
			var view: FoeView = stage.foes.get(hit.foe)
			if view != null:
				stage.popup(view.top_point(), Text.t("locked"), UiTheme.WARN, 26)
				view.recoil(0.5)
			Sound.play("sfx-lock", 0.8)
		"wasted":
			# A program's bolt aimed at a foe that already fell (ADR-0012): it sails through the empty air.
			var view: FoeView = stage.foes.get(hit.foe)
			if view != null:
				stage.popup(
					view.top_point() + Vector2(0, 30), Text.f("wasted %d", [int(hit.amount)]), UiTheme.FAINT, 20
				)
			Sound.play("sfx-whiff", 0.5)
	numbers_changed.emit()
	_in_flight = maxi(0, _in_flight - 1)


func _defeat(entry: Dictionary) -> void:
	var view: FoeView = stage.foes.get(entry.foe)
	if view == null or view.get_meta("defeated", false):
		return
	view.set_meta("defeated", true)
	view.defeat()
	if stage.spell("shatter", view.target_point(), "none", 0.9 + minf(0.6, view.sprite_width() / 300.0)) == null:
		Sound.play("sfx-shatter", 0.8)


func _one(entry: Dictionary, overlapping := false) -> void:
	match entry.kind:
		"enter":
			stage.banner(Text.sentences(String(entry.text)), UiTheme.AMBER, 900.0)
			await stage.wait(700.0)
		"turn":
			stage.banner(Text.f("Turn %d", [int(entry.amount)]), UiTheme.AMBER, 500.0)
			Sound.play("sfx-turn", 0.6)
			await stage.wait(650.0)
		"enemy":
			await _enemy(entry)
		"shield":
			var view: FoeView = stage.foes.get(entry.foe)
			var foe: Dictionary = shown.foes.get(entry.foe, {})
			if not foe.is_empty():
				foe.shield = int(foe.shield) + int(entry.amount)
			if view != null:
				view.show_foe(foe)
				stage.popup(view.top_point(), Text.f("+%d shield", [int(entry.amount)]), UiTheme.TEAL, 26)
			Sound.play("sfx-foe-shield", 0.6)
			await stage.wait(460.0)
		"stoke":
			var view: FoeView = stage.foes.get(entry.foe)
			var foe: Dictionary = shown.foes.get(entry.foe, {})
			if not foe.is_empty():
				foe.stoked = true
			if view != null:
				view.show_foe(foe)
				stage.popup(view.top_point(), Text.t("stoked!"), UiTheme.ELEMENTS.fire, 26)
			Sound.play("sfx-stoke", 0.7)
			await stage.wait(460.0)
		"heal":
			await _heal(entry)
		"tempo":
			# A foe quicker than the program acts before it lands (ADR-0012); its action is the next entry.
			var view: FoeView = stage.foes.get(entry.foe)
			var clock: SpellAnim = null
			if view != null:
				view.recoil(0.4)
				clock = stage.spell("tempo", view.top_point() - Vector2(0, 40), "tempo", 0.8)
				stage.popup(
					view.top_point() - Vector2(0, 24), Text.f("⚡ faster  %d ops", [int(entry.amount)]), UiTheme.WARN, 26
				)
			if clock == null:
				Sound.play("sfx-tempo", 0.6)
			if not overlapping:
				await stage.wait(560.0)
		"timeout":
			stage.banner(Text.t("Time limit exceeded"), UiTheme.FAIL, 1000.0)
			stage.popup(stage.hero.hand_point(), "%d ops" % int(entry.amount), UiTheme.FAIL, 28)
			stage.hero.flash(Color(UiTheme.FAIL, 0.3))
			shown.mana -= int(entry.get("cost", 0))
			numbers_changed.emit()
			Sound.play("sfx-timeout", 0.7)
			await stage.wait(1100.0)
		"fizzle":
			stage.popup(stage.hero.hand_point(), Text.t("fizzle"), UiTheme.MUTED, 26)
			Sound.play("sfx-glitch", 0.6)
			await stage.wait(420.0)
		"curse":
			shown.integrity = maxi(0, int(shown.integrity) - int(entry.amount))
			stage.popup(stage.hero.body_point(), "-%d" % int(entry.amount), UiTheme.SHARD, 30)
			stage.hero.flash(Color(UiTheme.SHARD, 0.35))
			Sound.play("sfx-curse", 0.7)
			numbers_changed.emit()
			await stage.wait(520.0)
		"ward":
			shown.block += int(entry.amount)
			stage.popup(
				stage.hero.body_point() - Vector2(0, 60), Text.f("+%d block", [int(entry.amount)]), UiTheme.TEAL, 26
			)
			numbers_changed.emit()
			await stage.wait(360.0)
		"mana":
			shown.mana += int(entry.amount)
			stage.popup(stage.hero.hand_point(), Text.f("+%d mana", [int(entry.amount)]), UiTheme.SHARD, 26)
			numbers_changed.emit()
			await stage.wait(300.0)
		"victory":
			stage.banner(Text.t("Victory"), UiTheme.PASS, 1100.0)
			Sound.cue("cue-victory", 0.8)
			await stage.wait(1300.0)
		"loss":
			stage.hero.play("death")
			stage.banner(Text.t("Kernel panic"), UiTheme.FAIL, 1400.0)
			Sound.cue("cue-defeat", 0.8)
			await stage.wait(1600.0)
		"defeat":
			_defeat(entry)
			await stage.wait(300.0)


func _enemy(entry: Dictionary) -> void:
	var view: FoeView = stage.foes.get(entry.foe)
	if view != null:
		view.lunge(stage.hero.body_point())
	await stage.wait(200.0)
	var amount := int(entry.amount)
	var blocked := int(entry.get("blocked", 0))
	shown.integrity = maxi(0, int(shown.integrity) - amount)
	shown.block = maxi(0, int(shown.block) - blocked)
	var at := stage.hero.body_point()
	if amount > 0:
		if stage.spell("claw", at, "foe", 0.85) == null:
			Sound.play("sfx-claw", 0.8)
		stage.hero.play("hurt")
		stage.hero.flash(Color(UiTheme.FAIL, 0.4))
		stage.popup(at, "-%d" % amount, UiTheme.FAIL, 36)
		var weight := float(amount) / maxf(1.0, float(shown.integrity_max))
		stage.shake(weight * 3.0)
	if blocked > 0:
		if amount == 0:
			stage.hero.play("guard")
		stage.popup(at + Vector2(-60, -40), Text.f("%d blocked", [blocked]), UiTheme.TEAL, 24)
		Sound.play("sfx-clang", 0.6)
	numbers_changed.emit()
	if _early_playing and int(shown.integrity) <= 0:
		if is_instance_valid(_circle):
			_circle.finish_construction()
			_circle.close()
		code_interrupted.emit()
	await stage.wait(360.0)


func _heal(entry: Dictionary) -> void:
	var amount := int(entry.get("amount", 0))
	if entry.has("foe"):
		var foe: Dictionary = shown.foes.get(entry.foe, {})
		var view: FoeView = stage.foes.get(entry.foe)
		if not foe.is_empty():
			foe.hp = mini(int(foe.max), int(foe.hp) + amount)
		if view != null:
			view.show_foe(foe)
			stage.popup(view.top_point(), "+%d" % amount, UiTheme.PASS, 28)
	else:
		shown.integrity = mini(int(shown.integrity_max), int(shown.integrity) + amount)
		stage.popup(stage.hero.body_point(), "+%d" % amount, UiTheme.PASS, 28)
	Sound.play("sfx-heal", 0.7)
	numbers_changed.emit()
	await stage.wait(460.0)


func _flight(hit: Dictionary) -> float:
	if hit.get("pierce", false):
		return FLIGHT.lance
	match hit.get("target", "front"):
		"all":
			return FLIGHT.rain
		"weakest", "strongest", "back":
			return FLIGHT.seeker
	return FLIGHT.missile


static func _hit_text(hit: Dictionary) -> String:
	# » marks Initiative: the program landed before this foe moved.
	var text := ("»" if hit.get("initiative", false) else "") + str(int(hit.amount))
	match hit.get("affinity", ""):
		"weak":
			text += "!"
		"resist":
			text += "…"
	return text


static func _hit_colour(hit: Dictionary) -> Color:
	match hit.get("affinity", ""):
		"weak":
			return UiTheme.WARN
		"resist":
			return UiTheme.MUTED
	if hit.get("initiative", false):
		return UiTheme.AMBER
	return UiTheme.element(hit.get("element", "none")).lightened(0.1)
