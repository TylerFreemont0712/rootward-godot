class_name ProfilePanel
extends RefCounted
## Local player creation, rename and deletion dialogs. The title owns placement and navigation.


static func editor(id: String, required: bool, done: Callable, cancel: Callable) -> Control:
	var current := Game.profiles.get_profile(id) if id != "" else {}
	var fresh := id == "" or required
	var heading := Text.t("New player") if fresh else Text.t("Your player")
	var name := LineEdit.new()
	name.placeholder_text = Text.t("Your name")
	name.text = "" if required else String(current.get("name", ""))
	name.max_length = ProfileRules.MAX_NAME_LENGTH
	name.custom_minimum_size = Vector2(420, 44)
	var language := OptionButton.new()
	language.add_item("English")
	language.add_item("日本語")
	language.selected = 1 if current.get("preferred_language", "en") == "ja" else 0
	var avatar := OptionButton.new()
	avatar.add_item(Text.t("Vesper"))
	avatar.add_item(Text.t("Emberfox"))
	avatar.add_item(Text.t("VesperV2.0"))
	avatar.add_item(Text.t("Vesper 1.5"))
	var avatar_ids: Array[String] = ["vesper", "emberfox", "vesper-v2", "vesper-v1-5"]
	var selected_avatar := avatar_ids.find(String(current.get("avatar", "vesper")))
	avatar.selected = maxi(selected_avatar, 0)
	var error := Ui.tint(Ui.label("", "Muted", true), UiTheme.FAIL)
	var save := func() -> void:
		var result := Game.profiles.create(name.text) if id == "" else Game.profiles.rename(id, name.text)
		if not result.ok:
			error.text = result.error
			return
		var player: Dictionary = result.profile
		player.preferred_language = "ja" if language.selected == 1 else "en"
		player.avatar = avatar_ids[avatar.selected]
		if not Game.profiles.save_profile(player) or not Game.select_profile(String(player.id)):
			error.text = Text.t("Could not save this player.")
			return
		done.call()
	var rows := (
		Ui
		. vbox(
			[
				Ui.label(heading, "Heading"),
				Ui.label(Text.t("A name, a language and a look. That's all."), "Muted", true),
				name,
				Ui.hbox([Ui.label(Text.t("Language")), language], 12),
				Ui.hbox([Ui.label(Text.t("Avatar")), avatar], 12),
				error,
				Ui.hbox([Ui.button(Text.t("Save player"), save, "PrimaryButton")]),
			],
			12
		)
	)
	if not required:
		rows.add_child(Ui.button(Text.t("Cancel"), cancel))
	var panel := Ui.panel(rows, "Overlay")
	panel.custom_minimum_size = Vector2(540, 0)
	name.call_deferred("grab_focus")
	return panel


static func delete_confirmation(done: Callable, cancel: Callable) -> Control:
	var player := Game.profile
	var warning := Text.f(
		"Delete %s? Their saved runs, git log, settings and Trial progress will be lost.", [player.name]
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
						Ui.label(Text.t("Delete player?"), "Heading"),
						Ui.label(warning, "", true),
						(
							Ui
							. hbox(
								[
									Ui.button(Text.t("Keep player"), cancel, "PrimaryButton"),
									Ui.button(Text.f("Delete %s", [player.name]), remove, "DangerButton"),
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
