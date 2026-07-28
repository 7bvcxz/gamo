extends Node2D
class_name MachineLayer

## Draws machines, the items flowing between them, and the build preview.

var sim: Sim
var view_rect := Rect2()
var preview_type: int = Defs.M_MINER
var preview_cell := Vector2i.ZERO
var preview_dir := Vector2i.RIGHT
var preview_valid := true
var preview_affordable := true
var pulse: float = 0.0

func _process(delta: float) -> void:
	pulse += delta
	queue_redraw()

func _draw() -> void:
	if sim == null:
		return
	var tile := float(Defs.TILE)
	# Belts first so machines and items always sit above them.
	for cell: Vector2i in sim.machines:
		var machine: Sim.Machine = sim.machines[cell]
		if machine.type != Defs.M_BELT:
			continue
		if not _visible(cell, tile):
			continue
		_draw_belt(machine, Vector2(cell) * tile, tile)
	for cell: Vector2i in sim.machines:
		var machine: Sim.Machine = sim.machines[cell]
		if machine.type == Defs.M_BELT:
			continue
		if not _visible(cell, tile):
			continue
		match machine.type:
			Defs.M_CORE: _draw_core(machine, Vector2(cell) * tile, tile)
			Defs.M_MINER: _draw_miner(machine, Vector2(cell) * tile, tile)
			Defs.M_FURNACE: _draw_furnace(machine, Vector2(cell) * tile, tile)
	for cell: Vector2i in sim.machines:
		var machine: Sim.Machine = sim.machines[cell]
		if machine.type != Defs.M_BELT or not _visible(cell, tile):
			continue
		_draw_belt_items(machine, Vector2(cell) * tile, tile)
	_draw_preview(tile)

func _visible(cell: Vector2i, tile: float) -> bool:
	return view_rect.grow(tile * 2.0).has_point(Vector2(cell) * tile + Vector2.ONE * tile * 0.5)

func _frost(machine: Sim.Machine) -> float:
	return 0.0 if sim.is_warm(machine.cell) else 0.45

func _draw_core(machine: Sim.Machine, px: Vector2, tile: float) -> void:
	var c: Vector2 = px + Vector2.ONE * tile * 0.5
	var beat: float = 1.0 + sin(pulse * 2.2) * 0.05 + machine.flash * 0.5
	# The core is the emotional centre of the run, so it is drawn large enough to
	# outrank the HUD clock in the visual hierarchy.
	draw_circle(c, 52.0 * beat, Color(1.0, 0.67, 0.31, 0.10))
	draw_circle(c, 38.0 * beat, Color(1.0, 0.67, 0.31, 0.16))
	draw_circle(c, 30.0, Defs.COL_MACHINE.darkened(0.4))
	draw_circle(c, 26.0, Defs.COL_CORE_DEEP)
	draw_circle(c, 18.0 * beat, Defs.COL_CORE)
	draw_circle(c, 10.0 * beat, Color("fff0c9"))
	for index in 10:
		var angle: float = TAU * float(index) / 10.0 + pulse * 0.25
		draw_circle(c + Vector2.from_angle(angle) * 33.0, 2.6, Defs.COL_BRASS)
	draw_arc(c, 44.0, 0.0, TAU, 64, Color(1.0, 0.69, 0.36, 0.30 + machine.flash), 2.0, true)

func _draw_miner(machine: Sim.Machine, px: Vector2, tile: float) -> void:
	var c: Vector2 = px + Vector2.ONE * tile * 0.5
	var frost: float = _frost(machine)
	var fur: Color = Defs.COL_CAT_FUR.lerp(Color("7f93b8"), frost)
	var face: Color = Defs.COL_CAT_FACE.lerp(Color("aebdd6"), frost)
	var work: float = clampf(machine.progress / Defs.MINER_PERIOD, 0.0, 1.0)
	var dig: float = sin(pulse * 9.0) * 1.6 * (1.0 - frost)

	draw_circle(c + Vector2(0, 9), 10.0, Color(0.02, 0.04, 0.08, 0.32))
	# Body then head: a chunky silhouette survives being 32px tall.
	draw_rect(Rect2(c.x - 9, c.y - 3 + dig, 18, 12), fur)
	draw_circle(c + Vector2(0, -6 + dig), 8.0, fur)
	draw_circle(c + Vector2(0, -5 + dig), 5.5, face)
	# Ears.
	draw_colored_polygon(PackedVector2Array([
		c + Vector2(-8, -10 + dig), c + Vector2(-4, -15 + dig), c + Vector2(-2, -9 + dig)]), fur)
	draw_colored_polygon(PackedVector2Array([
		c + Vector2(8, -10 + dig), c + Vector2(4, -15 + dig), c + Vector2(2, -9 + dig)]), fur)
	draw_circle(c + Vector2(-2, -6 + dig), 1.1, Color("2b2030"))
	draw_circle(c + Vector2(2, -6 + dig), 1.1, Color("2b2030"))
	# Output direction and a progress arc, so throughput is legible at a glance.
	var tip: Vector2 = c + Vector2(machine.dir) * 15.0
	draw_circle(tip, 2.6, Defs.COL_BRASS)
	draw_arc(c, 13.0, -PI * 0.5, -PI * 0.5 + TAU * work, 22, Color(1, 1, 1, 0.5), 2.0, true)
	if machine.flash > 0.0:
		draw_circle(c, 15.0 + machine.flash * 12.0, Color(1, 1, 1, machine.flash * 0.5), false, 2.0)

