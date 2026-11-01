extends "res://tests/framework/test_case.gd"

## Step 83 (design/HANDS83.md): the player's hands over the buildings they
## are working -- from the simulation's own state and events, for the stage's
## real length and no longer, a glove and the job's own tool (every action in
## the data has its right one), never for a Momo's or automatic work, back as
## they were after a load with no sound replayed, three at most; and the
## building card's little hand: shown only when it matters, warm and the card
## dimmed when all three are busy, a word over the building when tapped then.

const MainScene := preload("res://scenes/main.tscn")
## Each job and the tool its hands hold (an action with no entry would be a
## tool shown falsely -- hammering what is not built).
const TOOLS := {"sow": "seed_pouch", "water": "watering_can", "harvest": "basket", "dig": "pickaxe", "chop": "axe",
	"replant": "trowel", "study": "flask", "smelt": "hammer", "assemble": "hammer", "stoke": "logs",
	"design": "notebook", "develop": "notebook", "release": "notebook"}

var main: Node
var sim: Simulation
var bs: BuildingSystem
var hands: HandWorks


func before_each() -> void:
	main = MainScene.instantiate()
	tree.root.add_child(main)
	await tree.process_frame
	sim = main.get("sim")
	sim.time_scale = 0.0
	bs = sim.system(&"buildings")
	hands = main.get("hand_works")
	var world: WorldSystem = sim.system(&"world")
	for x in 5:
		for y in 4:
			world.add_land(Vector2i(x, y))
	for id: int in bs.ids().duplicate():
		bs.demolish(id)
	LocaleService.apply("en")
	await tree.process_frame


func after_each() -> void:
	main.queue_free()
	await tree.process_frame


func _ready_at(type: String, cell: Vector2i, action: String = "") -> int:
	var id := bs.place_instant(type, cell)
	var b := bs.get_building(id)
	if action != "":
		var list := bs.stages(b)
		for k in list.size():
			if String((list[k] as Dictionary).get("action", "")) == action:
				b["stage"] = k
				break
	var inv: InventorySystem = sim.system(&"inventory")
	var consumes: Dictionary = bs.current_stage(b).get("consumes", {})
	for item: String in consumes:
		inv.add(item, int(consumes[item]) * 3, "test")
	return id


func test_every_action_in_the_data_has_its_tool() -> void:
	var types: Dictionary = sim.data.get_value("buildings", "types", {})
	var seen := {}
	for type: String in types:
		var b := {"type": type, "stage": 0, "variety": "", "recipe": ""}
		for v: String in [""] + bs.varieties(type):
			b["variety"] = v
			for r: String in [""] + bs.recipes(type):
				b["recipe"] = r
				for stage: Dictionary in bs.stages(b):
					var action := String(stage.get("action", ""))
					if action == "":
						continue
					seen[action] = true
	assert_true(seen.size() >= 10, "the data's actions (%d)" % seen.size())
	for action: String in seen:
		assert_true(TOOLS.has(action), "%s: the test knows its tool" % action)
		var pose := MomoSheet.shared().work_animation(action)
		assert_true(HandWorks.POSES.has(pose), "%s: a pose for the hands (%s)" % [action, pose])
		if HandWorks.POSES.has(pose):
			var tool := String(HandWorks.POSES[pose]["tool"])
			assert_eq(tool, TOOLS.get(action, ""), "%s: its own tool" % action)
			assert_true(hands.tools.has(tool), "%s: %s in the atlas" % [action, tool])


func test_hands_follow_the_players_stage_and_nothing_else() -> void:
	var farm := _ready_at("farm", Vector2i(1, 1), "sow")
	assert_true(hands.hands.is_empty(), "nothing before")
	(main.get("selection") as SelectionController).call("_act_on", farm)
	assert_true(hands.hands.has(farm), "the player's tap: hands at the farm")
	assert_eq(String(hands.hands[farm]["pose"]), "sow", "sowing")
	assert_eq(String(hands.shown()[farm]["tool"]), "seed_pouch", "with the seed pouch")
	# Only while the stage runs.
	var end := int(bs.get_building(farm)["task_end"])
	sim.advance_ms(end - sim.now_ms() - 1)
	await tree.process_frame
	assert_true(hands.hands.has(farm), "a moment before its end, still there")
	sim.advance_ms(1)
	await tree.process_frame
	assert_false(hands.hands.has(farm), "gone when the stage ends")
	var after := bs.get_building(farm)
	assert_ne(after["state"], BuildingSystem.WORKING, "the farm waits or grows now")
	for i in 20:
		sim.advance_ms(250)
		await tree.process_frame
		if bs.get_building(farm)["state"] == BuildingSystem.WORKING:
			break
		assert_false(hands.hands.has(farm), "no hands while it waits or grows")
	# A Momo's job and an automatic one: no hands.
	with_starter_momo(sim)
	var momo: int = (sim.system(&"momo") as MomoSystem).ids()[0]
	var mine := _ready_at("mine", Vector2i(2, 1))
	assert_true(bs.start_stage(mine, momo, 1.0)["ok"], "a Momo works the mine")
	var wood := _ready_at("lumberyard", Vector2i(3, 1))
	assert_true(bs.start_stage(wood, JobSystem.AUTO_WORKER, 1.0)["ok"], "and the lumberyard works by itself")
	await tree.process_frame
	assert_false(hands.hands.has(mine), "no hands for a Momo's work")
	assert_false(hands.hands.has(wood), "nor automatic work")


