extends SceneTree

## The slot machine: the table, the purse, and what a graded cat is worth.
##
## Almost none of this is visible in a screenshot. A pull is a number nobody can
## see, a 0.5% grade will not appear in any session anyone runs by hand, and the
## thing a grade actually changes -- how fast a miner turns -- is a rate. So the
## table is checked against itself, the distribution against twenty thousand
## seeded rolls, and the work rate through the same call the miner makes.

var failures := 0

func _init() -> void:
	var main := load("res://scenes/Main.tscn").instantiate() as Node2D
	root.add_child(main)
	await process_frame
	await process_frame
	# _ready loads whatever the last test left behind, and a run that already has
	# cats and coins is not the run any of this is about.
	main.clear_save()
	main._start_run()
	main.state = main.State.PLAY
	var sim: Sim = main.sim

	_table()
	_boundaries()
	_distribution(sim)
	_purse(sim)
	_grades_reach_the_miner(sim)
	_crates_stay_ordinary(sim)
	_saving(main, sim)
	_reels(main, sim)
	_layout(main)

	print("GACHA: %s" % ("PASS" if failures == 0 else "FAIL %d" % failures))
	quit(failures)

## The five percentages are the ones the player was promised, and they add up.
## A table that sums to 99 or 101 still rolls -- it just quietly stops being the
## table on screen, which is the one thing a gacha cannot get away with.
func _table() -> void:
	var total: float = 0.0
	for percent: float in Defs.RARITY_PERCENT:
		total += percent
	_check(is_equal_approx(total, 100.0), "확률표 합계가 100%%: %.2f" % total)
	_check(Defs.RARITY_PERCENT.size() == Defs.RARITY_NAMES.size()
		and Defs.RARITY_NAMES.size() == Defs.RARITY_WORK_RATE.size()
		and Defs.RARITY_NAMES.size() == Defs.RARITY_COLORS.size(),
		"등급 배열 네 개의 길이가 같다")
	var wanted: Array[float] = [60.0, 33.0, 5.0, 1.5, 0.5]
	for grade in wanted.size():
		_check(is_equal_approx(Defs.RARITY_PERCENT[grade], wanted[grade]),
			"%s 등급은 %.1f%%" % [Defs.RARITY_NAMES[grade], wanted[grade]])

## Every edge of the table, from both sides. Off-by-one here is the classic way a
## published 0.5% becomes a real 1.5%, and nothing else in the game would notice.
func _boundaries() -> void:
	var cases: Array = [
		[0.0, Defs.RARITY_O], [59.999, Defs.RARITY_O],
		[60.0, Defs.RARITY_N], [92.999, Defs.RARITY_N],
		[93.0, Defs.RARITY_R], [97.999, Defs.RARITY_R],
		[98.0, Defs.RARITY_SR], [99.499, Defs.RARITY_SR],
		[99.5, Defs.RARITY_SSR], [99.9999, Defs.RARITY_SSR],
		# Past the end of the range, where floating-point slop lands.
		[100.0, Defs.RARITY_SSR],
	]
	for case: Array in cases:
		var got: int = Defs.roll_rarity(float(case[0]))
		_check(got == int(case[1]), "%.3f -> %s (got %s)"
			% [float(case[0]), Defs.RARITY_NAMES[int(case[1])], Defs.RARITY_NAMES[got]])

## Twenty thousand pulls out of the real generator. The tolerance is wide on
## purpose -- this is a sanity check that the wiring reaches the table, not a
## test of the RNG -- but a swapped row or a missing grade fails it outright.
func _distribution(sim: Sim) -> void:
	var rolls: int = 20000
	sim.gacha_rng.seed = 20260810
	var counts: Array[int] = []
	for _grade in Defs.RARITY_NAMES.size():
		counts.append(0)
	sim.coins = rolls
	_check(sim.begin_gacha(rolls), "2만 회분의 코인을 받는다")
	# Rolled without spawning, because twenty thousand cats on the doorstep is a
	# different test and a much slower one.
	for _index in rolls:
		counts[Defs.roll_rarity(sim.gacha_rng.randf() * 100.0)] += 1
	for grade in counts.size():
		var seen: float = float(counts[grade]) * 100.0 / float(rolls)
		var want: float = Defs.RARITY_PERCENT[grade]
		# Wide enough to survive an honest sample, narrow enough that two rows
		# swapping places cannot pass.
		var slack: float = maxf(want * 0.25, 0.25)
		_check(absf(seen - want) <= slack,
			"%s 실측 %.2f%% (표 %.1f%%)" % [Defs.RARITY_NAMES[grade], seen, want])
	sim.coins = 0

