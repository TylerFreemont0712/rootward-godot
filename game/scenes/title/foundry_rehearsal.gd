class_name FoundryRehearsal
extends Control
## The practice ring (ADR-0036, ADR-0037): a real BattleStage, so the skin, its size, its circles, its bolts and its
## impacts are exactly a fight's. A test cast is a made-up log played by the fight's own LogPlayer against practice
## targets that never fall. The stage keeps a clock of its own (speed, pause, frame steps) and changes no run, no
## equipment and no loadout: a look is only tried on (`set_look`) until the room saves it.

signal skin_ready

## A test cast's volley by weight: [bolts, power each]. The fight decides from these, as from any volley, whether she
## casts it light (a snap) or heavy (a gathering). Its circle follows the shards chosen, not the volley (ADR-0039).
const WEIGHTS: Array[Array] = [[3, 3], [6, 10]]
const PRACTICE_FOE := "tally-wisp"
const PRACTICE_HP := 999
const ARENA := "arena-ring-3-sandbox"

var stage: BattleStage
var hero: HeroView:
	get:
		return stage.hero if stage != null else null
var clip := StageCharacter.IDLE
var speed := 1.0
var paused := true
var looping := false
## How many shards the practice spell has (1..6): the circle's tier and its layers.
var shards := 4
## Cast it heavy (a gathering and a falling blow) rather than light (a snap).
var heavy := false
## The circle's tier for the shards chosen; setting it chooses as many shards as that tier holds (the fight's four
## circles by name: light I, II, heavy III, IV as the room used to offer them).
var tier: int:
	get:
		return CircleLayers.tier_for(shards)
	set(value):
		shards = CircleLayers.capacity(value)
var element := "none"
var targets := 1
var arena := true
var view_angle := 35.0
var marks := false
## The loadout being tried on, {slot: option id}; the rest is what the player wears.
var preview_loadout: Dictionary = {}
## Seconds into the clip being inspected (the Motion tab's timeline).
var _elapsed := 0.0
var _serial := 0
var _playing := false
var _circle: MagicCircle
var _catalog: Dictionary = {}
var _marks: Control


func _ready() -> void:
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage = BattleStage.new()
	stage.local_clock = true
	stage.foe_span = Vector2(0.44, 0.95)
	stage.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(stage)
	_marks = Control.new()
	_marks.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_marks.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_marks.draw.connect(_draw_marks)
	add_child(_marks)
	preview_loadout = Cosmetics.loadout()
	_catalog = Game.catalog
	set_arena(arena)
	resized.connect(_fit)


func set_skin(id: String) -> void:
	await _cancel()
	hero.preview_loadout = preview_loadout
	hero.set_preview_skin(id)
	_apply_speed()
	_foes()
	clip = hero.move_clip("idle")
	_elapsed = 0.0
	_fit()
	seek(0.0)
	skin_ready.emit()


## Tries a look on (a slot's option) without saving it: the idle changes at once, the rest on the next cast.
func set_look(slot: String, id: String) -> void:
	preview_loadout[slot] = id
	if hero != null:
		hero.set_preview_loadout(preview_loadout)


func clips() -> Array[String]:
	var available: Array[String] = []
	if hero == null:
		return available
	available = hero.clips().filter(
		func(id: String) -> bool: return not id.ends_with("-hold") and not id.ends_with("-end")
	)
	available.sort()
	return available


## Plays one of the skin's clips on its own, the move alone (the Motion tab).
func play(animation: String) -> void:
	if animation not in clips():
		return
	await _cancel()
	clip = animation
	_elapsed = 0.0
	hero.play(clip)
	set_paused(false)
	if looping and not hero.character == null and not hero.character.is_loop(clip):
		_replay_after(duration() + 0.6, _serial)


## The practice spell's cards: as many of the demonstration cards as there are shards (one of each role, up to six).
func cards() -> Array[Dictionary]:
	return CircleLayers.demo_cards(shards)


## A test cast with the chosen shards, against the practice targets, as the fight plays it: the worn (or tried-on)
## cast, circle, bolts and impact. Loops while `looping`. `power` is the older way to choose (a tier 0..3, which also
## set the cast heavy from the third): it sets the shards and the weight.
func test_cast(power := -1) -> void:
	await _cancel()
	if power >= 0:
		tier = clampi(power, 0, 3)
		heavy = power >= 2
	var chosen: Array = WEIGHTS[1 if heavy else 0]
	var player := LogPlayer.new(stage, _state())
	player.cast_cards["practice"] = cards()
	var entries: Array = [{"kind": "cast", "spell": "practice", "amount": 0}]
	var uids: Array = stage.foes.keys()
	for i in int(chosen[0]):
		var uid: String = uids[i % maxi(1, uids.size())] if not uids.is_empty() else ""
		entries.append(
			{
				"kind": "hit",
				"foe": uid,
				"amount": int(chosen[1]),
				"element": element,
				"target": "all" if targets > 1 else "front"
			}
		)
	clip = hero.move_clip("idle")
	_elapsed = 0.0
	set_paused(false)
	_serial += 1
	var serial := _serial
	_playing = true
	await player.play(entries)
	_playing = false
	if serial != _serial:
		return
	_foes()
	if looping:
		_replay_after(0.8, serial, true)


## The worn circle alone with the chosen shards: written layer by layer, firing six times, closing.
func preview_circle() -> void:
	await _cancel()
	set_paused(false)
	_serial += 1
	var serial := _serial
	_playing = true
	_circle = stage.magic_circle(cards(), element, 1.0, true)
	if _circle != null:
		for index in _circle.layers.size():
			if serial != _serial or not is_instance_valid(_circle):
				break
			_circle.construct_shard(index)
			await stage.wait(450.0)
		if serial == _serial and is_instance_valid(_circle):
			_circle.finish_construction()
			await stage.wait(_circle.construction_time_left() * 1000.0)
		for i in 6:
			if serial != _serial or not is_instance_valid(_circle):
				break
			_circle.pulse()
			await stage.wait(160.0)
		if is_instance_valid(_circle):
			_circle.close()
	_playing = false


