extends Node2D

## Orchestrator: owns game state, input routing, camera and the run timer.
## Simulation lives in Sim, drawing lives in the layers, so this file stays thin.

## RESULT is the end of a day, not the end of the game: the world, the factory
## and the warm radius all carry into the next morning.
## SETTINGS is a state rather than an overlay flag so that opening it stops the
## clock: sizing the UI should never cost the player warmth.
enum State { TITLE, PLAY, RESULT, SETTINGS, NIGHTFALL, DAYBREAK }
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
@onready var fx: FxLayer = $Fx
@onready var player: PlayerActor = $Player
@onready var camera: Camera2D = $Player/Camera2D
@onready var hud: Control = $UI/HUD
@onready var audio: Node = $Audio
@onready var touch: TouchControls = $UI/TouchControls

var state: int = State.TITLE
var time_left: float = Defs.DAY_SECONDS
var selected_index: int = 0
var build_dir := Vector2i.RIGHT
var shake: float = 0.0
var collapse_timer: float = -1.0
var run_seed: int = 0
var best_heat: int = 0
var day_number: int = 1
var day_start_heat: int = 0
var best_day_heat: int = 0
var rescued_tonight: bool = false
var message: String = ""
var message_life: float = 0.0
var night_warned: bool = false
var build_held: bool = false
var build_hold_time: float = 0.0
var build_rotated: bool = false
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
## Which entry of Defs.BUILDABLE the cursor is on. Separate from selected_index,
## which is what the gun is actually loaded with -- browsing must not change what
## a stray Z would build.
var menu_index: int = 0

func _ready() -> void:
	randomize()
	# Engine.time_scale is global and survives a scene reload, so a run that ends
	# while sped up would hand the next one a ten-times world.
	Engine.time_scale = 1.0
	speed_index = 0
	sim.heat_gained.connect(_on_heat_gained)
	sim.build_rejected.connect(_on_build_rejected)
	sim.warmth_changed.connect(_on_warmth_changed)
	world_layer.sim = sim
	ground_layer.sim = sim
	cold_fog.sim = sim
	machine_layer.sim = sim
	hud.set("main", self)
	player.blocked = func(cell: Vector2i) -> bool: return sim.blocks_player(cell)
	touch.main_controller = self
	touch.player = player
	load_settings()
	_start_run()
	if load_game():
		_notify("이어서 진행합니다", Defs.COL_CORE)
	state = State.TITLE

func _start_run() -> void:
	run_seed = randi()
	sim.setup(run_seed)
	day_number = 1
	day_start_heat = 0
	best_day_heat = 0
	time_left = Defs.DAY_SECONDS
	player.position = Vector2(sim.core_cell) * float(Defs.TILE) + Vector2(Defs.TILE * 0.5, Defs.TILE * 4.5)
	player.warmth = 100.0
	player.locked = false
	player.velocity = Vector2.ZERO
	collapse_timer = -1.0
	player.collapse = 0.0
	blackout = 0.0
	night_warned = false
	meter_cell = Vector2i(9999, 9999)
	build_menu_open = false
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

## The next useful action, as text plus a picture of the thing it is about.
##
## Both come out of the same branch on purpose. They were going to be two
## functions -- one returning the sentence, one returning an icon for it -- and
## that is a pair that drifts: add a step, update one, and the panel ends up
## showing a generator next to a line about cats. One branch, one answer.
##
## Derived from world state rather than a script, so it stays correct however the
## player plays.
func objective_data() -> Dictionary:
	if is_night():
		return _goal("밤입니다  숙소로 돌아가 Z로 취침하세요", "thing", Icons.THING_SHELTER)
	if is_dusk():
		return _goal("해가 기울고 있습니다  곧 숙소로 돌아가야 합니다", "thing", Icons.THING_SHELTER)
	if sim.carried_cat != null:
		return _goal("고양이를 안고 있습니다  채굴기 앞에서 Z 로 배치하세요", "thing", Icons.THING_CAT)
	# Lv1 -- do it with your hands, then hire someone to do it for you.
	if int(sim.stock.get(Defs.ITEM_CRYSTAL, 0)) == 0 and sim.ground.is_empty():
		return _goal("수정 광맥을 바라보고 C 를 눌러 직접 캐세요", "thing", Icons.THING_SEAM)
	if sim.cats.is_empty() and sim.carried_boxes < Defs.BOXES_PER_CAT:
		return _goal("고양이 상자를 %d개 모아 숙소로 가져가세요  (현재 %d개)"
			% [Defs.BOXES_PER_CAT, sim.carried_boxes], "thing", Icons.THING_CAT_BOX)
	if sim.cats.is_empty():
		return _goal("숙소로 가서 고양이를 입양하세요", "thing", Icons.THING_SHELTER)
	# Lv2 -- crystal automation, then the exchanger that turns it into distance.
	if sim.machine_count(Defs.M_MINER) == 0:
		return _goal("수정 광맥 위에 채굴기를 설치하세요  (수정조각 %d)"
			% int(Defs.MACHINE_COSTS[Defs.M_MINER][Defs.ITEM_CRYSTAL]), "machine", Defs.M_MINER)
	if _unassigned_cats() > 0:
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

