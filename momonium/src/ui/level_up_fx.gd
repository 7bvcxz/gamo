class_name LevelUpFx
extends Control

## A level gained, in the HUD (Step 54): at the EXP card, a gold burst -- a
## ring and short rays -- and beside it "LEVEL UP!" with the level reached
## ("Lv 5", or "Lv 3 -> 5" when several came at once), for DURATION seconds.
## It is the card's own news, not a screen: it covers no button, takes no tap,
## and a second level while it shows only updates it. What a level opens is
## named by the banner (main._celebrate_level); this does not repeat it.
## With reduced motion the words fade in and out where they are, no burst.

const DURATION := 2.0
const IN := 0.25
const OUT := 0.5

var title: Label
var line: Label
## The card's rect (this control's coordinates) the burst rings.
var anchor := Rect2()
var from_level := 0
var to_level := 0
var _age := -1.0


func _init() -> void:
	name = "LevelUpFx"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	title = _label(34, Color("#ffe27a"))
	title.name = "Title"
	line = _label(24, Color.WHITE)
	line.name = "Line"
	add_child(title)
	add_child(line)
	visible = false


func _label(font_size: int, color: Color) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0.04, 0.12, 0.28, 0.95))
	l.add_theme_constant_override("outline_size", 10)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


## Shows `from` -> `to` at `card` (a rect in this control's coordinates).
func play(card: Rect2, from: int, to: int) -> void:
	if playing():
		# Still on screen: the newer level, from where it started.
		to_level = maxi(to_level, to)
	else:
		from_level = from
		to_level = to
	anchor = card
	title.text = tr("fx.level_up_title")
	line.text = tr("fx.level_up") % to_level if to_level - from_level <= 1 else tr("fx.level_range").format({"from": from_level, "to": to_level})
	_age = 0.0 if not playing() or _age > IN else _age
	visible = true
	_place()
	set_process(true)
	queue_redraw()


func playing() -> bool:
	return _age >= 0.0 and _age < DURATION


func _place() -> void:
	title.reset_size()
	line.reset_size()
	var w := maxf(title.size.x, line.size.x)
	# Left of the card, just under its line: the "+EXP" beside the card keeps
	# its own place, the side buttons below the card theirs.
	var right := anchor.position.x - 14.0
	var top := anchor.end.y - 6.0
	title.position = Vector2(right - w, top)
	title.size.x = w
	line.position = Vector2(right - w, top + title.size.y - 6.0)
	line.size.x = w
	for l: Label in [title, line]:
		l.pivot_offset = Vector2(l.size.x, l.size.y * 0.5)


func _ready() -> void:
	# Not in _init: entering the tree turns processing back on (AGENTS.md).
	set_process(false)


func _process(delta: float) -> void:
	# Idle until play(): `_age` counts only a show in progress.
	if _age < 0.0:
		set_process(false)
		return
	_age += delta
	if _age >= DURATION:
		_age = -1.0
		visible = false
		set_process(false)
		return
	var a := clampf(_age / IN, 0.0, 1.0) * clampf((DURATION - _age) / OUT, 0.0, 1.0)
	for l: Label in [title, line]:
		l.modulate.a = a
		if FxPrefs.moving():
			# A small overshoot as it arrives, then still.
			var k := clampf(_age / IN, 0.0, 1.0)
			var s := 1.0 + 0.35 * (1.0 - k) * (1.0 - k) - 0.06 * sin(k * PI)
			l.scale = Vector2(s, s)
		else:
			l.scale = Vector2.ONE
	queue_redraw()


func _draw() -> void:
	if not playing() or not FxPrefs.moving():
		return
	var c := anchor.get_center()
	var k := clampf(_age / 0.7, 0.0, 1.0)
	var fade := 1.0 - k
	var r0 := anchor.size.y * 0.55
	# The ring opens past the card.
	draw_arc(c, r0 + 60.0 * (1.0 - pow(1.0 - k, 2.0)), 0.0, TAU, 48, Color(1.0, 0.86, 0.35, 0.8 * fade), 4.0 * fade + 1.0, true)
	# Rays: short gold strokes flying out, every other one longer.
	for i in 12:
		var dir := Vector2.from_angle(TAU * i / 12.0 + 0.2)
		var stroke := (18.0 if i % 2 == 0 else 11.0) * fade
		var start := c + dir * (r0 + 70.0 * k)
		draw_line(start, start + dir * stroke, Color(1.0, 0.9, 0.5, fade), 3.0, true)
