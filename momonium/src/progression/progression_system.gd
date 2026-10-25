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


## EXP needed to leave the current level.
func next_level_exp() -> int:
	return exp_needed_for(level)


func exp_needed_for(at_level: int) -> int:
	var steps: Array = sim.data.get_value("balance", "progression.exp_to_next", [100])
	if at_level - 1 < steps.size():
		return int(steps[maxi(at_level - 1, 0)])
	var growth := sim.data.get_float("balance", "progression.growth", 1.3)
	return int(float(steps[-1]) * pow(growth, at_level - steps.size()))


func save_state() -> Dictionary:
	return {"level": level, "exp": experience}


func load_state(state: Dictionary) -> void:
	level = int(state.get("level", 1))
	experience = int(state.get("exp", 0))
