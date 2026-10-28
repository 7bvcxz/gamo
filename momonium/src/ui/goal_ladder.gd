class_name GoalLadder
extends Control

## Step 72: the road from Village to Civilization in one thin strip on the
## Status tab -- a dot for every step, joined by a line. Reached steps are gold
## and named, the current one is a ring and named, the ones beyond are a faint
## star with no name: far away, and not told before their time.

var goals: GoalSystem
## [{id, state}] as drawn (GoalSystem.steps).
var shown: Array[Dictionary] = []

const DOT := 7.0
const GOLD := Color("#ffd166")


func setup(p_goals: GoalSystem) -> void:
	goals = p_goals
	name = "GoalLadder"
	custom_minimum_size = Vector2(0, 46)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)


func refresh() -> void:
	var now := goals.steps()
	if str(now) != str(shown):
		shown = now
		queue_redraw()


## Where step `i` sits: evenly across the strip.
func step_at(i: int) -> Vector2:
	var n := maxi(shown.size(), 1)
	return Vector2(size.x * (i + 0.5) / n, 12.0)


func _draw() -> void:
	if shown.is_empty():
		return
	var ink := get_theme_color("font_color", "Label")
	var faint := Color(ink, 0.25)
	for i in range(1, shown.size()):
		var done := String(shown[i]["state"]) == "done"
		draw_line(step_at(i - 1) + Vector2(DOT + 2, 0), step_at(i) - Vector2(DOT + 2, 0), Color(GOLD, 0.8) if done else faint, 2.0, true)
	var font := get_theme_default_font()
	for i in shown.size():
		var at := step_at(i)
		var state := String(shown[i]["state"])
		match state:
			"done":
				draw_circle(at, DOT, GOLD)
			"current":
				draw_arc(at, DOT, 0, TAU, 24, GOLD, 2.5, true)
			_:
				_star(at, DOT, faint)
		if state != "ahead":
			var text := tr(_name_key(String(shown[i]["id"])))
			var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
			var x := clampf(at.x - w * 0.5, 0.0, maxf(size.x - w, 0.0))
			draw_string(font, Vector2(x, at.y + DOT + 16), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, ink if state == "current" else Color(ink, 0.7))


func _star(at: Vector2, r: float, color: Color) -> void:
	var pts := PackedVector2Array()
	for k in 11:
		var a := -PI / 2 + k * PI / 5
		var rr := r if k % 2 == 0 else r * 0.45
		pts.append(at + Vector2(cos(a), sin(a)) * rr)
	draw_polyline(pts, color, 1.5, true)


static func _name_key(id: String) -> String:
	return "tier." + id if TierSystem.NAMES.has(id) else "goal." + id
