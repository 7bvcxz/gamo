extends Node2D

## Developer view of the Momo rig: every state, front and back, and walking
## both ways, at a readable size. Capture it with tools/capture.gd.

var rigs: Array[MomoRig] = []


func _ready() -> void:
	var lib := SpriteLibrary.load_atlas()
	var specs := [["idle", Vector2(1, 1)], ["walk", Vector2(1, 1)], ["sit", Vector2(1, 1)], ["sleep", Vector2(1, 1)],
		["idle", Vector2(1, -1)], ["walk", Vector2(-1, -1)], ["walk", Vector2(-1, 1)], ["idle", Vector2(-1, 1)]]
	for i in specs.size():
		var rig := MomoRig.new()
		rig.setup(lib, i)
		rig.set_state(specs[i][0])
		rig.face(specs[i][1])
		rig.position = Vector2(110 + (i % 4) * 170, 230 + (i / 4) * 230)
		rig.scale *= 2.2
		add_child(rig)
		rigs.append(rig)
		rig.tick(0.37 + i * 0.11)


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, get_viewport_rect().size), Color("#cfe8c2"))
