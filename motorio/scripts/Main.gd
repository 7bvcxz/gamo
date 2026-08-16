extends Node2D

## Orchestrator: owns game state, input routing, camera and the run timer.
## Simulation lives in Sim, drawing lives in the layers, so this file stays thin.

## RESULT is the end of a day, not the end of the game: the world, the factory
## and the warm radius all carry into the next morning.
## SETTINGS is a state rather than an overlay flag so that opening it stops the
## clock: sizing the UI should never cost the player warmth.
enum State { TITLE, OPENING, PLAY, RESULT, SETTINGS, NIGHTFALL, DAYBREAK }
## Phases inside NIGHTFALL and DAYBREAK. Both run on one timer rather than a
## handful of booleans, so there is one place to read what the sequence is doing.
enum Phase { GATHER, GLOW, DAWN, SPILL }

const SHAKE_DECAY := 7.0
const RESCUE_SECONDS := 1.6

@onready var sim: Sim = $Sim
@onready var ground_layer: GroundLayer = $Ground
@onready var cold_fog: ColdFog = $ColdFog
@onready var world_layer: WorldLayer = $World
@onready var machine_layer: MachineLayer = $Machines
## Cats are nodes rather than a pass inside the machine layer, so that a cat's
## shadow, body, drill and gauge move because their parent moved. Its z sits
## between the machines and what the machines say about themselves.
@onready var cats_layer: Node2D = $Cats
@onready var fx: FxLayer = $Fx
@onready var player: PlayerActor = $Player
@onready var camera: Camera2D = $Player/Camera2D
@onready var hud: Control = $UI/HUD
@onready var audio: Node = $Audio
@onready var music: Node = $Music
@onready var touch: TouchControls = $UI/TouchControls
@onready var atmosphere: ColorRect = $Grade/Atmosphere

var state: int = State.TITLE
## The opening plays once, for a run that is actually new. A player who closed
## the tab in the middle of day four does not need to be told again that Earth
## is gone, and the save is the only thing that knows which of the two they are.
var resumed := false
## Which panel is up and how long it has been. Two numbers, because everything
## else about the scene -- the fade, the shake, the line -- is a function of
## them, and a function can be asked what it will do.
var cutscene_panel: int = 0
var cutscene_time: float = 0.0

## The opening's four missions, and where the run is in them.
##
## Four rather than the twenty-two steps they were written as: a mission is the
## name of a situation, not the name of a step. "Investigate the kit" is an
## instruction; "get a fire going" is a predicament, and the player works out the
## steps because the situation makes them obvious.
##
## While any of them is outstanding the day clock does not run. The opening is
## about understanding rather than about hurrying, and the pressure it does need
## is already coming from her own temperature.
enum Mission { BASE, SURVIVE, MEANS, EXPLORE, DONE }
var mission: int = Mission.DONE

var time_left: float = Defs.DAY_SECONDS
var selected_index: int = 0
var build_dir := Vector2i.RIGHT
var shake: float = 0.0
var collapse_timer: float = -1.0
var run_seed: int = 0
var day_number: int = 1
var day_start_heat: int = 0
var rescued_tonight: bool = false
var message: String = ""
var message_life: float = 0.0
var night_warned: bool = false
var build_held: bool = false
var build_hold_time: float = 0.0
var build_rotated: bool = false
## True once a held Z has actually been swinging at a seam. Without it, letting
## go after mining runs the tap action -- and standing at the shelter mining the
## seam beside it would put her to bed.
var mine_swung: bool = false
## The swing frame the last time we looked, so the impact sound fires on the
## crossing rather than for every frame the pickaxe spends at the bottom.
var last_mine_frame: int = -1
## The walk frame a footfall was last played on, so one frame makes one sound.
var last_step_frame: int = -1
## Cats at the bowl get a bite sound on a slow timer of their own. Tying it to
## the chewing animation would fire three and a half times a second per cat,
## which is not a sound, it is a texture.
var nibble_timer: float = 0.0
const NIBBLE_INTERVAL := 0.44
var autosave_elapsed: float = 0.0
var blackout: float = 0.0
## True while the mine key is held. Hand mining is a hold, not a tap.
var mine_held: bool = false
## The machine whose throughput panel is open, or the invalid sentinel. Pinned to
## a cell rather than following what the player faces, so the numbers hold still
## while they are being read.
var meter_cell := Vector2i(9999, 9999)
## The nightfall/daybreak sequence.
var night_phase: int = Phase.GATHER
var night_timer: float = 0.0
## While this is >= 0 it decides how dark the world is drawn. The clock cannot:
## it is pinned at zero all through the sequence and back at a full day before
## the sun has actually come up.
var night_override: float = -1.0
## Extra camera pull-in during the sequence, eased rather than snapped.
var cinema_zoom: float = 1.0
## Which entry of Defs.DEBUG_SPEEDS is active. Never persisted: a save that came
## back at ten times speed would be a very confusing bug report.
var speed_index: int = 0
## Player's UI size multiplier, applied on top of the per-platform base.
var ui_scale: float = Defs.UI_SCALE_DEFAULT
## The same idea for the world: how large the game itself is drawn, which is the
## camera's zoom rather than anything the HUD does.
var game_scale: float = Defs.GAME_SCALE_DEFAULT
var state_before_settings: int = State.TITLE
## The build gun's menu. Not a State: the world keeps running behind it, the way
## this genre's build menus do, and movement is on WASD so the arrow keys the
## menu wants are free.
var build_menu_open: bool = false
## The fire's own window: what she is putting in and what she can make out of it.
## One door rather than two -- everything the base does is behind the same key,
## on the same building, and the player never has to learn which press is which.
var base_menu_open: bool = false
## Which entry of Defs.BUILDABLE the cursor is on. Separate from selected_index,
## which is what the gun is actually loaded with -- browsing must not change what
## a stray Z would build.
var menu_index: int = 0

## --- The slot machine ---------------------------------------------------------
## A modal over the world like the build list, not a State: the factory should
## keep running while a player watches the reels, and stopping it would make a
## three-second animation into a three-second pause in production.
var gacha_open: bool = false
## The map, and how far in it is zoomed. Zoom is a run-long setting rather than
## something that resets when the card closes: a player who zoomed out to find a
## seam wants it still zoomed out when they check again a minute later.
var map_open: bool = false
var map_zoom: float = Defs.MAP_ZOOM_DEFAULT
## Which of Defs.GACHA_COUNTS the cursor is on.
var gacha_index: int = 0
## Seconds of reel left, or negative when they are not turning. The pull has
## already been paid for by the time this is positive.
var gacha_spin: float = -1.0
## How many cats the turning reels owe, so the roll can happen when they stop
## rather than being decided and then hidden for three seconds.
var gacha_pending: int = 0
## What the last pull produced, oldest first. Stays on screen until the next
## pull, which is what makes the reel area the result window as well.
var gacha_results: Array[int] = []

func _ready() -> void:
	randomize()
	# Engine.time_scale is global and survives a scene reload, so a run that ends
	# while sped up would hand the next one a ten-times world.
	Engine.time_scale = 1.0
	speed_index = 0
	sim.heat_gained.connect(_on_heat_gained)
	sim.build_rejected.connect(_on_build_rejected)
	sim.warmth_changed.connect(_on_warmth_changed)
	sim.base_upgraded.connect(_on_base_upgraded)
	sim.cat_thawed.connect(_on_cat_thawed)
	world_layer.sim = sim
	ground_layer.sim = sim
	cold_fog.sim = sim
	machine_layer.sim = sim
	cats_layer.sim = sim
	hud.set("main", self)
	player.blocked = func(cell: Vector2i) -> bool: return sim.blocks_player(cell)
	touch.main_controller = self
	touch.player = player
	atmosphere.set("main", self)
	load_settings()
	_start_run()
	if load_game():
		resumed = true
		_notify("이어서 진행합니다", Defs.COL_CORE)
	state = State.TITLE

## --- The opening ----------------------------------------------------------
## 처음부터. A new run is a new crash, and the story of how she got there is
## part of it -- a player who asked for the beginning asked for the beginning.
func _restart_from_the_top() -> void:
	_start_run()
	resumed = false
	cutscene_panel = 0
	cutscene_time = 0.0
	state = State.OPENING

func _leave_title() -> void:
	audio.call("play", "confirm")
	if resumed:
		state = State.PLAY
		return
	cutscene_panel = 0
	cutscene_time = 0.0
	state = State.OPENING

func _process_cutscene(delta: float) -> void:
	cutscene_time += delta
	if cutscene_time < Defs.cutscene_panel_seconds():
		return
	_advance_cutscene()

func _advance_cutscene() -> void:
	cutscene_panel += 1
	cutscene_time = 0.0
	if cutscene_panel >= Defs.CUTSCENE_PANELS.size():
		_end_cutscene()

## Straight into the run. No fanfare: the last panel is her waking in the snow
## and the first frame of play is the same thing, so anything between them would
## be an interruption of the one join the scene exists to make.
func _end_cutscene() -> void:
	cutscene_panel = 0
	cutscene_time = 0.0
	state = State.PLAY

func _start_run() -> void:
	run_seed = randi()
	sim.setup(run_seed)
	day_number = 1
	day_start_heat = 0
	time_left = Defs.DAY_SECONDS
	sim.begin_crash()
	mission = Mission.BASE
	# She wakes where she landed, beside the kit rather than on top of it.
	player.position = sim.cell_centre(sim.core_cell)
	player.warmth = Defs.CRASH_WARMTH
	player.locked = false
	player.velocity = Vector2.ZERO
	collapse_timer = -1.0
	player.collapse = 0.0
	blackout = 0.0
	night_warned = false
	meter_cell = Vector2i(9999, 9999)
	build_menu_open = false
	base_menu_open = false
	map_open = false
	menu_index = 0
	tool_index = 0
	# A run that was reloaded or restarted mid-sequence would otherwise keep the
	# sky pinned at night and the player locked indoors.
	night_override = -1.0
	night_phase = Phase.GATHER
	night_timer = 0.0
	cinema_zoom = 1.0
	rescued_tonight = false
	selected_index = 0
	shake = 0.0
	message = ""
	message_life = 0.0
	gacha_open = false
	gacha_index = 0
	gacha_spin = -1.0
	gacha_pending = 0
	gacha_results.clear()

## The next useful action, as text plus a picture of the thing it is about.
##
## Both come out of the same branch on purpose. They were going to be two
## functions -- one returning the sentence, one returning an icon for it -- and
## that is a pair that drifts: add a step, update one, and the panel ends up
## showing a generator next to a line about cats. One branch, one answer.
##
## Derived from world state rather than a script, so it stays correct however the
## player plays.
## How to mine, in the words of whichever device is holding the game.
##
## This line said "press C" for eight versions after C stopped mining. It is the
## first instruction a new player is given and it named a key that opens the
## throughput meter, so the opening minute of the game was a player pressing a
## key and watching nothing happen. Mining moved onto the pickaxe in 0.20.22 and
## the sentence describing it did not move with it.
##
## Two devices, two sentences, because they genuinely differ: a phone has no Z to
## hold and a desktop has no 캐기 button to press. Both need the pickaxe first --
## hand mining checks holding_pickaxe() before anything else -- which is the part
## the old line never mentioned at all.
func _mining_hint() -> String:
	if touch != null and touch.visible:
		return "곡괭이를 고르고 열석 광맥 위에서 Z 버튼을 누르고 계세요"
	return "2번 곡괭이를 들고 열석 광맥 위에서 Z 를 누르고 계세요"