## The toolbar. One tool for now -- the build gun -- but it is a list because the
## slot it lives in is a tool slot, not a machine slot: that is the whole point of
## the change. What the gun is loaded with is chosen in its menu, not by which
## number key was pressed last.
const TOOL_BUILD_GUN := 0
const TOOLS: Array[int] = [TOOL_BUILD_GUN]
const TOOL_NAMES := ["건물건설총"]

var tool_index: int = 0

func holding_build_gun() -> bool:
	return TOOLS[tool_index] == TOOL_BUILD_GUN

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
	audio.call("play", "select")
	return true

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

## Loading the gun. A locked machine can be looked at in the menu -- seeing what
## is coming is half of why the menu exists -- but it cannot be loaded.
func _load_build_gun(index: int) -> void:
	var type: int = Defs.BUILDABLE[index]
	if not sim.is_unlocked(type):
		_notify("%s은 아직 해금되지 않았습니다" % Defs.MACHINE_NAMES[type], Defs.COL_DANGER)
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

func _process(delta: float) -> void:
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
	machine_layer.night = dark
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
	# The carried cat rides in front of her, turning as she turns. Driven from
	# here because the sim does not know where the player is standing.
	if sim.carried_cat != null:
		sim.carry_at(player.position, Vector2(player.facing))
		player.carried_cat_pos = sim.carried_cat.pos
		player.carried_cat_heading = sim.carried_cat.heading
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

	# The title is a hero shot: no player, no placement ghost, nothing that reads
	# as leftover debug UI in the one frame that sells the game.
	# Opening settings from the title must not spoil the hero shot, so visibility
	# follows the screen the panel was opened over rather than the panel itself.
	var showing: int = state_before_settings if state == State.SETTINGS else state
	var in_run: bool = showing != State.TITLE
	player.visible = in_run and not indoors()
	machine_layer.show_preview = state == State.PLAY

	match state:
		State.PLAY: _process_play(delta)
		State.TITLE: pass
		State.NIGHTFALL: _process_nightfall(delta)
		State.DAYBREAK: _process_daybreak(delta)
		State.RESULT, State.SETTINGS: pass

## Wind is always there and swells at night; the cold layer tracks how exposed
## the player actually is, so the ear learns the danger before the screen does.
func _update_ambience(delta: float) -> void:
	if state == State.TITLE:
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
const SAVE_PATH := "user://motorio_oneshot_save.cfg"
const SAVE_SCHEMA := 2
const AUTOSAVE_INTERVAL := 30.0

func _update_build_hold(delta: float) -> void:
	if not build_held:
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
	time_left = maxf(0.0, time_left - delta)
	sim.tick(delta)
	_collect_and_adopt()
	_update_warmth(delta)
	_update_preview()
	if not night_warned and is_night():
		night_warned = true
		_notify("밤이 옵니다 — 숙소로 돌아가 Z로 취침하세요", Defs.COL_DANGER)
		audio.call("play", "alarm")
	# Running out of night entirely means the cats come and get you.
	if time_left <= 0.0:
		_carried_home()

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
func _update_hand_mining(delta: float) -> void:
	if state != State.PLAY or player.locked or sim.carried_cat != null:
		sim.cancel_hand_mine()
		player.mining = 0.0
		return
	var facing: Vector2i = player.facing_cell()
	if not mine_held or not sim.ore.has(facing):
		sim.cancel_hand_mine()
		player.mining = 0.0
		return
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
	if sim.collect_box_at(player.cell()):
		fx.popup(player.position + Vector2(0, -22), "고양이 상자 %d/%d" % [sim.carried_boxes, Defs.BOXES_PER_CAT],
			Defs.COL_BELT_RIM, true)
		fx.ring(player.position, Defs.COL_BELT_RIM, Defs.RING_MEDIUM)
		audio.call("play", "select")
	if shelter_nearby() and sim.carried_boxes >= Defs.BOXES_PER_CAT:
		var adopted: int = sim.adopt_cats()
		if adopted > 0:
			_notify("고양이 %d마리를 입양했습니다" % adopted, Defs.COL_CORE)
			fx.ring(shelter_position(), Defs.COL_CORE, Defs.RING_LARGE)
			audio.call("play", "alloy")

