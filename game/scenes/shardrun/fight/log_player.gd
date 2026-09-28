class_name LogPlayer
extends RefCounted
## Plays what a command did (the rules' log, old ADR-0019) on the stage, entry by entry: bolts fly and land, foes
## lunge, numbers rise. It keeps the numbers the screen shows (`shown`) in step with what has landed so far, so no bar
## gives a result away before its hit arrives; the screen draws the true state once the log has played.

## The numbers on screen changed (Integrity, block, a foe's HP).
signal numbers_changed

## Flight times by how a bolt flies: straight, a lance that pierces, a rain on everyone, a seeker that picks a target.
const FLIGHT := {"missile": 250.0, "lance": 140.0, "rain": 380.0, "seeker": 320.0}
const BOLT_KINDS: Array[String] = ["hit", "absorb", "glance", "locked", "ward", "wasted"]
## What a cast logs after itself, before the next thing happens: its bolts, and what fizzled or burned on the way.
const CAST_PARTS: Array[String] = ["hit", "absorb", "glance", "locked", "ward", "wasted", "defeat", "fizzle", "curse"]
## A cast's magic circle by how much its volley deals (damage and block together), as the old games drew a higher spell
## with a more elaborate circle: [the most power for the tier, animation, size]. Stronger still is the last tier.
const TIERS: Array[Array] = [[11, "cast-sigil-1", 0.8], [34, "cast-sigil", 0.95], [79, "cast-sigil-3", 1.05]]
const GRAND := ["cast-sigil-4", 1.15]
## A blow at least this big (or this share of the foe's health) lands as a critical, with its own animation.
const CRITICAL_AMOUNT := 18
const CRITICAL_SHARE := 0.45
## A volley spreads its launches over about this long, one bolt every `max` ms at most and `min` at least.
const VOLLEY := {"spread": 1300.0, "max": 190.0, "min": 45.0}
## The longest a cast waits (in real time) for its bolts to land before it lets the log move on regardless: a guard
## against an animation that never finishes, never a pace.
const LANDING_CAP_MS := 8000

var stage: BattleStage
## {integrity, integrity_max, block, mana, foes: {uid: foe}} as currently drawn.
var shown: Dictionary = {}
## The log lines played so far, for the battle log.
var lines: Array[Dictionary] = []
var cast_cards: Dictionary = {}
## The walkthrough already showed these cards; with code playback off, the cast shows their motifs instead.
var motifs_shown := false
## The cast being played is a heavy one (many bolts, or a big total): its first blow on each foe falls from above.
var _heavy := false
## The foes a heavy cast's falling blow is falling or has fallen on (its animation while it falls).
var _crashed: Dictionary = {}
## Where the cast's bolts are born: the middle of its circle, and how far round it they may start.
var _circle := Vector2.ZERO
var _circle_reach := 0.0
## Bolts launched and not landed yet. The cast's playback ends when this is back to zero, so every hit is on the bars
## before the screen draws the true state.
var _in_flight := 0


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
	var index := 0
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


func _cast(entry: Dictionary, volley: Array) -> void:
	var bolts := volley.filter(func(e: Dictionary) -> bool: return e.kind in BOLT_KINDS)
	var element: String = bolts[0].get("element", "none") if not bolts.is_empty() else "none"
	shown.mana -= int(entry.get("amount", 0))
	numbers_changed.emit()
	var heavy := bolts.size() >= 4 or _total(bolts) >= 30
	_heavy = heavy
	_crashed = {}
	stage.hero.play("cast-heavy" if heavy else "cast-light")
	stage.hero.flash(Color(UiTheme.element(element), 0.3), 0.4)
	if not motifs_shown:
		for card: Dictionary in cast_cards.get(entry.get("spell", ""), []):
			stage.shard_effect(card)
			if not Settings.reduced_motion:
				await stage.wait(140.0)
	# The program runs: its circle draws itself at the hand and lets go, more elaborate the more it will deal; the
	# strongest also draw a circle on the ground with runes rising round the Maintainer. Each circle brings its own
	# sound, laid out on its beats (SpellAnim).
	var power := _total(bolts)
	var tier: Array = GRAND
	for candidate: Array in TIERS:
		if power <= int(candidate[0]):
			tier = candidate.slice(1)
			break
	var sigil := stage.spell(String(tier[0]), stage.hero.hand_point(), element, float(tier[1]))
	if sigil == null:
		sigil = stage.spell("cast-sigil", stage.hero.hand_point(), element, 1.2 if heavy else 0.9)
	if tier[0] in ["cast-sigil-3", "cast-sigil-4"]:
		var feet := stage.hero.position + Vector2(stage.hero.size.x * 0.5, stage.hero.size.y)
		stage.spell("cast-ground", feet, element, stage.hero.size.y / 440.0)
	_circle = stage.hero.hand_point()
	_circle_reach = (float(sigil.facts.size[0]) * 0.18 * sigil.scale.x) if sigil != null else 0.0
	if heavy:
		stage.dim(0.38, 0.3)
	if sigil == null:
		Sound.play("sfx-cast-sigil", 0.8)
		stage.cast_flash(element, heavy)
		if heavy:
			stage.vortex(element, 0.62)
		await stage.wait(380.0)
	else:
		await stage.wait(sigil.impact_time() * 1000.0)
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
	for hit: Dictionary in volley:
		if not hit.kind in BOLT_KINDS:
			continue
		_in_flight += 1
		_launch(hit, _flight(hit), volley)
		await stage.wait(gap)
	# LEARN: wait for the landings themselves, not for a guess at how long they take. A heavy cast's later bolts wait
	# for the blow falling on their foe, every blow waits for its brackets to slam, and hit-stops stretch all of it; a
	# fixed wait let the log move on with hits still to come, and the screen then drew the true state over a bar that
	# still showed the foe alive.
	var deadline := Time.get_ticks_msec() + LANDING_CAP_MS
	while _in_flight > 0 and stage.is_inside_tree() and Time.get_ticks_msec() < deadline:
		await stage.get_tree().process_frame
	# A beat after the last blow, before the foes answer.
	await stage.wait(400.0)
	if heavy:
		stage.dim(0.0, 0.4)


