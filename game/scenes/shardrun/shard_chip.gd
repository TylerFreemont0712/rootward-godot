class_name ShardChip
extends Button
## A shard sitting in a spell slot or among the spares, or an empty slot. Drag it somewhere else, or click it and
## then click where it should go. `place` is {spell: spell id or "" for the spares, index}.

## Picked up or dropped onto: the workbench decides what that means.
signal chosen(place: Dictionary)
signal dropped(from: Dictionary, onto: Dictionary, onto_shard: bool)
signal hovered(shard_id: String)

var place: Dictionary = {}
var shard_id := ""


static func filled(at: Dictionary, id: String, shard: Dictionary) -> ShardChip:
	var chip := ShardChip.new()
	chip.place = at
	chip.shard_id = id
	chip.text = shard.get("name", id)
	chip.icon = Art.texture("shardrun/shard-" + id)
	chip.expand_icon = false
	chip.theme_type_variation = "ChipButton"
	chip.tooltip_text = "%s · %s\nDrag it, or click it and then where it goes." % [chip.text, shard.get("rarity", "")]
	chip.add_theme_color_override("font_color", UiTheme.rarity(shard.get("rarity", "common")).lightened(0.2))
	chip.custom_minimum_size = Vector2(0, 38)
	chip.toggle_mode = true
	chip.pressed.connect(func() -> void: chip.chosen.emit(chip.place))
	chip.mouse_entered.connect(func() -> void: chip.hovered.emit(id))
	return chip


static func empty(at: Dictionary, label := "empty") -> ShardChip:
	var chip := ShardChip.new()
	chip.place = at
	chip.text = label
	chip.theme_type_variation = "ChipButton"
	chip.custom_minimum_size = Vector2(96, 38)
	chip.add_theme_color_override("font_color", UiTheme.FAINT)
	var dashed := UiTheme.box(Color(0, 0, 0, 0.25), UiTheme.LINE, 1, 3, Vector2(8, 4))
	chip.add_theme_stylebox_override("normal", dashed)
	chip.pressed.connect(func() -> void: chip.chosen.emit(chip.place))
	return chip


# LEARN: Godot's drag and drop is three virtual methods on Controls. The one dragged returns some data from
# _get_drag_data (null: nothing to drag); every Control under the pointer is asked _can_drop_data, and the one that
# says yes gets _drop_data. The data is any Variant; here it is only where the shard came from.
func _get_drag_data(_at: Vector2) -> Variant:
	if shard_id == "":
		return null
	var preview := Ui.panel(Ui.label(text, ""), "Chip")
	preview.modulate = Color(1, 1, 1, 0.85)
	set_drag_preview(preview)
	return {"shard_place": place}


func _can_drop_data(_at: Vector2, data: Variant) -> bool:
	return data is Dictionary and (data as Dictionary).has("shard_place")


func _drop_data(_at: Vector2, data: Variant) -> void:
	dropped.emit((data as Dictionary).shard_place, place, shard_id != "")
