class_name FoundryRecordsPanel
extends PanelContainer
## A readable journey ledger, backed by the existing history; its commit log remains one click away.

signal closed
signal commit_log_requested

var records: Array[Dictionary] = []
var _filter := "all"
var _selected := ""


static func make(history: Array[Dictionary]) -> FoundryRecordsPanel:
	var panel := FoundryRecordsPanel.new()
	panel.records = history
	panel.theme_type_variation = "Overlay"
	panel._build()
	return panel


func _build() -> void:
	custom_minimum_size = Vector2(770, 450)
	var column := Ui.vbox(
		[
			FoundryUi.heading("THE JOURNEY LEDGER", FoundryUi.text("Records", "冒険の記録"), func() -> void: closed.emit()),
			FoundryUi.rule()
		],
		8
	)
	var wins := records.filter(func(record: Dictionary) -> bool: return record.get("status", "") == "won").size()
	var best := 0
	for record: Dictionary in records:
		best = maxi(best, int(record.get("score", 0)))
	var stats := Ui.hbox([], 30)
	for pair: Array in [
		[str(records.size()), FoundryUi.text("DESCENTS", "冒険")],
		[str(wins), FoundryUi.text("COMPLETED", "クリア")],
		[str(best), FoundryUi.text("BEST SCORE", "最高スコア")]
	]:
		var stat := Ui.vbox([Ui.sized(Ui.label(pair[0], "Heading"), 22), Ui.label(pair[1], "Faint")], 8)
		stat.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		stats.add_child(stat)
	column.add_child(stats)
	var tabs := Ui.hbox([], 10)
	var names := {
		"all": FoundryUi.text("All journeys", "すべて"),
		"won": FoundryUi.text("Completed", "クリア"),
		"lost": FoundryUi.text("Lost", "敗北"),
		"abandoned": FoundryUi.text("Retired", "中断")
	}
	for status: String in names:
		var choose := func() -> void:
			_filter = status
			_rebuild()
		tabs.add_child(Ui.choice(names[status], _filter == status, choose))
	column.add_child(tabs)
	var list := Ui.vbox([], 14)
	var shown := 0
	for record: Dictionary in records:
		if _filter != "all" and record.get("status", "") != _filter:
			continue
		shown += 1
		var hash := RunHistory.short_hash(record)
		var open := func() -> void:
			_selected = "" if _selected == hash else hash
			_rebuild()
		var mode: String = Game.PLAYSTYLES.get(record.get("playstyle", "program"), "Shardrun")
		var heading := "%s · %s" % [mode, record.get("place", "")]
		var summary := (
			"%s · %s · %s · %d"
			% [
				record.get("date", "").get_slice("T", 0),
				String(record.get("language", "")).capitalize(),
				names.get(record.get("status", ""), "Retired"),
				int(record.get("score", 0))
			]
		)
		list.add_child(FoundryUi.action(heading, summary, open, _selected == hash))
		if _selected == hash:
			var detail := Ui.vbox(
				[
					Ui.label(
						(
							"%d rooms · %d fights · %d turns"
							% [int(record.get("rooms", 0)), int(record.get("fights", 0)), int(record.get("turns", 0))]
						),
						"Subheading"
					),
					Ui.label(
						"%d damage · %d best cast" % [int(record.get("damage", 0)), int(record.get("best_cast", 0))],
						"Muted"
					),
					Ui.label("Seed · " + String(record.get("seed", "")), "Faint")
				],
				12
			)
			var relics := Ui.flow([], 8)
			for id: String in record.get("relics", []):
				var art := Ui.picture("shardrun/relic-" + id, Vector2(40, 40), "◇")
				art.tooltip_text = id.capitalize()
				relics.add_child(art)
			detail.add_child(relics)
			list.add_child(Ui.panel(detail, "Card"))
	if shown == 0:
		list.add_child(Ui.spacer(0, 20))
		list.add_child(Ui.label(FoundryUi.text("Every descent leaves a trace.", "冒険は、ここに足あとを残す。"), "Heading"))
		list.add_child(
			Ui.label(
				FoundryUi.text(
					"Your finished journeys will appear here. For now, the lift is waiting.",
					"終わった冒険をここに残すよ。今は、リフトが待っている。"
				),
				"Muted",
				true
			)
		)
	var scroll := Ui.scroll(list)
	scroll.custom_minimum_size.y = 200
	column.add_child(scroll)
	column.add_child(FoundryUi.rule())
	column.add_child(
		Ui.hbox(
			[
				FoundryUi.button(
					FoundryUi.text("Commit log", "コミットログ"), func() -> void: commit_log_requested.emit(), false, true
				)
			]
		)
	)
	add_child(column)


func _rebuild() -> void:
	FoundryUi.rebuild(self, _build)