func _launch(hit: Dictionary, flight: float, volley: Array) -> void:
	# Born somewhere on the cast's circle, so a volley fans out of it rather than out of one point.
	var angle := randf() * TAU
	var from := _circle + Vector2(cos(angle), sin(angle)) * _circle_reach * randf_range(0.5, 1.0)
	if _circle == Vector2.ZERO:
		from = stage.hero.hand_point()
	if hit.kind == "ward":
		stage.fly(
			from, stage.hero.body_point(), hit.get("element", "none"), flight * 0.6, _land.bind(hit, volley), true
		)
		return
	var view: FoeView = stage.foes.get(hit.get("foe", ""))
	if view == null:
		_land(hit, volley)
		return
	var pending: Variant = _crashed.get(hit.foe)
	# LEARN: validity first. `is` on an object that has been freed is a script error that stops this function, and the
	# falling blow frees itself when its animation ends: a bolt launched after that never flew, and its damage never
	# reached the bar. is_instance_valid is safe on anything, freed or not an object at all.
	if is_instance_valid(pending) and pending is SpellAnim:
		# The foe's falling blow lands first; the bolts after it fly once it has.
		await (pending as SpellAnim).landed()
	if _heavy and not _crashed.has(hit.foe) and SpellAnim.has("hit-heavy"):
		# A heavy cast's first blow on a foe does not fly: blocks of code fall on it from above.
		_crashed[hit.foe] = true
		var crash := stage.spell(
			"hit-heavy", view.foot_point(), hit.get("element", "none"), 0.9 + minf(0.5, view.sprite_width() / 400.0)
		)
		if crash != null:
			_crashed[hit.foe] = crash
			await crash.landed()
			stage.hit_stop(80.0)
		_land(hit, volley, true)
		return
	var power := float(int(hit.get("amount", 0)) + int(hit.get("blocked", 0)) + int(hit.get("overkill", 0)))
	stage.fly(from, view.target_point(), hit.get("element", "none"), flight, _land.bind(hit, volley), false, power)