func test_a_stop_or_a_demolition_takes_the_hands_away() -> void:
	var mine := _ready_at("mine", Vector2i(1, 1))
	var wood := _ready_at("lumberyard", Vector2i(2, 1))
	sim.execute({"type": "building.tap", "id": mine})
	sim.execute({"type": "building.tap", "id": wood})
	assert_eq(hands.hands.size(), 2, "two hands")
	bs.demolish(mine)
	await tree.process_frame
	assert_false(hands.hands.has(mine), "the mine came down: its hands go")
	assert_true(hands.hands.has(wood), "the other stays")


func test_three_at_most_and_each_where_its_building_is() -> void:
	var ids: Array[int] = [_ready_at("farm", Vector2i(0, 1), "water"), _ready_at("mine", Vector2i(1, 1)), _ready_at("lumberyard", Vector2i(2, 1)), _ready_at("research", Vector2i(3, 1))]
	for id: int in ids:
		sim.execute({"type": "building.tap", "id": id})
	(main.get("cameras") as CameraController).frame_island()
	await tree.process_frame
	await tree.process_frame
	assert_eq(hands.hands.size(), 3, "three hands, not four")
	assert_eq(hands.drawn, 3, "all three drawn")
	var views: BuildingViews = main.get("building_views")
	for id: int in hands.hands:
		var s: Dictionary = hands.shown()[id]
		var work: Vector2 = views.view(id).work_point()
		assert_true((s["grip"] as Vector2).distance_to(work) < 80.0, "%d: the hand at its own building (%.0f px)" % [id, (s["grip"] as Vector2).distance_to(work)])
	assert_eq(hands.z_index, UiLayers.Z_HANDS, "over the buildings, by the layer table")
	assert_true(hands.get_canvas_layer_node() == null, "on the world's canvas, under every panel")


func test_a_load_brings_them_back_without_a_sound() -> void:
	var farm := _ready_at("farm", Vector2i(1, 1), "water")
	sim.execute({"type": "building.tap", "id": farm})
	sim.advance_ms(1500)
	var sounds := [0]
	var fresh := HandWorks.new()
	main.get_node("World").add_child(fresh)
	fresh.struck.connect(func(_id: int, _s: String) -> void: sounds[0] += 1)
	fresh.setup(sim, main.get("building_views"), main.get("cameras"))
	assert_true(fresh.hands.has(farm), "the job in progress has its hands at once")
	await tree.process_frame
	assert_eq(sounds[0], 0, "no sound for a stroke already past")
	fresh.queue_free()


func test_one_sound_per_stroke_as_the_tool_lands() -> void:
	FxPrefs.reset()
	var mine := _ready_at("mine", Vector2i(1, 1))
	(main.get("cameras") as CameraController).frame_island()
	var sounds: Array[String] = []
	hands.struck.connect(func(_id: int, s: String) -> void: sounds.append(s))
	sim.execute({"type": "building.tap", "id": mine})
	var period := float(HandWorks.POSES["dig"]["period"])
	for i in int(period * 3.0 / 0.05):
		sim.advance_ms(50)
		await tree.process_frame
	assert_eq(sounds.size(), 3, "three strokes, three taps (%d)" % sounds.size())
	assert_true(sounds.all(func(s: String) -> bool: return s == "tap_pick"), "the pickaxe's tap")


func test_the_card_shows_the_hands_only_when_it_matters() -> void:
	var panel: ContextPanel = main.get("panel")
	var selection: SelectionController = main.get("selection")
	var a := _ready_at("farm", Vector2i(0, 1), "sow")
	var b := _ready_at("mine", Vector2i(1, 1))
	var c := _ready_at("lumberyard", Vector2i(2, 1))
	var d := _ready_at("research", Vector2i(3, 1))
	selection.select_building(d)
	await tree.process_frame
	assert_false(panel.manual_chip.visible, "no hand busy: no chip")
	sim.execute({"type": "building.tap", "id": a})
	await tree.process_frame
	assert_true(panel.manual_chip.visible, "one busy: the lab's card shows 1/3")
	assert_eq(panel.manual_chip.used, 1, "one")
	assert_false(panel.manual_chip.full, "not full")
	sim.execute({"type": "building.tap", "id": b})
	sim.execute({"type": "building.tap", "id": c})
	await tree.process_frame
	assert_true(panel.manual_chip.full, "three busy: the chip warms")
	var card := panel.current_card()
	assert_true(card.modulate.a < 0.9, "and the lab's card dims")
	assert_false(card.disabled, "but still answers a tap")
	var fx: FeedbackFx = main.get("feedback_fx")
	var notes_before := fx.shown.filter(func(s: Dictionary) -> bool: return s["kind"] == "note").size()
	card.pressed.emit()
	assert_eq(String(selection.last_result.get("reason", "")), "err.manual_limit", "the tap is refused for want of a hand")
	var notes := fx.shown.filter(func(s: Dictionary) -> bool: return s["kind"] == "note")
	assert_eq(notes.size(), notes_before + 1, "a word over the lab")
	assert_eq(String(notes[-1]["text"]), tr("err.manual_limit") % 3, "saying why")
	# A Momo's job is never called the player's.
	with_starter_momo(sim)
	var momo: int = (sim.system(&"momo") as MomoSystem).ids()[0]
	var e := _ready_at("farm", Vector2i(4, 1), "sow")
	bs.start_stage(e, momo, 1.0)
	selection.select_building(e)
	await tree.process_frame
	assert_false(panel.manual_chip.visible, "a Momo's farm: no hands chip")
