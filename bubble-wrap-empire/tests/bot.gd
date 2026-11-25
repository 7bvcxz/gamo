extends SceneTree
# Tuning helper: a relaxed player taps the middle of the sheet every few seconds
# and buys the cheapest upgrade. godot --headless --path . --script res://tests/bot.gd
const Sim := preload("res://scripts/Sim.gd")

func _init() -> void:
	var s: RefCounted = Sim.new(5)
	var marks: Array[float] = [10.0, 30.0, 60.0, 120.0, 180.0]
	var mi: int = 0
	var dt: float = 1.0 / 60.0
	var elapsed: float = 0.0
	var next_tap: float = 0.0
	var first_buy: float = -1.0
	var biggest: int = 0
	var gap: float = 3.0
	while elapsed < 180.0:
		if elapsed >= next_tap:
			s.trigger(Vector2(3.0, 4.0 * 0.866))
			next_tap = elapsed + gap
		var cheapest: int = 0
		for i in 5:
			if s.cost(i) < s.cost(cheapest) or s.maxed(cheapest):
				cheapest = i
		if s.can_buy(cheapest):
			s.buy(cheapest)
			if first_buy < 0.0:
				first_buy = elapsed
		s.step(dt)
		biggest = maxi(biggest, s.last_wave_count)
		elapsed += dt
		if mi < marks.size() and elapsed >= marks[mi]:
			print("t=%3d pop=%8.1f lv=%s last_wave=%d (%.2fs) biggest=%d full=%d/%d triggers=%d pops=%d" % [int(marks[mi]), s.pop, str(s.lv), s.last_wave_count, s.last_wave_secs, biggest, s.full_count(), s.pos.size(), s.triggers, s.pops])
			mi += 1
	print("first buy at %.1fs" % first_buy)
	quit()
