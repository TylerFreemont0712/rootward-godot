class_name TrialTitle
extends RefCounted
## Builds the one-time title prompt for a profile's first Shardrun.


static func offer(start_trial: Callable, start_run: Callable) -> Control:
	var japanese: bool = Game.profile.get("preferred_language", "en") == "ja"
	var title := "ピップと練習する？" if japanese else "Try Pip's Trial first?"
	var line := (
		"ピップと10〜15分で、カード、プログラム、戦い、工房を体験しよう。いつでもスキップできるよ。"
		if japanese
		else "Pip can guide you through cards, programs, fights and the forge in 10–15 minutes. You can skip anytime."
	)
	var panel := Ui.panel(
		Ui.vbox(
			[
				Ui.label(title, "Heading"),
				Ui.label(line, "Narration", true),
				Ui.hbox(
					[
						Ui.button("トライアルへ" if japanese else "Start the Trial", start_trial, "PrimaryButton"),
						Ui.button("ふつうの冒険へ" if japanese else "Start a full run", start_run)
					],
					8
				)
			],
			12
		),
		"Overlay"
	)
	panel.custom_minimum_size.x = 600
	return panel
