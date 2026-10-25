extends SceneTree

## Minute by minute: money, crops, buildings, Momo, level and what the bot did
## -- to see where the time goes. Same --set overrides as tune.gd.
##
##   godot --headless --path momonium --script res://tools/playtest/trace.gd -- --minutes 15

const AutoPlayer := preload("res://tools/playtest/autoplayer.gd")
const Tune := preload("res://tools/playtest/tune.gd")


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var minutes := 15
	var data := GameData.load_default()
	for i in args.size():
		match args[i]:
			"--minutes":
				minutes = int(args[i + 1])
			"--set":
				var kv: PackedStringArray = args[i + 1].split("=", true, 1)
				var where: PackedStringArray = kv[0].split(":", true, 1)
				Tune._put_in(data.tables[where[0]], where[1].split("/"), JSON.parse_string(kv[1]))
	var bot := AutoPlayer.new(Simulation.new_game(data))
	var before := {}
	for m in minutes:
		bot.play(60.0)
		var did := {}
		for k: String in bot.counts:
			var n := int(bot.counts[k]) - int(before.get(k, 0))
			if n > 0:
				did[k] = n
		before = bot.counts.duplicate()
		var s := bot.sim
		var fam := {}
		var bs: BuildingSystem = s.system(&"buildings")
		for id: int in bs.ids():
			var f := bs.family_of(String(bs.get_building(id)["type"]))
			fam[f] = int(fam.get(f, 0)) + 1
		var prog: ProgressionSystem = s.system(&"progression")
		print("%2d min  island %d  $%4d  crop %2d notes %2d wood %2d  Lv %d (%d exp)  Momo %d  %s  did %s" % [m + 1, bot.island,
			(s.system(&"economy") as EconomySystem).money, (s.system(&"inventory") as InventorySystem).count("crop"),
			(s.system(&"inventory") as InventorySystem).count("notes"), (s.system(&"inventory") as InventorySystem).count("wood"),
			prog.level, prog.experience, (s.system(&"momo") as MomoSystem).ids().size(), str(fam), str(did)])
	quit()
