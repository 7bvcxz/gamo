class_name UiLayers
extends RefCounted

## Step 82 (design/LAYERS82.md): the one table of what draws over what, and
## so what a finger reaches first. Bottom to top:
##
##   1. BACKGROUND  the ocean (its own CanvasLayer).
##   2. WORLD       the island, buildings and Momo on the default canvas,
##                  sorted by depth among themselves (Step 55/76).
##   3. world marks the selection, Schedule tiles, sea for sale, the player's
##                  hands at work (Step 83), effects: in
##                  the world, above the entities by the Z_* below -- never
##                  over any UI, which is a CanvasLayer above the world.
##   4. Context     controls about something in the world: the Schedule
##                  button, the building card, the build strip, the camera
##                  buttons.
##      Announce    passing news over the island: level-up, banners.
##   5. Panels      Settings, Research, Status, Shop, Mail, details...
##      Hud         the corner and side buttons, Hire's menu: over the
##                  panels' scrim, so they stay usable beside an open panel
##                  (the cards keep clear of them, Step 81).
##      Guide       the tutorial and tips.
##   6. MODAL       blocking confirmations (Reset All Data): their own
##                  CanvasLayer above everything, the HUD included.
##
## While a panel or a modal is open the game is busy: Context, Announce and
## Guide are hidden (nothing about the world shows over or around a panel),
## and the island takes no input (InputRouter.blocked). Closing it gives both
## back -- the selection and the Schedule are kept, not dropped.
##
## A new piece of UI picks its tier here; it does not get a z_index of its own.

## CanvasLayer numbers.
const BACKGROUND := -10
const WORLD := 0
const UI := 1
const MODAL := 90

## z_index inside the world, above the depth-sorted entities (z 0).
const Z_LAND_PREVIEW := 30
## The player's hands at work (Step 83): over the buildings, under the pops.
const Z_HANDS := 35
const Z_FX := 40
const Z_ROUTE := 50

## The UI's tiers, bottom to top: the UI root's children in this order.
const TIERS: PackedStringArray = ["Context", "Announce", "Panels", "Hud", "Guide"]
## Hidden while the game is busy (a panel or a modal open).
const HIDDEN_WHEN_BUSY: PackedStringArray = ["Context", "Announce", "Guide"]


## Builds the tiers under `root` (full-screen Controls that take no input of
## their own and pass the root's theme on): -> {name: Control}.
static func build(root: Control) -> Dictionary:
	var out := {}
	for tier_name: String in TIERS:
		var t := Control.new()
		t.name = tier_name
		t.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		t.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root.add_child(t)
		out[tier_name] = t
	return out


## Shows or hides the tiers that give way to a panel.
static func set_busy(tiers: Dictionary, busy: bool) -> void:
	for tier_name: String in HIDDEN_WHEN_BUSY:
		(tiers[tier_name] as Control).visible = not busy