func objective_data() -> Dictionary:
	# Freezing comes before everything, including nightfall. A playtest caught the
	# card reading "고양이 상자를 3개 모아 숙소로 가져가세요" over a screen at 0% warmth
	# with "의식이 흐려집니다 1.4초" written across it. The objective is the largest
	# text on screen and it was calmly discussing errands. Night is a fifty second
	# warning; this is seconds from a blackout that costs a quarter of the run's
	# heat, so it outranks it.
	if not indoors() and player.warmth <= Defs.FROST_STAGES[2]:
		# Before the fire exists there is no radius to get back inside, and
		# telling her to go somewhere that does not exist is worse than telling
		# her nothing. The instruction is the same one the mission gives, said
		# with the urgency the temperature has earned.
		if not sim.base_placed:
			return _goal(Defs.mission_line("COLD-NOBASE"), "thing", Icons.THING_CORE)
		return _goal("몸이 얼고 있습니다  온기 반경 안으로 돌아가세요", "thing", Icons.THING_CORE)
	if is_night():
		return _goal("밤입니다  숙소로 돌아가 Z로 취침하세요", "thing", Icons.THING_SHELTER)
	if is_dusk():
		return _goal("해가 기울고 있습니다  곧 숙소로 돌아가야 합니다", "thing", Icons.THING_SHELTER)
	if sim.carried_cat != null:
		return _goal(Defs.mission_line("CARRY-CAT"), "thing", Icons.THING_CAT)
	# Ahead of the mining line: a thawing cat is three seconds from being the
	# thing the player has been walking towards, and a card telling them to go
	# back to a seam in the middle of it is the game looking away.
	# Both of these sit above the mining line, and for the same reason the carried
	# cat does: what she is holding, or what is three seconds from waking up, is
	# more urgent than the errand she was on before. A player who walked out and
	# picked one up before ever swinging the pickaxe was being told to go and
	# mine, with a body in her arms.
	if sim.carried_frozen:
		return _goal(Defs.mission_line("CARRY-FROZEN"), "thing", Icons.THING_CAT_FROZEN)
	if _thawing_nearby():
		return _goal(Defs.mission_line("THAW"), "thing", Icons.THING_CAT_FROZEN)
	# The opening. Four rungs of its own, above the ordinary ladder, because
	# until they are done most of that ladder is about machines that cannot be
	# built yet and a base that does not exist.
	if sim.carried_kit == Defs.KIT_BASE:
		return _goal(Defs.mission_line("M1-HOLD"), "thing", Icons.THING_CORE)
	if sim.carried_kit == Defs.KIT_SHELTER:
		return _goal(Defs.mission_line("M2-HOLD"), "thing", Icons.THING_SHELTER)
	match mission:
		Mission.BASE:
			return _goal(Defs.mission_line("M1"), "thing", Icons.THING_KIT)
		Mission.SURVIVE:
			return _goal(Defs.mission_line("M2"), "thing", Icons.THING_KIT)
		Mission.MEANS:
			if sim.has_fuel():
				return _goal(Defs.mission_line("M3-HOLD"), "thing", Icons.THING_CORE)
			return _goal(Defs.mission_line("M3"), "thing", Icons.THING_SEAM)
		Mission.EXPLORE:
			return _goal(Defs.mission_line("M4"), "thing", Icons.THING_CAT_FROZEN)
	# Lv1 -- do it with your hands, then hire someone to do it for you.
	if int(sim.stock.get(Defs.ITEM_HEATSTONE, 0)) == 0 and sim.ground.is_empty():
		return _goal(_mining_hint(), "thing", Icons.THING_SEAM)
	if sim.cats.is_empty() and not sim.frozen_cats.is_empty():
		return _goal("얼어붙은 고양이를 찾아 Z 로 안고 오세요", "thing", Icons.THING_CAT_FROZEN)
	# Lv2 -- automation, then the exchanger that turns it into distance.
	if sim.machine_count(Defs.M_MINER) == 0:
		return _goal("광맥 위에 채굴기를 설치하세요  (열석 %d)"
			% int(Defs.MACHINE_COSTS[Defs.M_MINER][Defs.ITEM_HEATSTONE]), "machine", Defs.M_MINER)
	# Only while there is somewhere to put one. A spare cat and no free miner is a
	# normal thing to own -- the gacha hands out cats faster than seams appear,
	# and the third cat in the standard scenario exists precisely to haul what the
	# other two dig. Asking for it anyway names an action with no target, and
	# because this rung sits early in the ladder it also hides every rung after
	# it: the player never gets told about the exchanger, copper or power for as
	# long as one cat is idle. A wrong instruction is bad; a wrong instruction
	# that silences the correct one for the rest of the run is worse.
	if _unassigned_cats() > 0 and not sim.idle_miner_cells().is_empty():
		return _goal("고양이를 Z 로 안아 채굴기에 올려놓으세요", "thing", Icons.THING_CAT)
	if sim.machine_count(Defs.M_EXCHANGER) == 0:
		return _goal("수정에너지교환기를 지으세요  (수정조각 %d)"
			% int(Defs.MACHINE_COSTS[Defs.M_EXCHANGER][Defs.ITEM_CRYSTAL]), "machine", Defs.M_EXCHANGER)
	if int(sim.delivered.get(Defs.ITEM_ENERGY, 0)) == 0:
		return _goal("교환기에 수정조각을 넣고 에너지결정을 기지로 가져가세요", "item", Defs.ITEM_ENERGY)
	if sim.warm_radius < Defs.COPPER_RING.x:
		return _goal("에너지결정으로 온기를 넓히세요  (구리까지 %.1f칸)"
			% (Defs.COPPER_RING.x - sim.warm_radius), "item", Defs.ITEM_ENERGY)
	# Lv3 -- copper, power, logistics.
	if int(sim.stock.get(Defs.ITEM_COPPER, 0)) == 0:
		return _goal("구리 광맥에 채굴기를 놓아 구리광석을 캐세요", "item", Defs.ITEM_COPPER)
	if sim.machine_count(Defs.M_GENERATOR) == 0:
		return _goal("발전기를 지어 전력을 만드세요  (구리광석 %d)"
			% int(Defs.MACHINE_COSTS[Defs.M_GENERATOR][Defs.ITEM_COPPER]), "machine", Defs.M_GENERATOR)
	if sim.machine_count(Defs.M_BELT) == 0:
		return _goal("벨트로 채굴기와 기지를 이으세요  (구리광석 %d)"
			% int(Defs.MACHINE_COSTS[Defs.M_BELT][Defs.ITEM_COPPER]), "machine", Defs.M_BELT)
	if sim.power_draw > sim.power_capacity:
		return _goal("전력이 부족합니다  발전기를 늘리세요", "machine", Defs.M_GENERATOR)
	if _unstaffed_miners() > 0 and sim.power_capacity <= 0.0:
		return _goal("발전기를 지으면 고양이 없이도 채굴기가 돕니다", "machine", Defs.M_GENERATOR)
	return _goal("%s  ·  더 지을수록 온기가 빨라집니다" % Defs.ratio_hint(), "machine", Defs.M_EXCHANGER)

func _goal(text: String, kind: String, id) -> Dictionary:
	return {"text": text, "kind": kind, "id": id}

func objective() -> String:
	return String(objective_data()["text"])

## Miners standing idle for want of a worker. Once power exists these run
## themselves, so this is the number that tells the player to electrify.
func _unstaffed_miners() -> int:
	var count := 0
	for cell: Vector2i in sim.machines:
		if sim.machines[cell].type == Defs.M_MINER and not sim.machines[cell].operated:
			count += 1
	return count

func _unassigned_cats() -> int:
	var count := 0
	for cat in sim.cats:
		if not cat.has_job():
			count += 1
	return count

## Taking a tool out. Only the torch does anything when it is picked up, and it
## does it here rather than in the key handler so the touch row goes through the
## same door.
func _on_tool_selected() -> void:
	if TOOLS[tool_index] != TOOL_TORCH:
		return
	sim.learn("TORCH")
	if sim.light_torch():
		audio.call("play", "confirm")
		fx.ring(player.position, Defs.COL_CORE, Defs.RING_MEDIUM)
	else:
		_notify("%s이 없습니다  기지에서 만들 수 있습니다" % Defs.TORCH_NAME,
			Defs.COL_TEXT_DIM)
		audio.call("play", "deny")

## The toolbar. One tool for now -- the build gun -- but it is a list because the
## slot it lives in is a tool slot, not a machine slot: that is the whole point of
## the change. What the gun is loaded with is chosen in its menu, not by which
## number key was pressed last.
const TOOL_BUILD_GUN := 0
const TOOL_PICKAXE := 1
const TOOL_TORCH := 2
const TOOLS: Array[int] = [TOOL_BUILD_GUN, TOOL_PICKAXE, TOOL_TORCH]
const TOOL_NAMES := ["건물건설총", "곡괭이", Defs.TORCH_NAME]

var tool_index: int = 0

func holding_build_gun() -> bool:
	return TOOLS[tool_index] == TOOL_BUILD_GUN

func holding_pickaxe() -> bool:
	return TOOLS[tool_index] == TOOL_PICKAXE

## Selected *and* alight. Choosing the slot with an empty pack shows the slot and
## lights nothing, which is what tells the player they have run out.
func holding_torch() -> bool:
	return TOOLS[tool_index] == TOOL_TORCH and sim.torch_left > 0.0

func selected_type() -> int:
	return Defs.BUILDABLE[selected_index]

## B opens and closes it, and so does Esc. Toggling rather than a separate close
## key because a menu that opens with one press and needs a different one to
## leave is a menu players get stuck in.
func toggle_build_menu() -> bool:
	if state != State.PLAY:
		return false
	build_menu_open = not build_menu_open
	if build_menu_open:
		menu_index = selected_index
		meter_cell = Vector2i(9999, 9999)
		gacha_open = false
		map_open = false
	audio.call("play", "select")
	return true

func _base_menu_key(key: InputEventKey) -> void:
	match key.keycode:
		KEY_ESCAPE, KEY_X:
			close_base_menu()
		KEY_UP, KEY_DOWN:
			var step: int = -1 if key.keycode == KEY_UP else 1
			menu_index = posmod(menu_index + step, maxi(1, base_rows().size()))
			audio.call("play", "select")
		KEY_Z, KEY_ENTER, KEY_KP_ENTER:
			_base_menu_confirm()

func _build_menu_key(key: InputEventKey) -> void:
	var count: int = Defs.BUILDABLE.size()
	match key.keycode:
		KEY_ESCAPE, KEY_B:
			build_menu_open = false
			audio.call("play", "select")
		KEY_UP, KEY_LEFT, KEY_W, KEY_A:
			menu_index = posmod(menu_index - 1, count)
			audio.call("play", "select")
		KEY_DOWN, KEY_RIGHT, KEY_S, KEY_D:
			menu_index = posmod(menu_index + 1, count)
			audio.call("play", "select")
		KEY_Z, KEY_ENTER, KEY_KP_ENTER:
			_load_build_gun(menu_index)
	if key.keycode >= KEY_1 and key.keycode < KEY_1 + count:
		_load_build_gun(key.keycode - KEY_1)

## --- The map ------------------------------------------------------------------
## What the player has seen, drawn small. Everything else is void: the fog is
## what makes walking somewhere worth anything, and a map that showed the whole
## plateau would answer the only question exploring asks.
func toggle_map() -> bool:
	if state != State.PLAY:
		return false
	map_open = not map_open
	if map_open:
		# One window at a time. Two would both claim the keyboard, and the arrow
		# keys mean different things in each.
		build_menu_open = false
		close_gacha()
		meter_cell = Vector2i(9999, 9999)
	audio.call("play", "select")
	return true

func set_map_zoom(value: float) -> void:
	map_zoom = snappedf(clampf(value, Defs.MAP_ZOOM_MIN, Defs.MAP_ZOOM_MAX),
		Defs.MAP_ZOOM_STEP)

func _map_key(key: InputEventKey) -> void:
	match key.keycode:
		KEY_ESCAPE, KEY_M:
			map_open = false
			audio.call("play", "select")
		KEY_LEFT, KEY_A, KEY_MINUS:
			set_map_zoom(map_zoom - Defs.MAP_ZOOM_STEP)
			audio.call("play", "select")
		KEY_RIGHT, KEY_D, KEY_EQUAL:
			set_map_zoom(map_zoom + Defs.MAP_ZOOM_STEP)
			audio.call("play", "select")

## Drawn into the HUD's canvas, because that is where the card is.
##
## Cells rather than machines are the unit: the map's job is "have I been here
## and what is there", and at two pixels a cell a machine is a dot either way.
func draw_map(on: CanvasItem, view: Rect2) -> void:
	var scale: float = Defs.MAP_CELL_PX * map_zoom
	var centre: Vector2 = view.position + view.size * 0.5
	var here: Vector2i = sim.cell_of(player.position)
	# How many cells fit, plus one so the edge row is drawn rather than clipped
	# into a gap the eye reads as unexplored.
	var reach := Vector2i(int(view.size.x / scale * 0.5) + 1,
		int(view.size.y / scale * 0.5) + 1)
	var block: float = maxf(scale * float(Sim.EXPLORED_CHUNK), 1.0)
	var dot: float = maxf(scale, 2.0)

	var seen := Color(0.78, 0.83, 0.90, 1.0)
	for dy in range(-reach.y, reach.y + 1, Sim.EXPLORED_CHUNK):
		for dx in range(-reach.x, reach.x + 1, Sim.EXPLORED_CHUNK):
			var cell: Vector2i = here + Vector2i(dx, dy)
			if not sim.is_explored(cell):
				continue
			var at: Vector2 = centre + Vector2(cell - here) * scale
			on.draw_rect(Rect2(at, Vector2(block, block)), seen)

	# Only what stands in explored ground. A seam nobody has been near must not
	# appear on the map because it happens to be inside the drawn area.
	for cell: Vector2i in sim.ore:
		if not sim.is_explored(cell):
			continue
		var at: Vector2 = centre + Vector2(cell - here) * scale
		on.draw_rect(Rect2(at, Vector2(dot, dot)), Defs.ITEM_COLORS[int(sim.ore[cell])])
	for cell: Vector2i in sim.machines:
		if not sim.is_explored(cell):
			continue
		var machine: Sim.Machine = sim.machines[cell]
		var at: Vector2 = centre + Vector2(cell - here) * scale
		if machine.type == Defs.M_CORE:
			on.draw_circle(at + Vector2(scale, scale) * 0.5, maxf(scale * 2.0, 5.0),
				Defs.COL_CORE)
			continue
		on.draw_rect(Rect2(at, Vector2(dot, dot)), Defs.COL_MACHINE_EDGE)
	# Grim last, over everything, because the one thing a map has to answer
	# instantly is where you are.
	on.draw_circle(centre, 4.0, Color(0.05, 0.06, 0.09, 0.9))
	on.draw_circle(centre, 2.6, Defs.COL_TEXT)

## --- The slot machine ---------------------------------------------------------
## G opens and closes it, and so does Esc, for the same reason B does the build
## list: a window you enter with one key and leave with another is a window
## players get stuck in.
func toggle_gacha() -> bool:
	if state != State.PLAY:
		return false
	# One gate, at the only door. The key, the pad and the on-screen button all
	# arrive here, so switching the feature off cannot leave one of the three
	# still open -- which is how a half-removed feature usually shows up.
	if not Defs.GACHA_ENABLED:
		return false
	if gacha_open:
		close_gacha()
		return true
	gacha_open = true
	# Two modals over the same world would both claim the keyboard.
	build_menu_open = false
	map_open = false
	meter_cell = Vector2i(9999, 9999)
	audio.call("play", "select")
	return true

## Closing mid-spin is allowed and costs nothing extra: the coins are already
## gone, and the reels finish in the background so the cats still arrive. A
## window that refuses to close is worse than one that resolves without you.
func close_gacha() -> void:
	if not gacha_open:
		return
	gacha_open = false
	audio.call("play", "select")

## Presses one of the three buttons. Charges immediately -- see Sim.begin_gacha
## for why -- and starts the reels; the grades are rolled when they stop.
func start_gacha(index: int) -> bool:
	if not gacha_open or gacha_spin >= 0.0:
		return false
	if index < 0 or index >= Defs.GACHA_COUNTS.size():
		return false
	gacha_index = index
	var count: int = Defs.GACHA_COUNTS[index]
	if not sim.begin_gacha(count):
		_notify("코인이 부족합니다", Defs.COL_DANGER)
		audio.call("play", "deny")
		return false
	gacha_pending = count
	gacha_spin = Defs.GACHA_SPIN_SECONDS
	gacha_results.clear()
	audio.call("play", "confirm")
	return true

## Runs whether or not the window is open, so closing it mid-spin still delivers.
func _update_gacha(delta: float) -> void:
	if gacha_spin < 0.0:
		return
	gacha_spin -= delta
	if gacha_spin > 0.0:
		return
	gacha_spin = -1.0
	gacha_results = sim.pull_gacha(gacha_pending)
	gacha_pending = 0
	var best: int = Defs.RARITY_O
	for grade: int in gacha_results:
		best = maxi(best, grade)
	# The rarest thing in the pull is what the moment is about, so the feedback
	# scales with it rather than with how many cats came out.
	if best >= Defs.RARITY_SR:
		_notify("%s 고양이!" % Defs.RARITY_NAMES[best], Defs.RARITY_COLORS[best])
		fx.ring(player.position, Defs.RARITY_COLORS[best], Defs.RING_MILESTONE)
		shake = maxf(shake, Defs.FX_LARGE)
		audio.call("play", "finish")
	else:
		_notify("고양이 %d마리를 맞이했습니다" % gacha_results.size(), Defs.COL_CORE)
		audio.call("play", "deliver")

## Keyboard while the window is up. Left and right pick the amount, Z pulls;
## the same three buttons the pointer taps, reachable without one.
func _gacha_key(key: InputEventKey) -> void:
	var count: int = Defs.GACHA_COUNTS.size()
	match key.keycode:
		KEY_ESCAPE, KEY_G:
			close_gacha()
		KEY_LEFT, KEY_A, KEY_UP, KEY_W:
			gacha_index = posmod(gacha_index - 1, count)
			audio.call("play", "select")
		KEY_RIGHT, KEY_D, KEY_DOWN, KEY_S:
			gacha_index = posmod(gacha_index + 1, count)
			audio.call("play", "select")
		KEY_Z, KEY_ENTER, KEY_KP_ENTER:
			start_gacha(gacha_index)

