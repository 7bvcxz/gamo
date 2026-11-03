extends "res://tests/framework/test_case.gd"

## Step 94: C and E are the owner's picks, and each now grows an improved
## track (C+ `#rock-plus`, E+ `#tycoon-plus`). The baselines they are judged
## against must stay exactly what the owner played -- Step 88's C and Step
## 92's E as published in Lab 0.93.0 -- or every later comparison measures a
## moving target. Two locks: the baseline files byte for byte, and the
## numbers their own simulations give (the Step 93 report's three minutes).
## Changing a baseline on purpose means changing this file in the same
## commit and saying why in TRACKS.md.

const FROZEN := {
	"res://experiments/rock/rock.gd": "8490f3b37b4e2a70cf0752329a208452eea004cb07142ce45821346c4ae042b5",
	"res://experiments/rock/rock_levels.gd": "dbf736f4f85526f6c212c0439eba73a56e2aada6fb1fe4b9e71d8f226594fb80",
	"res://experiments/rock/rock_view.gd": "ce1afa6872a309f73b6d054e30b68f518dd0abc19cf9f9f95ba16b309d306a19",
	"res://experiments/tycoon/tycoon.gd": "47fc2a20c1e86ff10f9d0be7ee1a7efcb44e7255048d41505412668b9e1b968b",
	"res://experiments/tycoon/tycoon_levels.gd": "4f838234c282e6cb0d4f14465bbe179cb36c477ba01785203e8cbc31b6b20d46",
	"res://experiments/tycoon/tycoon_line.gd": "cbb1ec0385d87b3b0a496b6ffc6a4a98d328136048cdc2a6f62f01c2dc2704f3",
}


func test_the_baseline_files_are_frozen() -> void:
	for path: String in FROZEN:
		assert_eq(FileAccess.get_sha256(path), String(FROZEN[path]), "%s is the baseline the owner played" % path)


func test_c_baseline_numbers() -> void:
	# 2.5 taps a second, buying each pickaxe level when it can pay.
	var s := RockLevels.simulate(2.5, 180.0)
	assert_eq((s["breaks"] as Array).size(), 7, "seven rocks in three minutes")
	assert_eq((s["upgrades"] as Array).size(), 5, "five pickaxe levels")
	assert_near(float((s["breaks"] as Array)[0]), 20.0, 0.01, "the first break at 20 s")
	assert_near(float((s["upgrades"] as Array)[4]), 160.0, 0.01, "the fifth level at 160 s")
	assert_eq(int(s["coins"]), 180, "180 coins left")


func test_e_baseline_numbers() -> void:
	# Buying each improvement 1.5 s after it can pay, on the real line.
	var s := TycoonLevels.simulate(180.0, 1.5)
	assert_eq(int(s["level"]), 8, "Lv8 in three minutes")
	assert_eq(int(s["delivered"]), 182, "182 deliveries")
	assert_eq(int(s["spawned"]), 203, "203 items made")
	assert_near(float((s["upgrades"] as Array)[0]), 20.1, 0.01, "the first improvement at 20.1 s")


func test_the_tracks_start_from_their_baselines() -> void:
	for id: String in LabRegistry.track_ids():
		var base := LabRegistry.base_of(id)
		assert_true(LabRegistry.has(base), "%s grows from %s, one of the six" % [id, base])
		var script: GDScript = load(LabRegistry.script_path(id))
		var inst: Object = script.new()
		assert_true(inst is LabExperiment, "%s runs a LabExperiment" % id)
		(inst as Node).free()
