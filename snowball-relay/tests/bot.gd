extends SceneTree
# Tuning helper, not a pass/fail test: plays a relaxed player (one swipe each
# time the ball stops, buys the cheapest affordable upgrade) and prints the
# milestones the issue cares about. godot --headless --path . --script res://tests/bot.gd
const Sim := preload("res://scripts/Sim.gd")

func _init() -> void:
	var s: RefCounted = Sim.new(7)
	var t_first_snow: float = -1.0
	var marks: Array[float] = [10.0, 30.0, 60.0, 120.0, 180.0]
	var mi: int = 0
	var first_buy: float = -1.0
	var dt: float = 1.0 / 60.0
	var elapsed: float = 0.0
	while elapsed < 180.0:
		if s.speed <= 0.0:
			s.push(0.8)
		var cheapest: int = 0
		for i in 5:
			if s.cost(i) < s.cost(cheapest) or s.maxed(cheapest):
				cheapest = i
		if s.can_buy(cheapest):
			s.buy(cheapest)
			if first_buy < 0.0:
				first_buy = elapsed
		s.step(dt)
		elapsed += dt
		if t_first_snow < 0.0 and s.earned > 0.0:
			t_first_snow = elapsed
		if mi < marks.size() and elapsed >= marks[mi]:
			print("t=%3d snow=%7.1f mass=%6.2f r=%.2f v0=%.1f T=%.1f lv=%s dist=%.0f pushes=%d breaks=%d" % [int(marks[mi]), s.snow, s.mass, s.radius(), s.v0(), s.roll_time(), str(s.lv), s.dist, s.pushes, s.breaks])
			mi += 1
	print("first snow at %.2fs, first buy at %.1fs" % [t_first_snow, first_buy])
	quit()
