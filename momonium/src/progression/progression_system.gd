class_name ProgressionSystem
extends SimSystem

## Player level and experience. Thresholds and building mastery arrive with
## Step 16; this holds the starting values the rules promise (Level 1, 0 EXP).

var level: int = 1
var experience: int = 0


func _init() -> void:
	key = &"progression"


func on_new_game() -> void:
	level = sim.data.get_int("balance", "start.level", 1)
	experience = sim.data.get_int("balance", "start.exp")


func save_state() -> Dictionary:
	return {"level": level, "exp": experience}


func load_state(state: Dictionary) -> void:
	level = int(state.get("level", 1))
	experience = int(state.get("exp", 0))