## Coins leave the purse when the button is pressed, and a pull that cannot be
## paid for does not happen at all.
func _purse(sim: Sim) -> void:
	sim.coins = 4
	_check(not sim.begin_gacha(10), "코인 4로 10연차는 거부된다")
	_check(sim.coins == 4, "거부된 시도는 코인을 쓰지 않는다")
	_check(sim.begin_gacha(3), "코인 4로 3연차는 가능하다")
	_check(sim.coins == 1, "3연차는 정확히 3코인: 남은 %d" % sim.coins)
	_check(not sim.begin_gacha(0), "0회는 뽑기가 아니다")
	_check(not sim.begin_gacha(-2), "음수 회차는 거부된다")
	_check(sim.coins == 1, "거부된 시도들이 코인을 건드리지 않았다")

	var before: int = sim.cats.size()
	var grades: Array[int] = sim.pull_gacha(3)
	_check(grades.size() == 3, "3연차는 등급 3개를 돌려준다")
	_check(sim.cats.size() == before + 3, "그리고 고양이가 정확히 3마리 늘었다")
	for grade: int in grades:
		_check(grade >= 0 and grade < Defs.RARITY_NAMES.size(), "등급이 표 안에 있다")
	# Ten at once must not stack on one pixel; that is what the lane spacing is
	# for, and a ten-pull is the first thing that would have exposed it.
	before = sim.cats.size()
	var ten: Array[int] = sim.pull_gacha(10)
	_check(sim.cats.size() == before + 10, "10연차는 고양이 10마리")
	var spread: float = 0.0
	for index in ten.size():
		var cat: Sim.Cat = sim.cats[before + index]
		spread = maxf(spread, absf(cat.pos.x - sim.cats[before].pos.x))
	_check(spread >= Defs.CAT_LANE * 9.0 - 0.5,
		"10마리가 한 픽셀에 겹치지 않는다: 폭 %.1f" % spread)
	sim.cats.clear()
	sim.coins = 0

## What a grade is actually for. Read through _operator_rate, which is the call
## the miner makes -- checking the constant would only prove the constant.
func _grades_reach_the_miner(sim: Sim) -> void:
	sim.setup(4242)
	var seam: Vector2i = Vector2i(0, 0)
	for cell: Vector2i in sim.ore:
		seam = cell
		break
	var miner := Sim.Machine.new()
	miner.type = Defs.M_MINER
	miner.cell = seam
	sim.machines[seam] = miner
	var cat := Sim.Cat.new()
	cat.pos = sim.cell_centre(seam)
	cat.assigned = seam
	cat.state = Defs.CAT_WORKING
	sim.cats.append(cat)

	for grade in Defs.RARITY_NAMES.size():
		cat.rarity = grade
		cat.hunger = 1.0
		var fed: float = sim._operator_rate(seam, 1.0)
		_check(is_equal_approx(fed, Defs.RARITY_WORK_RATE[grade]),
			"%s 고양이는 %.1f배로 일한다 (got %.2f)"
			% [Defs.RARITY_NAMES[grade], Defs.RARITY_WORK_RATE[grade], fed])
		cat.hunger = 0.0
		var starved: float = sim._operator_rate(seam, 1.0)
		_check(is_equal_approx(starved, Defs.RARITY_WORK_RATE[grade] * Defs.HUNGER_STARVED_RATE),
			"%s 고양이도 굶으면 3분의 1로 떨어진다" % Defs.RARITY_NAMES[grade])
	# The whole point of O being exactly 1.0: the game that existed before the
	# slot machine still runs at the speed it was balanced at.
	_check(is_equal_approx(Defs.RARITY_WORK_RATE[Defs.RARITY_O], 1.0),
		"O 등급은 정확히 1.0배 — 기존 밸런스가 그대로다")
	sim.cats.clear()

## A cat carried home in a crate is an O. If crates started handing out grades
## the gacha would stop being the only place they come from.
func _crates_stay_ordinary(sim: Sim) -> void:
	sim.setup(4242)
	sim.carried_boxes = Defs.BOXES_PER_CAT * 2
	var adopted: int = sim.adopt_cats()
	_check(adopted == 2, "상자 6개로 고양이 2마리")
	for cat: Sim.Cat in sim.cats:
		_check(cat.rarity == Defs.RARITY_O, "상자에서 온 고양이는 O 등급")
	sim.cats.clear()

## Coins and grades survive a save. Both are new fields, and a save written
## before either existed has to keep loading as a run that has never pulled.
func _saving(main: Node2D, sim: Sim) -> void:
	sim.setup(4242)
	sim.coins = 17
	sim.cats.clear()
	sim._spawn_cats([Defs.RARITY_SSR, Defs.RARITY_R] as Array[int])
	var blob: Dictionary = sim.to_save()

	var fresh := Sim.new()
	fresh.setup(4242)
	fresh.from_save(blob)
	_check(fresh.coins == 17, "코인이 저장을 넘어온다: %d" % fresh.coins)
	_check(fresh.cats.size() == 2, "고양이 2마리가 복원된다")
	if fresh.cats.size() == 2:
		_check(fresh.cats[0].rarity == Defs.RARITY_SSR and fresh.cats[1].rarity == Defs.RARITY_R,
			"등급까지 복원된다")

	# An older save: no coins key, no rarity key.
	var old: Dictionary = blob.duplicate(true)
	old.erase("coins")
	for row: Dictionary in old["cats"]:
		row.erase("rarity")
	var legacy := Sim.new()
	legacy.setup(4242)
	legacy.from_save(old)
	_check(legacy.coins == 0, "가챠 이전 세이브는 코인 0으로 열린다")
	for cat: Sim.Cat in legacy.cats:
		_check(cat.rarity == Defs.RARITY_O, "그리고 등급 없는 고양이는 O가 된다")
	fresh.free()
	legacy.free()
	sim.cats.clear()
	sim.coins = 0