## A bolt reaches its mark. A hit first plays its blow (brackets slamming on the foe) and lands on the frame they meet;
## `crashed` when a heavy blow already fell there.
func _land(hit: Dictionary, volley: Array, crashed := false) -> void:
	var element: String = hit.get("element", "none")
	var struck := false
	if hit.kind == "hit" and not crashed:
		var aimed: FoeView = stage.foes.get(hit.get("foe", ""))
		if aimed != null:
			var weight := float(hit.get("amount", 0)) / maxf(1.0, float(shown.foes.get(hit.foe, {}).get("max", 1)))
			# A big blow lands as a critical: drawn in first, then breaking open with two shockwaves, a longer stop and
			# a shake; the rest slam their brackets, larger for more damage.
			var critical := int(hit.get("amount", 0)) >= CRITICAL_AMOUNT or weight >= CRITICAL_SHARE
			var blow: SpellAnim = null
			if critical:
				blow = stage.spell("hit-critical", aimed.target_point(), element, 0.75 + minf(0.45, weight * 0.6))
			if blow == null:
				blow = stage.spell("hit-compile", aimed.target_point(), element, 0.75 + minf(0.6, weight * 1.2))
			if blow != null:
				struck = true
				await blow.landed()
				stage.hit_stop(95.0 if critical else 30.0)
				if critical:
					stage.shake(0.8)
	match hit.kind:
		"ward":
			shown.block += int(hit.amount)
			# The honeycomb (about 224 px tall as drawn) covers the Maintainer from hat to boots.
			var cover := stage.hero.size.y * 0.92 / 224.0
			if (
				stage.spell("ward-hex", stage.hero.body_point() - Vector2(0, stage.hero.size.y * 0.06), "ward", cover)
				== null
			):
				stage.ward_glow()
				Sound.play("sfx-ward-hex", 0.7)
			stage.popup(stage.hero.body_point() - Vector2(0, 60), "+%d block" % int(hit.amount), UiTheme.TEAL, 28)
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
				stage.popup(view.top_point(), "nullified", UiTheme.SHARD, 24)
			Sound.play("sfx-gulp", 0.7)
		"glance":
			var view: FoeView = stage.foes.get(hit.foe)
			if view != null:
				stage.popup(view.top_point(), "glance", UiTheme.MUTED, 24)
			Sound.play("sfx-ricochet", 0.7)
		"locked":
			# A deadlock held (ADR-0017): the bolt rings off a lock whose partner this program never touched.
			var view: FoeView = stage.foes.get(hit.foe)
			if view != null:
				stage.popup(view.top_point(), "locked", UiTheme.WARN, 26)
				view.recoil(0.5)
			Sound.play("sfx-lock", 0.8)
		"wasted":
			# A program's bolt aimed at a foe that already fell (ADR-0012): it sails through the empty air.
			var view: FoeView = stage.foes.get(hit.foe)
			if view != null:
				stage.popup(view.top_point() + Vector2(0, 30), "wasted %d" % int(hit.amount), UiTheme.FAINT, 20)
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


func _one(entry: Dictionary) -> void:
	match entry.kind:
		"enter":
			stage.banner(entry.text, UiTheme.AMBER, 900.0)
			await stage.wait(700.0)
		"turn":
			stage.banner("Turn %d" % int(entry.amount), UiTheme.AMBER, 500.0)
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
				stage.popup(view.top_point(), "+%d shield" % int(entry.amount), UiTheme.TEAL, 26)
			Sound.play("sfx-foe-shield", 0.6)
			await stage.wait(460.0)
		"stoke":
			var view: FoeView = stage.foes.get(entry.foe)
			var foe: Dictionary = shown.foes.get(entry.foe, {})
			if not foe.is_empty():
				foe.stoked = true
			if view != null:
				view.show_foe(foe)
				stage.popup(view.top_point(), "stoked!", UiTheme.ELEMENTS.fire, 26)
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
				stage.popup(view.top_point() - Vector2(0, 24), "⚡ faster  %d ops" % int(entry.amount), UiTheme.WARN, 26)
			if clock == null:
				Sound.play("sfx-tempo", 0.6)
			await stage.wait(560.0)
		"timeout":
			stage.banner("Time limit exceeded", UiTheme.FAIL, 1000.0)
			stage.popup(stage.hero.hand_point(), "%d ops" % int(entry.amount), UiTheme.FAIL, 28)
			stage.hero.flash(Color(UiTheme.FAIL, 0.3))
			shown.mana -= int(entry.get("cost", 0))
			numbers_changed.emit()
			Sound.play("sfx-timeout", 0.7)
			await stage.wait(1100.0)
		"fizzle":
			stage.popup(stage.hero.hand_point(), "fizzle", UiTheme.MUTED, 26)
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
			stage.popup(stage.hero.body_point() - Vector2(0, 60), "+%d block" % int(entry.amount), UiTheme.TEAL, 26)
			numbers_changed.emit()
			await stage.wait(360.0)
		"mana":
			shown.mana += int(entry.amount)
			stage.popup(stage.hero.hand_point(), "+%d mana" % int(entry.amount), UiTheme.SHARD, 26)
			numbers_changed.emit()
			await stage.wait(300.0)
		"victory":
			stage.hero.play("victory")
			stage.banner("Victory", UiTheme.PASS, 1100.0)
			Sound.cue("cue-victory", 0.8)
			await stage.wait(1300.0)
		"loss":
			stage.hero.play("death")
			stage.banner("Kernel panic", UiTheme.FAIL, 1400.0)
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
		stage.popup(at + Vector2(-60, -40), "%d blocked" % blocked, UiTheme.TEAL, 24)
		Sound.play("sfx-clang", 0.6)
	numbers_changed.emit()
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


static func _total(bolts: Array) -> int:
	var total := 0
	for bolt: Dictionary in bolts:
		total += int(bolt.get("amount", 0))
	return total
