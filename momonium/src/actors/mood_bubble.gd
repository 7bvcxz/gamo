class_name MoodBubble
extends Sprite2D

## The one small mood over a Momo's head (Step 48): a little speech bubble
## with a heart, three dots, a question mark or a sweat drop -- what MomoMood
## reads from the job rules. Shown sparingly, never as a status line:
##
##   - a reason must hold SETTLE seconds before it shows (between two stages
##     of the same job there is a moment with no job -- that is not a mood);
##   - it shows for a few seconds, then rests before the same mood may come
##     back (AGAIN), so a worker waiting all afternoon is not a lit sign;
##   - it goes at once when the Momo starts working or walking, and makes way
##     for the letter a Momo holds up (one thing over a head at a time);
##   - it appears and leaves calmly (a fade and a small rise; a fade only with
##     reduced motion), and it is a sprite: it takes no taps or drags.
##
## Driven by its MomoActor (no per-frame code of its own); asks the rules a
## few times a second, only while the Momo is on screen.

const CHECK_SECONDS := 0.25
const SETTLE := 1.5
const SHOW := {"content": 3.0, "thinking": 4.0, "confused": 6.0, "worried": 6.0}
const AGAIN := {"content": 30.0, "thinking": 16.0, "confused": 10.0, "worried": 10.0}
const FADE_RATE := 4.0
## Above the head, a little to the right (the letter goes on the left).
const ANCHOR := Vector2(22, -96)

## The mood on show ("" when none) and why, for tests and the E2E bridge.
var mood := ""
var why := ""
## What the rules say now, before settling.
var wanted := ""
var shown_count := 0

var _lib: SpriteLibrary
var _t := 0.0
var _check := 0.0
var _since := 0.0
var _shown_for := 0.0
var _next_ok := {}
var _alpha := 0.0


func setup(lib: SpriteLibrary) -> void:
	_lib = lib
	name = "Mood"
	centered = true
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	visible = false
	modulate.a = 0.0


## One step. `reason` is MomoMood.reason now (asked by the actor every
## CHECK_SECONDS); `held` when something else is over the head or the Momo
## is being dragged.
func step(delta: float, reason: String, held: bool, head: Vector2) -> void:
	_t += delta
	var want := String(MomoMood.MOODS.get(reason, ""))
	if want != wanted:
		wanted = want
		_since = _t
	if mood != "":
		_shown_for += delta
		var over := _shown_for >= float(SHOW.get(mood, 4.0))
		if want != mood or held or over:
			# However it ends, the same mood rests before it may show again:
			# a worker between jobs all afternoon is not a blinking sign.
			_next_ok[mood] = _t + float(AGAIN.get(mood, 10.0))
			mood = ""
			why = ""
	elif want != "" and not held and _t - _since >= SETTLE and _t >= float(_next_ok.get(want, 0.0)):
		mood = want
		why = reason
		_shown_for = 0.0
		shown_count += 1
		_lib.place(self, "mood_" + mood, "center")
		centered = false
	var target := 1.0 if mood != "" else 0.0
	_alpha = move_toward(_alpha, target, delta * FADE_RATE)
	visible = _alpha > 0.01
	if not visible:
		return
	modulate.a = _alpha
	var lift := 0.0
	if FxPrefs.moving():
		lift = (1.0 - _alpha) * 8.0 + sin(_t * 2.0) * 1.2
	position = head + ANCHOR + Vector2(0, lift)


## Whether the rules should be asked again this step.
func due(delta: float) -> bool:
	_check -= delta
	if _check > 0.0:
		return false
	_check = CHECK_SECONDS
	return true
