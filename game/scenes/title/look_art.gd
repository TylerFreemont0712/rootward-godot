class_name LookArt
extends Control
## The picture on a cosmetic option's card (ADR-0037), drawn by the game's own effects rather than painted: a magic
## circle writing itself in its style, a bolt's sheet flying in place, an impact's sheet landing, or a move's pose
## on the motion dummy (a picture made by tools/move_thumbs). While `live` it plays on a loop; otherwise it holds its
## most telling moment, still. Silent: the cards never make a sound.

const LOOP_SECONDS := 2.6

var slot := ""
var option: Dictionary = {}
var live := false
var _clock := 0.0
var _effect: Node2D


static func make(for_slot: String, for_option: Dictionary) -> LookArt:
	var art := LookArt.new()
	art.slot = for_slot
	art.option = for_option
	art.clip_contents = true
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if for_slot in CosmeticRules.NATIVE and for_option.get("construction", "") != "shards":
		var picture := Ui.picture("menus/moves/" + String(for_option.get("clip", "")), Vector2(150, 150), "✦")
		picture.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		picture.offset_bottom = -30
		art.add_child(picture)
	art.resized.connect(art._restart)
	return art


func set_live(value: bool) -> void:
	if live == value and _effect != null:
		return
	live = value
	_restart()


func _restart() -> void:
	var construction: bool = option.get("construction", "") == "shards"
	if (slot in CosmeticRules.NATIVE and not construction) or size.x < 8.0 or not is_inside_tree():
		return
	if is_instance_valid(_effect):
		_effect.queue_free()
	_effect = null
	_clock = 0.0
	var middle := Vector2(size.x * 0.5, (size.y - 30.0) * 0.5)
	if construction:
		var circle := MagicCircle.cast(self, middle, 1, "none", minf(size.x, size.y) * 0.3, "", 1.0, true)
		circle.style = String(option.get("circle_style", "codex"))
		circle.external_construction = true
		circle.use_plan(CircleLayers.demo_plan(1))
		circle.position.x -= circle.radius * 0.35
		circle.set_process(false)
		_effect = circle
		if not live:
			_advance(1.6)
		return
	match slot:
		"circle":
			var circle := MagicCircle.cast(self, middle, 2, "none", minf(size.x, size.y) * 0.3, "", 1.0, true)
			circle.style = String(option.get("style", "codex"))
			circle.use_plan(CircleLayers.demo_plan(3 if circle.style == "ring-bloom" else 2))
			circle.position.x -= circle.radius * 0.35
			circle.set_process(false)
			_effect = circle
			if not live:
				_advance(circle.form_time() * 1.1)
		"bolt":
			var bolt := SpellAnim.play(
				self, String(option.get("sprite", "")), middle, "none", size.x / 300.0, 0.0, true
			)
			if bolt != null:
				bolt.set_process(false)
				_effect = bolt
				_advance(0.1)
		"impact":
			var foot := Vector2(size.x * 0.5, size.y - 40.0)
			var blow := SpellAnim.play(self, String(option.get("sprite", "")), foot, "none", size.y / 520.0, 0.0, true)
			if blow != null:
				blow.looping = true
				blow.set_process(false)
				_effect = blow
				_advance(blow.impact_time() + 0.12)


func _advance(seconds: float) -> void:
	var left := seconds
	while left > 0.0 and is_instance_valid(_effect):
		var step := minf(left, 1.0 / 30.0)
		_tick(step)
		left -= step


func _tick(seconds: float) -> void:
	_clock += seconds
	if _effect is MagicCircle and (_effect as MagicCircle).external_construction:
		var circle := _effect as MagicCircle
		for index in circle.layers.size():
			var start := 0.15 + index * 0.32
			if _clock < start:
				break
			circle.trace_shard(index, (_clock - start) / 0.32)
		if _clock >= 0.15 + circle.layers.size() * 0.32:
			circle.finish_construction()
	_effect.call("_process", seconds)


func _process(delta: float) -> void:
	if not live:
		return
	if not is_instance_valid(_effect):
		_restart()
		return
	_tick(delta)
	if _effect is MagicCircle:
		var circle := _effect as MagicCircle
		if _clock > circle.form_time() + 1.2 and circle._closing < 0.0:
			circle.close()
	if _clock >= LOOP_SECONDS:
		_restart()
