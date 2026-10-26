class_name ExpBar
extends Bar

## The level's progress in the HUD (Step 54): a gold bar that fills to the
## exact share of this level's EXP (experience / experience needed for the
## next level, both from ProgressionSystem -- never a number of its own).
##
## It moves rather than jumps: a gain slides the fill up; a level crossed runs
## it to the end, empties it and fills to where the new level stands -- once
## per level gained, up to three, so a batch of levels reads as levels, not as
## one long slide. With reduced motion, after a load and on the first show it
## is set at once. `level` and `target` are what it shows (tests).

const SLIDE := 0.35
const WRAP := 0.22
const MAX_WRAPS := 3

## The level the bar stands for, and the share it is heading to.
var level := 0
var target := 0.0
var _tween: Tween


func _init(p_fill: Color = Color("#ffd34d")) -> void:
	super(p_fill)
	custom_minimum_size = Vector2(150, 12)


## The share of a level `exp` stands for when `need` reaches the next.
static func fraction(exp: int, need: int) -> float:
	return clampf(float(exp) / float(need), 0.0, 1.0) if need > 0 else 1.0


## Shows `exp` of `need` at `p_level`; `animate` false sets it at once.
func show_progress(p_level: int, exp: int, need: int, animate: bool = true) -> void:
	var to := fraction(exp, need)
	if p_level == level and is_equal_approx(to, target):
		return
	var wraps := clampi(p_level - level, 0, MAX_WRAPS)
	var first := level == 0
	level = p_level
	target = to
	if _tween != null:
		_tween.kill()
		_tween = null
	if first or not animate or not FxPrefs.moving() or not is_inside_tree():
		value = to
		return
	_tween = create_tween()
	for i in wraps:
		_tween.tween_property(self, "value", 1.0, WRAP).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		_tween.tween_callback(func() -> void: value = 0.0)
	_tween.tween_property(self, "value", to, SLIDE).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


## Whether the fill is still on its way (tests wait for it).
func moving() -> bool:
	return _tween != null and _tween.is_valid() and _tween.is_running()


func _draw() -> void:
	super()
	# A soft highlight along the fill's top: the bar reads as a bar of gold,
	# not a flat stripe, on the navy pill.
	if value > 0.0:
		var w := maxf(size.x * value, size.y)
		var hi := Rect2(Vector2(size.y * 0.3, 1.5), Vector2(maxf(w - size.y * 0.6, 0.0), size.y * 0.28))
		draw_rect(hi, Color(1, 1, 1, 0.35))