func _draw_furnace(machine: Sim.Machine, px: Vector2, tile: float) -> void:
	var c: Vector2 = px + Vector2.ONE * tile * 0.5
	var frost: float = _frost(machine)
	var body: Color = Color("8e5ac0").lerp(Color("5c6a92"), frost)
	var ready: bool = int(machine.buffer.get(Defs.ITEM_FROST, 0)) > 0 and int(machine.buffer.get(Defs.ITEM_EMBER, 0)) > 0
	var glow: float = (0.45 + sin(pulse * 6.0) * 0.25) if ready else 0.12

	draw_circle(c + Vector2(0, 9), 11.0, Color(0.02, 0.04, 0.08, 0.32))
	draw_rect(Rect2(c.x - 12, c.y - 12, 24, 24), body.darkened(0.4))
	draw_rect(Rect2(c.x - 10, c.y - 10, 20, 20), body)
	draw_rect(Rect2(c.x - 6, c.y - 4, 12, 10), Color(1.0, 0.55, 0.2, glow))
	draw_rect(Rect2(c.x - 10, c.y - 12, 20, 4), Defs.COL_BRASS.lerp(body, 0.3))
	var tip: Vector2 = c + Vector2(machine.dir) * 15.0
	draw_circle(tip, 2.6, Defs.COL_BRASS)
	# Two input pips tell the player exactly what the recipe is still missing.
	_draw_pip(c + Vector2(-6, 12), Defs.ITEM_FROST, int(machine.buffer.get(Defs.ITEM_FROST, 0)))
	_draw_pip(c + Vector2(6, 12), Defs.ITEM_EMBER, int(machine.buffer.get(Defs.ITEM_EMBER, 0)))
	if machine.flash > 0.0:
		draw_circle(c, 16.0 + machine.flash * 14.0, Color(1, 0.9, 0.7, machine.flash * 0.55), false, 2.0)

func _draw_pip(at: Vector2, item_type: int, count: int) -> void:
	var col: Color = Defs.ITEM_COLORS[item_type]
	draw_circle(at, 3.4, Color(0.05, 0.07, 0.11, 0.85))
	if count > 0:
		draw_circle(at, 2.4, col)
	else:
		draw_arc(at, 2.4, 0.0, TAU, 10, Color(col.r, col.g, col.b, 0.35), 1.0)

func _draw_belt(machine: Sim.Machine, px: Vector2, tile: float) -> void:
	var c: Vector2 = px + Vector2.ONE * tile * 0.5
	var frost: float = _frost(machine)
	var body: Color = Defs.COL_BELT_BODY.lerp(Color8(40, 48, 66), frost)
	# A warm bloom beneath powered machinery: belts should emit light, not absorb
	# it, and dropping the bloom is how the frost penalty reads visually.
	draw_circle(c, 17.0, Color(0.94, 0.59, 0.27, 0.35 * (1.0 - frost) + 0.06))
	draw_rect(Rect2(px.x + 2, px.y + 2, tile - 4, tile - 4), body)
	draw_rect(Rect2(px.x + 2, px.y + 2, tile - 4, 2.0), Defs.COL_BELT_RIM.lerp(body, frost))
	var dir := Vector2(machine.dir)
	var perp := Vector2(-dir.y, dir.x)
	# Scrolling chevrons: the cheapest possible "this is moving" signal.
	for index in 2:
		var offset: float = fmod(pulse * Defs.BELT_SPEED * 0.5 + float(index) * 0.5, 1.0)
		var along: float = (offset - 0.5) * tile
		var head: Vector2 = c + dir * (along + 5.0)
		var tail: Vector2 = c + dir * (along - 2.0)
		var chev: Color = Defs.COL_BELT_CHEVRON if frost <= 0.0 else Defs.COL_FROZEN_CHEVRON
		draw_line(tail + perp * 5.0, head, chev, 2.0)
		draw_line(tail - perp * 5.0, head, chev, 2.0)

func _draw_belt_items(machine: Sim.Machine, px: Vector2, tile: float) -> void:
	var c: Vector2 = px + Vector2.ONE * tile * 0.5
	var dir := Vector2(machine.dir)
	for item: Dictionary in machine.items:
		var t: float = float(item["t"])
		var at: Vector2 = c + dir * (t - 0.5) * tile
		var col: Color = Defs.ITEM_COLORS[int(item["type"])]
		draw_circle(at + Vector2(0, 2), 5.0, Color(0.02, 0.04, 0.08, 0.35))
		draw_circle(at, 4.6, col.darkened(0.35))
		draw_circle(at, 3.4, col)
		draw_circle(at + Vector2(-1, -1), 1.2, Color(1, 1, 1, 0.6))

func _draw_preview(tile: float) -> void:
	var px: Vector2 = Vector2(preview_cell) * tile
	# Three explicit states. A ghost that is always red teaches nothing.
	var col: Color = Defs.COL_VALID if preview_valid else (
		Color8(150, 160, 180) if not preview_affordable else Defs.COL_DANGER)
	var alpha: float = 0.55 + sin(pulse * 5.0) * 0.12
	draw_rect(Rect2(px.x + 1, px.y + 1, tile - 2, tile - 2), Color(col.r, col.g, col.b, 0.16))
	draw_rect(Rect2(px.x + 1, px.y + 1, tile - 2, tile - 2), Color(col.r, col.g, col.b, alpha), false, 2.0)
	if preview_type != Defs.M_MINER:
		var c: Vector2 = px + Vector2.ONE * tile * 0.5
		var dir := Vector2(preview_dir)
		draw_line(c - dir * 8.0, c + dir * 10.0, Color(col.r, col.g, col.b, alpha), 2.0)
		draw_circle(c + dir * 11.0, 2.6, Color(col.r, col.g, col.b, alpha))
