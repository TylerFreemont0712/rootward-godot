class_name LegendaryCast
extends RefCounted
## One cast's state (docs/LEGENDARY_LOOKS.md, "Fight wiring"): its serial, whether it is heavy and the falling blow each
## foe took, its constellation volley, the point each foe was aimed at, the foes whose black hole has opened, and the
## origin its bolts are born from. LogPlayer makes one for each cast and keeps that reference, so a bolt that resumes
## after the next cast has started still joins the cast it was launched in, and reads that cast's own state. Points are
## global. The decisions read plain values, so the tests run them without a stage; the helpers that draw (a bolt's ride,
## a hole, a blow) take the fight's stage as their first argument.

## A foe's first blow in a cast under the black-hole impact opens a hole this wide, in pixels; a heavy cast's, wider.
const HOLE_RADIUS := 120.0
const HOLE_HEAVY_RADIUS := 150.0

## The cast's serial, counted once per cast by the stage (BattleStage.next_cast_serial): each bolt's seed, and so its
## path, comes from it.
var serial := 0
## Whether the cast is heavy (three or more shards): its first blow on each foe falls from above, and its hole is wider.
var heavy := false
## Each foe's heavy first blow this cast: the falling SpellAnim while it falls, then true. A bolt that waits behind it
## reads it here, from its own cast, however late it resumes.
var crashed: Dictionary = {}
## The cast's constellation volley, made on its first legendary bolt; null until then.
var volley: ConstellationVolley
## The orrery's final star this cast last read, global (the launch point for a circle that is not an orrery). Seeded at
## the first launch and kept once the circle has freed, so a volley that reads its origin late still rides from it.
var last_origin := Vector2.ZERO
## Each foe's aim, global, taken at this cast's first launch to that foe.
var _aims: Dictionary = {}
## The foes whose black hole has opened this cast.
var _holed: Dictionary = {}
## Whether the origin has been seeded, at the cast's first launch.
var _seeded := false
## Whether the next cast has started (or the log has ended): a volley made for a bolt that arrives after that is closed.
var _closed := false


func _init(cast_serial: int, cast_heavy: bool = false) -> void:
	serial = cast_serial
	heavy = cast_heavy


## The point a bolt aimed at `foe` flies to, global. `live` gives the foe's point, global, and is called only at this
## cast's first launch to that foe. The point is kept after, so the foe's bolts and its black hole share one point
## even if the foe moves.
func target_of(foe: String, live: Callable) -> Vector2:
	if not _aims.has(foe):
		_aims[foe] = live.call()
	return _aims[foe] as Vector2


## Whether a landing opens the foe's black hole: the first non-critical hit on that foe in this cast. A critical hit
## does not open it (its own blow plays), a ward's bolt never does, and a foe whose hole has opened does not open again.
func opens_hole(foe: String, kind: String, critical: bool) -> bool:
	if kind != "hit" or critical or _holed.has(foe):
		return false
	_holed[foe] = true
	return true


## A point in the coordinates `node` is positioned in (its parent's, as its `position` is), as a global point. A foe's
## target and the Maintainer's hand and body are in the world layer's coordinates; a circle's launch point is in the
## effects layer's.
# LEARN: each point converts with its own node's parent, not with the stage's transform. The world and effects layers
# shake together, so the stage's own transform misses the shake, and a bolt would start a few pixels off.
static func global_of(node: CanvasItem, point: Vector2) -> Vector2:
	return (node.get_parent() as CanvasItem).get_global_transform() * point


## The draw of the option worn in `slot`: "constellation" or "black-hole" for the legendary bolt or impact, else "".
static func worn_draw(stage: BattleStage, slot: String) -> String:
	return String(stage.hero.look(slot).get("draw", ""))


## The sheet a heavy cast's first blow falls with: "" for a black hole, which is the blow itself (it does not fall back
## to the falling code's hit-heavy); else the worn impact's sheet, else the falling code's, or "" if neither plays.
static func crash_sheet(stage: BattleStage) -> String:
	if worn_draw(stage, "impact") == "black-hole":
		return ""
	var look := stage.hero.look("impact")
	for sheet: String in [String(look.get("sprite", "")), "hit-heavy"]:
		if sheet != "" and SpellAnim.has(sheet):
			return sheet
	return ""


## Where the cast's bolts are born, global, read once a frame: the orrery's final star while `circle` is a valid orrery,
## else the global point `launch`. The first call seeds the cast's point from the circle's final star (or from
## `launch`), and each read of a valid orrery keeps its star on the cast. Once the circle has freed, the origin returns
## the last star read, so bolts still in the air do not jump, and never the orrery's centre.
func origin_of(circle: MagicCircle, launch: Vector2) -> Callable:
	# LEARN: the point lives on the cast, not in the closure, so every bolt of the cast shares it. A volley can first read
	# its origin after its circle has freed (a bolt waited behind a falling blow). It then gets the star the cast last saw.
	var orrery: MagicCircle = circle if _is_orrery(circle) else null
	if not _seeded:
		_seeded = true
		last_origin = orrery.final_node_global() if orrery != null else launch
	# LEARN: the closure holds the circle through a WeakRef. A lambda that captures a freed object is called with null and
	# logs "Lambda capture ... was freed" on every call, and a volley reads its origin each frame until the cast ends.
	var circle_ref: WeakRef = weakref(orrery) if orrery != null else null
	return func() -> Vector2:
		var live: MagicCircle = circle_ref.get_ref() if circle_ref != null else null
		if is_instance_valid(live):
			last_origin = live.final_node_global()
		return last_origin