func _update_warmth(delta: float) -> void:
	_update_collapse(delta)
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
	_notify("의식이 흐려집니다  %.0f초 안에 숙소로" % Defs.COLLAPSE_GRACE, Defs.COL_DANGER)
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
	# the state machine below.
	if event.is_action_pressed("mine"):
		if not toggle_meter():
			mine_held = true
	elif event.is_action_released("mine"):
		mine_held = false
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
	if event is InputEventMouseMotion and hud.dragging_slider >= 0:
		touch_hud_drag((event as InputEventMouseMotion).position)
		get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and not event.is_pressed() and event.is_action_released("build"):
		if build_held and not build_rotated:
			_primary_action()
		build_held = false
		get_viewport().set_input_as_handled()
		return
	if not (event is InputEventKey) or not event.is_pressed() or event.is_echo():
		return
	var key := event as InputEventKey
	# The panel is modal: while it is open the only keys that mean anything are
	# the ones that close it and the ones that nudge the slider.
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
		get_viewport().set_input_as_handled()
		return
	# The build menu owns the keyboard while it is up. Placed before the state
	# match so a keypress cannot both move the cursor and build something.
	if build_menu_open and state == State.PLAY:
		_build_menu_key(key)
		get_viewport().set_input_as_handled()
		return

	match state:
		State.TITLE:
			if key.keycode == KEY_ESCAPE:
				return
			state = State.PLAY
			audio.call("play", "confirm")
			get_viewport().set_input_as_handled()
			return
		State.RESULT:
			if key.keycode == KEY_ENTER or key.keycode == KEY_KP_ENTER or key.keycode == KEY_SPACE:
				_begin_next_day()
				get_viewport().set_input_as_handled()
			elif key.keycode == KEY_N:
				clear_save()
				_start_run()
				state = State.PLAY
				audio.call("play", "confirm")
				get_viewport().set_input_as_handled()
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
	if key.keycode == KEY_B:
		toggle_build_menu()
		get_viewport().set_input_as_handled()
		return
	if key.keycode >= KEY_1 and key.keycode < KEY_1 + TOOLS.size():
		tool_index = key.keycode - KEY_1
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
	if state == State.SETTINGS:
		# While the panel is up it owns every touch, so a stray tap cannot fall
		# through onto the world behind it.
		if (hud.settings_close_rect as Rect2).has_point(local):
			close_settings()
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
	for index in hud.hotbar_rects.size():
		if (hud.hotbar_rects[index] as Rect2).has_point(local):
			selected_index = index
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
	if state != State.SETTINGS or hud.dragging_slider < 0:
		return false
	_apply_slider(hud.dragging_slider, hud_local(position).x)
	return true

func touch_hud_release() -> void:
	hud.call("end_slider_drag")

## Entry points for the mobile buttons, so touch and keyboard run through the
## same code rather than drifting apart.
func touch_primary() -> void:
	match state:
		State.TITLE:
			state = State.PLAY
			audio.call("play", "confirm")
		State.RESULT:
			_begin_next_day()
		State.SETTINGS:
			close_settings()
		State.PLAY:
			# Route through the same entry point the keyboard uses. Calling
			# _try_build directly meant touch players could never pick up or
			# place a cat, which makes the game unplayable on a phone.
			_primary_action()

