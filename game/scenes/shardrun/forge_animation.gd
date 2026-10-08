class_name ForgeAnimation
extends RefCounted
## The forge's two card changes, played on the card itself. A melt covers the card with a rune circle, then breaks it
## away; a refactor flashes the card and turns it into its better version: the same card, changed from one to the
## other. Each returns its tween so the caller can wait for it, or null when the motion is skipped (tests, reduced
## motion).

const MELT_SECONDS := 0.95
const MORPH_SECONDS := 0.8

## Tests skip the motion, as BattleStage does.
static var instant := false


## `holder` is the card's box, which must be the card's size, and `face` is the card in it.
static func melt(holder: Control, face: CardFace) -> Tween:
	if _skipped():
		return null
	Sound.play("sfx-glyph", 0.8)
	var rune := ForgeRune.new()
	rune.set_anchors_preset(Control.PRESET_FULL_RECT)
	rune.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(rune)
	face.pivot_offset = holder.custom_minimum_size * 0.5
	var tween := holder.create_tween()
	tween.tween_property(rune, "progress", 1.0, MELT_SECONDS * 0.6).set_trans(Tween.TRANS_SINE).set_ease(
		Tween.EASE_IN_OUT
	)
	tween.tween_callback(Sound.play.bind("sfx-shatter", 0.9))
	var gone := MELT_SECONDS * 0.4
	tween.tween_property(face, "modulate", Color(1.0, 0.5, 0.45, 0.0), gone).set_trans(Tween.TRANS_QUAD).set_ease(
		Tween.EASE_IN
	)
	tween.parallel().tween_property(face, "scale", Vector2(0.55, 0.55), gone).set_trans(Tween.TRANS_BACK).set_ease(
		Tween.EASE_IN
	)
	tween.parallel().tween_property(rune, "modulate:a", 0.0, gone)
	return tween


## The card flashes while its old face fades and the better one turns in over it, in the same box.
static func morph(holder: Control, before: CardFace, after: CardFace) -> Tween:
	if _skipped():
		# The better card was never shown, so nothing else will free it.
		after.free()
		return null
	Sound.play("sfx-forge", 0.8)
	var centre := holder.custom_minimum_size * 0.5
	after.set_anchors_preset(Control.PRESET_FULL_RECT)
	after.modulate.a = 0.0
	after.scale = Vector2(0.86, 0.86)
	after.pivot_offset = centre
	before.pivot_offset = centre
	holder.add_child(after)
	var flash := ColorRect.new()
	flash.color = Color(1.0, 0.95, 0.8, 0.0)
	flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(flash)
	var tween := holder.create_tween().set_parallel(true)
	tween.tween_property(flash, "color:a", 0.7, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(flash, "color:a", 0.0, MORPH_SECONDS * 0.5).set_delay(0.18)
	tween.tween_property(before, "modulate:a", 0.0, MORPH_SECONDS * 0.4).set_delay(0.06)
	tween.tween_property(after, "modulate:a", 1.0, MORPH_SECONDS * 0.5).set_delay(0.2)
	(
		tween
		. tween_property(after, "scale", Vector2.ONE, MORPH_SECONDS * 0.6)
		. set_delay(0.2)
		. set_trans(Tween.TRANS_BACK)
		. set_ease(Tween.EASE_OUT)
	)
	tween.finished.connect(flash.queue_free)
	return tween


static func _skipped() -> bool:
	return instant or Settings.reduced_motion
