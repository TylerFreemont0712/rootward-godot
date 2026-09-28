class_name HoverInfo
extends Node
## A readable, clamped hover window shared by enemy tags and owned relics. A CanvasLayer keeps it above the arena's
## clipping rectangle. It belongs to its source, so rebuilding that source also removes its window.

static var active: HoverInfo

var title := ""
var body := ""
var detail := ""
var colour := UiTheme.TEAL
var source: Control
var _layer: CanvasLayer
var _panel: PanelContainer
var _elapsed := -1.0


static func attach(control: Control, heading: String, text: String, note := "", tint := UiTheme.TEAL) -> HoverInfo:
	var info := HoverInfo.new()
	info.title = heading
	info.body = text
	info.detail = note
	info.colour = tint
	info.source = control
	control.tooltip_text = ""
	control.mouse_filter = Control.MOUSE_FILTER_PASS
	control.focus_mode = Control.FOCUS_ALL
	control.mouse_entered.connect(info._enter)
	control.mouse_exited.connect(info.dismiss)
	control.focus_entered.connect(info.show_now)
	control.focus_exited.connect(info.dismiss)
	control.add_child(info)
	return info


func _enter() -> void:
	_elapsed = 0.0


func _process(delta: float) -> void:
	if not source.is_visible_in_tree():
		dismiss()
		return
	if _elapsed >= 0.0:
		_elapsed += delta
		if _elapsed >= 0.18:
			show_now()
	if is_instance_valid(_panel):
		_place()


func show_now() -> void:
	_elapsed = -1.0
	if is_instance_valid(_layer) or not source.is_inside_tree():
		return
	if is_instance_valid(active):
		active.dismiss()
	active = self
	_layer = CanvasLayer.new()
	_layer.layer = 100
	add_child(_layer)
	var column := Ui.vbox([Ui.tint(Ui.label(title, "Subheading", true), colour), Ui.label(body, "", true)], 10)
	if detail != "":
		column.add_child(Ui.label(detail, "Muted", true))
	_panel = Ui.panel(column)
	_panel.theme = UiTheme.shared()
	_panel.custom_minimum_size.x = 380
	var style := UiTheme.box(Color(0.045, 0.035, 0.065, 0.98), colour.darkened(0.25), 1, 12, Vector2(20, 16))
	style.shadow_color = Color(0, 0, 0, 0.55)
	style.shadow_size = 12
	_panel.add_theme_stylebox_override("panel", style)
	_ignore_mouse(_panel)
	_layer.add_child(_panel)
	_panel.modulate.a = 0.0
	_panel.create_tween().tween_property(_panel, "modulate:a", 1.0, 0.12)
	_place.call_deferred()


func _place() -> void:
	if not is_instance_valid(_panel):
		return
	var screen := source.get_viewport_rect().size
	_panel.size = _panel.get_combined_minimum_size()
	var rect := source.get_global_rect()
	var at := Vector2(rect.position.x, rect.end.y + 12)
	if at.y + _panel.size.y > screen.y - 12:
		at.y = rect.position.y - _panel.size.y - 12
	at.x = clampf(at.x, 12, maxf(12, screen.x - _panel.size.x - 12))
	at.y = clampf(at.y, 12, maxf(12, screen.y - _panel.size.y - 12))
	_panel.position = at


func dismiss() -> void:
	_elapsed = -1.0
	if is_instance_valid(_layer):
		_layer.queue_free()
	_layer = null
	_panel = null
	if active == self:
		active = null


func _exit_tree() -> void:
	if active == self:
		active = null


static func _ignore_mouse(node: Node) -> void:
	if node is Control:
		(node as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in node.get_children():
		_ignore_mouse(child)
