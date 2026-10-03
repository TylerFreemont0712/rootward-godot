class_name HandView
extends Control
## The hand, held like one: fanned in a shallow arc, overlapping when it is full. The card under the mouse
## straightens, rises and grows, and its neighbours lean aside, as Slay the Spire holds its hand; its details appear
## beside it (CardFace). A card dropped here goes to the end of the hand.
##
## The hand keeps its cards from one update to the next, so when one is played the rest close the gap rather than being
## drawn afresh. A new turn's cards are dealt from the draw pile, one after another, into their places; what is left of
## the old hand goes to the discard pile; a card that comes back from the Program or the hold flies from where it was.

## How much the pointed-at card grows, how far (in degrees) the fan turns each card from the one beside it, and the room
## kept at each side so a turned card never leans over the piles beside the hand.
const GROW := 1.2
const FAN := 3.2
const SIDE := 30.0
const MOVE := 0.14
## Seconds between one dealt card and the next, and how long a card takes to fly to its place.
const DEAL_GAP := 0.08
const FLIGHT := 0.34

## Called with a card's spot when it is dropped on the hand.
var dropped: Callable
## Where the draw and discard piles are, in the canvas (functions, because the piles move with the layout).
var draw_point: Callable
var discard_point: Callable
var cards: Array[CardFace] = []
var hovered := -1
## Cards waiting for the hand to have its size before they fly in (the fight's first deal is drawn before layout).
var _arriving: Array[CardFace] = []


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	custom_minimum_size.y = CardFace.SIZES[CardFace.Size.HAND].y + 14.0
	resized.connect(_on_resized)


## Holds the cards `ids`. A card already held stays (and glides to its new place); a new one is made by `make` (id,
## index) and flies in from `origins` (id -> canvas points cards of that id left from, taken as they are used) or, when
## `deal`, from the draw pile, or else rises from below. A card no longer held goes to the discard pile when `deal` (the
## turn ended) and simply goes otherwise (it was played; its slot flies it there).
func show_hand(ids: Array, make: Callable, deal: bool, origins: Dictionary) -> void:
	var old := cards.duplicate()
	var kept := {}
	var next: Array[CardFace] = []
	var dealt := 0
	for index in ids.size():
		var id: String = ids[index]
		var face: CardFace = null
		if not deal:
			for candidate: CardFace in old:
				if not kept.has(candidate) and candidate.shard_id == id:
					face = candidate
					kept[candidate] = true
					break
		if face == null:
			face = make.call(id, index)
			var from: Variant = _take(origins, id)
			if from == null and deal and draw_point.is_valid():
				from = draw_point.call()
				face.set_meta("delay", dealt * DEAL_GAP)
				dealt += 1
			face.set_meta("from", from)
			face.visible = false
			add_child(face)
			face.pivot_offset = Vector2(face.custom_minimum_size.x * 0.5, face.custom_minimum_size.y)
			face.mouse_entered.connect(_point.bind(face, true))
			face.mouse_exited.connect(_point.bind(face, false))
			_arriving.append(face)
		face.spot = {"zone": "hand", "index": index}
		next.append(face)
	# LEARN: swap the hand before any card leaves. Leaving sets a card's mouse_filter, and Godot answers a pointed-at
	# card turning IGNORE with mouse_exited at once; _point would then re-arrange the OLD hand, cancelling the discard
	# tweens of the cards already sent off, which stayed on screen as a ghost of the previous hand.
	cards = next
	hovered = -1
	for face: CardFace in old:
		if not kept.has(face):
			_leave(face, deal)
	for index in cards.size():
		move_child(cards[index], index)
	if dealt > 0:
		Sound.play("sfx-card-flick", 0.5)
	if size.x > 1.0 and is_inside_tree():
		_fly_in.call_deferred()


static func _take(origins: Dictionary, id: String) -> Variant:
	var points: Array = origins.get(id, [])
	return points.pop_front() if not points.is_empty() else null


func _on_resized() -> void:
	if not _arriving.is_empty():
		# The fight's first deal: now the hand (and the piles beside it) have their places, the cards can fly in.
		_fly_in.call_deferred()
	else:
		_arrange(false)


## Cards just made start where they came from and fly to their places in the fan, the dealt ones one after another.
func _fly_in() -> void:
	if size.x <= 1.0:
		return
	var card_size: Vector2 = CardFace.SIZES[CardFace.Size.HAND]
	var back := get_global_transform().affine_inverse()
	for face in _arriving:
		if not is_instance_valid(face):
			continue
		var from: Variant = face.get_meta("from", Vector2.INF)
		if from is Vector2 and (from as Vector2).is_finite():
			face.position = back * (from as Vector2) - card_size * 0.5
			face.scale = Vector2.ONE * 0.6
			face.rotation_degrees = -18.0
		else:
			face.position = Vector2(size.x * 0.5 - card_size.x * 0.5, size.y + 40.0)
		face.modulate = Color(1, 1, 1, 0.2)
		face.visible = true
	_arriving.clear()
	_arrange(true)