## The pad's mine button. Held rather than tapped, so it forwards both edges.
func touch_mine(pressed: bool) -> void:
	if pressed and toggle_meter():
		return
	mine_held = pressed and state == State.PLAY

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
	if sim.carried_cat != null:
		if sim.place_cat(cell):
			_notify("고양이를 채굴기에 배치했습니다", Defs.COL_CORE)
			fx.ring(sim.cell_centre(cell), Defs.COL_CORE, 26.0)
			audio.call("play", "build")
		elif sim.drop_cat(sim.cell_centre(cell)):
			_notify("고양이를 내려놓았습니다", Defs.COL_TEXT_DIM)
			audio.call("play", "remove")
		return
	if sim.pick_up_cat(cell):
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
	_notify("디버그 전체 해금", Defs.COL_DANGER)
	audio.call("play", "confirm")

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
func save_game(announce: bool = true) -> bool:
	var config := ConfigFile.new()
	config.set_value("motorio_oneshot", "schema", SAVE_SCHEMA)
	config.set_value("motorio_oneshot", "state", {
		"seed": run_seed,
		"day": day_number,
		"time_left": time_left,
		"day_start_heat": day_start_heat,
		"best_day_heat": best_day_heat,
		"best_heat": best_heat,
		"px": player.position.x,
		"py": player.position.y,
		"warmth": player.warmth,
		"sim": sim.to_save(),
	})
	if config.save(SAVE_PATH) != OK:
		return false
	if announce:
		_notify("저장했습니다", Defs.COL_CORE)
	return true

func load_game() -> bool:
	var config := ConfigFile.new()
	if config.load(SAVE_PATH) != OK:
		return false
	# A schema change means the shape of the data moved; starting fresh is safer
	# than half-restoring a run into a game that no longer matches it.
	if int(config.get_value("motorio_oneshot", "schema", -1)) != SAVE_SCHEMA:
		return false
	var data: Dictionary = config.get_value("motorio_oneshot", "state", {})
	if data.is_empty():
		return false
	run_seed = int(data.get("seed", run_seed))
	sim.setup(run_seed)
	sim.from_save(data.get("sim", {}))
	day_number = int(data.get("day", 1))
	time_left = float(data.get("time_left", Defs.DAY_SECONDS))
	day_start_heat = int(data.get("day_start_heat", 0))
	best_day_heat = int(data.get("best_day_heat", 0))
	best_heat = int(data.get("best_heat", 0))
	player.position = Vector2(float(data.get("px", 0.0)), float(data.get("py", 0.0)))
	player.warmth = float(data.get("warmth", 100.0))
	player.locked = false
	player.collapse = 0.0
	collapse_timer = -1.0
	return true

func clear_save() -> void:
	DirAccess.remove_absolute(SAVE_PATH)

## --- Settings -------------------------------------------------------------
## Kept in its own file, deliberately. UI size is a property of the player's
## screen, not of the run, so it must survive both "new game" and a save schema
## bump -- neither of which should ever hand someone back an unreadable HUD.
const SETTINGS_PATH := "user://motorio_oneshot_settings.cfg"

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
	var config := ConfigFile.new()
	if config.load(SETTINGS_PATH) == OK:
		ui_scale = Defs.quantise_ui_scale(
			float(config.get_value("settings", "ui_scale", Defs.UI_SCALE_DEFAULT)))
		game_scale = Defs.quantise_game_scale(
			float(config.get_value("settings", "game_scale", Defs.GAME_SCALE_DEFAULT)))
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
	_start_run()
	state = State.PLAY
	state_before_settings = State.PLAY
	hud.call("end_slider_drag")
	_notify("처음부터 시작합니다", Defs.COL_DANGER)
	audio.call("play", "confirm")

func settings_save() -> void:
	if save_game(false):
		hud.saved_flash = 2.0
		audio.call("play", "confirm")
	else:
		_notify("저장에 실패했습니다", Defs.COL_DANGER)

func close_settings() -> void:
	if state != State.SETTINGS:
		return
	hud.restart_armed = 0.0
	state = state_before_settings
	hud.call("end_slider_drag")
	audio.call("play", "confirm")

func day_heat() -> int:
	return sim.total_heat - day_start_heat

## Falling asleep outside: the cats bring you in, and the night ends anyway, but
## the day is scored as it stood.
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

## Dusk, not game over. The factory keeps everything it built.
func _finish_run() -> void:
	state = State.RESULT
	best_heat = maxi(best_heat, sim.total_heat)
	best_day_heat = maxi(best_day_heat, day_heat())
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