## Loading the gun. A locked machine can be looked at in the menu -- seeing what
## is coming is half of why the menu exists -- but it cannot be loaded.
func _load_build_gun(index: int) -> void:
	var type: int = Defs.BUILDABLE[index]
	if not sim.is_unlocked(type):
		_notify("%s%s 아직 해금되지 않았습니다"
			% [Defs.MACHINE_NAMES[type], Defs.topic(Defs.MACHINE_NAMES[type])],
			Defs.COL_DANGER)
		audio.call("play", "select")
		return
	selected_index = index
	menu_index = index
	build_menu_open = false
	_notify("%s 장전" % Defs.MACHINE_NAMES[type], Defs.COL_CORE)
	audio.call("play", "confirm")

func day_fraction() -> float:
	return clampf(1.0 - time_left / Defs.DAY_SECONDS, 0.0, 1.0)

## How dark to draw the world, 0 morning to 1 deep night. Normally the clock
## decides, but the night sequence has to hold the sky at night while the clock
## reads zero and then walk it back to morning while the clock reads a full day.
func night_level() -> float:
	return night_override if night_override >= 0.0 else day_fraction()

## True while the player is inside the hut: asleep, or waiting for the sun. They
## are a silhouette on the shelter wall then, not a figure standing in the snow.
func indoors() -> bool:
	match state:
		State.NIGHTFALL:
			return night_phase == Phase.GLOW
		State.DAYBREAK:
			return night_phase == Phase.DAWN
		State.RESULT:
			# The summary card sits inside the sequence, with the lit hut behind it.
			return night_override >= 0.0
	return false

## Whether the camera leans in on the hut. Deliberately not the same as being
## indoors: the summary card is a full-screen panel that lands squarely on the
## shelter, so holding a close-up behind it would frame the one thing the card
## covers. The camera is out for the card and leans back in for the sunrise.
func cinema() -> bool:
	match state:
		State.NIGHTFALL:
			return night_phase == Phase.GLOW
		State.DAYBREAK:
			return night_phase == Phase.DAWN
	return false

func is_night() -> bool:
	return time_left <= Defs.NIGHT_SECONDS

func is_dusk() -> bool:
	return time_left <= Defs.DUSK_SECONDS

func shelter_position() -> Vector2:
	return sim.cell_centre(sim.shelter_cell)

## Where the player stands when they wake: the doorstep, since the hut itself is
## solid and putting them inside it would leave them clipped into a structure.
func shelter_doorstep() -> Vector2:
	return shelter_position() + Vector2(0.0, float(Defs.TILE))

func shelter_nearby() -> bool:
	return player.global_position.distance_to(shelter_position()) <= Defs.SHELTER_REACH

## Is a window up? One predicate, because every part of the game that has to
## behave differently while one is open has to agree about when that is -- and
## the last time this was decided in two places, the build list took the arrow
## keys and Grim walked off anyway.
func modal_open() -> bool:
	return build_menu_open or gacha_open or map_open or base_menu_open

func _process(delta: float) -> void:
	_follow_music()
	# Pushed rather than pulled: the character polls Input directly, so it needs
	# to be told, and being told once a frame from here is what keeps the answer
	# in one place.
	player.modal = modal_open()
	# Re-applied every frame because the platform base follows the touch pad,
	# which appears and disappears as the player switches between thumb and
	# keyboard mid-session.
	_apply_camera_zoom(delta)
	var view := _view_rect()
	var dark: float = night_level()
	world_layer.set_view(view)
	world_layer.night = dark
	ground_layer.night = dark
	ground_layer.view_rect = view
	cold_fog.view_rect = view
	cold_fog.night = dark
	machine_layer.view_rect = view
	cats_layer.view_rect = view
	machine_layer.night = dark
	# Two tiles to the player's right, on the same ground line, so the generated
	machine_layer.shelter_glow = shelter_glow()
	machine_layer.shelter_sleepers = sim.cats.size() + 1
	machine_layer.focus_cell = player.facing_cell() if state == State.PLAY else Vector2i(9999, 9999)
	# A panel pinned to a machine the player has since demolished would keep
	# reporting a machine that no longer exists.
	if meter_cell != Vector2i(9999, 9999) and sim.machine_at(meter_cell) == null:
		meter_cell = Vector2i(9999, 9999)
	machine_layer.meter_cell = meter_cell

	_update_ambience(delta)
	message_life = maxf(0.0, message_life - delta)
	_update_build_hold(delta)
	_update_hand_mining(delta)
	player.carrying_cat = sim.carried_cat != null
	player.carrying_frozen = sim.carried_frozen
	player.carrying_kit = sim.carried_kit
	# The carried cat rides in front of her, turning as she turns. Driven from
	# here because the sim does not know where the player is standing.
	if sim.carried_cat != null:
		sim.carry_at(player.position, Vector2(player.facing))
		player.carried_cat_pos = sim.carried_cat.pos
		player.carried_cat_heading = sim.carried_cat.heading
		player.carried_cat_rarity = sim.carried_cat.rarity
	if state == State.PLAY:
		autosave_elapsed += delta
		if autosave_elapsed >= AUTOSAVE_INTERVAL:
			autosave_elapsed = 0.0
			save_game(false)
	if shake > 0.0:
		shake = maxf(0.0, shake - SHAKE_DECAY * delta)
		camera.offset = Vector2(randf_range(-shake, shake), randf_range(-shake, shake))
	else:
		camera.offset = Vector2.ZERO

	match state:
		State.PLAY: _process_play(delta)
		State.TITLE: pass
		State.OPENING: _process_cutscene(delta)
		State.NIGHTFALL: _process_nightfall(delta)
		State.DAYBREAK: _process_daybreak(delta)
		State.RESULT, State.SETTINGS: pass

	# After the state machine, not before it. These two read the state, and
	# setting them first means they describe the frame that has just gone rather
	# than the one about to be drawn: on the frame the sequence steps from DAWN
	# to SPILL, the door opens on an empty doorstep because she was still being
	# hidden by the phase that ended a few lines ago. One frame, and a playtest
	# screenshot landed on it.
	#
	# The title is a hero shot: no player, no placement ghost, nothing that reads
	# as leftover debug UI in the one frame that sells the game.
	# Opening settings from the title must not spoil the hero shot, so visibility
	# follows the screen the panel was opened over rather than the panel itself.
	var showing: int = state_before_settings if state == State.SETTINGS else state
	var in_run: bool = showing != State.TITLE and showing != State.OPENING
	player.visible = in_run and not indoors()
	machine_layer.show_preview = state == State.PLAY and sim.base_placed

## Wind is always there and swells at night; the cold layer tracks how exposed
## the player actually is, so the ear learns the danger before the screen does.
func _update_ambience(delta: float) -> void:
	# The opening is the title's neighbour here, not the run's: the day clock is
	# not running and the player is not standing in the cold, so a cold bed that
	# tracked her warmth would be describing a scene she is not in yet.
	if state == State.TITLE or state == State.OPENING:
		audio.call("set_bed", "wind", 0.35, delta)
		audio.call("set_bed", "cold", 0.0, delta)
		return
	var night: float = day_fraction()
	audio.call("set_bed", "wind", 0.45 + night * 0.45, delta)
	var exposure: float = clampf(1.0 - player.warmth / 100.0, 0.0, 1.0)
	if sim != null and not sim.is_warm(player.cell()):
		exposure = maxf(exposure, 0.45)
	audio.call("set_bed", "cold", exposure, delta)

## Holding the build key past the threshold rotates instead of building, so PC
## players never need a second key for direction.
const BUILD_HOLD_ROTATE := 0.4
## Slots, not one file. A single save meant every session overwrote the last one
## and a bad decision was permanent; three is enough to keep a known-good run
## while trying something.
##
## Slot 0 is the autosave, so the timed write can never land on a slot the player
## put something in deliberately. clear_save() still empties every slot, because
## the thing it exists for -- 처음부터 -- means all of it.
##
## Thirty of them plus the autosave. More than fit on a card, so the list
## scrolls; the cost of an unused slot is a file that was never written, which is
## nothing.
const SAVE_SLOTS := 31
## Renamed with the game (2026-08-14). Saves written before that are not
## reachable anyway: Godot derives the user data directory from
## `config/name`, so changing "Motorio: One Shot" to "Motorio" moves the whole
## directory regardless of what the files inside are called. The schema check on
## load is what makes that safe -- an unrecognised file starts a new run rather
## than half-restoring one.
const SAVE_PATH := "user://motorio_save.cfg"
const SAVE_SCHEMA := 5

static func slot_path(slot: int) -> String:
	return SAVE_PATH if slot <= 0 else "user://motorio_save_%d.cfg" % slot
const AUTOSAVE_INTERVAL := 30.0

func _update_build_hold(delta: float) -> void:
	# Holding Z turns the ghost, but only when the build gun is out. With the
	# pickaxe it is the swing, and a swing that spun the build direction every
	# quarter second would be a key doing two unrelated things at once.
	if not build_held or not holding_build_gun():
		return
	build_hold_time += delta
	# Keeps turning for as long as the key is down, one quarter turn per
	# interval, so reaching the far side does not need four separate presses.
	while build_hold_time >= BUILD_HOLD_ROTATE:
		build_hold_time -= BUILD_HOLD_ROTATE
		build_rotated = true
		build_dir = Vector2i(-build_dir.y, build_dir.x)
		audio.call("play", "select")

func _process_play(delta: float) -> void:
	_update_footsteps()
	# Where Grim has been is what the map is allowed to show. Marked from here
	# rather than inside the character, because the character does not know about
	# the world and this is the one place that has both.
	sim.mark_explored(sim.cell_of(player.position), Defs.SIGHT_RADIUS)
	sim.walked += player.velocity.length() * delta / float(Defs.TILE)
	if player.velocity.length() > PlayerActor.SPEED * 1.2:
		sim.learn("RUN")
	player.prompt = active_prompt()
	# The clock is held until the opening is over. Thirteen minutes of tutorial
	# is four days at this length: the summary card would interrupt it four
	# times, and the first night would arrive at 3:00 -- before there is anywhere
	# to sleep, which is the thing the second mission is about.
	if mission == Mission.DONE:
		time_left = maxf(0.0, time_left - delta)
	sim.tick(delta)
	_update_nibbles(delta)
	_update_gacha(delta)
	_collect_and_adopt()
	_update_warmth(delta)
	_update_kit_search(delta)
	_update_torch(delta)
	_update_torch_light()
	_update_preview()
	if not night_warned and is_night():
		night_warned = true
		_notify("밤이 옵니다 — 숙소로 돌아가 Z로 취침하세요", Defs.COL_DANGER)
		audio.call("play", "alarm")
	# Running out of night entirely means the cats come and get you.
	if mission == Mission.DONE and time_left <= 0.0:
		_carried_home()
	_advance_mission()

## Crates are picked up simply by walking over them, and carrying three to the
## shelter adopts a cat. No extra verb to learn.
## Picked up simply by walking over it. Announced with the running stock so the
## player learns that loose items and the base ledger are the same thing.
func _collect_ground() -> void:
	var item_type: int = sim.collect_ground_at(player.cell())
	if item_type < 0:
		return
	var held: int = int(sim.stock.get(item_type, 0))
	fx.popup(player.position + Vector2(0, -22),
		"%s %d" % [Defs.ITEM_NAMES[item_type], held], Defs.ITEM_COLORS[item_type], true)
	fx.ring(player.position, Defs.ITEM_COLORS[item_type], Defs.RING_SMALL)
	audio.call("play", "deliver")
	_announce_unlocks(sim.note_resource_seen(item_type))

## A new machine appearing in the hotbar is a real milestone, so it gets the
## banner and the confirm sting rather than a silent slot.
func _announce_unlocks(opened: Array[int]) -> void:
	for type: int in opened:
		_notify("%s 해금!" % Defs.MACHINE_NAMES[type], Defs.COL_CORE)
		fx.ring(player.position, Defs.COL_CORE, Defs.RING_MILESTONE)
		fx.burst(player.position, Defs.COL_CORE, 14)
		audio.call("play", "finish")
		shake = maxf(shake, Defs.FX_MILESTONE)

## Working a seam by hand. Held rather than tapped, so the player feels the ten
## seconds they are about to automate away.
## A bite from whoever is at the bowl. One sound however many cats are eating --
## the voice pool would happily play four at once and the result is not four cats
## eating, it is a noise.
func _update_nibbles(delta: float) -> void:
	var eating := false
	for cat: Sim.Cat in sim.cats:
		if cat.state == Defs.CAT_EATING:
			eating = true
			break
	if not eating:
		nibble_timer = 0.0
		return
	nibble_timer -= delta
	if nibble_timer > 0.0:
		return
	nibble_timer = NIBBLE_INTERVAL * randf_range(0.85, 1.25)
	audio.call("play", "nibble", 0.18)

## Which seam a swing lands on: the one being faced, or the one underfoot.
##
## Ore used to be solid, so walking into a seam stopped you against it and left
## you facing it -- "face a seam and hold Z" described what happened by itself.
## It is terrain now and you walk onto it instead, which put the first thing the
## game asks for out of reach: press W at the starting seam and you are standing
## on it, facing the empty tile beyond. Thirteen seconds of holding Z did
## nothing, and the objective card sat there repeating the instruction.
##
## Facing still wins, so a player standing on one seam can deliberately mine the
## next one over.
func _hand_target() -> Vector2i:
	var facing: Vector2i = player.facing_cell()
	if sim.ore.has(facing):
		return facing
	return player.cell()

## A boot landing, on the frames where the drawing puts one down.
##
## Fired on the frame changing rather than on a timer: the cadence has to be the
## legs', and a timer drifts against them the moment the run plays at fourteen
## frames a second instead of ten. Indoors and out of play are silent -- she is
## not on the snow then.
func _update_footsteps() -> void:
	var frame: int = player.step_frame
	if state != State.PLAY or indoors() or frame < 0:
		last_step_frame = -1
		return
	if frame == last_step_frame:
		return
	last_step_frame = frame
	if frame in PlayerActor.STEP_FRAMES:
		audio.call("play", "step_run" if player.step_running else "step")

