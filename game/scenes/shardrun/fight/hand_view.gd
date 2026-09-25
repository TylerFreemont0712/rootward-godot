class_name HandView
extends Control
## The hand, held like one: fanned in a shallow arc, overlapping when it is full, resting low so their tops show. The
## card under the mouse straightens, rises whole and grows, and its neighbours lean aside, as Slay the Spire holds its
## hand; its details appear beside it (CardFace). A card dropped here goes to the end of the hand.

## How much of a resting card shows above the hand's bottom edge, how much the pointed-at card grows, and how far (in
## degrees) the fan turns each card from the one beside it.
const PEEK := 0.72
const GROW := 1.2
const FAN := 3.2
const MOVE := 0.14

## Called with a card's spot when it is dropped on the hand.
var dropped: Callable
var cards: Array[CardFace] = []
var hovered := -1


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	custom_minimum_size.y = CardFace.SIZES[CardFace.Size.HAND].y * PEEK
	resized.connect(_arrange.bind(false))


## Holds these cards (freeing the ones held before). `deal` brings them in from below, one after another.
func hold(faces: Array[CardFace], deal: bool) -> void:
	for card in cards:
		card.queue_free()
	cards = faces
	hovered = -1
	for index in cards.size():
		var card := cards[index]
		add_child(card)
		card.pivot_offset = Vector2(card.custom_minimum_size.x * 0.5, card.custom_minimum_size.y)
		card.mouse_entered.connect(_point.bind(card, true))
		card.mouse_exited.connect(_point.bind(card, false))
	_arrange(false)
	if deal:
		for index in cards.size():
			var card := cards[index]
			var rest := card.position
			card.position = rest + Vector2(-80.0, 200.0)
			card.rotation_degrees -= 14.0
			card.modulate = Color(1, 1, 1, 0)
			var tween := _tween(card, Tween.TRANS_BACK)
			var delay := index * 0.06
			tween.tween_property(card, "position", rest, 0.36).set_delay(delay)
			tween.tween_property(card, "rotation_degrees", _rest_angle(index), 0.36).set_delay(delay)
			tween.tween_property(card, "modulate", Color.WHITE, 0.18).set_delay(delay)
		if not cards.is_empty():
			Sound.play("sfx-card", 0.5)


func _point(card: CardFace, on: bool) -> void:
	var index := cards.find(card)
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
	if count == 0:
		return
	var card_size: Vector2 = CardFace.SIZES[CardFace.Size.HAND]
	var room := maxf(0.0, size.x - card_size.x)
	var spacing := minf(card_size.x * 0.84, room / maxf(1.0, count - 1.0))
	var x0 := (size.x - card_size.x - spacing * (count - 1)) * 0.5
	for index in count:
		var card := cards[index]
		var offset := index - (count - 1) * 0.5
		var target := Vector2(x0 + spacing * index, size.y - card_size.y * PEEK + offset * offset * 2.2)
		var angle := _rest_angle(index)
		var grow := 1.0
		if hovered >= 0 and index == hovered:
			target.y = size.y - card_size.y - 6.0
			angle = 0.0
			grow = GROW
		elif hovered >= 0:
			var away := signf(index - hovered) * card_size.x * 0.34 / absf(index - hovered)
			target.x += away
		if not animate:
			card.position = target
			card.rotation_degrees = angle
			card.scale = Vector2.ONE * grow
			continue
		var tween := _tween(card, Tween.TRANS_QUAD)
		tween.tween_property(card, "position", target, MOVE)
		tween.tween_property(card, "rotation_degrees", angle, MOVE)
		tween.tween_property(card, "scale", Vector2.ONE * grow, MOVE)


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
