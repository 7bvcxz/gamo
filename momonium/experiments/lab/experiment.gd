class_name LabExperiment
extends Control

## Base of every experiment. The host gives it a session, the sound, the
## flourishes layer and the reduced-motion choice, adds it under the frame and
## then drives it:
##   tick(dt)       play-time seconds (stops while the page is hidden or
##                  unfocused; never more than LabHost.MAX_STEP at once)
##   hud()          the one visible resource: {value, rate, icon}
##   action_info()  the one button: {label, cost, affordable, icon (an atlas
##                  sprite) or texture, tint}; {} hides it
##   do_action()    the button was pressed (the host already recorded the press)
##   state()        what tests and window.funlab read
##   dev(name, arg) test hooks (window.funlab.call("dev_*") in dev or E2E runs)
##   intent_question()  what the card at three minutes of play asks
## An experiment keeps all its state in itself: Restart throws it away and
## builds a new one, so no two runs share anything.

var session: LabSession
var audio: LabAudio
var fx: LabFx
var reduced_motion := false
## Tells the host the button's label or cost changed (it reads action_info()).
signal action_changed


func tick(_dt: float) -> void:
	pass


func hud() -> Dictionary:
	return {}


func action_info() -> Dictionary:
	return {}


func do_action() -> void:
	pass


func state() -> Dictionary:
	return {}


func dev(_name: String, _arg: Variant) -> Variant:
	return null


## What the three-minute card asks (LabHost.INTENT_AT_MS).
func intent_question() -> String:
	return "Keep playing?"


## A point of this experiment in the flourishes layer's coordinates.
func to_fx(global_point: Vector2) -> Vector2:
	return fx.get_global_transform().affine_inverse() * global_point if fx != null else global_point
