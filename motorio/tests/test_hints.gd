extends SceneTree

## Every key the interface names has to be a key that does that.
##
## The objective line told new players to press C to mine for eight versions
## after mining moved to the pickaxe. Nothing caught it: the string was correct
## GDScript, the objective drew fine, and the only way to notice was to start a
## game, read the sentence, press the key and watch nothing happen. A playtest
## found it in the end, which is a slow way to find a typo.
##
## So the bindings are the source of truth and the sentences are checked against
## them. This cannot prove a sentence is good advice; it can prove no sentence
## names a key that does something else.

const HudScript := preload("res://scripts/HUD.gd")

var failures := 0

## What the interface claims, and the action that would have to be bound to that
## key for the claim to be true.
const CLAIMS: Array[Array] = [
	["Z", "build"], ["X", "demolish"], ["R", "rotate"], ["F", "recipe"], ["C", "mine"],
]

func _init() -> void:
	var main := load("res://scenes/Main.tscn").instantiate() as Node2D
	root.add_child(main)
	await process_frame
	await process_frame
	main.clear_save()
	main._start_run()
	main.state = main.State.PLAY

	_bindings()
	_mining_hint(main)
	_objectives(main)
	_legend()
	_particles(main)

	print("HINTS: %s" % ("PASS" if failures == 0 else "FAIL %d" % failures))
	quit(failures)

## The letters the interface uses are bound to the actions it means by them.
## Written against the keycode constants rather than the numbers, which is the
## lesson this repository already has about arrow keys turning out to be Home.
func _bindings() -> void:
	var letters := {"Z": KEY_Z, "X": KEY_X, "R": KEY_R, "F": KEY_F, "C": KEY_C}
	for claim: Array in CLAIMS:
		var name: String = claim[0]
		var action: String = claim[1]
		_check(InputMap.has_action(action), "%s 액션이 존재한다" % action)
		if not InputMap.has_action(action):
			continue
		var found := false
		for event: InputEvent in InputMap.action_get_events(action):
			var key := event as InputEventKey
			if key == null:
				continue
			if key.physical_keycode == letters[name] or key.keycode == letters[name]:
				found = true
		_check(found, "%s 키가 %s 액션에 실제로 묶여 있다" % [name, action])

## The opening instruction names the pickaxe and the key that actually swings it.
## It used to have to say something different on a phone, because the pad's Z did
## only half of what Z does and the digging lived on a button no key had; the pad
## is the keys now, so both say Z and the difference is only the word for
## pressing one.
func _mining_hint(main: Node2D) -> void:
	main.touch.visible = false
	var desktop: String = main._mining_hint()
	main.touch.visible = true
	var touch: String = main._mining_hint()
	main.touch.visible = false

	_check(desktop.contains("곡괭이"), "데스크톱 안내가 곡괭이를 언급한다: %s" % desktop)
	_check(desktop.contains("Z"), "데스크톱 안내가 Z를 말한다")
	_check(not desktop.contains("C "), "데스크톱 안내가 더 이상 C를 말하지 않는다")
	_check(touch.contains("곡괭이"), "터치 안내가 곡괭이를 언급한다: %s" % touch)
	# The pad's buttons are the game's keys now, so the hint says the same thing
	# on both. It used to have to differ, because the pad's Z did only half of
	# what Z does and the digging lived on a button no key had.
	_check(touch.contains("Z"), "터치 안내도 Z를 말한다: %s" % touch)
	_check(not touch.contains("캐기"), "더 이상 캐기 버튼을 말하지 않는다")

