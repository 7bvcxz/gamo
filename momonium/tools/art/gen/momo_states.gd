extends Node2D

## Step 46: Momo's rig in every state side by side, magnified, on a grass
## swatch -- the close-up for the art contact sheet. Capture with
##   tools/capture.gd -- --scene res://tools/art/gen/momo_states.tscn --size 720x1280
## (a 3x2 grid in the game's 720x1280 base resolution).

const STATES := [["idle", 0.4], ["walk", 0.12], ["sit", 0.3], ["sleep", 0.3], ["work", 0.2], ["back", 0.3]]
const ZOOM := 3.2


func _ready() -> void:
	var lib := SpriteLibrary.load_atlas()
	for i in STATES.size():
		var rig := MomoRig.new()
		rig.position = Vector2(125 + (i % 3) * 235, 560 + (i / 3) * 420)
		rig.scale = Vector2.ONE * ZOOM
		add_child(rig)
		rig.setup(lib, 7)
		rig.set_process(false)
		var st: String = STATES[i][0]
		if st == "back":
			rig.face(Vector2(0.3, -1))
			rig.set_state("idle")
		else:
			rig.set_state(st)
		rig.time = 0.0
		rig.blinking = false
		rig.tick(float(STATES[i][1]))
		# The rig mirrors on face(); keep the zoom on top of it.
		rig.scale = Vector2(signf(rig.scale.x) * ZOOM, ZOOM)


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, get_viewport_rect().size), Color("#dff0fb"))
	for row in 2:
		draw_rect(Rect2(0, 520 + row * 420, get_viewport_rect().size.x, 90), Color("#9cc94a"))
