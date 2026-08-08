extends Node2D

## The whole game, because the whole game is one question: does the moment
## between the signal and your finger feel good enough to want again?
##
## Everything here is shapes and colour. The POC is not asking whether the art
## works, and a rectangle in the right place at the right time answers the
## question just as well as a drawing would.

enum State { TITLE, DUEL, RESULT, MATCH_OVER }

## The duel is two moments, not one, and they want different code: before the
## signal nothing may happen, after it everything is decided in milliseconds.
enum Phase { STEADY, SIGNAL }

## Who won and how. RESULT needs to say more than "you won" -- the reaction time
## is the score, and without it there is nothing to beat next round.
enum Outcome { NONE, PLAYER, RIVAL, FOUL }

const W := 960.0
const H := 540.0

## Where the two figures stand. The duel reads left-to-right, so the player is
## on the left where a reader's eye starts.
const PLAYER_X := 250.0
const RIVAL_X := 710.0
const GROUND_Y := 360.0

# The desert at dusk: warm ground, cold sky, one hot accent for the signal.
const SKY := Color("#2b1b2e")
const SUN := Color("#c9663a")
const SAND := Color("#3c2a25")
const PLAYER_COL := Color("#7fd4e8")
const RIVAL_COL := Color("#e8574c")
const INK := Color("#f2e9dd")
const DIM := Color("#8a7a70")
const ALERT := Color("#ffd166")

## The wait, in seconds. The range is the whole design: too narrow and the hand
## learns the rhythm and stops being surprised, too wide and the player stops
## paying attention before it arrives. Two to six is long enough that counting
## does not help and short enough to stay taut.
const WAIT_MIN := 2.0
const WAIT_MAX := 6.0

## The rival's reaction, in milliseconds, one per difficulty.
##
## These are picked against human reaction times rather than for round numbers.
## A person's simple visual reaction is roughly 200-250ms and practice pulls it
## toward 180. So 420 is beatable while you are still learning what the signal
## looks like, 300 needs attention, and 200 is at the edge of what a human does
## at all -- it should feel like the rival is barely losing, or barely winning.
## How long the muzzle flash lasts and how long the fall takes, in seconds. The
## flash is brief enough to read as an instant and the fall is slow enough to
## watch, which is the whole difference between "you lost" and "you were shot".
const FLASH_S := 0.12
const FALL_S := 0.55

const RIVAL_MS: Array[int] = [420, 300, 200]
const DIFFICULTY_NAME: Array[String] = ["GREENHORN", "OUTLAW", "LEGEND"]

var state: State = State.TITLE
var phase: Phase = Phase.STEADY
var font: Font

## Seconds still to wait, counted down in _process. Time and not frames: the
## whole game is a stopwatch and a frame count is not one.
var wait_left: float = 0.0
## When the signal fired, on the system clock, for the reaction time that the
## next condition will show.
var signal_at_ms: int = 0
## Milliseconds from DRAW! to each side's shot. -1 means they never fired.
var player_ms: int = -1
var difficulty: int = 1
var rival_ms: int = RIVAL_MS[1]
var outcome: Outcome = Outcome.NONE
## Seconds since the round was decided, which drives the staging: the flash, the
## fall, and the delay before the result text arrives.
var result_t: float = 0.0

## Rounds won. First to WINS_NEEDED takes the match, so a single unlucky draw --
## or one lucky one -- does not decide anything. Best of three is the shortest
## format in which losing the first round is still a game.
const WINS_NEEDED := 2
var player_wins: int = 0
var rival_wins: int = 0

func _ready() -> void:
	font = ThemeDB.fallback_font
	set_process_unhandled_input(true)

## Counts the wait down and fires the signal. Nothing else in the duel moves, on
## purpose -- the stillness is what makes the cut to DRAW! land.
func _process(delta: float) -> void:
	if state == State.RESULT:
		result_t += delta
		queue_redraw()
		return
	if state != State.DUEL:
		return
	# Both halves of the duel run here, and the first version returned early on
	# anything but STEADY -- which meant that the moment the signal fired the
	# rival stopped being ticked and a player who simply never pressed waited
	# forever. The bug only shows if you do nothing, which is exactly the case a
	# person testing by playing never tries.
	if phase == Phase.STEADY:
		wait_left -= delta
		if wait_left <= 0.0:
			phase = Phase.SIGNAL
			signal_at_ms = Time.get_ticks_msec()
	else:
		_tick_rival()
	queue_redraw()

## The rival is a stopwatch, not an opponent: it fires at a fixed delay after the
## signal. Checked every frame while the signal is up, so a player who is slower
## than the delay loses without having to press anything.
func _tick_rival() -> void:
	if state != State.DUEL or phase != Phase.SIGNAL or outcome != Outcome.NONE:
		return
	if _since_signal() >= rival_ms:
		_settle(Outcome.RIVAL)

