extends RefCounted
class_name WorldProgress

## The one ring for everything in the world that takes a moment.
##
## The fire making a tool, her swing at a seam, the case being searched, ice
## letting go, a wreck coming apart -- each is "something is happening here, and
## it is this far along", and each is answered in the same place with the same
## picture: a ring that closes over the thing doing the work. The screen says
## nothing about it; the world does. That is the division this game keeps -- the
## window says what to make, the world shows it being made.
##
## It began as `MachineLayer._progress_ring`, which still exists and calls this,
## so every caller that already drew a ring keeps drawing exactly the same one.
## What is new is the end: `complete` is the short pulse the ring leaves behind
## when it fills, so a make that finishes reads as finishing rather than as a
## ring that vanished.

const RADIUS := 16.0
const WIDTH := 3.0
const SEGMENTS := 32
## The track under the fill: dark enough to read over snow and over the fire.
const TRACK := Color(0.02, 0.04, 0.08, 0.55)

static func draw(canvas: CanvasItem, at: Vector2, fraction: float, tint: Color,
		radius: float = RADIUS, width: float = WIDTH) -> void:
	canvas.draw_arc(at, radius, 0.0, TAU, SEGMENTS, TRACK, width)
	canvas.draw_arc(at, radius, -PI * 0.5, -PI * 0.5 + TAU * clampf(fraction, 0.0, 1.0),
		SEGMENTS, tint, width, true)

## The ring is full: one pulse outward from where it was, a few sparks, and it is
## gone. Short on purpose -- it marks the moment, it does not hold the player.
static func complete(fx: FxLayer, at: Vector2, tint: Color, radius: float = RADIUS) -> void:
	if fx == null:
		return
	fx.ring(at, tint, radius + 12.0)
	fx.burst(at, tint, 8)
