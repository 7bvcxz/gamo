class_name PopPlayView
extends Control

## The play area of one experiment: the machine and what flies out of it.
## The whole area is the target (a newcomer who taps beside the machine still
## makes it pop). It turns input into commands for the app -- it never changes
## the rules itself -- and turns the rules' events into pictures.
##
## Hints, never words: the machine breathes; after HINT_RING_MS without input a
## ring pulses round it; after HINT_HAND_MS with no input at all, a finger taps
## it (AGENTS.md: more help only after someone has been stuck ~20 seconds).

signal command(kind: String, cmd: Dictionary)

const HINT_RING_MS := 8000
const HINT_HAND_MS := 20000

var rules: PopRules
var fx := PopFx.new()
## Set by the app; null in tests that build a view alone.
var audio: PopAudio
## Three layers, back to front. The machine has its own canvas item and is
## redrawn only when its look changes (level, size); breathing and the squash
## of a pop are its node's scale. Redrawing the whole machine every frame was
## a third of the draw work at the top level (Step 04 render probe).
var under_layer := Node2D.new()
var machine_node := PopMachineNode.new()
var over_layer := Node2D.new()
var rng := RandomNumberGenerator.new()
var reduced_motion := false
## Set by the app each frame: active time and the time of the last input (-1: none).
var now_ms := 0
var last_input_ms := -1
var _t := 0.0
var _jump := 0.0      # the upgrade's hop, 1 -> 0
## The machine's squash is a damped spring: x > 0 pressed down and wide,
## x < 0 stretched up (the recoil overshoot). A press sets it, it rings and
## settles -- anticipation, impact, recoil, settle (Step 04 addendum).
var _squash := 0.0
var _squash_v := 0.0
const SPRING_K := 520.0
const SPRING_DAMP := 16.0
var _held := false
## "+N" over the machine for each earning: [{text, age}]
var _gains: Array[Dictionary] = []


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_NONE
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	rng.seed = 1
	under_layer.name = "Under"
	machine_node.name = "Machine"
	over_layer.name = "Over"
	for n: Node2D in [under_layer, machine_node, over_layer]:
		add_child(n)
	under_layer.draw.connect(func() -> void: _layer_draw(under_layer, true))
	over_layer.draw.connect(func() -> void: _layer_draw(over_layer, false))


func setup(p_rules: PopRules) -> void:
	rules = p_rules
	fx.clear()
	_squash = 0.0
	_squash_v = 0.0
	_held = false
	_gains.clear()


## Bottom-centre of the machine and its stage-4 height, in this control's space.
func machine_base() -> Vector2:
	return Vector2(size.x / 2, size.y * 0.86)


## The stage-4 machine is this tall: it must leave room above for the
## popcorn to fly and fit the column's width with the awning.
func machine_size() -> float:
	return minf(size.y * 0.72, size.x * 0.78)


func machine_top() -> Vector2:
	var h := PopMachineArt.height_at(rules.level if rules else 0, machine_size())
	return machine_base() - Vector2(0, h * 0.78)


func _gui_input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if mb == null or mb.button_index != MOUSE_BUTTON_LEFT:
		return
	accept_event()
	if mb.pressed:
		_held = true
		_press()
	elif _held:
		_held = false
		_release()


## Space / Enter: the same action from the keyboard.
func key(down: bool) -> void:
	if down:
		_press()
	else:
		_release()


func _press() -> void:
	command.emit("press", {"type": "press"})


func _release() -> void:
	pass


## The machine's middle, where hints and rings centre.
func machine_centre() -> Vector2:
	return machine_base() - Vector2(0, PopMachineArt.height_at(rules.level, machine_size()) * 0.5)


## Called each frame before the machine is drawn / after it (variants add to the picture).
func _draw_under(_ci: CanvasItem, _base: Vector2, _size_px: float) -> void:
	pass


func _draw_over(_ci: CanvasItem, _base: Vector2, _size_px: float) -> void:
	pass


## Every experiment's upgrade looks and sounds the same: the machine jumps,
## gold popcorn and sparkles burst from it, a rising chime.
func _upgraded() -> void:
	squash(0.0, 9.0)
	_jump = 1.0
	var s := machine_size() / 900.0
	fx.burst(machine_top(), 22 if not reduced_motion else 2, s, rng, PopPalette.GOLD, 1.2, 1.2)
	if not reduced_motion:
		fx.sparkle(machine_centre(), s, rng, 8, 220.0)
	_sound("upgrade")


## Press the machine down (anticipation) or kick it (an impact rings).
func squash(amount: float, kick: float = 0.0) -> void:
	_squash = maxf(_squash, amount) if kick == 0.0 else _squash
	_squash_v += kick