## Whether `circle` stands and is an orrery: the only style whose final star is a bolt's origin.
static func _is_orrery(circle: MagicCircle) -> bool:
	return is_instance_valid(circle) and circle.style == "orrery"


## Adds a constellation bolt to this cast's volley, which the cast makes on its first bolt, under the stage's effects
## layer. `origin` is the bolt's launch, made by origin_of at launch before any wait, and `target` its aim: both are
## global. `arrive` runs once, when the bolt lands, and `index` is the bolt's place in the cast. A fast stage has no
## flight, so the bolt lands at once, with no volley.
func ride(
	stage: BattleStage, origin: Callable, target: Vector2, hit: Dictionary, index: int, flight: float, arrive: Callable
) -> void:
	# LEARN: a fast stage skips every flight, as BattleStage.fly does, so the bolt lands at once, with no volley.
	if stage.fast:
		arrive.call()
		return
	# LEARN: a freed volley takes no more riders. Its add_rider would land a bolt at once, with a warning, so ride never
	# calls it: a late bolt of this cast starts a new volley and flies on that, and once the cast is closed the new volley
	# closes too, so it frees itself when the bolt lands.
	# Known limit (LEGENDARY_LOOKS.md): a bolt past LANDING_CAP_MS may start a second volley and bloom its foe again.
	if not is_instance_valid(volley) or volley.is_queued_for_deletion():
		volley = ConstellationVolley.start(stage.fx_layer(), origin)
		if _closed:
			volley.close()
	volley.add_rider(target, rider_look(hit, index), flight, arrive)


## No new bolt of this cast is coming: its volley closes, and frees itself once its riders are done.
func close() -> void:
	_closed = true
	if is_instance_valid(volley):
		volley.close()


## The worn black hole for a foe's first non-critical hit this cast, centred where its bolts converge: the aim this cast
## kept for the foe, and wider when the cast is heavy. Null for any other blow, when the impact worn is not a black
## hole, and in fast play.
func open_hole(stage: BattleStage, hit: Dictionary, aimed: FoeView, critical: bool) -> BlackHoleImpact:
	if worn_draw(stage, "impact") != "black-hole" or stage.fast:
		return null
	# LEARN: the hole is keyed by the foe, not the bolt, so one hole stands per foe however many bolts land on it.
	var foe := String(hit.get("foe", ""))
	if not opens_hole(foe, String(hit.get("kind", "")), critical):
		return null
	var at := target_of(foe, func() -> Vector2: return global_of(aimed, aimed.target_point()))
	var look := {"role": String(hit.get("role", "")), "card": String(hit.get("card", ""))}
	return BlackHoleImpact.play(stage.fx_layer(), at, HOLE_HEAVY_RADIUS if heavy else HOLE_RADIUS, look)


## A foe's blow sprite: a critical's own sheet, else the element's, else the bracket slam (null if none can play).
static func blow_sprite(
	stage: BattleStage, aimed: FoeView, element: String, critical: bool, weight: float
) -> SpellAnim:
	var blow: SpellAnim = null
	if critical:
		blow = stage.spell("hit-critical", aimed.target_point(), element, 0.75 + minf(0.45, weight * 0.6))
	var power := 0.75 + minf(0.6, weight * 1.2)
	if blow == null:
		blow = stage.spell(LogPlayer.blow_sheet(element), aimed.target_point(), element, power)
	# A missing sheet falls back to the bracket slam, which every element has.
	if blow == null:
		blow = stage.spell("hit-compile", aimed.target_point(), element, power)
	return blow


## The look a rider is drawn with (LegendaryLook and ConstellationVolley read it): its role, card, its index in the
## cast, the cast's serial, its element's colour and its power.
func rider_look(hit: Dictionary, index: int) -> Dictionary:
	return {
		"role": String(hit.get("role", "")),
		"card": String(hit.get("card", "")),
		"index": index,
		"cast_serial": serial,
		"element_colour": UiTheme.ELEMENTS.get(String(hit.get("element", "none")), UiTheme.TEXT),
		"power": power_of(hit),
	}


## A bolt's power: its damage, the part it broke through a shield with, and any overkill.
static func power_of(hit: Dictionary) -> float:
	return float(int(hit.get("amount", 0)) + int(hit.get("blocked", 0)) + int(hit.get("overkill", 0)))