func _update_hand_mining(delta: float) -> void:
	if state != State.PLAY or player.locked or sim.hands_full():
		sim.cancel_hand_mine()
		player.mining = 0.0
		last_mine_frame = -1
		return
	var facing: Vector2i = _hand_target()
	if not holding_pickaxe() or not mine_held or not sim.ore.has(facing):
		sim.cancel_hand_mine()
		player.mining = 0.0
		last_mine_frame = -1
		return
	mine_swung = true
	# Steel on stone, once per swing, on the frame the head reaches the ground.
	var frame: int = int(player.mine_frame)
	if frame == PlayerActor.MINE_IMPACT_FRAME and last_mine_frame != frame:
		audio.call("play", "pick")
		fx.burst(sim.cell_centre(facing), Defs.ITEM_COLORS[int(sim.ore[facing])], 3)
	last_mine_frame = frame
	var produced: int = sim.hand_mine(facing, delta)
	player.mining = sim.hand_fraction()
	if produced < 0:
		return
	# Drops at the player's feet rather than into an invisible pocket, so the
	# thing they made is a thing in the world that a cat can come and fetch.
	var at: Vector2i = player.cell()
	if not sim.drop_item(at, produced):
		at = facing + (facing - player.cell())
		if not sim.drop_item(at, produced):
			sim.stock[produced] = int(sim.stock.get(produced, 0)) + 1
	fx.popup(sim.cell_centre(facing) + Vector2(0, -18),
		"+1 %s" % Defs.ITEM_NAMES[produced], Defs.ITEM_COLORS[produced], true)
	fx.burst(sim.cell_centre(facing), Defs.ITEM_COLORS[produced], 9)
	fx.ring(sim.cell_centre(facing), Defs.ITEM_COLORS[produced], Defs.RING_SMALL)
	audio.call("play", "build")
	shake = maxf(shake, Defs.FX_SMALL)
	_announce_unlocks(sim.note_resource_seen(produced))

func _collect_and_adopt() -> void:
	_collect_ground()
	_collect_shard()

## Crystal, off the snow. Announced with the running total because there is a
## fixed number of these in the world and no way to make more: the number in her
## pack is the only thing that says how much of the energy line is left.
func _collect_shard() -> void:
	if not sim.collect_shard_at(player.cell()):
		return
	var held: int = int(sim.stock.get(Defs.ITEM_CRYSTAL, 0))
	fx.popup(player.position + Vector2(0, -22),
		"%s %d" % [Defs.ITEM_NAMES[Defs.ITEM_CRYSTAL], held],
		Defs.ITEM_COLORS[Defs.ITEM_CRYSTAL], true)
	fx.ring(player.position, Defs.ITEM_COLORS[Defs.ITEM_CRYSTAL], Defs.RING_MEDIUM)
	fx.burst(player.position, Defs.ITEM_COLORS[Defs.ITEM_CRYSTAL], 9)
	audio.call("play", "alloy")
	_announce_unlocks(sim.note_resource_seen(Defs.ITEM_CRYSTAL))

## Whether any ice near the core is on its way out. Read by the objective card,
## which is why it asks the simulation rather than remembering a flag: a cat put
## down and picked up again has to stop counting.
func _thawing_nearby() -> bool:
	for cell: Vector2i in sim.frozen_cats:
		if sim.can_thaw(cell):
			return true
	return false

## The moment the ice finishes. The rest of the game announces things with a
## line of text; this one gets the ring, the shake and a voice, because it is the
## first cat and the design calls it the most expensive three seconds in the
## game. The camera move and the music change that belong with it are still to
## come -- this is the mechanism, not yet the whole scene.
## The base going up a step. This is the only thing that grows the circle now,
## so it is the moment the world gets bigger -- and it has to look like one.
func _on_base_upgraded(level: int, radius: float) -> void:
	var at: Vector2 = sim.cell_centre(sim.core_cell)
	fx.ring(at, Defs.COL_CORE, radius * float(Defs.TILE))
	fx.burst(at, Defs.COL_CORE, 18)
	fx.popup(at + Vector2(0, -40.0), "기지 %d단계" % level, Defs.COL_CORE, true)
	shake = maxf(shake, Defs.FX_SMALL)
	audio.call("play", "finish")
	_notify("기지가 커졌습니다  온기 %.0f칸" % radius, Defs.COL_CORE)

func _on_cat_thawed(total: int, at: Vector2) -> void:
	fx.popup(at + Vector2(0, -30), "먀?", Defs.COL_CAT_FACE, true)
	fx.ring(at, Defs.COL_CORE, Defs.RING_LARGE)
	fx.burst(at, Defs.COL_CAT_FACE, 14)
	shake = maxf(shake, Defs.FX_SMALL)
	audio.call("play", "meow")
	if total == 1:
		_notify("고양이가 깨어났습니다  Z 로 안아 채굴기에 올려놓으세요", Defs.COL_CORE)
	else:
		_notify("고양이가 깨어났습니다  (%d마리)" % total, Defs.COL_CORE)

## Which mission the run is on, recomputed from the world rather than advanced
## by whoever happened to do the thing. A flag set at the moment of an action is
## a flag that can be set twice, or missed when the action happens some other
## way -- and every one of these has more than one way to happen.
## Z held on the survival kit. A hold rather than a press because opening it is
## the first thing she does on this planet and it should take a moment -- and
## because the same key, held, is how everything else in this game is worked at.
func _update_kit_search(delta: float) -> void:
	if not _facing_kit() or not mine_held or player.locked:
		sim.kit_progress = 0.0
		return
	sim.kit_progress += delta / Defs.KIT_SEARCH_SECONDS
	if sim.kit_progress < 1.0:
		return
	sim.kit_progress = 0.0
	var found: int = sim.search_kit()
	if found == Defs.KIT_NONE:
		return
	fx.ring(sim.cell_centre(sim.kit_cell), Defs.COL_CORE, Defs.RING_MEDIUM)
	audio.call("play", "alloy")
	if found == Defs.KIT_BASE:
		_notify("긴급기지를 꺼냈습니다  Z 로 내려놓으세요", Defs.COL_CORE)
	else:
		# The pickaxe comes out with the shelter. It is a tool rather than a
		# thing to carry, so it goes straight into the row she already has.
		_notify("곡괭이와 긴급거처를 꺼냈습니다  Z 로 거처를 세우세요", Defs.COL_CORE)

## Whether she is at the kit with something still in it.
##
## Distance rather than facing. Everything else in this game is aimed -- you
## face a seam, a machine, a cat -- and that is right for a world full of tiles
## that look alike. The kit is the first thing the player ever touches, there is
## exactly one of it, and there is nothing else within three tiles it could be
## confused with. Requiring the correct facing there buys nothing and costs a
## player standing next to a glowing case pressing a key that does nothing.
##
## Found exactly that way: the browser run walked to the kit, held Z, and the
## game did nothing, because the last arrow pressed had been Down.
const KIT_REACH := 1.4
func _facing_kit() -> bool:
	if sim.kit_searched >= 2 or sim.hands_full():
		return false
	return player.position.distance_to(sim.cell_centre(sim.kit_cell)) \
		<= float(Defs.TILE) * KIT_REACH

## The torch burns only while it is in her hand. Putting it away stops the clock
## on it, which is what makes thirty seconds a distance rather than a countdown
## that starts when you make it.
func _update_torch(delta: float) -> void:
	if not holding_torch():
		return
	var before: float = sim.torch_left
	sim.burn_torch(delta)
	if before > 0.0 and sim.torch_left <= 0.0:
		_notify("%s이 꺼졌습니다" % Defs.TORCH_NAME, Defs.COL_TEXT_DIM)
		audio.call("play", "deny")
		fx.ring(player.position, Defs.COL_TEXT_DIM, Defs.RING_MEDIUM)

## Where the torch's hole in the fog is, in viewport pixels. Computed here
## because this is the one place that has both the character and the camera; the
## fog knows about neither.
func _update_torch_light() -> void:
	if cold_fog == null:
		return
	# Two layers, one number. The fog opens a hole and the ground lights what is
	# under it; either without the other is a black disc or a lit patch nobody
	# can see through.
	var radius: float = Defs.TORCH_SIGHT * float(Defs.TILE) if holding_torch() else 0.0
	cold_fog.torch_at = player.global_position
	cold_fog.torch_radius = radius
	ground_layer.torch_at = player.global_position
	ground_layer.torch_radius = radius

## --- The key over her head --------------------------------------------------
## Which prompt is showing, or "". The first one in the table that is wanted and
## not yet learned; only ever one, because two of them is a menu.
func active_prompt() -> String:
	if state != State.PLAY or modal_open() or player.locked:
		return ""
	for row: Dictionary in Defs.KEY_PROMPTS:
		var id: String = String(row["id"])
		var status: Dictionary = _prompt_status(id)
		if bool(status["done"]) or not bool(status["want"]):
			continue
		return id
	return ""

## Whether a prompt applies and whether it is finished with, in one branch each.
##
## Both together on purpose. Written as two functions they are two lists keyed by
## the same ids, and this repository has watched that arrangement go out of step
## every time it has been tried.
##
## `done` is read off the world wherever the world remembers -- the kit has been
## opened, a cat exists, a machine is standing. Only walking, switching tools,
## lighting a torch and running leave no trace, and those four are the only ones
## that ask `has_learned`.
func _prompt_status(id: String) -> Dictionary:
	var cats_working := false
	for cat: Sim.Cat in sim.cats:
		if cat.has_job():
			cats_working = true
			break
	match id:
		"KIT":
			return {"want": _facing_kit(), "done": sim.kit_searched >= 2}
		"PLACE":
			return {"want": sim.carried_kit != Defs.KIT_NONE, "done": sim.shelter_placed}
		"THAW":
			return {"want": sim.carried_frozen, "done": not sim.cats.is_empty()}
		"FROZEN":
			return {"want": not sim.hands_full() and _frozen_within_reach(),
				"done": not sim.cats.is_empty()}
		"CATPLACE":
			return {"want": sim.carried_cat != null, "done": cats_working}
		"CATLIFT":
			return {"want": not sim.hands_full() and not cats_working
				and _idle_cat_within_reach(), "done": cats_working}
		"FUEL":
			return {"want": sim.base_placed and sim.has_fuel()
				and player.facing_cell() == sim.core_cell,
				"done": int(sim.delivered.get(Defs.ITEM_HEATSTONE, 0)) > 0}
		"MINE":
			return {"want": holding_pickaxe() and sim.ore.has(_hand_target()),
				"done": int(sim.stock.get(Defs.ITEM_HEATSTONE, 0)) > 0
					or int(sim.delivered.get(Defs.ITEM_HEATSTONE, 0)) > 0}
		"TORCH":
			return {"want": sim.torches > 0 and not holding_torch(),
				"done": sim.has_learned("TORCH")}
		"TOOL":
			return {"want": sim.kit_searched >= 2, "done": sim.has_learned("TOOL")}
		"BUILD":
			return {"want": sim.base_placed and _anything_buildable(),
				"done": sim.machine_count(Defs.M_MINER) > 0 or build_menu_open}
		"RUN":
			return {"want": sim.walked >= Defs.PROMPT_WALK_RUN, "done": sim.has_learned("RUN")}
		"MOVE":
			return {"want": true, "done": sim.walked >= Defs.PROMPT_WALK_LEARNED}
	return {"want": false, "done": true}

func _frozen_within_reach() -> bool:
	for cell: Vector2i in sim.frozen_cats:
		if player.position.distance_to(sim.cell_centre(cell)) <= float(Defs.TILE) * 1.5:
			return true
	return false

func _idle_cat_within_reach() -> bool:
	for cat: Sim.Cat in sim.cats:
		if not cat.has_job() \
				and player.position.distance_to(cat.pos) <= float(Defs.TILE) * 1.5:
			return true
	return false

func _anything_buildable() -> bool:
	for type: int in Defs.BUILDABLE:
		if sim.is_unlocked(type):
			return true
	return false

func _advance_mission() -> void:
	var was: int = mission
	match mission:
		Mission.BASE:
			if sim.base_placed:
				mission = Mission.SURVIVE
		Mission.SURVIVE:
			if sim.shelter_placed:
				mission = Mission.MEANS
		Mission.MEANS:
			# Three stones in the core. The number the opening asks for, and the
			# first time the player sees the circle grow because of something
			# they carried.
			if int(sim.delivered.get(Defs.ITEM_HEATSTONE, 0)) >= Defs.OPENING_STONES:
				mission = Mission.EXPLORE
		Mission.EXPLORE:
			if not sim.cats.is_empty():
				mission = Mission.DONE
	if mission == was:
		return
	if mission == Mission.EXPLORE:
		_notify("불이 커졌습니다  온기 %.0f칸  ·  주변을 둘러보세요" % sim.warm_radius,
			Defs.COL_CORE)
		audio.call("play", "finish")
	elif mission == Mission.DONE:
		_notify("살아남았습니다  이제 하루가 흐릅니다", Defs.COL_CORE)
		audio.call("play", "finish")
	else:
		audio.call("play", "confirm")

## Everything the opening builds, at once. The game after the tutorial is the
## game this repository already had, so anything that wants that world -- a save
## from before the opening existed, a test, a debug key -- asks for it here
## rather than reproducing the four missions by hand.
func finish_tutorial() -> void:
	if not sim.base_placed:
		sim.carried_kit = Defs.KIT_BASE
		sim.place_base(sim.core_cell)
	if not sim.shelter_placed:
		sim.carried_kit = Defs.KIT_SHELTER
		sim.shelter_placed = true
		sim.shelter_cell = sim.core_cell + Defs.SHELTER_CELL
		sim.food_cell = sim.core_cell + Vector2i(Defs.FOOD_OFFSET.round())
		sim.carried_kit = Defs.KIT_NONE
	sim.kit_searched = 2
	mission = Mission.DONE
	player.warmth = 100.0

func _update_warmth(delta: float) -> void:
	_update_collapse(delta)
	# Before the fire exists there is nowhere to be warm and nowhere to be
	# carried to, so the ordinary rules -- which are all about a base -- do not
	# apply. She loses a degree every two seconds wherever she stands, which is
	# eighty seconds of looking around, and hitting zero means coming to again
	# in the snow rather than waking up at a base that has not been built.
	if not sim.base_placed:
		player.warmth = maxf(0.0, player.warmth - Defs.CRASH_DRAIN * delta)
		if player.warmth <= 0.0:
			_come_to()
		return
	var warm: bool = sim.is_warm(player.cell())
	if warm and not is_night():
		player.warmth = minf(100.0, player.warmth + Defs.COLD_RECOVER * delta)
	elif warm:
		# The core still helps at night, but it no longer keeps you alive: this is
		# what makes going indoors a decision rather than an option.
		var shelter_help: float = 0.35 if shelter_nearby() else 1.0
		player.warmth = maxf(0.0, player.warmth - Defs.NIGHT_DRAIN * shelter_help * delta)
		if player.warmth <= 0.0:
			_carried_home()
	else:
		var night_extra: float = Defs.NIGHT_DRAIN if is_night() else 0.0
		player.warmth = maxf(0.0, player.warmth - (Defs.COLD_DRAIN + night_extra) * delta)
		if player.warmth <= 0.0:
			if is_night():
				_carried_home()
			else:
				_begin_rescue()