func _replay_after(seconds: float, serial: int, cast := false) -> void:
	await stage.wait(seconds * 1000.0)
	if serial == _serial and looping and is_inside_tree():
		if cast:
			test_cast()
		else:
			play(clip)


## Lets go of whatever is playing: a cast still running finishes at once (the stage plays fast), and every effect
## is cleared, so nothing from it lands on the next one.
func _cancel() -> void:
	_serial += 1
	if _playing:
		# Played fast and running (even if paused), the cast finishes in a few frames: its bolts land at once.
		stage.fast = true
		stage.process_mode = Node.PROCESS_MODE_INHERIT
		var guard := 0
		while _playing and guard < 90 and is_inside_tree():
			guard += 1
			await get_tree().process_frame
		stage.fast = false
		set_paused(paused)
	_playing = false
	_circle = null
	if stage != null:
		for node in stage._fx.get_children():
			node.queue_free()
	if hero != null:
		hero.end_cast()


func set_paused(value: bool) -> void:
	paused = value
	if stage != null:
		stage.process_mode = Node.PROCESS_MODE_DISABLED if paused else Node.PROCESS_MODE_INHERIT
	_apply_speed()


func set_speed(value: float) -> void:
	speed = value
	_apply_speed()


func _apply_speed() -> void:
	if stage != null:
		stage.tempo = speed
	if hero != null:
		hero.set_time_scale(speed)


func set_arena(on: bool) -> void:
	arena = on
	stage.set_backdrop(ARENA if on else "")
	stage._backdrop.visible = on
	stage._grade.visible = on


func set_targets(count: int) -> void:
	targets = clampi(count, 1, 3)
	_foes()


## The practice targets: training wisps of the run's catalogue that never fall, at full health again after each cast.
func _foes() -> void:
	var content: Dictionary = _catalog.get("foes", {}).get(PRACTICE_FOE, {})
	if content.is_empty() or stage == null:
		return
	var states: Array = []
	for i in targets:
		(
			states
			. append(
				{
					"uid": "practice-%d" % i,
					"id": PRACTICE_FOE,
					"name": FoundryUi.text("Practice Wisp", "練習のウィスプ"),
					"sprite": String(content.get("sprite", PRACTICE_FOE)),
					"hp": PRACTICE_HP,
					"max": PRACTICE_HP,
					"shield": 0,
					"intents": [],
					"intent_index": 0,
				}
			)
		)
	if stage.foes.size() == states.size():
		stage.show_foes(states)
	else:
		stage.set_foes(states, _catalog)


func _state() -> Dictionary:
	var foes: Array = []
	for view: FoeView in stage.foes.values():
		foes.append(view.foe.duplicate(true))
	return {"integrity": 60, "integrity_max": 60, "battle": {"foes": foes, "block": 0, "mana": 5}}


func duration() -> float:
	if hero == null:
		return 0.0
	if hero.sprite != null:
		return hero.sprite._duration(hero.sprite.manifest.get("clips", {}).get(clip, {}))
	if hero.character != null and hero.character.player != null and hero.character.player.has_animation(clip):
		return hero.character.player.get_animation(clip).length
	return 0.0


## Shows one moment of the clip, still: the pose sampled directly, without a blend from a previous one.
func seek(seconds: float) -> void:
	await _cancel()
	set_paused(true)
	_elapsed = clampf(seconds, 0.0, duration())
	if hero.sprite != null:
		hero.sprite.play(clip)
		hero.sprite._time = _elapsed
		var info: Dictionary = hero.sprite.manifest.clips.get(clip, {})
		hero.sprite.frame = clampi(hero.sprite._frame_at(info, _elapsed), 0, maxi(0, int(info.get("frames", 1)) - 1))
		hero.sprite.queue_redraw()
	elif hero.character != null and hero.character.player != null:
		hero.character.play(clip)
		hero.character.player.play(clip, 0.0)
		hero.character.player.seek(_elapsed, true)


## One thirtieth of a second on (or back, for the inspected clip): the pose, and every effect on the stage with it.
func step(direction: int) -> void:
	if direction < 0:
		seek(_elapsed - 1.0 / 30.0)
		return
	set_paused(true)
	var seconds := 1.0 / 30.0
	if hero.sprite != null:
		hero.sprite._process(seconds / maxf(speed, 0.01))
	elif hero.character != null and hero.character.player != null:
		hero.character.player.advance(seconds)
		if hero.character.skeleton != null:
			hero.character.skeleton.advance(seconds)
	_elapsed += seconds
	stage.advance(seconds)


func _process(delta: float) -> void:
	if not paused:
		_elapsed += delta * speed


func _fit() -> void:
	if hero != null and hero.character != null:
		hero.character.rotation_degrees.y = view_angle
	if _marks != null:
		_marks.queue_redraw()


func _draw_marks() -> void:
	if not marks or hero == null:
		return
	# The figure's height on the stage and the floor it stands on, for judging a skin's size against the others.
	var floor_y := size.y * BattleStage.FLOOR
	var top := floor_y - hero.figure_height()
	_marks.draw_line(Vector2(0, floor_y), Vector2(size.x, floor_y), Color(UiTheme.AMBER, 0.5), 1.0)
	_marks.draw_dashed_line(Vector2(0, top), Vector2(size.x * 0.5, top), Color(UiTheme.TEAL, 0.6), 1.0, 6.0)
