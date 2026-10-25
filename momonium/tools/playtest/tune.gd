extends SceneTree

## Tries balance changes before they are written into data/: plays the
## autoplayer on data with overrides and prints the milestones in one line
## each, so candidates can be compared side by side.
##
##   godot --headless --path momonium --script res://tools/playtest/tune.gd -- \
##     --minutes 40 --set "balance:clock/day_seconds=30" --set "buildings:types/farm/cycle/stages/1/cooldown=15"
##
## A value is JSON. Paths walk dictionaries by key and arrays by index,
## separated by "/" (keys such as "farm.sow" contain dots).

const AutoPlayer := preload("res://tools/playtest/autoplayer.gd")
const SHOW := ["first harvest", "first sale", "level 2", "built research", "built lumberyard", "first research", "first hire",
	"first land", "level 3", "built mine", "level 4", "level 5", "earned $500", "tier 1", "sold island 1", "level 5 (island 2)", "sold island 2"]


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var minutes := 40.0
	var data := GameData.load_default()
	for i in args.size():
		match args[i]:
			"--minutes":
				minutes = float(args[i + 1])
			"--set":
				var kv: PackedStringArray = args[i + 1].split("=", true, 1)
				var where: PackedStringArray = kv[0].split(":", true, 1)
				_put(data.tables[where[0]], where[1].split("/"), JSON.parse_string(kv[1]))
	var bot := AutoPlayer.new(Simulation.new_game(data))
	bot.play(minutes * 60.0)
	var line := ""
	for k: String in SHOW:
		var t := bot.first(k)
		line += "%s=%s  " % [k, "-" if t < 0 else "%d:%02d" % [t / 60000, (t / 1000) % 60]]
	print("tune: ", line)
	var gaps := ""
	for span: Array in [[60, 300], [300, 900], [900, 1800]]:
		var q: Dictionary = bot.longest_quiet(int(span[0]) * 1000, int(span[1]) * 1000)
		var m: Dictionary = bot.longest_between_milestones(int(span[0]) * 1000, int(span[1]) * 1000)
		gaps += "%d-%ds quiet %ds new %d (wait %ds)  " % [span[0], span[1], q["gap_ms"] / 1000, m["count"], m["gap_ms"] / 1000]
	print("tune: ", gaps, "stuck %ds" % bot.stuck_seconds)
	var prog: ProgressionSystem = bot.sim.system(&"progression")
	print("tune: end island %d Lv %d $%d %d buildings %d Momo sales %s" % [bot.island, prog.level, (bot.sim.system(&"economy") as EconomySystem).money,
		(bot.sim.system(&"buildings") as BuildingSystem).ids().size(), (bot.sim.system(&"momo") as MomoSystem).ids().size(), str(bot.sales)])
	quit()


func _put(node: Variant, path: PackedStringArray, value: Variant) -> void:
	_put_in(node, path, value)


static func _put_in(node: Variant, path: PackedStringArray, value: Variant) -> void:
	var cur: Variant = node
	for i in path.size() - 1:
		cur = cur[int(path[i])] if typeof(cur) == TYPE_ARRAY else cur[path[i]]
	var last := path[path.size() - 1]
	if typeof(cur) == TYPE_ARRAY:
		cur[int(last)] = value
	else:
		cur[last] = value
