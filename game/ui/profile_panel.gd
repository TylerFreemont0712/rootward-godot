class_name ProfilePanel
extends RefCounted
## Local player creation, rename and deletion dialogs. The title owns placement and navigation.


static func _text(english: String, japanese: String) -> String:
	return japanese if Game.profile.get("preferred_language", "en") == "ja" else english


static func editor(id: String, required: bool, done: Callable, cancel: Callable) -> Control:
	var current := Game.profiles.get_profile(id) if id != "" else {}
	var fresh := id == "" or required
	var heading := _text("New player", "新しいプレイヤー") if fresh else _text("Your player", "プレイヤーの設定")
	var name := LineEdit.new()
	name.placeholder_text = _text("Your name", "なまえ")
	name.text = "" if required else String(current.get("name", ""))
	name.max_length = ProfileRules.MAX_NAME_LENGTH
	name.custom_minimum_size = Vector2(420, 44)
	var language := OptionButton.new()
	language.add_item("English")
	language.add_item("日本語")
	language.selected = 1 if current.get("preferred_language", "en") == "ja" else 0
	var avatar := OptionButton.new()
	avatar.add_item("Vesper")
	avatar.add_item("Emberfox")
	avatar.selected = 1 if current.get("avatar", "vesper") == "emberfox" else 0
	var error := Ui.tint(Ui.label("", "Muted", true), UiTheme.FAIL)
	var save := func() -> void:
		var result := Game.profiles.create(name.text) if id == "" else Game.profiles.rename(id, name.text)
		if not result.ok:
			error.text = result.error
			return
		var player: Dictionary = result.profile
		player.preferred_language = "ja" if language.selected == 1 else "en"
		player.avatar = "emberfox" if avatar.selected == 1 else "vesper"
		if not Game.profiles.save_profile(player) or not Game.select_profile(String(player.id)):
			error.text = _text("Could not save this player.", "保存できませんでした。")
			return
		done.call()
	var rows := (
		Ui
		. vbox(
			[
				Ui.label(heading, "Heading"),
				Ui.label(_text("A name, a language and a look. That's all.", "なまえとことば、すがただけで始められるよ。"), "Muted", true),
				name,
				Ui.hbox([Ui.label(_text("Language", "ことば")), language], 12),
				Ui.hbox([Ui.label(_text("Avatar", "すがた")), avatar], 12),
				error,
				Ui.hbox([Ui.button(_text("Save player", "保存する"), save, "PrimaryButton")]),
			],
			12
		)
	)
	if not required:
		rows.add_child(Ui.button(_text("Cancel", "やめる"), cancel))
	var panel := Ui.panel(rows, "Overlay")
	panel.custom_minimum_size = Vector2(540, 0)
	name.call_deferred("grab_focus")
	return panel


static func delete_confirmation(done: Callable, cancel: Callable) -> Control:
	var player := Game.profile
	var warning := _text(
		"Delete %s? Their saved runs, git log, settings and Trial progress will be lost." % player.name,
		"%sを消しますか？ セーブ、遊んだ記録、設定、トライアルの進みぐあいが消えます。" % player.name
	)
	var remove := func() -> void:
		if not Game.profiles.delete(String(player.id)):
			return
		var remaining := Game.profiles.list_profiles()
		if remaining.is_empty():
			var created := Game.profiles.create("Player 1")
			if created.ok:
				var newcomer: Dictionary = created.profile
				newcomer.needs_name = true
				Game.profiles.save_profile(newcomer)
				Game.select_profile(String(newcomer.id))
		else:
			Game.select_profile(String(remaining[0].id))
		done.call()
	var panel := (
		Ui
		. panel(
			(
				Ui
				. vbox(
					[
						Ui.label(_text("Delete player?", "プレイヤーを消す？"), "Heading"),
						Ui.label(warning, "", true),
						(
							Ui
							. hbox(
								[
									Ui.button(_text("Keep player", "消さない"), cancel, "PrimaryButton"),
									Ui.button(
										_text("Delete %s" % player.name, "%sを消す" % player.name), remove, "DangerButton"
									),
								]
							)
						),
					],
					14
				)
			),
			"Overlay"
		)
	)
	panel.custom_minimum_size = Vector2(600, 0)
	return panel
