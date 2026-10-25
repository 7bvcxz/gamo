extends RefCounted

## Status > Records after six minutes of play and an hour away: the journey
## (Step 42).

const AutoPlayer := preload("res://tools/playtest/autoplayer.gd")


func setup(main: Node) -> void:
	var sim: Simulation = main.get("sim")
	var bot := AutoPlayer.new(sim)
	bot.sell_at_points = 99
	bot.play(6 * 60.0)
	OfflineProgress.catch_up(sim, 3600000)
	LocaleService.apply(OS.get_environment("MOMONIUM_CAPTURE_STEP") if OS.get_environment("MOMONIUM_CAPTURE_STEP") != "" else "ko")
	var frame: PanelFrame = main.get("status_frame")
	frame.open(3)
