class_name TokenStream
extends Control
## Token Stream, a cast style (ADR-0058): each card's function name lifts out of the code panel where its call stands
## and flies into the spell's circle. It hovers there while the call runs, then dissolves into the layer the call
## writes, so the code writes its own circle. The code walk drives it, and only a construction cast runs it.

## How long the panel takes to scroll to a call before its token leaves.
# LEARN: the code panel reveals (scrolls to) a call after its shard_progress signal, so a token started at once would
# leave from where the call was. The flight waits for the reveal to settle.
const SETTLE := 0.2

var _program: ProgramCode
var _player: LogPlayer
var _flights: Dictionary = {}
var _colour := Color.WHITE


## Whether the worn circle is this style.
static func wanted_by(hero: HeroView) -> bool:
	return String(hero.look("circle").get("id", "")) == "token-stream"


## Lays a stream over `parent` for this walk: `program` lifts the names and resolves the calls, `player` says where the
## circle stands, and `colour` is the element's.
static func attach(parent: Node, program: ProgramCode, player: LogPlayer, colour: Color) -> TokenStream:
	var stream := TokenStream.new()
	stream.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stream.z_index = 60
	stream.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	stream._program = program
	stream._player = player
	stream._colour = colour
	parent.add_child(stream)
	program.shard_progress.connect(stream._launch)
	program.shard_resolved.connect(stream._land)
	return stream


## The walk is over: no more tokens start, and any still in the air land into the circle before the stream goes.
func detach() -> void:
	if is_instance_valid(_program):
		if _program.shard_progress.is_connected(_launch):
			_program.shard_progress.disconnect(_launch)
		if _program.shard_resolved.is_connected(_land):
			_program.shard_resolved.disconnect(_land)
	for slot: int in _flights.keys():
		_land(slot)
	get_tree().create_timer(TokenFlight.LAND + 0.1).timeout.connect(queue_free)


func _launch(slot: int, progress: float) -> void:
	if progress > 0.0 or _flights.has(slot) or not is_instance_valid(_player):
		return
	# Reserved now, started once the panel has scrolled to the call (its reveal runs after this signal).
	_flights[slot] = null
	get_tree().create_timer(SETTLE).timeout.connect(_start.bind(slot))


func _start(slot: int) -> void:
	if not _flights.has(slot) or _flights[slot] != null or not is_instance_valid(_player):
		return
	var index := _program.line_of_slot(slot)
	var target := _player.circle_point()
	if index < 0 or target == Vector2.ZERO:
		_flights.erase(slot)
		return
	_flights[slot] = TokenFlight.launch(self, _program.call_name(index), _program.call_point(index), target, _colour)


func _land(slot: int) -> void:
	if not _flights.has(slot):
		return
	var flight: TokenFlight = _flights[slot]
	_flights.erase(slot)
	if is_instance_valid(flight):
		flight.land()