## Milliseconds since DRAW!, on the system clock. Not a frame count: at 60fps a
## frame is 17ms, which is a third of the gap between a fast draw and a slow one,
## and rounding the score to that would throw away the thing being measured.
func _since_signal() -> int:
	return Time.get_ticks_msec() - signal_at_ms

func _settle(who: Outcome) -> void:
	outcome = who
	if who == Outcome.PLAYER:
		player_wins += 1
	else:
		# A foul counts for the rival. Losing the round is the whole point of the
		# rule; making it cost nothing in the match would undo it.
		rival_wins += 1
	state = State.RESULT
	result_t = 0.0
	queue_redraw()

func _match_done() -> bool:
	return player_wins >= WINS_NEEDED or rival_wins >= WINS_NEEDED

func _begin_match() -> void:
	player_wins = 0
	rival_wins = 0
	_begin_duel()

## A fresh wait, drawn per round so no two rounds are the same length.
func _begin_duel() -> void:
	state = State.DUEL
	phase = Phase.STEADY
	wait_left = randf_range(WAIT_MIN, WAIT_MAX)
	rival_ms = RIVAL_MS[difficulty]
	signal_at_ms = 0
	player_ms = -1
	outcome = Outcome.NONE

func _unhandled_input(event: InputEvent) -> void:
	# One verb for the whole game. Press is what a duel is made of, so the
	# release half of an event is never interesting here.
	if not _is_press(event):
		return
	get_viewport().set_input_as_handled()
	# Number keys pick the rival on the title screen and nowhere else -- during a
	# duel every key is the trigger, and a key that quietly did something else
	# would be a foul the player did not understand.
	if state == State.TITLE and event is InputEventKey:
		var picked: int = _difficulty_key(event as InputEventKey)
		if picked >= 0:
			difficulty = picked
			queue_redraw()
			return
	_advance()

func _difficulty_key(key: InputEventKey) -> int:
	match key.keycode:
		KEY_1: return 0
		KEY_2: return 1
		KEY_3: return 2
	return -1

## Any of the three ways a person might play this. Touch is listed because the
## goal calls for it and because a phone is where a reaction game belongs.
func _is_press(event: InputEvent) -> bool:
	if event is InputEventScreenTouch:
		return event.pressed
	if event is InputEventMouseButton:
		return event.pressed
	if event is InputEventKey:
		return event.pressed and not event.echo
	return false

func _advance() -> void:
	match state:
		State.TITLE:
			_begin_match()
		State.DUEL:
			# Drawing early loses on the spot. This is what makes the wait cost
			# something: without it the winning strategy is to mash from the
			# first frame, and a game you can win without watching is not a
			# reaction game.
			if phase == Phase.STEADY:
				_settle(Outcome.FOUL)
			elif phase == Phase.SIGNAL and outcome == Outcome.NONE:
				player_ms = _since_signal()
				# Whoever is quicker wins, and the rival's clock is still running
				# in _process, so a tie on the same frame goes to the player.
				_settle(Outcome.PLAYER if player_ms <= rival_ms else Outcome.RIVAL)
		State.RESULT:
			# The match ends on its own screen rather than rolling straight into
			# another round, so winning it is an event and not just a score that
			# happened to tick over.
			if _match_done():
				state = State.MATCH_OVER
			else:
				_begin_duel()
		State.MATCH_OVER:
			_begin_match()
	queue_redraw()

func _draw() -> void:
	_draw_scene()
	match state:
		State.TITLE:
			_draw_title()
		State.DUEL:
			_draw_duel()
		State.RESULT:
			_draw_result()
		State.MATCH_OVER:
			_draw_match_over()

## The standoff itself, drawn the same in every state so that changing state
## never moves the world. The tension is supposed to come from waiting, and a
## background that jumps would spend it.
func _draw_scene() -> void:
	draw_rect(Rect2(0.0, 0.0, W, H), SKY)
	draw_circle(Vector2(W * 0.5, GROUND_Y - 40.0), 110.0, SUN)
	draw_rect(Rect2(0.0, GROUND_Y, W, H - GROUND_Y), SAND)
	# Only the result stages a fall; every other screen shows both standing.
	var player_fall: float = 0.0
	var rival_fall: float = 0.0
	if state == State.RESULT:
		var f: float = clampf((result_t - FLASH_S) / FALL_S, 0.0, 1.0)
		if outcome == Outcome.PLAYER:
			rival_fall = f
		else:
			player_fall = f
	_draw_figure(PLAYER_X, PLAYER_COL, player_fall)
	_draw_figure(RIVAL_X, RIVAL_COL, rival_fall)
	if state == State.RESULT:
		_draw_shot()