func _step_spring(delta: float) -> void:
	var dt := minf(delta, 1.0 / 30.0)
	var a := -SPRING_K * _squash - SPRING_DAMP * _squash_v
	_squash_v += a * dt
	_squash = clampf(_squash + _squash_v * dt, -0.6, 1.2)
	if absf(_squash) < 0.002 and absf(_squash_v) < 0.02:
		_squash = 0.0
		_squash_v = 0.0


## Machine shake (C rattles as it fills).
func _shake() -> Vector2:
	return Vector2.ZERO


func _sound(name: String, pitch: float = 1.0, volume_db: float = 0.0) -> void:
	if audio != null:
		audio.play(name, pitch, volume_db)


func _gain(amount: int) -> void:
	_gains.append({"text": "+" + PopMoneyView._format(amount), "age": 0.0})
	if _gains.size() > 6:
		_gains.pop_front()


## The rules' events of this frame, in order.
func on_events(events: Array[Dictionary]) -> void:
	for e: Dictionary in events:
		match String(e["type"]):
			"pop":
				squash(0.0, 9.0)
				var n := int(e["data"].get("count", 1))
				fx.burst(machine_top(), mini(n, 14) if not reduced_motion else 1, machine_size() / 900.0, rng)
				_sound("pop_%d" % (1 + rng.randi() % 3), rng.randf_range(0.92, 1.08))
			"earn":
				fx.coin(machine_top(), machine_size() / 900.0)
				_gain(int(e["data"].get("amount", 0)))
				_sound("coin", 1.0, -6.0)
			"upgrade":
				_upgraded()


func _process(delta: float) -> void:
	_t += delta
	_step_spring(delta)
	_jump = maxf(0.0, _jump - delta * 2.2)
	fx.step(delta)
	for g: Dictionary in _gains:
		g["age"] = float(g["age"]) + delta
	while not _gains.is_empty() and float(_gains[0]["age"]) > 0.9:
		_gains.pop_front()
	if rules != null:
		var size_px := machine_size()
		var fill := 0.15 + 0.7 * float(rules.level) / maxf(1.0, float(rules.max_level()))
		machine_node.set_look(rules.level, size_px, fill)
		var breathe := 0.0 if reduced_motion else sin(_t * 2.4) * 0.012
		var hop := sin(_jump * PI) * machine_size() * 0.06 if not reduced_motion else 0.0
		var grow := 1.0 + 0.08 * sin(_jump * PI) if not reduced_motion else 1.0
		machine_node.position = machine_base() + _shake() - Vector2(0, hop)
		machine_node.scale = Vector2((1.0 + 0.06 * _squash) * (1.0 + breathe) * grow, (1.0 - 0.08 * _squash) * (1.0 - breathe) * grow)
	machine_node.visible = rules != null
	under_layer.queue_redraw()
	over_layer.queue_redraw()


func _layer_draw(ci: CanvasItem, under: bool) -> void:
	if rules == null:
		return
	var base := machine_base() + _shake()
	var size_px := machine_size()
	if under:
		_draw_under(ci, base, size_px)
		return
	_draw_over(ci, base, size_px)
	_draw_hints(ci, base, size_px)
	fx.draw(ci)
	_draw_gains(ci)


func _draw_gains(ci: CanvasItem) -> void:
	var font := ThemeDB.fallback_font
	var top := machine_top()
	for g: Dictionary in _gains:
		var age := float(g["age"])
		var a := clampf(1.0 - age / 0.9, 0.0, 1.0)
		var p := top + Vector2(machine_size() * 0.3, -40.0 - age * 120.0)
		var fs := 44
		ci.draw_string_outline(font, p, String(g["text"]), HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 8, Color(1, 1, 1, a))
		ci.draw_string(font, p, String(g["text"]), HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(PopPalette.INK, a))


func _draw_hints(ci: CanvasItem, _base: Vector2, size_px: float) -> void:
	var idle := now_ms - maxi(last_input_ms, 0)
	if idle < HINT_RING_MS:
		return
	var c := machine_centre()
	var phase := fmod(_t, 1.2) / 1.2
	var r := size_px * (0.35 + 0.15 * phase)
	ci.draw_arc(c, r, 0.0, TAU, 48, Color(PopPalette.INK, 0.45 * (1.0 - phase)), 6.0)
	if last_input_ms < 0 and now_ms >= HINT_HAND_MS:
		var tap := 0.5 + 0.5 * sin(_t * 6.0)
		var p := c + Vector2(size_px * 0.12, size_px * 0.05 + tap * 18.0)
		# A finger: a rounded stub with a nail, pointing up-left at the machine.
		ci.draw_circle(p, 22, PopPalette.CREAM)
		ci.draw_rect(Rect2(p.x - 22, p.y, 44, 70), PopPalette.CREAM)
		ci.draw_circle(p + Vector2(0, -6), 10, Color(1, 0.85, 0.8))
		ci.draw_arc(p, 22, PI, TAU, 16, PopPalette.INK, 4.0)