## A card leaving the hand: to the discard pile at the turn's end, spinning down and fading; otherwise at once.
func _leave(face: CardFace, to_discard: bool) -> void:
	_arriving.erase(face)
	if not to_discard or not discard_point.is_valid() or not face.visible or size.x <= 1.0:
		face.queue_free()
		return
	face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var target := get_global_transform().affine_inverse() * (discard_point.call() as Vector2)
	var tween := _tween(face, Tween.TRANS_QUAD)
	tween.tween_property(face, "position", target - face.custom_minimum_size * 0.5, 0.3)
	tween.tween_property(face, "rotation_degrees", 24.0, 0.3)
	tween.tween_property(face, "scale", Vector2.ONE * 0.45, 0.3)
	tween.tween_property(face, "modulate:a", 0.0, 0.3)
	tween.chain().tween_callback(face.queue_free)


func _point(card: CardFace, on: bool) -> void:
	var index := cards.find(card)
	if index < 0:
		return
	if on:
		hovered = index
		# Drawn last, so it lies over its neighbours and keeps the mouse while it grows.
		move_child(card, get_child_count() - 1)
	elif hovered == index:
		hovered = -1
		move_child(card, index)
	_arrange(true)


func _rest_angle(index: int) -> float:
	return (index - (cards.size() - 1) * 0.5) * FAN


## Places every card: in a fan along the bottom, or, with one pointed at, that one upright and whole above the edge.
func _arrange(animate: bool) -> void:
	var count := cards.size()
	if count == 0 or size.x <= 1.0:
		return
	var card_size: Vector2 = CardFace.SIZES[CardFace.Size.HAND]
	var room := maxf(0.0, size.x - card_size.x - SIDE * 2.0)
	var spacing := minf(card_size.x * 0.84, room / maxf(1.0, count - 1.0))
	var x0 := (size.x - card_size.x - spacing * (count - 1)) * 0.5
	var top := size.y - card_size.y - 12.0
	for index in count:
		var card := cards[index]
		if not card.visible:
			continue
		var offset := index - (count - 1) * 0.5
		var target := Vector2(x0 + spacing * index, top + minf(10.0, offset * offset * 2.2))
		var angle := _rest_angle(index)
		var grow := 1.0
		if hovered >= 0 and index == hovered:
			target.y = top - 8.0
			angle = 0.0
			grow = GROW
		elif hovered >= 0:
			var away := signf(index - hovered) * card_size.x * 0.34 / absf(index - hovered)
			target.x += away
		if not animate:
			card.position = target
			card.rotation_degrees = angle
			card.scale = Vector2.ONE * grow
			card.modulate = Color.WHITE
			continue
		var arriving := card.modulate.a < 1.0
		var seconds := FLIGHT if arriving else MOVE
		var delay := 0.0
		if arriving and card.has_meta("delay"):
			delay = float(card.get_meta("delay"))
			card.remove_meta("delay")
		var tween := _tween(card, Tween.TRANS_BACK if arriving else Tween.TRANS_QUAD)
		tween.tween_property(card, "position", target, seconds).set_delay(delay)
		tween.tween_property(card, "rotation_degrees", angle, seconds).set_delay(delay)
		tween.tween_property(card, "scale", Vector2.ONE * grow, seconds).set_delay(delay)
		tween.tween_property(card, "modulate", Color.WHITE, seconds * 0.6).set_delay(delay)


## A card's one motion: a new one replaces the one under way, so a quick sweep across the hand never has two tweens
## pulling one card in different directions.
static func _tween(card: CardFace, transition: Tween.TransitionType) -> Tween:
	# LEARN: get_meta(name, null) is an error when the key is missing (a null default reads as "no default").
	if card.has_meta("hand_tween"):
		var previous := card.get_meta("hand_tween") as Tween
		if previous != null and previous.is_valid():
			previous.kill()
	var tween := card.create_tween().set_parallel().set_trans(transition).set_ease(Tween.EASE_OUT)
	card.set_meta("hand_tween", tween)
	return tween


func _can_drop_data(_at: Vector2, data: Variant) -> bool:
	return dropped.is_valid() and data is Dictionary and (data as Dictionary).has("card_spot")


func _drop_data(_at: Vector2, data: Variant) -> void:
	dropped.call((data as Dictionary).card_spot)
