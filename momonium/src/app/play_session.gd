class_name PlaySession
extends RefCounted

## Step 79: only the game on screen moves. The island's clock advances by the
## frames the player actually sees, and by nothing else -- not the time the
## game was closed, not the time its tab was hidden or the app was in the
## background (offline progression is off, design/OFFLINE79.md).
##
## Gone to the background (a hidden tab, `pagehide`, an app paused): `hide`.
## The composition root saves once; from then on `step` gives no game time,
## so buildings, Momo, ripening crops, research and the day stay exactly
## where they were, as time left to run. Back (`show`): the first frame after
## gives nothing either -- a browser hands the frame loop the whole hidden
## time as one delta -- and every frame after at most `max_frame` seconds
## (a stall or a hitch never jumps the island).
##
## Presentation-free and saved nowhere: only how the frame loop is driven.

## The game is on screen and its time runs.
var foreground := true
## The longest frame that counts in full (balance.session.max_frame_seconds).
var max_frame := 0.5
## How often it went to the background and came back, and how long it was
## away in all (wall seconds) -- for the tests and the browser bridge, never
## credited to the island.
var pauses := 0
var resumes := 0
var away_seconds := 0.0
var _hidden_at := 0.0
var _skip := false


## Gone to the background at wall time `wall` (seconds). True when that is a
## change (the caller saves then, once).
func hide(wall: float) -> bool:
	if not foreground:
		return false
	foreground = false
	pauses += 1
	_hidden_at = wall
	return true


## Back on screen at wall time `wall`. True when that is a change.
func show(wall: float) -> bool:
	if foreground:
		return false
	foreground = true
	resumes += 1
	away_seconds += maxf(wall - _hidden_at, 0.0)
	_skip = true
	return true


## The seconds of game time this frame advances (before the island's own
## time scale): none in the background or on the first frame back, else the
## frame's delta, at most `max_frame`.
func step(delta: float) -> float:
	if not foreground:
		return 0.0
	if _skip:
		_skip = false
		return 0.0
	return clampf(delta, 0.0, max_frame)