## Nothing any objective can say may name a key that is not bound, and the one
## the game opens on is the mining line -- which is where the stale one lived.
func _objectives(main: Node2D) -> void:
	var sim: Sim = main.sim
	sim.setup(4242)
	var opening: String = String(main.objective_data()["text"])
	_check(opening == main._mining_hint(),
		"새 게임의 첫 목표가 채굴 안내다: %s" % opening)

	# Freezing outranks everything. This was found by a playtest screenshot of the
	# card discussing crates over a blackout countdown.
	var warm: float = main.player.warmth
	main.player.warmth = Defs.FROST_STAGES[2] - 1.0
	var freezing: String = String(main.objective_data()["text"])
	_check(freezing.contains("얼고"), "체온이 낮으면 목표가 온기로 바뀐다: %s" % freezing)
	main.time_left = Defs.NIGHT_SECONDS - 1.0
	_check(String(main.objective_data()["text"]) == freezing,
		"밤이어도 동결이 먼저다")
	main.time_left = Defs.DAY_SECONDS
	main.player.warmth = warm
	_check(String(main.objective_data()["text"]) == opening, "체온이 돌아오면 목표도 돌아온다")

	# Walk the ladder and read every line it can produce, so a key named in a
	# later objective is checked too rather than only the first one.
	var seen: Array[String] = []
	var states: Array[Callable] = [
		func() -> void: sim.stock[Defs.ITEM_CRYSTAL] = 5,
		func() -> void: sim.carried_boxes = Defs.BOXES_PER_CAT,
		func() -> void: sim._spawn_cats([Defs.RARITY_O] as Array[int]),
		func() -> void: sim.carried_cat = sim.cats[0],
		func() -> void: sim.carried_cat = null,
		func() -> void: sim.stock[Defs.ITEM_COPPER] = 10,
		func() -> void: sim.delivered[Defs.ITEM_ENERGY] = 3,
	]
	seen.append(opening)
	for change: Callable in states:
		change.call()
		seen.append(String(main.objective_data()["text"]))
	var bound := {"Z": true, "X": true, "R": true, "F": true, "C": true}
	for line: String in seen:
		for letter: String in ["Z", "X", "R", "F", "C", "B", "G"]:
			if not line.contains(" %s " % letter) and not line.contains("%s로" % letter) \
					and not line.contains("%s를" % letter):
				continue
			_check(bound.has(letter),
				"목표 문구가 묶이지 않은 키를 말하지 않는다: '%s' 안의 %s" % [line, letter])
	print("HINTS: 목표 문구 %d줄 확인" % seen.size())

	# A rung must not ask for something with no target. Owning a spare cat is
	# normal -- the gacha gives them out and the standard scenario keeps one on
	# purpose to haul -- and while this rung was unconditional it both named an
	# impossible action and, sitting early in the ladder, hid every rung after it
	# for the rest of the run.
	var place := "고양이를 Z 로 안아 채굴기에 올려놓으세요"
	for cat: Sim.Cat in sim.cats:
		cat.assigned = Vector2i(9999, 9999)
	sim.stock[Defs.ITEM_CRYSTAL] = 500
	sim.unlocked[Defs.M_MINER] = true
	var seam_a: Vector2i = sim.core_cell + Sim.STARTER_PATCH[0]
	var seam_b: Vector2i = sim.core_cell + Sim.STARTER_PATCH[1]
	_check(sim.build(Defs.M_MINER, seam_a, Vector2i(0, -1)), "채굴기가 섰다")
	while sim.cats.size() < 2:
		sim._spawn_cats([Defs.RARITY_O] as Array[int])
	_check(String(main.objective_data()["text"]) == place,
		"빈 채굴기가 있으면 고양이를 올리라고 한다")

	sim.carried_cat = sim.cats[0]
	sim.place_cat(seam_a)
	_check(main._unassigned_cats() > 0, "아직 노는 고양이가 있다")
	_check(String(main.objective_data()["text"]) != place,
		"올려놓을 자리가 없으면 올리라고 하지 않는다: %s" % main.objective())

	# And it comes back the moment a seat opens.
	_check(sim.build(Defs.M_MINER, seam_b, Vector2i(0, -1)), "두 번째 채굴기가 섰다")
	_check(String(main.objective_data()["text"]) == place,
		"자리가 생기면 다시 올리라고 한다")

## The key legend lists every key the game answers to on a desktop. It is a
## hand-written list, which is the kind that goes stale the moment someone adds
## a key -- G and the zoom pair were both missing from it, and both were added
## by me, two versions apart.
func _legend() -> void:
	# Through the script rather than an instance: HUD.gd has no class_name, and a
	# constant is not a property, so this is the one way to reach it.
	var legend: String = HudScript.key_legend()
	for letter: String in ["Z", "X", "R", "C", "B", "M"]:
		_check(legend.contains("%s " % letter), "조작 안내에 %s가 있다: %s" % [letter, legend])

	# G follows the switch in both directions. A legend that advertises a key the
	# game no longer answers to is the fault this whole file exists for, and a
	# legend that hides a key that does work is the same fault backwards.
	var was: bool = Defs.GACHA_ENABLED
	Defs.GACHA_ENABLED = false
	_check(not HudScript.key_legend().contains("G "), "가챠가 꺼져 있으면 G를 말하지 않는다")
	Defs.GACHA_ENABLED = true
	_check(HudScript.key_legend().contains("G "), "가챠가 켜져 있으면 G를 말한다")
	Defs.GACHA_ENABLED = was
	_check(legend.contains("-/="), "조작 안내에 화면 크기 키가 있다")
	_check(legend.contains("Esc"), "조작 안내에 Esc가 있다")

## Korean particles, against every name the game can put in front of one. Two
## sentences had a fixed particle and both were wrong for every word they could
## ever receive -- "컨테이너 벨트은", "수정조각가 부족합니다" -- and neither looks wrong
## in the source, which is why this is a test and not a proofread.
func _particles(main: Node2D) -> void:
	for word: String in ["수정조각", "구리광석", "에너지결정"]:
		_check(Defs.has_final(word), "%s은 받침이 있다" % word)
		_check(Defs.topic(word) == "은" and Defs.object_of(word) == "을"
			and Defs.subject(word) == "이", "%s의 조사: 은/을/이" % word)
	for word: String in Defs.MACHINE_NAMES:
		_check(not Defs.has_final(word), "%s는 받침이 없다" % word)
		_check(Defs.topic(word) == "는" and Defs.object_of(word) == "를"
			and Defs.subject(word) == "가", "%s의 조사: 는/를/가" % word)
	# Not Hangul at all, and words the fallback has to survive.
	_check(Defs.topic("Grim") == "는" and Defs.topic("") == "는", "한글이 아니면 기본형")
	_check(Defs.subject("자원") == "이", "자원 -> 이")

	# And the sentences themselves, built the way the game builds them.
	var sim: Sim = main.sim
	sim.setup(4242)
	var seam: Vector2i = sim.ore.keys()[0]
	var reason: String = sim.can_build(Defs.M_EXCHANGER, seam + Vector2i(0, 40))
	_check(not reason.contains("수정조각가"), "부족 안내의 조사가 맞다: %s" % reason)
	_check(reason.contains("수정조각이") or reason == "" or not reason.contains("수정조각"),
		"부족 안내: %s" % reason)

func _check(condition: bool, message: String) -> void:
	if condition:
		return
	print("  FAIL: ", message)
	failures += 1