## Warmth hitting zero does not end anything immediately. The player stays on
## their feet for a few seconds -- long enough to run for the shelter -- and only
## then collapses and is carried home.
func _begin_rescue() -> void:
	# Guarding on the timer alone was not enough. Once the fall starts the timer
	# is already negative, and _update_warmth re-checks warmth every frame right
	# after running the collapse -- so it re-armed the full grace period the
	# instant the player went down. The result was one frame of falling every
	# five seconds and a day that never ended.
	if collapse_timer >= 0.0 or player.collapse > 0.0 or blackout > 0.0:
		return
	collapse_timer = Defs.COLLAPSE_GRACE
	shake = 3.0
	# The warm radius, not the shelter. This is the daytime path -- _update_warmth
	# only calls it when it is not night -- and what cancels the collapse is
	# warmth above zero, which the radius restores at 26 a second from anywhere
	# inside it. The shelter is one building at one end of that circle, and in
	# daylight running for it is usually the longer way to the same rescue. The
	# objective card was already saying "온기 반경 안으로 돌아가세요" at the same
	# moment, so the two most urgent lines on screen named different places.
	_notify("의식이 흐려집니다  %.0f초 안에 온기 반경 안으로" % Defs.COLLAPSE_GRACE,
		Defs.COL_DANGER)
	fx.ring(player.position, Defs.COL_DANGER, 44.0)
	audio.call("play", "alarm")

func _update_collapse(delta: float) -> void:
	# Once the fall has begun the grace timer is already negative, so the guard
	# has to consider both: checking the timer alone froze the player mid-fall.
	var falling: bool = player.collapse > 0.0
	if collapse_timer < 0.0 and not falling:
		return
	if player.warmth > 0.0 and not falling:
		# Made it somewhere warm in time.
		collapse_timer = -1.0
		_notify("체온을 되찾았습니다", Defs.COL_CORE)
		return
	collapse_timer -= delta
	if collapse_timer > 0.0:
		return
	# Grace is over: fall, then wake up in the morning.
	player.locked = true
	player.velocity = Vector2.ZERO
	player.collapse = clampf(player.collapse + delta / Defs.COLLAPSE_FALL, 0.0, 1.0)
	if player.collapse < 1.0:
		return
	# Down, and the world darkens before the morning arrives.
	blackout = clampf(blackout + delta / Defs.BLACKOUT_SECONDS, 0.0, 1.0)
	if blackout < 1.0:
		return
	collapse_timer = -1.0
	player.collapse = 0.0
	rescued_tonight = true
	var lost: int = sim.spend_rescue()
	_notify("쓰러졌습니다 · 열 %d 손실" % lost, Defs.COL_DANGER)
	_finish_run()



func _update_preview() -> void:
	# The placement ghost belongs to the build gun. Holding the pickaxe and still
	# being shown where a miner would go says Z will place one, and it will not.
	if not holding_build_gun():
		machine_layer.preview_cell = Vector2i(9999, 9999)
		return
	var cell: Vector2i = player.facing_cell()
	machine_layer.preview_cell = cell
	machine_layer.preview_type = selected_type()
	machine_layer.preview_dir = build_dir
	var reason: String = sim.can_build(selected_type(), cell)
	machine_layer.preview_valid = reason == ""
	machine_layer.preview_affordable = sim.can_afford(selected_type()) and sim.is_unlocked(selected_type())
	machine_layer.preview_occupied = sim.machine_at(cell) != null

func _view_rect() -> Rect2:
	var size: Vector2 = get_viewport_rect().size / maxf(camera.zoom.x, 0.01)
	return Rect2(camera.get_screen_center_position() - size * 0.5, size)

func _unhandled_input(event: InputEvent) -> void:
	# Mining is a hold, so both edges matter and neither should be swallowed by
	# the state machine below. It hangs off the build key, because mining is now
	# what the build key does while the pickaxe is the held tool -- C only opens
	# the meter.
	if event.is_action_pressed("build"):
		mine_held = true
	elif event.is_action_released("build"):
		mine_held = false
	if event.is_action_pressed("mine"):
		toggle_meter()
	# Mouse first: the settings gear and its slider are the only pointer targets
	# in the game, and a desktop player has no pad to route them through.
	if event is InputEventMouseButton:
		var button := event as InputEventMouseButton
		if button.button_index == MOUSE_BUTTON_LEFT:
			if button.pressed:
				if touch_hud(button.position):
					get_viewport().set_input_as_handled()
					return
			else:
				touch_hud_release()
		if state == State.SETTINGS:
			get_viewport().set_input_as_handled()
			return
	if event is InputEventMouseMotion and (hud.dragging_slider >= 0
			or bool(hud.dragging_map_zoom)):
		touch_hud_drag((event as InputEventMouseMotion).position)
		get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and not event.is_pressed() and event.is_action_released("build"):
		# The pickaxe still puts a carried cat down -- being unable to let go of
		# a cat because of which tool is selected would be a trap -- but it does
		# not build.
		if build_held and not build_rotated and not mine_swung:
			_primary_action()
		build_held = false
		get_viewport().set_input_as_handled()
		return
	if not (event is InputEventKey) or not event.is_pressed() or event.is_echo():
		return
	var key := event as InputEventKey
	# The panel is modal: while it is open the only keys that mean anything are
	# the ones that close it and the ones that nudge the slider.
	if state == State.SETTINGS and int(hud.slot_picker) > 0:
		# The slot list owns the panel while it is up.
		match key.keycode:
			KEY_ESCAPE:
				close_slot_picker()
			KEY_UP, KEY_W:
				hud.slot_index = posmod(int(hud.slot_index) - 1, SAVE_SLOTS)
				audio.call("play", "select")
			KEY_DOWN, KEY_S:
				hud.slot_index = posmod(int(hud.slot_index) + 1, SAVE_SLOTS)
				audio.call("play", "select")
			KEY_Z, KEY_ENTER, KEY_KP_ENTER:
				confirm_slot(int(hud.slot_index))
		get_viewport().set_input_as_handled()
		return
	if state == State.SETTINGS:
		var rows: int = hud.slider_track_rects.size()
		if key.keycode == KEY_ESCAPE or key.keycode == KEY_ENTER or key.keycode == KEY_KP_ENTER:
			close_settings()
		elif key.keycode == KEY_UP or key.keycode == KEY_DOWN:
			var step: int = -1 if key.keycode == KEY_UP else 1
			hud.settings_row = posmod(int(hud.settings_row) + step, rows)
			audio.call("play", "select")
		elif key.keycode == KEY_LEFT or key.keycode == KEY_MINUS:
			_nudge_slider(int(hud.settings_row), -Defs.UI_SCALE_STEP)
		elif key.keycode == KEY_RIGHT or key.keycode == KEY_EQUAL:
			_nudge_slider(int(hud.settings_row), Defs.UI_SCALE_STEP)
		elif key.keycode == KEY_N:
			settings_restart()
		elif key.keycode == KEY_S:
			settings_save()
		elif key.keycode == KEY_L:
			settings_load()
		get_viewport().set_input_as_handled()
		return
	# The build menu owns the keyboard while it is up. Placed before the state
	# match so a keypress cannot both move the cursor and build something.
	if base_menu_open and state == State.PLAY:
		_base_menu_key(key)
		get_viewport().set_input_as_handled()
		return
	if build_menu_open and state == State.PLAY:
		_build_menu_key(key)
		get_viewport().set_input_as_handled()
		return
	# And so does the slot machine, for the same reason: Z pulls in there, and a
	# Z that both pulled and placed a belt would be a key doing two jobs.
	if gacha_open and state == State.PLAY:
		_gacha_key(key)
		get_viewport().set_input_as_handled()
		return
	# And the map, where left and right are the zoom rather than two steps west.
	if map_open and state == State.PLAY:
		_map_key(key)
		get_viewport().set_input_as_handled()
		return

	match state:
		State.TITLE:
			if key.keycode == KEY_ESCAPE:
				return
			_leave_title()
			get_viewport().set_input_as_handled()
			return
		State.OPENING:
			# Any key moves on; Escape leaves the whole thing. Two verbs rather
			# than one because "I have seen this" and "I want the next picture"
			# are different requests and the second one is the common one.
			if key.keycode == KEY_ESCAPE:
				_end_cutscene()
			else:
				_advance_cutscene()
			get_viewport().set_input_as_handled()
			return
		State.RESULT:
			if key.keycode == KEY_ENTER or key.keycode == KEY_KP_ENTER or key.keycode == KEY_SPACE:
				_begin_next_day()
				get_viewport().set_input_as_handled()
			# N is gone with its label. Removing the line and leaving the key
			# would be worse than either: a run thrown away by a stray press on
			# the screen nobody reads, with nothing on screen to explain it.
			# Starting over lives in settings, where it asks twice.
			return
		State.NIGHTFALL, State.DAYBREAK:
			# The sequence plays itself and is over in seconds. Only the debug
			# speed stays live, so a tester who has watched it forty times can
			# wind it forward instead of sitting through it.
			if event.is_action_pressed("debug_speed"):
				cycle_debug_speed()
			get_viewport().set_input_as_handled()
			return

	if key.keycode == KEY_ESCAPE:
		# Settings, not a separate pause screen. Opening settings already stops
		# the world, so a second stopped screen was one more thing to build,
		# explain and keep consistent for no behaviour anyone was missing.
		open_settings()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("debug_unlock"):
		debug_unlock_all()
		get_viewport().set_input_as_handled()
		return
	if key.keycode == KEY_F5:
		debug_crowd()
		get_viewport().set_input_as_handled()
		return
	if key.keycode == KEY_F6:
		debug_belt_loop()
		get_viewport().set_input_as_handled()
		return
	if key.keycode == KEY_F7:
		debug_rescue()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("debug_scenario"):
		debug_scenario()
		get_viewport().set_input_as_handled()
		return
	if _zoom_key(key):
		get_viewport().set_input_as_handled()
		return
	if key.keycode == KEY_B:
		toggle_build_menu()
		get_viewport().set_input_as_handled()
		return
	if key.keycode == KEY_G:
		toggle_gacha()
		get_viewport().set_input_as_handled()
		return
	if key.keycode == KEY_M:
		toggle_map()
		get_viewport().set_input_as_handled()
		return
	if key.keycode >= KEY_1 and key.keycode < KEY_1 + TOOLS.size():
		tool_index = key.keycode - KEY_1
		sim.learn("TOOL")
		_on_tool_selected()
		audio.call("play", "select")
		get_viewport().set_input_as_handled()
		return
	# Test the event itself rather than the Input singleton. is_action_just_pressed
	# is frame-scoped, so inside an event handler it can silently drop a press
	# when two arrive in one frame -- which reads to the player as a dead key.
	if event.is_action_pressed("rotate"):
		build_dir = Vector2i(-build_dir.y, build_dir.x)
		audio.call("play", "select")
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("build"):
		# Held, Z rotates; tapped, it builds. Handled on release so the hold can
		# be measured, which is why nothing happens here.
		build_held = true
		build_hold_time = 0.0
		build_rotated = false
		mine_swung = false
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("debug_speed"):
		cycle_debug_speed()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("recipe"):
		_cycle_recipe()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("demolish"):
		_try_demolish()
		get_viewport().set_input_as_handled()

## True on any screen where the only sensible action is "continue", so a tap
## anywhere is accepted instead of demanding a precise button press.
func touch_anywhere_starts() -> bool:
	return state == State.TITLE or state == State.RESULT

## Touch handling for the on-screen HUD: picking a machine and rotating it are
## keyboard-only otherwise, which left the game unplayable on a phone.
func touch_hud(position: Vector2) -> bool:
	# The HUD draws itself scaled, so its published rects are in its own space.
	# Hit-testing raw viewport coordinates against them silently misses by the
	# scale factor, which is exactly the bug that made the pad feel dead.
	var local: Vector2 = hud_local(position)
	if state == State.SETTINGS and int(hud.slot_picker) > 0:
		var slot: int = int(hud.call("slot_row_at", local))
		if slot >= 0:
			hud.slot_index = slot
			confirm_slot(slot)
		else:
			close_slot_picker()
		return true
	if state == State.SETTINGS:
		# While the panel is up it owns every touch, so a stray tap cannot fall
		# through onto the world behind it.
		if (hud.settings_close_rect as Rect2).has_point(local):
			close_settings()
			return true
		if (hud.settings_load_rect as Rect2).has_point(local):
			settings_load()
			return true
		if (hud.settings_restart_rect as Rect2).has_point(local):
			settings_restart()
			return true
		if (hud.settings_save_rect as Rect2).has_point(local):
			settings_save()
			return true
		var row: int = int(hud.call("slider_at", local))
		if row >= 0:
			hud.call("begin_slider_drag", row)
			_apply_slider(row, local.x)
		return true
	if (hud.settings_button_rect as Rect2).has_point(local):
		open_settings()
		return true
	if state != State.PLAY:
		return false
	if map_open:
		# The card owns the screen while it is up. Dragging the track sets the
		# zoom; a tap anywhere off the card closes it, which is how every other
		# window here behaves.
		if bool(hud.call("map_slider_at", local)):
			hud.call("begin_map_drag")
			_apply_map_zoom(local.x)
			return true
		if not (hud.map_card_rect as Rect2).has_point(local):
			map_open = false
			audio.call("play", "select")
		return true
	if (hud.map_button_rect as Rect2).has_point(local):
		toggle_map()
		return true
	if build_menu_open:
		# The menu owns the screen while it is up: a tap picks a row or closes it,
		# and nothing falls through to the world behind.
		var row: int = int(hud.call("build_menu_row_at", local))
		if row >= 0:
			_load_build_gun(row)
		else:
			build_menu_open = false
			audio.call("play", "select")
		return true
	if gacha_open:
		# Same contract as the build list: the window owns every tap while it is
		# up, so a miss closes it rather than building something underneath.
		var pull: int = int(hud.call("gacha_button_at", local))
		if pull >= 0:
			start_gacha(pull)
		elif not (hud.gacha_card_rect as Rect2).has_point(local):
			close_gacha()
		return true
	if (hud.gacha_button_rect as Rect2).has_point(local):
		toggle_gacha()
		return true
	for index in hud.hotbar_rects.size():
		if (hud.hotbar_rects[index] as Rect2).has_point(local):
			# The row holds tools, so a tap picks a tool. It used to hold machines
			# and this line still set selected_index -- which is the machine the
			# build gun is loaded with, indexed into a different and longer list.
			# The keyboard was moved to tool_index when the pickaxe arrived and
			# this was not, so on a phone the pickaxe could not be picked up at
			# all: the first thing the game asks for is crystal, hand mining
			# checks holding_pickaxe() before anything else, and there was no way
			# to hold it. Tapping also silently re-loaded the gun.
			#
			# Tapping the tool you already hold opens what that tool chooses from,
			# which for the gun is the build list -- otherwise a phone has no way
			# to reach it, there being no B key to press.
			if tool_index == index and index == TOOL_BUILD_GUN:
				toggle_build_menu()
				return true
			tool_index = index
			audio.call("play", "select")
			return true
	if (hud.direction_rect as Rect2).has_point(local):
		build_dir = Vector2i(-build_dir.y, build_dir.x)
		audio.call("play", "select")
		return true
	return false

