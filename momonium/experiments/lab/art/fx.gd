class_name LabFx
extends Node2D

## Short flourishes on top of an experiment: rising numbers, a spray of coins
## that flies to the counter, a ring, a shake. Every one has a reduced-motion
## form that keeps the information (the number, the change) and drops the
## movement.

var reduced_motion := false
## Where coins fly to (the counter), in this node's coordinates.
var coin_target := Vector2(360, 120)
var font: Font


func _ready() -> void:
	z_index = 50
	font = ThemeDB.fallback_font if ThemeDB.get_project_theme() == null else ThemeDB.get_project_theme().default_font
	if font == null:
		font = ThemeDB.fallback_font


## A number or word rising from `at` and fading.
func float_text(at: Vector2, text: String, color: Color = Color.WHITE, size: int = 40) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0.1, 0.16, 0.24, 0.9))
	l.add_theme_constant_override("outline_size", 8)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(l)
	l.reset_size()
	l.position = at - l.size * 0.5
	var tw := l.create_tween()
	if reduced_motion:
		tw.tween_interval(0.6)
	else:
		l.scale = Vector2(0.6, 0.6)
		l.pivot_offset = l.size * 0.5
		tw.set_parallel(true)
		tw.tween_property(l, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(l, "position:y", l.position.y - 70.0, 0.9).set_ease(Tween.EASE_OUT)
		tw.set_parallel(false)
	tw.tween_property(l, "modulate:a", 0.0, 0.3)
	tw.tween_callback(l.queue_free)
	return l


## `count` coins spraying out of `at` and flying to the counter.
func coins(at: Vector2, count: int, sprite: String = "icon_coin") -> void:
	if reduced_motion or count <= 0:
		return
	var tex := LabAtlas.texture(sprite)
	var rng := RandomNumberGenerator.new()
	rng.seed = int(at.x * 31.0 + at.y * 17.0) + count
	for i in mini(count, 18):
		var s := Sprite2D.new()
		s.texture = tex
		s.scale = Vector2.ONE * 0.32
		s.position = at
		add_child(s)
		var out := at + Vector2(rng.randf_range(-130, 130), rng.randf_range(-150, -40))
		var tw := s.create_tween()
		tw.tween_property(s, "position", out, 0.28 + rng.randf() * 0.12).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
		tw.tween_interval(0.05 + 0.03 * i)
		tw.tween_property(s, "position", coin_target, 0.42).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
		tw.parallel().tween_property(s, "scale", Vector2.ONE * 0.2, 0.42)
		tw.tween_callback(s.queue_free)


## A ring spreading from `at` (an upgrade, a break).
func ring(at: Vector2, color: Color = Color(1, 0.95, 0.6), radius: float = 160.0) -> void:
	if reduced_motion:
		return
	var r := _Ring.new()
	r.position = at
	r.color = color
	r.radius = radius
	add_child(r)


## Shakes `node` for a moment (its position comes back exactly).
func shake(node: Node2D, amount: float = 8.0, seconds: float = 0.18) -> void:
	if reduced_motion or node == null:
		return
	var home := node.position
	if node.has_meta("lab_shake_home"):
		home = node.get_meta("lab_shake_home")
	node.set_meta("lab_shake_home", home)
	var tw := node.create_tween()
	var steps := 5
	for i in steps:
		var k := 1.0 - float(i) / steps
		tw.tween_property(node, "position", home + Vector2((amount if i % 2 == 0 else -amount) * k, amount * 0.3 * k), seconds / steps)
	tw.tween_property(node, "position", home, 0.03)
	tw.tween_callback(func() -> void: node.remove_meta("lab_shake_home"))


class _Ring extends Node2D:
	var color := Color.WHITE
	var radius := 160.0
	var t := 0.0

	func _process(delta: float) -> void:
		t += delta / 0.55
		if t >= 1.0:
			queue_free()
			return
		queue_redraw()

	func _draw() -> void:
		var e := 1.0 - pow(1.0 - t, 3.0)
		draw_arc(Vector2.ZERO, radius * e, 0.0, TAU, 48, Color(color, 1.0 - t), 10.0 * (1.0 - t) + 2.0)
