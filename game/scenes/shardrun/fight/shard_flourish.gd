class_name ShardFlourish
extends Node2D
## A card's function expressed as motion: split branches, sorting bars, a searching reticle, merging crystals,
## elemental seals and a woven shield. Cosmetic only; LogPlayer's original landings still own every hit.

const MOTIFS := {
	"fork": "split",
	"split": "split",
	"divide": "split",
	"recursive-mirror": "split",
	"repeat": "split",
	"recursion-tree": "split",
	"higher-order": "split",
	"import-copy": "split",
	"hash-merge": "merge",
	"run-length": "merge",
	"reduce": "merge",
	"huffman": "merge",
	"merge-strike": "merge",
	"import-collections": "merge",
	"sliding-window": "search",
	"binary-execute": "search",
	"two-pointers": "search",
	"hash-aim": "search",
	"quickselect": "search",
	"linear-search": "search",
	"kindle": "fire",
	"fire-constant": "fire",
	"chill": "frost",
	"frost-constant": "frost",
	"charge": "spark",
	"spark-constant": "spark",
	"chain-lightning": "spark",
}
const ROLES := {
	"source": "split", "shape": "merge", "order": "sort", "strike": "search", "guard": "guard", "import": "import"
}

var motif := "merge"
var progress := 0.0
var colour := UiTheme.SHARD


static func motif_for(card: Dictionary) -> String:
	var id := String(card.get("id", "")).trim_suffix("-plus")
	return MOTIFS.get(id, ROLES.get(String(card.get("role", "")), "merge"))


static func play(parent: Node, card: Dictionary, at: Vector2, scale_to := 1.0) -> ShardFlourish:
	var effect := ShardFlourish.new()
	effect.motif = motif_for(card)
	effect.colour = UiTheme.element(effect.motif) if effect.motif in ["fire", "frost", "spark"] else UiTheme.SHARD
	if effect.motif == "guard":
		effect.colour = UiTheme.TEAL
	effect.position = at
	effect.scale = Vector2.ONE * scale_to
	parent.add_child(effect)
	var tween := effect.create_tween()
	tween.tween_method(effect._advance, 0.0, 1.0, 0.85)
	tween.tween_callback(effect.queue_free)
	return effect


func _advance(value: float) -> void:
	progress = value
	queue_redraw()


func _draw() -> void:
	var t := smoothstep(0.0, 0.75, progress)
	var ink := Color(colour, sin(progress * PI) * 0.85)
	var reach := 28.0 + t * 42.0
	draw_arc(Vector2.ZERO, 82, -PI * 0.5, -PI * 0.5 + TAU * t, 64, Color(ink, ink.a * 0.25), 2, true)
	match motif:
		"split", "merge":
			var spread := t if motif == "split" else 1.0 - t
			for index in 3:
				var to := Vector2(lerpf(0, (index - 1) * 70.0, spread), -20 - spread * 35)
				draw_line(Vector2(0, 45), to, ink, 3, true)
				_gem(to, 10 + (1.0 - spread) * 5, ink)
		"sort":
			for index in 5:
				var start := float([3, 1, 4, 0, 2][index])
				var x := lerpf(start, float(index), t) * 26 - 52
				var height := 18.0 + index * 12.0
				draw_rect(Rect2(x - 7, 34 - height, 14, height), ink, false, 3)
				draw_line(Vector2(x - 6, 34 - height), Vector2(x + 6, 34 - height), ink.lightened(0.2), 3, true)
		"search":
			var target := Vector2(lerpf(-65, 38, t), 0)
			for index in 5:
				_gem(Vector2(index * 28 - 56, 0), 7, Color(ink, ink.a * 0.5))
			draw_arc(target, 22 - t * 7, 0, TAU, 32, ink, 3, true)
			draw_line(target + Vector2(-28, 0), target + Vector2(28, 0), ink, 2, true)
		"fire":
			for index in 7:
				var angle := TAU * index / 7.0 + t * 1.3
				var at := Vector2(cos(angle), sin(angle)) * reach + Vector2(0, -t * 24)
				_gem(at, 6 + sin(progress * PI) * 6, ink)
		"frost":
			for index in 6:
				var spoke := Vector2.from_angle(TAU * index / 6.0 - PI * 0.5)
				draw_line(spoke * 9, spoke * reach, ink, 3, true)
				for branch: int in [-1, 1]:
					var end := spoke * reach * 0.72 + spoke.rotated(branch * PI / 3) * 18 * t
					draw_line(spoke * reach * 0.53, end, ink, 2, true)
		"spark":
			var points := PackedVector2Array()
			for index in 9:
				points.append(Vector2(index * 18 - 72, sin(index * 2.4 + t * 9) * 21 * sin(progress * PI)))
			draw_polyline(points, ink, 3, true)
			for index in 3:
				_gem(Vector2(index * 72 - 72, 0), 9, ink)
		"guard":
			for index in 3:
				var centre := Vector2((index - 1) * 38 * t, 0)
				var shield := PackedVector2Array()
				for corner in 7:
					shield.append(centre + Vector2.from_angle(TAU * corner / 6.0) * 28)
				draw_polyline(shield, ink, 3, true)
		"import":
			draw_rect(Rect2(-48, 0, 96, 40), ink, false, 3)
			for index in 3:
				_gem(Vector2((index - 1) * 30, lerpf(-65, 18, t)), 8, ink)


func _gem(at: Vector2, radius: float, ink: Color) -> void:
	var points := PackedVector2Array(
		[
			at + Vector2(0, -radius),
			at + Vector2(radius * 0.7, 0),
			at + Vector2(0, radius),
			at + Vector2(-radius * 0.7, 0),
			at + Vector2(0, -radius)
		]
	)
	draw_colored_polygon(points, Color(ink, ink.a * 0.18))
	draw_polyline(points, ink, 2, true)