## Viewport coordinates into HUD-local ones.
func hud_local(position: Vector2) -> Vector2:
	return position / maxf(hud.scale.x, 0.01)

func _nudge_slider(row: int, delta: float) -> void:
	if row == 0:
		set_ui_scale(ui_scale + delta)
	else:
		set_game_scale(game_scale + delta)

## One row's worth of slider, so touch, drag and the keyboard share a path.
func _apply_slider(row: int, local_x: float) -> void:
	var value: float = float(hud.call("slider_value_at", row, local_x))
	if row == 0:
		set_ui_scale(value)
	else:
		set_game_scale(value)

## Dragging the slider keeps updating the value; the pad forwards drags here.
func touch_hud_drag(position: Vector2) -> bool:
	if bool(hud.dragging_map_zoom):
		_apply_map_zoom(hud_local(position).x)
		return true
	if state != State.SETTINGS or hud.dragging_slider < 0:
		return false
	_apply_slider(hud.dragging_slider, hud_local(position).x)
	return true

func touch_hud_release() -> void:
	hud.call("end_slider_drag")
	hud.call("end_map_drag")

## Where along the track the pointer is, as a zoom.
func _apply_map_zoom(x: float) -> void:
	var track: Rect2 = hud.map_slider_rect
	if track.size.x <= 0.0:
		return
	var fraction: float = clampf((x - track.position.x) / track.size.x, 0.0, 1.0)
	set_map_zoom(Defs.MAP_ZOOM_MIN + fraction * (Defs.MAP_ZOOM_MAX - Defs.MAP_ZOOM_MIN))

## Entry points for the mobile buttons, so touch and keyboard run through the
## same code rather than drifting apart.
## Z, on a pad, meaning exactly what Z means on a keyboard.
##
## It used to mean less: the pad sent only the press, so mining -- which is a
## hold on the build key -- was impossible with it, and a separate 캐기 button
## did the holding *and* opened the throughput panel. Two buttons each doing half
## of two different jobs, and neither matching the keys the game teaches.
##
## Both edges now, and the hold is set before the action runs, which is the order
## _unhandled_input uses for the keyboard.
func touch_primary(pressed: bool = true) -> void:
	mine_held = pressed and state == State.PLAY
	if not pressed:
		return
	match state:
		State.TITLE:
			_leave_title()
		State.OPENING:
			_advance_cutscene()
		State.RESULT:
			_begin_next_day()
		State.SETTINGS:
			close_settings()
		State.PLAY:
			# Route through the same entry point the keyboard uses. Calling
			# _try_build directly meant touch players could never pick up or
			# place a cat, which makes the game unplayable on a phone.
			_primary_action()

## The pad's C. It opens the throughput panel and nothing else, the way C does on
## a keyboard -- it used to start a dig as well, which is why the pad had a verb
## the keyboard did not.
func touch_meter() -> void:
	toggle_meter()

## The mine key does double duty: on a seam it digs, and on a machine it opens
## that machine's throughput panel. The two never overlap in practice -- a cell
## with a miner on it is one the player has already stopped digging by hand --
## and giving the readout its own key would have meant a sixth binding to teach.
##
## Returns true when the press was spent on the panel, so the caller knows not to
## start a dig with it.
func toggle_meter() -> bool:
	if meter_cell != Vector2i(9999, 9999):
		meter_cell = Vector2i(9999, 9999)
		audio.call("play", "select")
		return true
	if state != State.PLAY or player.locked:
		return false
	var cell: Vector2i = player.facing_cell()
	if sim.machine_at(cell) == null:
		return false
	meter_cell = cell
	audio.call("play", "select")
	return true

func touch_secondary() -> void:
	match state:
		State.PLAY:
			_try_demolish()
		State.SETTINGS:
			close_settings()

## One key, in priority order. Carrying a cat takes precedence over building so
## a full-handed player can always put the cat down.
func _primary_action() -> void:
	if sleep_available():
		_sleep()
		return
	var cell: Vector2i = player.facing_cell()
	# The kit answers Z by being held rather than pressed, so a press at it is
	# not a build, a pick-up or anything else.
	if _facing_kit():
		return
	if sim.carried_kit != Defs.KIT_NONE:
		_place_kit(cell)
		return
	# Facing the fire. Nothing can be built on the core, so Z here used to do
	# nothing at all -- which is where the heat that had been mined by hand sat
	# for good, because the only doorway into the core was a belt or a cat.
	if cell == sim.core_cell and sim.base_placed:
		_open_base_menu()
		return
	# A frozen cat answers Z before anything else. She has both arms round it,
	# so there is nothing else the press could mean.
	if sim.carried_frozen:
		if not sim.put_down_frozen(cell):
			audio.call("play", "deny")
		elif sim.can_thaw(cell):
			_notify("얼음이 녹기 시작합니다", Defs.COL_CORE)
			fx.ring(sim.cell_centre(cell), Defs.COL_CORE, 26.0)
			audio.call("play", "confirm")
		else:
			# Allowed, and said out loud. Setting it down out here is a real move
			# -- she can leave it and come back with a shorter walk -- but a
			# player who thinks they have finished the errand would stand and
			# watch nothing happen.
			_notify("기지에서 멉니다  기지 %d칸 안에 놓아야 녹기 시작합니다"
				% int(Defs.THAW_RADIUS), Defs.COL_TEXT_DIM)
			audio.call("play", "remove")
		return
	if sim.carried_cat != null:
		if sim.place_cat(cell):
			_notify("고양이를 채굴기에 배치했습니다" if sim.machines.has(cell)
				else "고양이가 광맥을 캡니다  채굴기 위라면 더 빠릅니다", Defs.COL_CORE)
			fx.ring(sim.cell_centre(cell), Defs.COL_CORE, 26.0)
			audio.call("play", "build")
		elif sim.drop_cat(sim.cell_centre(cell)):
			_notify("고양이를 내려놓았습니다", Defs.COL_TEXT_DIM)
			audio.call("play", "remove")
		return
	# ...unless she is holding the pickaxe and aiming at a bare seam, in which
	# case the press is a swing. Z lifts cats before it does anything else, and
	# the third cat in a working factory spends its whole day walking between the
	# miners and the core -- across the seams. Pressing Z to mine while it passed
	# lifted it instead, and _update_hand_mining cancels the swing outright while
	# a cat is being carried, so the player got no progress, an armful of cat and
	# an objective card telling them to go put it somewhere.
	#
	# Only bare ore. A cat standing on a miner is standing on ore too, and taking
	# it off to reassign it has to keep working.
	var target: Vector2i = _hand_target()
	var mining_here: bool = holding_pickaxe() and sim.ore.has(target) \
		and not sim.machines.has(target)
	if not mining_here and sim.pick_up_frozen(cell):
		_notify("얼어붙은 고양이를 안았습니다  느려지고 달릴 수 없습니다", Defs.COL_BELT_RIM)
		fx.ring(sim.cell_centre(cell), Defs.COL_ICE, 22.0)
		audio.call("play", "select")
		return
	if not mining_here and sim.pick_up_cat(cell):
		_notify("고양이를 안았습니다 · 채굴기 앞에서 Z", Defs.COL_BELT_RIM)
		fx.ring(sim.cell_centre(cell), Defs.COL_BELT_RIM, 22.0)
		audio.call("play", "select")
		return
	# Nothing here refuses the press for facing a structure. A miner is built
	# *onto* ore, and ore is a structure, so a "구조물은 들 수 없습니다" guard
	# ahead of this line made the game's central placement impossible. Ore has no
	# pick-up verb to protect anyway -- Z takes cats, X takes machines -- so
	# can_build's own reason is both sufficient and more useful.
	if not holding_build_gun():
		return
	_try_build()

## Putting down the base or the shelter. Both refuse for reasons the player
## cannot see from the tile alone, so a refusal says which one it was -- a
## placement that silently does nothing is the same experience as a broken key.
## Walking up to the fire. Putting fuel in and making something out of it are
## both what "going to the base" means, so both are behind the one press -- but
## as two rows rather than one automatic action and one choice.
##
## The first version deposited on open, and it was wrong for a reason the window
## itself made obvious: a torch is made of the same heat stone the fire burns, so
## opening the window spent the material the window exists to spend. Every visit
## ended with a red cost and nothing to pay it with.
func base_rows() -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	# Only while there is something to put in. A row that is always there and
	# usually refuses teaches the player to skip past it.
	if sim.has_fuel():
		rows.append({"kind": "fuel"})
	for index in Defs.BASE_CRAFTS.size():
		rows.append({"kind": "craft", "craft": index})
	return rows

func _open_base_menu() -> void:
	base_menu_open = true
	build_menu_open = false
	map_open = false
	gacha_open = false
	menu_index = 0
	audio.call("play", "select")

func close_base_menu() -> void:
	if not base_menu_open:
		return
	base_menu_open = false
	audio.call("play", "select")

## Whichever row the cursor is on.
func _base_menu_confirm() -> void:
	var rows: Array[Dictionary] = base_rows()
	if rows.is_empty():
		return
	var row: Dictionary = rows[clampi(menu_index, 0, rows.size() - 1)]
	if String(row["kind"]) == "fuel":
		_deposit_at_core()
		# The row it was on has just gone, so the cursor lands on the craft list
		# rather than on whatever slid into its place.
		menu_index = 0
		return
	craft_selected(int(row["craft"]))

## Making something at the fire. A table rather than a branch, so the second
## thing the base can make is a row and not a rewrite.
func craft_selected(index: int = 0) -> void:
	var craft: Dictionary = Defs.BASE_CRAFTS[clampi(index, 0, Defs.BASE_CRAFTS.size() - 1)]
	if not sim.craft_torch():
		_notify("%s  ·  재료가 모자랍니다" % String(craft["name"]), Defs.COL_TEXT_DIM)
		audio.call("play", "deny")
		return
	_notify("%s을 만들었습니다  (%d개)" % [String(craft["name"]), sim.torches], Defs.COL_CORE)
	fx.ring(sim.cell_centre(sim.core_cell), Defs.COL_CORE, Defs.RING_MEDIUM)
	audio.call("play", "alloy")

## Handing the fuel over, and showing it go in. The pieces fly out of her arms
## and are pulled into the core, because "the number in the corner changed" is
## not a thing happening -- and this is the action the whole first ten minutes
## is built around.
func _deposit_at_core() -> void:
	if not sim.has_fuel():
		_notify("넣을 연료가 없습니다", Defs.COL_TEXT_DIM)
		audio.call("play", "deny")
		return
	var before: int = sim.heat
	var moved: Dictionary = sim.deposit_fuel()
	var target: Vector2 = sim.cell_centre(sim.core_cell)
	var parts: Array[String] = []
	for item_type: int in moved:
		var count: int = int(moved[item_type])
		fx.stream(player.position + Vector2(0, -10.0), target,
			Defs.ITEM_COLORS[item_type], mini(count, 8))
		parts.append("%s %d" % [Defs.ITEM_NAMES[item_type], count])
	var gained: int = sim.heat - before
	fx.popup(target + Vector2(0, -34.0), "+%d 열" % gained, Defs.COL_CORE, true)
	fx.ring(target, Defs.COL_CORE, Defs.RING_LARGE)
	shake = maxf(shake, Defs.FX_SMALL)
	audio.call("play", "deliver")
	_notify("%s  ·  온기 %.1f칸" % [" · ".join(parts), sim.warm_radius], Defs.COL_CORE)

func _place_kit(cell: Vector2i) -> void:
	var kit: int = sim.carried_kit
	if kit == Defs.KIT_BASE:
		if sim.place_base(cell):
			_notify("불이 붙었습니다  기지 %.0f칸 안이 따뜻합니다" % sim.warm_radius,
				Defs.COL_CORE)
			fx.ring(sim.cell_centre(cell), Defs.COL_CORE, Defs.RING_LARGE)
			fx.burst(sim.cell_centre(cell), Defs.COL_CORE, 16)
			shake = maxf(shake, Defs.FX_SMALL)
			audio.call("play", "finish")
			return
		if Vector2(cell - sim.core_cell).length() > Defs.BASE_PLACE_RADIUS:
			_notify("추락 지점에서 너무 멉니다  %d칸 안에 놓으세요"
				% int(Defs.BASE_PLACE_RADIUS), Defs.COL_TEXT_DIM)
		else:
			_notify("여기에는 놓을 수 없습니다", Defs.COL_TEXT_DIM)
	elif kit == Defs.KIT_SHELTER:
		if sim.place_shelter(cell):
			_notify("거처를 세웠습니다  밤에는 여기서 잡니다", Defs.COL_CORE)
			fx.ring(sim.cell_centre(cell), Defs.COL_CORE, Defs.RING_LARGE)
			audio.call("play", "finish")
			return
		var distance: float = Vector2(cell - sim.core_cell).length()
		if distance <= Defs.SHELTER_CLEARANCE:
			_notify("기지에 너무 붙었습니다  %d칸 밖에 세우세요"
				% int(Defs.SHELTER_CLEARANCE), Defs.COL_TEXT_DIM)
		elif distance > sim.warm_radius:
			_notify("온기 반경 밖입니다  기지가 닿는 곳에 세우세요", Defs.COL_TEXT_DIM)
		else:
			_notify("여기에는 세울 수 없습니다", Defs.COL_TEXT_DIM)
	audio.call("play", "deny")

func _try_build() -> void:
	if player.locked:
		return
	var cell: Vector2i = player.facing_cell()
	var type: int = selected_type()
	if sim.build(type, cell, build_dir):
		var at: Vector2 = Vector2(cell) * float(Defs.TILE) + Vector2.ONE * Defs.TILE * 0.5
		fx.ring(at, Defs.machine_color(type), Defs.RING_MEDIUM)
		fx.burst(at, Defs.machine_color(type), 8)
		shake = maxf(shake, Defs.FX_MEDIUM)
		audio.call("play", "build")

