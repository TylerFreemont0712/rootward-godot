class_name BlackHoleImpact
extends Node2D
## A black-hole impact (docs/LEGENDARY_LOOKS.md, "The black-hole impact"): a Node2D holding a BackBufferCopy, which
## copies the screen under the quad, and a ColorRect whose ShaderMaterial (black_hole.gdshader) draws the hole. The quad
## is QUAD_RADII radii across and centred on this node; the disc is `radius` pixels. It plays once: `impact` at
## IMPACT_SHARE of its timeline, `finished` at the end, and then it frees itself. Its point is global, and the node
## keeps itself on that point through its parent every frame.

signal impact
signal finished

const SHADER_PATH := "res://scenes/shardrun/fight/black_hole.gdshader"
## The quad's width, in disc radii: the shock ring reaches 2.4 and the jets 1.9, so 5.0 (2.5 a side) holds both.
const QUAD_RADII := 5.0
## The timeline's length in seconds, full and reduced, and the share of it at which the blow lands.
const FULL_SECONDS := 1.2
const REDUCED_SECONDS := 0.6
const IMPACT_SHARE := 0.25
## The draw order among the fight's effects: the volley draws at 2, over the hole, so its bloom shows.
const DRAW_ORDER := 1
## The impact style's keys. Each is also a shader uniform of the same name.
const STYLE_UNIFORMS: Array[String] = [
	"bands",
	"spin",
	"tilt",
	"jets",
	"lens",
	"hue",
	"photon_sides",
	"arms",
	"scanlines",
	"digits",
	"split",
	"cells",
	"rings",
]
## The releases of blows that left the tree before their impact, until their deferred release runs (see _exit_tree).
static var _leaving: Array[_Release] = []

## How fast its time runs, as a SpellAnim's does: BattleStage sets it on each effect of its layer. 1 in a fight.
var time_scale := 1.0
## The timeline's progress, 0 to 1. The shader's `progress` uniform follows it.
var progress := 0.0
## The timeline's length in seconds: FULL_SECONDS, or REDUCED_SECONDS when Settings.reduced_motion is on.
var duration := FULL_SECONDS
## The point the hole sits on, in global coordinates.
var _at := Vector2.ZERO
var _elapsed := 0.0
## Set when the blow lands, or when the node leaves the tree first (see _exit_tree): its waiters are released then.
var _landed := false
var _done := false
var _material: ShaderMaterial
var _copy: BackBufferCopy
var _copy_area := Rect2()
## What the blow's waiters await. It is a RefCounted, so it outlives this node (see _exit_tree).
var _release := _Release.new()


func _init() -> void:
	# LEARN: z_index is relative to the effects layer the hole is parented to, so the volley's 2 draws over this 1 in any
	# parent. It is set here rather than in play(), so a hole made with new() draws in the same order.
	z_index = DRAW_ORDER


## Plays a black-hole impact under `parent`, centred on `at`, a global point. `radius` is the disc's radius in
## pixels, and `look` holds `role` and `card`, which choose its features (LegendaryLook.impact_style). Returns the
## node, already in the tree: its clock runs only from _process, so nothing is emitted before then.
static func play(parent: Node, at: Vector2, radius: float, look: Dictionary) -> BlackHoleImpact:
	var hole := BlackHoleImpact.new()
	hole._at = at
	hole._build(radius, look)
	parent.add_child(hole)
	return hole


## The signal the blow's waiters await: `await hole.landed()`. It is emitted at the impact, or when the node leaves
## the tree before it, so no waiter is left waiting. It is emitted once and never again, so awaiting it after
## either has happened never resumes: a caller that may come late awaits landed_of instead.
func landed() -> Signal:
	return _release.released


## Returns once the blow has landed or has left the tree, at once if either has happened: a safe thing to await. It is
## static, because a coroutine of an instance is cancelled when that instance is freed, which an early removal does.
static func landed_of(hole: BlackHoleImpact) -> void:
	if is_instance_valid(hole) and not hole._landed:
		await hole._release.released


## The material that draws the hole, or null when the shader did not load (the timeline still runs).
func shader_material() -> ShaderMaterial:
	return _material


func _ready() -> void:
	_follow()
	_fit_copy()


func _process(frame_delta: float) -> void:
	# LEARN: the time_scale convention is SpellAnim's. _process gets the frame's time, and the node's own time_scale
	# multiplies it here. BattleStage._keep_time relies on that: its by-hand step calls _process with seconds / tempo,
	# so the clock moves by `seconds`.
	_follow()
	_fit_copy()
	var delta := frame_delta * time_scale
	advance(delta)


## Moves the timeline on by `delta` seconds. `_process` calls it every frame with the scaled time, and a test may
## call it directly. The clock runs only while the node is in the tree, so no signal is emitted before the node is.
func advance(delta: float) -> void:
	# LEARN: the clock stops out of the tree, so an impact is never emitted for a node its parent does not hold yet.
	if _done or not is_inside_tree():
		return
	# LEARN: the clock is here rather than in a Tween, so a test steps it exactly and the shader sees only `progress`.
	_elapsed += delta
	progress = clampf(_elapsed / duration, 0.0, 1.0)
	_set_param("progress", progress)
	if not _landed and progress >= IMPACT_SHARE:
		_strike()
	if progress >= 1.0:
		_done = true
		finished.emit()
		queue_free()


