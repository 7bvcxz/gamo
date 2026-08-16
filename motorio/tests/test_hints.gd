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
	main.finish_tutorial()
	main.state = main.State.PLAY

	_bindings()
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

func _objectives(main: Node2D) -> void:
	var sim: Sim = main.sim
	sim.setup(4242)
	# The card stops giving instructions once the hut is up. What it shows from
	# then on is the next step of the fire and what it costs -- no verb, no key.
	var opening: String = String(main.objective_data()["text"])
	_check(opening.begins_with("기지 업그레이드"),
		"거처를 세운 뒤의 목표는 다음 기지 단계다: %s" % opening)
	_check(not opening.contains("Z") and not opening.contains("하세요"),
		"그리고 지시하지 않는다: %s" % opening)

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
		func() -> void: sim.carried_frozen = true,
		func() -> void: sim.carried_frozen = false,
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

	# The title screen, which is the one line every player reads and nobody
	# re-reads. It advertised WASD, and WASD moves nothing.
	var title: String = HudScript.title_controls(false)
	_check(not title.to_upper().contains("WASD"),
		"타이틀이 묶여 있지 않은 키를 말하지 않는다: %s" % title)
	_check(title.contains("←") and title.contains("이동"),
		"타이틀이 실제 이동 키를 말한다: %s" % title)
	for pair: Array in [["←", "move_left"], ["→", "move_right"], ["↑", "move_up"], ["↓", "move_down"]]:
		var arrow: String = pair[0]
		var action: String = pair[1]
		if not title.contains(arrow):
			continue
		var codes := {"←": KEY_LEFT, "→": KEY_RIGHT, "↑": KEY_UP, "↓": KEY_DOWN}
		var bound := false
		for event: InputEvent in InputMap.action_get_events(action):
			var key := event as InputEventKey
			if key != null and (key.keycode == codes[arrow] or key.physical_keycode == codes[arrow]):
				bound = true
		_check(bound, "%s 가 %s 에 묶여 있다" % [arrow, action])

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