## The three seconds. Driven through the real per-frame path rather than by
## calling the timer's own function, because what is being checked is that the
## reels resolve at all -- a spin that never lands is a pull the player paid for
## and never received.
func _reels(main: Node2D, sim: Sim) -> void:
	sim.setup(4242)
	sim.cats.clear()
	sim.coins = 10
	main.gacha_results.clear()
	main.gacha_spin = -1.0
	_check(main.toggle_gacha(), "G로 슬롯머신이 열린다")
	_check(bool(main.gacha_open), "열린 상태다")
	_check(not main.start_gacha(99), "존재하지 않는 버튼은 아무 일도 하지 않는다")

	_check(main.start_gacha(1), "3코인 버튼이 눌린다")
	_check(sim.coins == 7, "코인은 누른 즉시 빠진다: %d" % sim.coins)
	_check(not main.start_gacha(0), "돌아가는 동안에는 다시 넣을 수 없다")
	_check(sim.coins == 7, "그래서 코인도 그대로다")
	_check(sim.cats.size() == 0, "릴이 도는 동안에는 아직 고양이가 없다")

	# Closing mid-spin must not swallow the pull.
	main.close_gacha()
	# Ticked without yielding, so the engine's own _process cannot advance the
	# same timer alongside this loop and make the frame count mean nothing. The
	# first version of this awaited a frame per step and measured 2.45 seconds of
	# a 3 second spin, which is the double-tick rather than a short spin.
	var frames: int = 0
	while main.gacha_spin >= 0.0 and frames < 400:
		main._process_play(0.05)
		frames += 1
	_check(frames < 400, "릴은 반드시 멈춘다 (%d 프레임)" % frames)
	_check(float(frames) * 0.05 >= Defs.GACHA_SPIN_SECONDS - 0.06,
		"그리고 3초를 다 채운다: %.2f초" % (float(frames) * 0.05))
	_check(main.gacha_results.size() == 3, "결과 3마리가 나온다")
	_check(sim.cats.size() == 3, "창을 닫아도 고양이는 도착한다")
	main.gacha_open = false
	sim.cats.clear()
	sim.coins = 0

## Where the button is. Bottom-left was the request; the corner it has to share
## with is the touch pad's four thumb buttons and the hotbar, and a button drawn
## underneath either of those can never be pressed.
func _layout(main: Node2D) -> void:
	var hud = main.hud
	hud._apply_scale()
	hud._layout()
	var button: Rect2 = hud.gacha_button_rect
	var screen := Rect2(Vector2.ZERO, hud.size)
	_check(screen.encloses(button), "버튼이 화면 안에 있다")
	_check(button.position.x < hud.size.x * 0.5, "화면 좌측이다")
	_check(button.position.y > hud.size.y * 0.5, "화면 아래쪽이다")
	_check(button.end.y <= hud.size.y - hud.bottom_reserved() + 0.01,
		"터치 패드가 차지한 띠 위에 있다")
	for slot: Rect2 in hud.hotbar_rects:
		_check(not slot.intersects(button), "핫바 카드와 겹치지 않는다")

	# The window's own buttons, which touch finds by hit-testing the published
	# rects rather than by recomputing the layout.
	main.gacha_open = true
	hud._layout()
	_check(hud.gacha_pull_rects.size() == Defs.GACHA_COUNTS.size(),
		"가격 버튼이 %d개" % Defs.GACHA_COUNTS.size())
	for index in hud.gacha_pull_rects.size():
		var rect: Rect2 = hud.gacha_pull_rects[index]
		_check(int(hud.gacha_button_at(rect.get_center())) == index,
			"%d코인 버튼을 누르면 %d번이 잡힌다" % [Defs.GACHA_COUNTS[index], index])
		_check((hud.gacha_card_rect as Rect2).encloses(rect), "버튼이 창 안에 있다")
	_check(int(hud.gacha_button_at(Vector2(-50.0, -50.0))) == -1, "창 밖은 -1")
	main.gacha_open = false
	_check(int(hud.gacha_button_at(Vector2.ZERO)) == -1, "창이 닫히면 아무것도 잡히지 않는다")
	_check(Defs.GACHA_COUNTS == ([1, 3, 10] as Array[int]), "버튼은 1 / 3 / 10 코인")

func _check(condition: bool, message: String) -> void:
	if condition:
		print("  ok  : ", message)
		return
	print("  FAIL: ", message)
	failures += 1