## A gunslinger: hat, head, body, legs. Four shapes is enough to read as a person
## standing ready, which is all this needs to be.
##
## `fall` from 0 to 1 drops and tips the figure. Rotating the draw transform
## about the feet rather than moving each shape means the pose stays a pose --
## the figure pivots on the ground the way a body does, instead of sliding.
func _draw_figure(x: float, colour: Color, fall: float = 0.0) -> void:
	var body_top: float = GROUND_Y - 96.0
	if fall > 0.0:
		draw_set_transform(Vector2(x, GROUND_Y), -PI * 0.5 * fall, Vector2.ONE)
		draw_rect(Rect2(-18.0, body_top - GROUND_Y, 36.0, 62.0), colour)
		draw_rect(Rect2(-10.0, -34.0, 8.0, 34.0), colour)
		draw_rect(Rect2(2.0, -34.0, 8.0, 34.0), colour)
		draw_circle(Vector2(0.0, body_top - GROUND_Y - 16.0), 14.0, colour)
		draw_rect(Rect2(-26.0, body_top - GROUND_Y - 30.0, 52.0, 7.0), colour.darkened(0.35))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		return
	draw_rect(Rect2(x - 18.0, body_top, 36.0, 62.0), colour)
	draw_rect(Rect2(x - 10.0, GROUND_Y - 34.0, 8.0, 34.0), colour)
	draw_rect(Rect2(x + 2.0, GROUND_Y - 34.0, 8.0, 34.0), colour)
	draw_circle(Vector2(x, body_top - 16.0), 14.0, colour)
	draw_rect(Rect2(x - 26.0, body_top - 30.0, 52.0, 7.0), colour.darkened(0.35))

func _draw_title() -> void:
	_centred("GUNSLINGER", 150.0, 56, INK)
	_centred("one shot decides it", 190.0, 20, DIM)
	# Difficulty is chosen here rather than buried in a menu: it is one line, it
	# is the only setting, and a POC that hides its variable makes it unused.
	_centred("%s   ·   draws in %d ms" % [DIFFICULTY_NAME[difficulty], RIVAL_MS[difficulty]],
		250.0, 26, ALERT)
	_centred("1 / 2 / 3 to choose", 284.0, 18, DIM)
	_centred("press anything else to face him", H - 60.0, 22, INK)

func _draw_duel() -> void:
	if phase == Phase.STEADY:
		_centred("steady...", 150.0, 34, DIM)
		return
	# Loud, and covering ground the quiet state never touches, so it registers
	# in peripheral vision rather than needing to be read.
	draw_rect(Rect2(0.0, 96.0, W, 96.0), ALERT)
	_centred("DRAW!", 168.0, 76, SKY)

## The shot itself: a line from the winner's hip to the loser, and a flash at the
## muzzle. A foul has no shot -- nobody fired, the player just moved too soon,
## and drawing a bullet would be telling the wrong story.
func _draw_shot() -> void:
	if outcome == Outcome.FOUL or result_t > FLASH_S:
		return
	var winner_x: float = PLAYER_X if outcome == Outcome.PLAYER else RIVAL_X
	var loser_x: float = RIVAL_X if outcome == Outcome.PLAYER else PLAYER_X
	var y: float = GROUND_Y - 52.0
	var muzzle: float = winner_x + (18.0 if outcome == Outcome.PLAYER else -18.0)
	draw_line(Vector2(muzzle, y), Vector2(loser_x, y), ALERT, 3.0)
	draw_circle(Vector2(muzzle, y), 11.0, ALERT)

func _draw_result() -> void:
	# The text waits for the staging. Announcing the result over the top of the
	# shot throws away the half second that makes it land.
	if result_t < FLASH_S + FALL_S * 0.6:
		return
	var won: bool = outcome == Outcome.PLAYER
	_centred("YOU WIN" if won else "YOU LOSE", 140.0, 52, PLAYER_COL if won else RIVAL_COL)
	# The number is the point. A duel you won by 12ms and one you won by 200ms
	# are different duels, and only this line can tell them apart. A foul has no
	# number to show and says why instead.
	if outcome == Outcome.FOUL:
		_centred("drew too early", 190.0, 26, RIVAL_COL)
	elif player_ms >= 0:
		_centred("%d ms   ·   rival %d ms" % [player_ms, rival_ms], 190.0, 24, INK)
	else:
		_centred("too slow   ·   rival %d ms" % rival_ms, 190.0, 24, DIM)
	_centred("%d - %d" % [player_wins, rival_wins], 240.0, 34, INK)
	_centred("press to draw again" if not _match_done() else "press to see the match",
		H - 60.0, 22, INK)

func _draw_match_over() -> void:
	var won: bool = player_wins >= WINS_NEEDED
	_centred("MATCH WON" if won else "MATCH LOST", 140.0, 54, PLAYER_COL if won else RIVAL_COL)
	_centred("%d - %d   ·   %s" % [player_wins, rival_wins, DIFFICULTY_NAME[difficulty]],
		192.0, 26, INK)
	_centred("press for a new match", H - 60.0, 22, INK)

## Text centred by measuring it rather than by guessing an offset, so a longer
## string stays centred instead of drifting left.
func _centred(text: String, y: float, size: int, colour: Color) -> void:
	var width: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, size).x
	draw_string(font, Vector2((W - width) * 0.5, y), text,
		HORIZONTAL_ALIGNMENT_LEFT, -1.0, size, colour)