## The blow lands on its frame: its impact is emitted for the listeners, and whoever waits for it is released.
func _strike() -> void:
	_landed = true
	impact.emit()
	_release.released.emit()


## A node that leaves the tree before its impact still releases its waiters: an awaited signal that never fires
## would hold that code forever. The release waits for this removal to end, because a waiter that adds a child to the
## parent would fail while the parent is busy with the removal. The release sits in a static list until the deferred
## call runs, so neither depends on this node, which may be freed before then.
# LEARN: a node's own signal cannot be emitted once the node is freed, and emitting it here would run its waiters
# inside the parent's removal. The release is a RefCounted that outlives the node, and it is emitted after the
# removal, as SpellAnim's is.
func _exit_tree() -> void:
	if not _landed:
		_landed = true
		_leaving.append(_release)
		BlackHoleImpact._release_leaving.call_deferred()


## Releases the blows that left the tree before their impact (see _exit_tree), now that their removals have ended.
static func _release_leaving() -> void:
	var waiting := _leaving.duplicate()
	_leaving.clear()
	for release: _Release in waiting:
		release.released.emit()


## Puts the node on its point: each frame, its position is the point in its parent's space.
# LEARN: the node's own to_local is measured from where the node already is, so setting the position from it would
# move the node every frame. The parent's transform is the space a child's position is in, and the fight's effects
# layer is a Control, which is read through CanvasItem.get_global_transform.
func _follow() -> void:
	position = _local_at()


## The global point in the parent's space: through the inverse of the parent's transform. A parent that is not a
## CanvasItem has no transform of its own, so the point is the position as it is.
func _local_at() -> Vector2:
	var host := get_parent() as CanvasItem
	if host == null:
		return _at
	return host.get_global_transform().affine_inverse() * _at


func _build(radius: float, look: Dictionary) -> void:
	var reduced := Settings.reduced_motion
	duration = REDUCED_SECONDS if reduced else FULL_SECONDS
	var side := QUAD_RADII * radius
	var area := Rect2(Vector2(-side, -side) * 0.5, Vector2(side, side))
	var shader := load(SHADER_PATH) as Shader
	# LEARN: without the shader the timeline still runs and emits its signals, so a caller awaiting `landed()` never hangs.
	if shader == null:
		return
	_add_screen_copy(area, reduced)
	_add_quad(area, shader, look, reduced)


## A BackBufferCopy over the quad. It copies the screen under the quad into the back buffer before the quad draws, and
## the shader reads that copy. In reduced motion nothing is bent, so no copy is made.
func _add_screen_copy(area: Rect2, reduced: bool) -> void:
	_copy = BackBufferCopy.new()
	_copy.copy_mode = BackBufferCopy.COPY_MODE_DISABLED if reduced else BackBufferCopy.COPY_MODE_RECT
	_copy_area = area
	add_child(_copy)


## Points the copy's rect at the quad. The rect is in viewport coordinates, so this node's global transform moves it.
func _fit_copy() -> void:
	# LEARN: a BackBufferCopy's rect is read in viewport coordinates, not in the copy's own space. Set in _build, it
	# copied the wrong patch of screen, and the lens read flat grey. So it is set once the node is in the tree, and
	# again every frame after that.
	if _copy != null:
		_copy.rect = get_global_transform() * _copy_area


func _add_quad(area: Rect2, shader: Shader, look: Dictionary, reduced: bool) -> void:
	var quad := ColorRect.new()
	quad.position = area.position
	quad.size = area.size
	quad.color = Color.WHITE
	quad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_material = ShaderMaterial.new()
	_material.shader = shader
	quad.material = _material
	add_child(quad)
	_set_uniforms(look, reduced)


func _set_uniforms(look: Dictionary, reduced: bool) -> void:
	var style := LegendaryLook.impact_style(str(look.get("role", "")), str(look.get("card", "")))
	for key: String in STYLE_UNIFORMS:
		_set_param(key, style[key])
	# LEARN: the inflow arms are motion, so reduced motion drops them (LEGENDARY_LOOKS.md, v3.4). The shader draws arms
	# only while this uniform is above 0, so 0 draws none. The shader also checks `reduced`, so the rule holds for any
	# shader set up by hand.
	if reduced:
		_set_param("arms", 0)
	_set_param("radius_uv", 1.0 / QUAD_RADII)
	_set_param("reduced", reduced)
	_set_param("progress", progress)


func _set_param(param: String, value: Variant) -> void:
	if _material != null:
		_material.set_shader_parameter(param, value)


## The signal a blow's waiters await: a class of its own, so the signal outlives the node that owns it.
class _Release:
	extends RefCounted
	signal released