## Switching a machine to its other recipe. Per machine rather than global, so a
## player with spare copper on one line and none on another can run both.
## Steps through the debug time multipliers. Engine.time_scale is global, so this
## moves the whole game at once rather than just the simulation.
## --- Zoom keys -----------------------------------------------------------------
## The two keys next to each other on every layout: minus shrinks, equals grows.
## Shift moves the same pair from the world to the HUD, which is why they are one
## function -- the pair has to stay a pair, and splitting it across two handlers
## is how one of them ends up bound and the other forgotten.
##
## Read from `physical_keycode`, not `keycode`. Shift turns minus into underscore
## and equals into plus, so the character the key produces is not the key: a
## handler written against KEY_MINUS simply stops firing the moment Shift is
## held, which is exactly when the HUD binding is wanted. The numpad's own pair
## is accepted too, and it does not change under Shift.
##
## One step is the same step the settings sliders move in, so nudging with the
## keyboard and dragging the slider land on the same values.
func _zoom_key(key: InputEventKey) -> bool:
	var physical: int = key.physical_keycode
	var direction: float = 0.0
	if physical == KEY_MINUS or physical == KEY_KP_SUBTRACT:
		direction = -Defs.UI_SCALE_STEP
	elif physical == KEY_EQUAL or physical == KEY_KP_ADD:
		direction = Defs.UI_SCALE_STEP
	else:
		return false
	if key.shift_pressed:
		set_ui_scale(ui_scale + direction)
		_notify("화면 UI 크기 %d%%" % int(round(ui_scale * 100.0)), Defs.COL_MACHINE_EDGE)
	else:
		set_game_scale(game_scale + direction)
		_notify("게임 화면 크기 %d%%" % int(round(game_scale * 100.0)), Defs.COL_MACHINE_EDGE)
	audio.call("play", "select")
	return true

func cycle_debug_speed() -> int:
	speed_index = (speed_index + 1) % Defs.DEBUG_SPEEDS.size()
	Engine.time_scale = Defs.DEBUG_SPEEDS[speed_index]
	_notify("디버그 %.0f배속" % Defs.DEBUG_SPEEDS[speed_index],
		Defs.COL_DANGER if speed_index > 0 else Defs.COL_TEXT_DIM)
	audio.call("play", "select")
	return speed_index

func debug_speed() -> float:
	return Defs.DEBUG_SPEEDS[speed_index]

## Opens everything and fills the bank. The second debug tool, and the one that
## makes the mid-game reachable for inspection at all: half the interface only
## exists once a machine is unlocked, so screens like the build list could not be
## looked at without playing to them first.
func debug_unlock_all() -> void:
	for type: int in Defs.BUILDABLE:
		sim.unlocked[type] = true
	for index in Defs.RECIPES.size():
		sim.unlocked_recipes[index] = true
	for item_type: int in Defs.COUNTED_ITEMS:
		sim.stock[item_type] = 500
	# And a crew. Everything else this key grants can be checked from a
	# screenshot the moment it is pressed; cats cannot, because getting one means
	# walking out to a frozen one and carrying it home at half speed, and that is
	# most of a twelve minute day. Verifying anything about how a cat is drawn
	# meant playing the game to the point of having one, several times, and the
	# day kept running out first.
	sim.grant_cats(maxi(0, Defs.DEBUG_CATS - sim.cats.size()))
	# And coins. There is no way to earn one yet, so without this the slot machine
	# is a window with three buttons that all refuse -- and a 0.5% grade cannot be
	# looked at by anyone at all.
	sim.coins = maxi(sim.coins, Defs.DEBUG_COINS)
	_notify("디버그 전체 해금", Defs.COL_DANGER)
	audio.call("play", "confirm")

## The standard scenario in one key: two miners on the first two starter seams
## facing north, a cat working each, a third left idle. TESTS.md calls this
## `real test`, and building it by hand is a dozen timed key holds -- one hold
## that lands Grim a cell off puts a cat on the ore instead of the miner, and the
## run afterwards looks exactly like a game that will not produce. A test rig
## that fails the way a bug fails is worse than no rig.
##
## North matters and is the reason this key exists at all rather than a scatter
## of miners. A miner emits into the cell it faces; on adjacent seams facing east
## the left one emits into the right one and the right one into the third seam,
## so both jam. Facing north they drop onto open floor for the idle cat to haul.
func debug_scenario() -> void:
	debug_unlock_all()
	# Whatever Grim was holding goes down first, or assigning it below would drop
	# it silently and leave the player carrying a cat that is standing elsewhere.
	if sim.carried_cat != null:
		sim.drop_cat(player.position)
	var north := Vector2i(0, -1)
	for index in 2:
		var cell: Vector2i = sim.core_cell + Sim.STARTER_PATCH[index]
		if not sim.machines.has(cell):
			sim.build(Defs.M_MINER, cell, north)
	# Through the same door the player uses, so this cannot drift away from what
	# carrying a cat over and putting it down actually does.
	for cell: Vector2i in sim.idle_miner_cells():
		var spare: Sim.Cat = null
		for cat: Sim.Cat in sim.cats:
			if not cat.has_job():
				spare = cat
				break
		if spare == null:
			break
		sim.carried_cat = spare
		sim.place_cat(cell)
	_notify("디버그 시나리오 · 채굴기 2대 · 고양이 배치", Defs.COL_DANGER)
	audio.call("play", "confirm")

## A closed rectangle of belt, so every turn a belt can make is on screen at once.
##
## Belts pick between a straight tile and a corner by looking at what feeds them,
## which means the picture depends on the neighbours rather than on the belt --
## and a rule like that is only really checked by laying belts down and looking.
## Doing that by hand takes a couple of dozen presses each time, and a run built
## by timed key holds fails in ways that look exactly like the game being broken.
##
## A loop rather than a line because it contains all four corner cases, both
## handednesses, and a straight run in each direction, which is everything the
## drawing can get wrong. `test_belt` pins the choice; this is for looking at the
## seams, which no assertion is going to judge.
func debug_belt_loop() -> void:
	debug_unlock_all()
	var origin: Vector2i = sim.core_cell + Vector2i(-3, 3)
	var span := Vector2i(6, 4)
	# Clockwise: east along the top, south down the right, west along the bottom,
	# north up the left. Each belt points the way the loop travels, so the corners
	# are made by the neighbours rather than by anything stored here.
	var runs: Array[Array] = [
		[Vector2i(0, 0), Vector2i(1, 0), span.x],
		[Vector2i(span.x, 0), Vector2i(0, 1), span.y],
		[Vector2i(span.x, span.y), Vector2i(-1, 0), span.x],
		[Vector2i(0, span.y), Vector2i(0, -1), span.y],
	]
	var built := 0
	for run: Array in runs:
		var at: Vector2i = origin + (run[0] as Vector2i)
		var step: Vector2i = run[1]
		for _index in int(run[2]):
			sim.machines.erase(at)
			# Ore too. The first run of this landed half built because seams sat
			# under it, and a tool that sometimes produces the arrangement it
			# promises is worse than no tool: a gap in the loop looks exactly
			# like a corner the drawing failed to make.
			sim.ore.erase(at)
			if sim.build(Defs.M_BELT, at, step):
				built += 1
			at += step
	_notify("디버그 벨트 고리 · %d칸" % built, Defs.COL_DANGER)
	audio.call("play", "confirm")

## The crowded version: eight cats and a miner on every seam that will take one.
##
## The standard scenario is three cats, which is the arrangement to watch when
## asking whether a factory runs. It is the wrong one for asking whether cats
## come apart while they walk -- that needs traffic, several animals crossing at
## once, some working and some off to eat. Separate key rather than a bigger
## `debug_scenario`, because `real test` is defined as three.
func debug_crowd() -> void:
	debug_unlock_all()
	if sim.carried_cat != null:
		sim.drop_cat(player.position)
	var north := Vector2i(0, -1)
	# Any seam, not a named resource. This read ITEM_CRYSTAL, and the day crystal
	# moved out to the middle of the game the key silently built nothing -- the
	# crowd it exists to make was eight cats standing around. A debug key that
	# quietly stops working is worse than one that is missing.
	for cell: Vector2i in sim.ore.keys():
		if sim.machines.has(cell):
			continue
		if Vector2(cell - sim.core_cell).length() > 6.0:
			continue
		sim.build(Defs.M_MINER, cell, north)
	sim.grant_cats(maxi(0, 8 - sim.cats.size()))
	for cell: Vector2i in sim.idle_miner_cells():
		var spare: Sim.Cat = null
		for cat: Sim.Cat in sim.cats:
			if not cat.has_job():
				spare = cat
				break
		if spare == null:
			break
		sim.carried_cat = spare
		sim.place_cat(cell)
	_notify("디버그 혼잡 · 고양이 %d마리" % sim.cats.size(), Defs.COL_DANGER)

## One frozen cat, on the tile she is facing.
##
## Checking the rescue in a browser meant walking four tiles east, one north,
## turning to face east and pressing Z -- and when any of that landed her half a
## tile off, Z fell through to the build gun and the run looked exactly like a
## rescue that does not work. It happened on the first attempt. The world is
## seeded per run, so the walk cannot be written down once and trusted.
##
## The whole flow after this point is real: she carries it at half speed, has to
## get it within two tiles of the core, and the ice takes its twelve seconds.
func debug_rescue() -> void:
	if sim.carried_frozen:
		_notify("이미 안고 있습니다", Defs.COL_TEXT_DIM)
		return
	var cell: Vector2i = player.facing_cell()
	if sim.is_structure(cell):
		cell = player.cell() + Vector2i(1, 0)
	sim.frozen_cats[cell] = 0.0
	_notify("디버그 구조 · 얼어붙은 고양이를 앞에 두었습니다", Defs.COL_DANGER)
	fx.ring(sim.cell_centre(cell), Defs.COL_ICE, 22.0)

func _cycle_recipe() -> void:
	if player.locked:
		return
	var cell: Vector2i = player.facing_cell()
	var machine = sim.machine_at(cell)
	if machine == null:
		return
	if machine.type == Defs.M_BELT:
		var tier: int = sim.cycle_belt_tier(cell)
		if tier < 0:
			_notify("구리광석이 부족합니다", Defs.COL_DANGER)
			audio.call("play", "deny")
			return
		_notify("%s · %.0f배 속도" % [Defs.BELT_TIERS[tier]["name"], Defs.BELT_TIERS[tier]["speed"]],
			Defs.COL_CORE)
		fx.ring(sim.cell_centre(cell), Defs.COL_BELT_RIM, Defs.RING_MEDIUM)
		audio.call("play", "build")
		return
	if machine.type != Defs.M_EXCHANGER:
		return
	if not sim.recipe_unlocked(Defs.RECIPE_ALLOY):
		_notify("구리광석을 손에 넣으면 다른 제법이 열립니다", Defs.COL_TEXT_DIM)
		audio.call("play", "deny")
		return
	var picked: int = sim.cycle_recipe(cell)
	if picked < 0:
		return
	_notify("%s 제법 · %s" % [Defs.RECIPES[picked]["name"], Defs.recipe_line(picked)], Defs.COL_CORE)
	fx.ring(sim.cell_centre(cell), Defs.COL_CORE, Defs.RING_MEDIUM)
	audio.call("play", "select")

func _try_demolish() -> void:
	if player.locked:
		return
	# Both hands are busy. Letting X pull up a machine while a cat is being
	# carried was the one way to hold two things at once.
	if sim.carried_cat != null:
		_notify("고양이를 안고 있어 회수할 수 없습니다", Defs.COL_TEXT_DIM)
		audio.call("play", "deny")
		return
	var cell: Vector2i = player.facing_cell()
	if sim.demolish(cell):
		var at: Vector2 = Vector2(cell) * float(Defs.TILE) + Vector2.ONE * Defs.TILE * 0.5
		fx.burst(at, Defs.COL_TEXT_DIM, 5)
		audio.call("play", "remove")
	else:
		_notify("회수할 설비가 없습니다", Defs.COL_TEXT_DIM)

func _on_heat_gained(amount: int, cell: Vector2i, item_type: int) -> void:
	var at: Vector2 = Vector2(cell) * float(Defs.TILE) + Vector2.ONE * Defs.TILE * 0.5
	fx.popup(at, "+%d" % amount, Defs.ITEM_COLORS[item_type])
	var energy: bool = item_type == Defs.ITEM_ENERGY
	fx.ring(at, Defs.COL_CORE, Defs.RING_LARGE if energy else Defs.RING_SMALL)
	shake = maxf(shake, Defs.FX_LARGE if energy else Defs.FX_QUIET)
	audio.call("play", "alloy" if item_type == Defs.ITEM_ENERGY else "deliver")

func _on_build_rejected(reason: String, cell: Vector2i) -> void:
	# One channel only. Showing the same reason both here and in the centre
	# banner produced two overlapping copies of the same string.
	fx.popup(Vector2(cell) * float(Defs.TILE) + Vector2(Defs.TILE * 0.5, -8.0), reason,
		Color8(255, 154, 143), true)
	fx.ring(Vector2(cell) * float(Defs.TILE) + Vector2.ONE * Defs.TILE * 0.5, Defs.COL_DANGER, 14.0)
	audio.call("play", "deny")

func _on_warmth_changed(radius: float) -> void:
	if state != State.PLAY:
		return
	# The panel already carries this number. Printing it in the world drew it
	# straight across the core at 1.22:1, defacing the one hero object.
	fx.ring(Vector2(sim.core_cell) * float(Defs.TILE) + Vector2.ONE * Defs.TILE * 0.5,
		Defs.COL_CORE, radius * float(Defs.TILE) * 0.12)

func _notify(text: String, color: Color) -> void:
	message = text
	message_life = 2.0
	hud.set("message_color", color)

## --- Persistence ----------------------------------------------------------
## The run seed is stored, so the same world is rebuilt and only the player's
## changes need to travel in the file.
func save_game(announce: bool = true, slot: int = 0) -> bool:
	var config := ConfigFile.new()
	config.set_value("motorio", "schema", SAVE_SCHEMA)
	# The slot list has to be readable without loading a run, so what the picker
	# shows lives beside the state rather than inside it.
	config.set_value("motorio", "card", {
		"saved_at": Time.get_unix_time_from_system(),
		"day": day_number,
		"heat": sim.total_heat,
		"machines": _slot_thumbnail(),
	})
	config.set_value("motorio", "state", {
		"seed": run_seed,
		"day": day_number,
		"time_left": time_left,
		"day_start_heat": day_start_heat,
		"px": player.position.x,
		"py": player.position.y,
		"warmth": player.warmth,
		"mission": mission,
		"sim": sim.to_save(),
	})
	if config.save(slot_path(slot)) != OK:
		return false
	if announce:
		_notify("저장했습니다", Defs.COL_CORE)
	return true

## The picture on a save slot: the factory's own shape, as cells and colours.
##
## Not a screenshot. Capturing the viewport needs a renderer, which headless has
## none of -- the repository already has a lesson about assuming otherwise -- and
## a PNG of a screen is kilobytes per slot. The factory layout is the thing that
## actually distinguishes one run from another, and it is already in the save;
## this is a few dozen bytes and draws itself.
func _slot_thumbnail() -> Array:
	var cells: Array = []
	for cell: Vector2i in sim.machines:
		var machine = sim.machines[cell]
		var offset: Vector2i = cell - sim.core_cell
		# Only what fits the little window, so a distant outpost cannot stretch
		# the drawing until the base is a single dot.
		if absf(float(offset.x)) > 24.0 or absf(float(offset.y)) > 24.0:
			continue
		cells.append([offset.x, offset.y, machine.type])
		if cells.size() >= 220:
			break
	return cells

