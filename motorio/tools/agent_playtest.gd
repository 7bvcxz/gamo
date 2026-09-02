extends SceneTree

## One autonomous run of Motorio, by the Agent Harness V2.
##
##   godot --headless --path motorio --script res://tools/agent_playtest.gd -- \
##       --seed 5001 [--mode qa|player] [--until first_iron|motor|...] \
##       [--timeout 35] [--output <dir>]
##
## The batch wrapper is tools/agent_playtest.sh; this file is one seed, one
## process, one JSON + one log in the output directory. It never grants, never
## teleports, never upgrades by debug -- the guard test greps this tree for
## exactly those calls.

const Body := preload("res://tools/agent/body.gd")
const Mind := preload("res://tools/agent/mind.gd")
const Observe := preload("res://tools/agent/observe.gd")
const Telemetry := preload("res://tools/agent/telemetry.gd")
const MainScene := preload("res://scenes/Main.tscn")

func _init() -> void:
	call_deferred("_boot")

func _boot() -> void:
	await process_frame
	var seed_value := 5001
	var mode := "qa"
	var until := "first_iron"
	var timeout_minutes := 35.0
	var output := "res://../test-results/agent/latest"
	var args := OS.get_cmdline_user_args()
	for index in args.size():
		match args[index]:
			"--seed": seed_value = int(args[index + 1])
			"--mode": mode = String(args[index + 1])
			"--until": until = String(args[index + 1])
			"--timeout": timeout_minutes = float(args[index + 1])
			"--output": output = String(args[index + 1])

	var main: Node2D = MainScene.instantiate()
	root.add_child(main)
	await process_frame
	main.process_mode = Node.PROCESS_MODE_DISABLED
	main.clear_save()
	main._start_run()
	main.run_seed = seed_value
	main.sim.setup(seed_value)
	main.sim.begin_crash()
	main.player.position = main.sim.cell_centre(main.sim.core_cell + Vector2i(0, 1))
	main.player.warmth = Defs.CRASH_WARMTH
	main.player.velocity = Vector2.ZERO
	main.state = main.State.PLAY

	var telemetry = Telemetry.new(main, seed_value, mode, func() -> float: return 0.0)
	var body = Body.new(main, telemetry)
	telemetry.clock_ref = func() -> float: return body.clock
	var eyes = Observe.new(main.sim, mode)
	var mind = Mind.new(main, body, eyes, telemetry, mode, until, timeout_minutes * 60.0)

	mind.play()

	var snapshot: Dictionary = {}
	if mind.result != "completed":
		snapshot = telemetry.failure_snapshot(mind.goal, body.activity, mind.failure_reason)
	var record: Dictionary = telemetry.to_record(mind.result, mind.failure_kind,
		mind.failure_reason, snapshot, {
			"path_replans": body.replans,
			"interaction_failures": body.interaction_failures,
			"until": until, "timeout_minutes": timeout_minutes,
		})
	var absolute := ProjectSettings.globalize_path(output)
	telemetry.write(absolute, record)
	print("AGENT seed=%d mode=%s result=%s kind=%s t=%.0fs improvements=%d" %
		[seed_value, mode, mind.result, mind.failure_kind, body.clock,
		telemetry.improvements])
	quit(0)
