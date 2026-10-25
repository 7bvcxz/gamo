class_name Tips
extends Control

## Small, one-time help for the things the first-run tutorial does not walk
## through: buying the sea, editing a Momo's tiles, the Special choices and
## their slots, the settlement's next tier, placing research points after a
## sale. A tip rings what it is about, says one line, and goes when tapped
## away or after a while; each is shown once (Settings keeps which), all can
## be turned off or shown again from Settings. Taps pass through it.

const SHOWN_FOR := 14.0

var settings: SettingsStore
## Off under browser tests unless a test asks for tips (they would sit over
## what the test taps); the player's own setting is untouched.
var allowed := true
var bubble: PanelContainer
var text: Label
var ok_button: Button
var tip := ""
var target := Rect2()
var _age := 0.0
var _t := 0.0
## The Control (or a function giving a rect) the ring follows while shown.
var _follow: Callable


func setup(p_settings: SettingsStore) -> void:
	settings = p_settings
	name = "Tips"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	bubble = PanelContainer.new()
	bubble.name = "Bubble"
	bubble.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text = PanelViews.label("", 17)
	text.name = "Text"
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.custom_minimum_size = Vector2(260, 0)
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(text)
	ok_button = Button.new()
	ok_button.name = "Ok"
	ok_button.custom_minimum_size = Vector2(84, 44)
	ok_button.focus_mode = Control.FOCUS_NONE
	ok_button.pressed.connect(dismiss)
	row.add_child(ok_button)
	bubble.add_child(row)
	add_child(bubble)
	visible = false


func seen(id: String) -> bool:
	return (settings.get_value("tips_seen") as Array).has(id)


## Shows tip `id` once: false if tips are off, it was seen, or another is up.
## `follow` returns the screen rect to ring (called each frame while shown).
func offer(id: String, line: String, follow: Callable) -> bool:
	if not allowed or not bool(settings.get_value("tips")) or seen(id) or tip != "":
		return false
	var list: Array = (settings.get_value("tips_seen") as Array).duplicate()
	list.append(id)
	settings.set_value("tips_seen", list)
	tip = id
	_follow = follow
	_age = 0.0
	text.text = line
	ok_button.text = tr("tutorial.ok")
	visible = true
	_place()
	return true


func dismiss() -> void:
	tip = ""
	visible = false
	queue_redraw()


## Every tip again, from the start.
func replay() -> void:
	settings.set_value("tips_seen", [])
	dismiss()


func _process(delta: float) -> void:
	if tip == "":
		return
	_age += delta
	_t += delta
	if _age >= SHOWN_FOR:
		dismiss()
		return
	_place()
	queue_redraw()


func _place() -> void:
	target = _follow.call() if _follow.is_valid() else Rect2()
	bubble.reset_size()
	var s := bubble.size
	var t := target if target.size != Vector2.ZERO else Rect2(size * 0.5, Vector2.ZERO)
	var x := clampf(t.get_center().x - s.x * 0.5, 12.0, maxf(size.x - s.x - 12.0, 12.0))
	var y := t.position.y - s.y - 16.0
	if y < 80.0:
		y = t.end.y + 16.0
	bubble.position = Vector2(x, clampf(y, 80.0, maxf(size.y - s.y - 12.0, 80.0)))


func _draw() -> void:
	if tip == "" or target.size == Vector2.ZERO:
		return
	var pulse := 0.5 + 0.5 * sin(_t * 4.0)
	draw_rect(target.grow(5.0 + 5.0 * pulse), Color(0.62, 1.0, 0.96, 0.25 + 0.3 * (1.0 - pulse)), false, 3.0)
	draw_rect(target.grow(2.0), Color(0.62, 1.0, 0.96, 0.9), false, 2.5)