## What is in each slot, for the picker. Empty slots come back with exists false
## rather than being skipped, so the list always shows every slot a player has.
func slot_cards() -> Array[Dictionary]:
	var cards: Array[Dictionary] = []
	for slot in SAVE_SLOTS:
		var config := ConfigFile.new()
		var card := {"slot": slot, "exists": false, "day": 0, "heat": 0,
			"saved_at": 0.0, "machines": []}
		if config.load(slot_path(slot)) == OK \
				and int(config.get_value("motorio", "schema", -1)) == SAVE_SCHEMA:
			var stored: Dictionary = config.get_value("motorio", "card", {})
			card["exists"] = true
			card["day"] = int(stored.get("day", 0))
			card["heat"] = int(stored.get("heat", 0))
			card["saved_at"] = float(stored.get("saved_at", 0.0))
			card["machines"] = stored.get("machines", [])
		cards.append(card)
	return cards

## "8월 6일 14:32". Local time, because a player reading their own save list is
## not thinking in UTC.
static func slot_when(saved_at: float) -> String:
	if saved_at <= 0.0:
		return ""
	var when: Dictionary = Time.get_datetime_dict_from_unix_time(
		int(saved_at) + Time.get_time_zone_from_system().get("bias", 0) * 60)
	return "%d월 %d일  %02d:%02d" % [int(when["month"]), int(when["day"]),
		int(when["hour"]), int(when["minute"])]

func load_game(slot: int = 0) -> bool:
	var config := ConfigFile.new()
	if config.load(slot_path(slot)) != OK:
		return false
	# A schema change means the shape of the data moved; starting fresh is safer
	# than half-restoring a run into a game that no longer matches it.
	if int(config.get_value("motorio", "schema", -1)) != SAVE_SCHEMA:
		return false
	var data: Dictionary = config.get_value("motorio", "state", {})
	if data.is_empty():
		return false
	run_seed = int(data.get("seed", run_seed))
	sim.setup(run_seed)
	sim.from_save(data.get("sim", {}))
	day_number = int(data.get("day", 1))
	time_left = float(data.get("time_left", Defs.DAY_SECONDS))
	day_start_heat = int(data.get("day_start_heat", 0))
	player.position = Vector2(float(data.get("px", 0.0)), float(data.get("py", 0.0)))
	player.warmth = float(data.get("warmth", 100.0))
	mission = int(data.get("mission", Mission.DONE))
	player.locked = false
	player.collapse = 0.0
	collapse_timer = -1.0
	return true

func clear_save() -> void:
	for slot in SAVE_SLOTS:
		DirAccess.remove_absolute(slot_path(slot))

## --- Settings -------------------------------------------------------------
## Kept in its own file, deliberately. UI size is a property of the player's
## screen, not of the run, so it must survive both "new game" and a save schema
## bump -- neither of which should ever hand someone back an unreadable HUD.
const SETTINGS_PATH := "user://motorio_settings.cfg"

func set_ui_scale(value: float) -> void:
	var wanted: float = Defs.quantise_ui_scale(value)
	if is_equal_approx(wanted, ui_scale):
		return
	ui_scale = wanted
	touch.set_pad_scale(ui_scale)
	save_settings()

func set_game_scale(value: float) -> void:
	var wanted: float = Defs.quantise_game_scale(value)
	if is_equal_approx(wanted, game_scale):
		return
	game_scale = wanted
	# Applied immediately rather than on the next frame, so dragging the slider
	# shows the world resizing under the panel while the finger is still down.
	_apply_camera_zoom()
	save_settings()

## Touch and desktop want different amounts of world on screen: the phone's
## logical viewport is three times taller than the layout was drawn for, so at
## 1:1 it shows a vast area at postage-stamp size.
func _apply_camera_zoom(delta: float = 0.0) -> void:
	var touch_pad: bool = touch != null and touch.visible
	var base: float = Defs.GAME_SCALE_TOUCH_BASE if touch_pad else Defs.GAME_SCALE_DESKTOP_BASE
	# The hut is a single tile, so at play zoom the shadows in its window are a
	# few pixels. The sequence leans in; eased rather than snapped, because a cut
	# in zoom reads as a glitch where a push reads as attention.
	var want: float = Defs.NIGHT_CAMERA_ZOOM if cinema() else 1.0
	if delta > 0.0:
		cinema_zoom = lerpf(cinema_zoom, want, clampf(delta * Defs.NIGHT_CAMERA_LERP, 0.0, 1.0))
	else:
		cinema_zoom = want
	var zoom: float = maxf(base * game_scale * cinema_zoom, 0.05)
	camera.zoom = Vector2(zoom, zoom)

func save_settings() -> bool:
	var config := ConfigFile.new()
	config.set_value("settings", "ui_scale", ui_scale)
	config.set_value("settings", "game_scale", game_scale)
	return config.save(SETTINGS_PATH) == OK

func load_settings() -> void:
	# Defaults are per platform: a phone needs everything enlarged just to be
	# legible, a desktop wants the HUD out of the way of the factory. Chosen from
	# the same test the pad uses to decide whether to show itself, so the two can
	# never disagree about which kind of device this is.
	var touch_device: bool = touch != null and touch.visible
	ui_scale = Defs.UI_SCALE_DEFAULT if touch_device else Defs.UI_SCALE_DEFAULT_DESKTOP
	game_scale = Defs.GAME_SCALE_DEFAULT if touch_device else Defs.GAME_SCALE_DEFAULT_DESKTOP
	var config := ConfigFile.new()
	if config.load(SETTINGS_PATH) == OK:
		ui_scale = Defs.quantise_ui_scale(
			float(config.get_value("settings", "ui_scale", ui_scale)))
		game_scale = Defs.quantise_game_scale(
			float(config.get_value("settings", "game_scale", game_scale)))
	touch.set_pad_scale(ui_scale)
	_apply_camera_zoom()

func open_settings() -> void:
	if state == State.SETTINGS:
		return
	state_before_settings = state
	state = State.SETTINGS
	build_held = false
	touch.release_all()
	audio.call("play", "select")

## Wipes the save and starts a fresh day one. Asked twice on purpose: it is the
## only button in the game that can destroy hours of factory, it now sits on the
## panel Esc opens rather than behind a menu, and a mis-tap has no undo.
func settings_restart() -> void:
	if hud.restart_armed <= 0.0:
		hud.restart_armed = 4.0
		audio.call("play", "select")
		return
	hud.restart_armed = 0.0
	clear_save()
	_restart_from_the_top()
	state_before_settings = State.PLAY
	hud.call("end_slider_drag")
	_notify("처음부터 시작합니다", Defs.COL_DANGER)
	audio.call("play", "confirm")

## Both buttons open the same list. Which slot holds what is exactly the thing
## you need to see whether you are about to write over one or read one.
func settings_save() -> void:
	_open_slot_picker(1)

func settings_load() -> void:
	_open_slot_picker(2)

func _open_slot_picker(mode: int) -> void:
	hud.slot_picker = mode
	hud.restart_armed = 0.0
	# Never start on the autosave: for saving it is the slot the timer owns, and
	# for loading it is the one the player did not choose.
	hud.slot_index = 1
	audio.call("play", "select")

func close_slot_picker() -> void:
	hud.slot_picker = 0
	audio.call("play", "select")

## Confirming a slot. Saving writes and stays put so the list visibly updates;
## loading drops straight into the restored run, because a menu you have to close
## yourself after it has already done the thing is a menu in the way.
func confirm_slot(slot: int) -> void:
	if hud.slot_picker == 1:
		if save_game(false, slot):
			hud.saved_flash = 2.0
			audio.call("play", "confirm")
		else:
			_notify("저장에 실패했습니다", Defs.COL_DANGER)
		return
	if not load_game(slot):
		_notify("빈 슬롯입니다", Defs.COL_DANGER)
		audio.call("play", "select")
		return
	hud.slot_picker = 0
	hud.call("end_slider_drag")
	hud.call("end_map_drag")
	build_menu_open = false
	map_open = false
	meter_cell = Vector2i(9999, 9999)
	night_override = -1.0
	cinema_zoom = 1.0
	state = State.PLAY
	state_before_settings = State.PLAY
	_notify("%d일차부터 이어서 진행합니다" % day_number, Defs.COL_CORE)
	audio.call("play", "confirm")

func close_settings() -> void:
	if state != State.SETTINGS:
		return
	hud.restart_armed = 0.0
	hud.slot_picker = 0
	state = state_before_settings
	hud.call("end_slider_drag")
	audio.call("play", "confirm")

func day_heat() -> int:
	return sim.total_heat - day_start_heat

## Falling asleep outside: the cats bring you in, and the night ends anyway, but
## the day is scored as it stood.
## Zero warmth before there is a base. Nothing rescues her because there is
## nothing to rescue her -- she simply comes round again at the crash site, cold
## and with the same eighty seconds. The opening cannot be lost; it can only be
## made to take longer, which is what the temperature is there to say.
func _come_to() -> void:
	if collapse_timer >= 0.0 or player.collapse > 0.0:
		return
	player.position = sim.cell_centre(sim.core_cell)
	player.velocity = Vector2.ZERO
	player.warmth = Defs.CRASH_WARMTH
	shake = maxf(shake, Defs.FX_SMALL)
	fx.ring(player.position, Defs.COL_FROST_TINT, Defs.RING_LARGE)
	_notify("정신을 잃었다가 다시 눈을 떴습니다  서둘러야 합니다", Defs.COL_DANGER)
	audio.call("play", "alarm")

func _carried_home() -> void:
	rescued_tonight = true
	_sleep()

func sleep_available() -> bool:
	return state == State.PLAY and is_night() and shelter_nearby()

func _sleep() -> void:
	if state != State.PLAY:
		return
	player.locked = true
	player.velocity = Vector2.ZERO
	player.position = shelter_doorstep()
	audio.call("play", "confirm")
	fx.ring(shelter_position(), Defs.COL_CORE, 52.0)
	_begin_nightfall()

# --- The night sequence ------------------------------------------------------
## Bedtime is not a cut to a summary card. The workforce walks home, the lamp
## goes on with everyone's shadows on the wall, and the hut spends five seconds
## turning from night to morning. It is the only moment the game asks nothing of
## the player, which is what makes it the moment they see what they built.
##
## Both halves are strictly bounded. Every phase advances on a timer as well as
## on its condition, so a cat that cannot reach the hut cannot hold the night
## open forever.

func _begin_nightfall() -> void:
	state = State.NIGHTFALL
	night_phase = Phase.GATHER
	night_timer = 0.0
	night_override = 1.0
	meter_cell = Vector2i(9999, 9999)
	player.locked = true
	player.velocity = Vector2.ZERO
	player.position = shelter_doorstep()
	sim.send_cats_home()

func _process_nightfall(delta: float) -> void:
	# The factory keeps running while its workers walk out on it. _tick_cats
	# clears `operated` every frame, so the machines go quiet one at a time as
	# each cat leaves -- the day ending is something the player watches happen
	# rather than something that is announced.
	sim.tick(delta)
	night_timer += delta
	match night_phase:
		Phase.GATHER:
			if sim.cats_all_home() or night_timer >= Defs.NIGHT_GATHER_MAX:
				sim.force_cats_home()
				night_phase = Phase.GLOW
				night_timer = 0.0
				fx.ring(shelter_position(), Defs.COL_CORE, 40.0)
				audio.call("play", "confirm")
		Phase.GLOW:
			if night_timer >= Defs.NIGHT_GLOW_SECONDS:
				_finish_run()

## 0 when the hut is just a building, 1 when it is full and lit. Drives the
## window, the light spilling onto the snow and the shadows on the wall.
func shelter_glow() -> float:
	match state:
		State.NIGHTFALL:
			if night_phase != Phase.GLOW:
				return 0.0
			return clampf(night_timer / 0.5, 0.0, 1.0)
		State.RESULT:
			return 1.0 if night_override >= 0.0 else 0.0
		State.DAYBREAK:
			if night_phase != Phase.DAWN:
				return 0.0
			# Fades out as the sun comes up: a lamp still burning at dawn reads as
			# a bug rather than as a light.
			return clampf(1.0 - night_timer / Defs.DAWN_SECONDS, 0.0, 1.0)
	return 0.0

func _process_daybreak(delta: float) -> void:
	sim.tick(delta)
	night_timer += delta
	match night_phase:
		Phase.DAWN:
			night_override = clampf(1.0 - night_timer / Defs.DAWN_SECONDS, 0.0, 1.0)
			if night_timer >= Defs.DAWN_SECONDS:
				night_phase = Phase.SPILL
				night_timer = 0.0
				night_override = 0.0
				# Everyone spills out of the door at once and walks back to the
				# post they had. The assignments the player made are the thing
				# that survives the night, so morning is where they are visible.
				sim.wake_cats(shelter_doorstep())
				_notify("%d일차 아침" % day_number, Defs.COL_CORE)
				fx.ring(shelter_doorstep(), Defs.COL_CORE, 46.0)
				audio.call("play", "confirm")
		Phase.SPILL:
			if night_timer >= Defs.DAWN_SPILL_SECONDS:
				night_override = -1.0
				player.locked = false
				state = State.PLAY

## Which score belongs to the screen that is showing, decided in one place.
##
## Driven from the state each frame instead of from the transitions. There are
## eleven assignments to `state` in this file and a hook added to each of them is
## a hook that will be missing from the twelfth -- the same shape of bug as the
## cat walking states, which were listed at the draw call and were short by two.
func _follow_music() -> void:
	var showing: int = state_before_settings if state == State.SETTINGS else state
	match showing:
		State.TITLE: music.call("play_score", "title")
		State.RESULT: music.call("play_score", "result")
		_: music.call("stop")

## Dusk, not game over. The factory keeps everything it built.
##
## No records are kept. A best-day and a best-total were tracked here until
## 2026-08-14, when the shape of the game was settled as long-form rather than
## score attack -- and a high score is the one piece of furniture that cannot be
## in a game like that without telling the player to replay the day.
func _finish_run() -> void:
	state = State.RESULT
	player.locked = true
	save_game(false)
	shake = 4.0
	audio.call("play", "finish")

func _begin_next_day() -> void:
	day_number += 1
	day_start_heat = sim.total_heat
	time_left = Defs.DAY_SECONDS
	night_warned = false
	rescued_tonight = false
	player.collapse = 0.0
	collapse_timer = -1.0
	blackout = 0.0
	player.warmth = 100.0
	# Morning starts at the shelter beside the core, as it does in Motorio.
	player.position = shelter_doorstep()
	# Still locked and still indoors: the clock has been reset to a full day but
	# the sun has not come up yet, which is exactly what night_override is for.
	player.locked = true
	night_override = 1.0
	state = State.DAYBREAK
	night_phase = Phase.DAWN
	night_timer = 0.0
