extends SceneTree

## Calibrates E+'s prices from level 11 on (TycoonPlusLevels.PLUS) on the
## real line: a player buys each level 1.5 s after it can pay; each price is
## what the line earns in the target wait after the level before, rounded to
## two significant figures. The target wait grows with play time: 30 s after
## three minutes to 55 s at eight, 75 s at fifteen, 95 s at thirty -- so the
## last of the twenty comes near the thirtieth minute, not at the twentieth.
## Prints the prices to copy into the table (the table, not this tool, is
## what the game reads).
##
##   godot --headless --path momonium/experiments --script res://tools/e_costs.gd

const REACTION := 1.5


func _init() -> void:
	var n0 := TycoonLevels.LEVELS.size()
	var prices: Array[int] = []
	var line := TycoonLine.new()
	var level := 0
	line.configure(TycoonPlusLevels.row(0))
	var coins := 0
	var t := 0.0
	var ready_since := -1.0
	var last_up := 0.0
	while level < TycoonPlusLevels.count() - 1 and t < 3600.0:
		line.advance(TycoonLine.STEP)
		t += TycoonLine.STEP
		coins += line.just_delivered.size() * line.value
		var next := level + 1
		var price := TycoonPlusLevels.cost(next) if next < n0 else -1
		if next >= n0 and next - n0 >= prices.size():
			# Calibrating this one: wait the target time, then price it at
			# what was earned (the player buys it REACTION s later).
			if t - last_up >= _target(last_up):
				prices.append(_nice(coins))
				price = prices.back()
			else:
				continue
		elif next >= n0:
			price = prices[next - n0]
		if coins >= price:
			if ready_since < 0.0:
				ready_since = t
			if t - ready_since >= REACTION:
				coins -= price
				level = next
				line.configure(_row_with(level, prices))
				print("Lv%d %s at %.1f s for %d (capacity %.1f/s)" % [level, TycoonPlusLevels.row(level)["name"], t, price, TycoonPlusLevels.capacity(level)])
				last_up = t
				ready_since = -1.0
		else:
			ready_since = -1.0
	print("PLUS prices: %s" % str(prices))
	quit()


static func _row_with(n: int, _prices: Array[int]) -> Dictionary:
	return TycoonPlusLevels.row(n)


static func _target(t: float) -> float:
	if t < 180.0:
		return 25.0
	if t < 480.0:
		return lerpf(30.0, 55.0, (t - 180.0) / 300.0)
	if t < 900.0:
		return lerpf(55.0, 75.0, (t - 480.0) / 420.0)
	return lerpf(75.0, 95.0, clampf((t - 900.0) / 900.0, 0.0, 1.0))


static func _nice(v: int) -> int:
	if v < 100:
		return maxi(v, 10)
	var digits := int(floor(log(float(v)) / log(10.0)))
	var unit := pow(10.0, digits - 1)
	return int(round(float(v) / unit) * unit)
