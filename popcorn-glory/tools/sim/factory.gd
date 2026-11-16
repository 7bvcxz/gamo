extends SceneTree

## Step 17: the factory's model played by scripted players for a few minutes --
## the real rules (variants/factory/factory_rules.gd), not a copy. Measures what
## design/PROGRESSION.md H-1 asks: the first sale, money by minute, and how much
## of the time the hand waits on a full glass (QUALITY_GATES G-06 <= 20%).
##   godot --headless --path popcorn-glory --script res://tools/sim/factory.gd -- [minutes] [out.md]
## A scripted player is not a person and not fun; these are what the rules do.

const Factory := preload("res://variants/factory/factory_rules.gd")
const PLAYERS := {
	# name: [aim offset into the gold (ms), think time between pops (ms), buys upgrades]
	"skilled": [10, 300, true],
	"casual": [-150, 1200, true],
	"slow": [250, 3500, false],
}


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var minutes := int(args[0]) if args.size() > 0 else 3
	var out_path := args[1] if args.size() > 1 else ""
	var lines: Array[String] = ["# Factory model, %d minutes per player (Step 17, automatic)" % minutes, "",
		"| player | first sale (s) | money @1m | @3m | sold | arrived | abandoned | lots | hand waits on a full glass | packer starved | counter empty | upgrades |",
		"|---|---|---|---|---|---|---|---|---|---|---|---|"]
	for name: String in PLAYERS.keys():
		lines.append(_play(name, PLAYERS[name], minutes))
	var text := "\n".join(lines) + "\n"
	print(text)
	if out_path != "":
		var f := FileAccess.open(out_path, FileAccess.WRITE)
		f.store_string(text)
		f.close()
	quit(0)


func _play(name: String, p: Array, minutes: int) -> String:
	var f: PopRules = Factory.new()
	var end := minutes * 60000
	var first_sale := -1
	var at1 := -1
	var at3 := -1
	var ups := 0
	var think := 0
	var hand_busy_ms := 0   # time the hand could act (not blocked by the glass)
	var blocked_ms := 0
	while f.now_ms < end:
		if bool(p[2]) and f.can_buy():
			f.execute({"type": "buy"})
			ups += 1
		var r := f.execute({"type": "press"})
		if bool(r["ok"]):
			var hold := maxi(100, f.window_start() + int(p[0]))
			f.advance(hold)
			f.execute({"type": "release"})
			f.advance(int(p[1]))
		else:
			f.advance(100)
			if String(r.get("reason", "")) == "err.kettle_full":
				blocked_ms += 100
		if first_sale < 0 and int(f.stats["sold"]) > 0:
			first_sale = f.now_ms
		if at1 < 0 and f.now_ms >= 60000:
			at1 = f.money
		if at3 < 0 and f.now_ms >= 180000:
			at3 = f.money
	var s: Dictionary = f.stats
	return "| %s | %s | %d | %s | %d | %d | %d | %d | %.0f%% | %.0f%% | %.0f%% | %d |" % [name,
		"%.1f" % (first_sale / 1000.0) if first_sale >= 0 else "-", at1, str(at3) if at3 >= 0 else "-",
		s["sold"], s["arrived"], s["abandoned"], s["lots"], 100.0 * blocked_ms / end,
		100.0 * int(s["packer_starved_ms"]) / end, 100.0 * int(s["counter_empty_ms"]) / end, ups]
