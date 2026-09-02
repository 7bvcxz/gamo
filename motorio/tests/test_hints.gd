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

## Whether a line the player reads on a card names a key. The letters are the
## ones this interface actually uses; the Korean fragments catch the sentence
## form ("아무 키나 눌러") that names no letter at all.
func _no_keys(line: String, where: String) -> void:
	var found := ""
	for token: String in ["Z", "X", "R", "F", "C", "Esc", "Enter", "Space", "눌러", "누르"]:
		if line.contains(token):
			found = token
	_check(found == "", "%s가 키를 말하지 않는다: '%s' (%s)" % [where, line, found])

func _objectives(main: Node2D) -> void:
	var sim: Sim = main.sim
	sim.setup(4242)
	# The card stops giving instructions once the hut is up. What it shows from
	# then on is the next step of the fire and what it costs -- no verb, no key.
	# The one-line card is finished with once the opening is. What the player is
	# working towards from there is three tracks at once, and the fire's own count
	# moved onto the fire.
	var opening: String = String(main.objective_data()["text"])
	_check(opening.is_empty(),
		"거처를 세운 뒤에는 한 줄짜리 목표가 비워진다: '%s'" % opening)
	for row: Dictionary in main.open_missions():
		var line: String = String(row["line"])
		_check(not line.contains("하세요") and not line.contains("세요"),
			"임무는 지시하지 않는다: %s" % line)

	# State lines live on their own card now. The goal is what she is working
	# towards and does not change because the sun went down; the state card is
	# what is true right now. They used to be the same card, and the second kind
	# kept evicting the first -- a player who picked a cat up stopped being able
	# to see what they were working towards until they put it down.
	_check(main.info().is_empty(), "조용할 때는 정보창이 없다: '%s'" % main.info())
	var warm: float = main.player.warmth
	main.player.warmth = Defs.FROST_STAGES[2] - 1.0
	var freezing: String = main.info()
	_check(freezing.contains("얼고"), "체온이 낮으면 정보창이 온기를 말한다: %s" % freezing)
	_check(String(main.objective_data()["text"]) == opening,
		"그동안 목표는 그대로다: %s" % String(main.objective_data()["text"]))
	main.time_left = Defs.NIGHT_SECONDS - 1.0
	_check(main.info() == freezing, "밤이어도 동결이 먼저다")
	main.time_left = Defs.DAY_SECONDS
	main.player.warmth = warm
	_check(main.info().is_empty(), "체온이 돌아오면 정보창도 닫힌다")
	_check(String(main.objective_data()["text"]) == opening, "목표는 내내 같았다")

	# --- And no card names a key ------------------------------------------------
	# The prompt over her shoulder is where a key is named: it is drawn on the
	# thing it applies to, at the moment it applies, and it goes away. A mission
	# card spells one out on a plate that stays on screen for the rest of the day
	# -- "숙소로 돌아가 Z로 취침하세요" was still up while she was in the hut.
	for row: Dictionary in Defs.MISSION_LINES:
		_no_keys(String(row["line"]), "오프닝 줄")
	for row: Dictionary in Defs.MISSIONS:
		_no_keys(String(row["line"]), "임무 줄")
	main.player.warmth = warm
	main.time_left = Defs.NIGHT_SECONDS - 1.0
	_check(main.info().contains("밤"), "밤에는 정보창이 밤이라고 말한다: %s" % main.info())
	_no_keys(main.info(), "밤 정보창")
	main.time_left = Defs.DUSK_SECONDS - 1.0
	_no_keys(main.info(), "해질녘 정보창")
	main.time_left = Defs.DAY_SECONDS
	main.player.warmth = Defs.FROST_STAGES[2] - 1.0
	_no_keys(main.info(), "동결 정보창")
	main.player.warmth = warm

	# And the card that stacks above it never pushes the goal off the screen.
	main.player.warmth = Defs.FROST_STAGES[2] - 1.0
	var hud: Node = main.hud
	var info_box: Rect2 = hud.call("info_rect", main.info())
	var goal_box: Rect2 = hud.call("objective_rect", main.objective())
	_check(goal_box.position.y >= info_box.position.y + info_box.size.y,
		"정보창이 목표창 위에 앉는다: 정보 %.0f..%.0f, 목표 %.0f"
			% [info_box.position.y, info_box.position.y + info_box.size.y, goal_box.position.y])
	_check(goal_box.position.y + goal_box.size.y < hud.size.y,
		"그래도 목표창이 화면 안에 있다")
	main.player.warmth = warm

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
		func() -> void: sim.delivered[Defs.ITEM_CRYSTAL] = 3,
	]
	seen.append(opening)
	for change: Callable in states:
		change.call()
		seen.append(String(main.objective_data()["text"]))
		if main.info() != "":
			seen.append(main.info())
		# Whatever the world is doing, the goal card keeps showing the ladder.
		# This is the whole point of the split: picking a cat up used to blank the
		# thing the player was working towards.
		_check(String(main.objective_data()["text"]) == opening,
			"세상이 무슨 일을 하든 목표는 사다리다: '%s'" % String(main.objective_data()["text"]))
	var bound := {"Z": true, "X": true, "R": true, "F": true, "C": true}
	for line: String in seen:
		for letter: String in ["Z", "X", "R", "F", "C", "B", "G"]:
			if not line.contains(" %s " % letter) and not line.contains("%s로" % letter) \
					and not line.contains("%s를" % letter):
				continue
			_check(bound.has(letter),
				"목표 문구가 묶이지 않은 키를 말하지 않는다: '%s' 안의 %s" % [line, letter])
	print("HINTS: 목표 문구 %d줄 확인" % seen.size())

## Every key the game answers to, checked against what is actually bound.
##
## This used to read a hand-written string in the HUD and look for letters in it.
## The string is gone -- the play screen no longer carries a permanent list of
## controls -- and the knowledge moved into `Defs.KEY_GUIDE`, which the ESC guide
## draws. So the check moved with it, and got stronger: instead of asking "does
## the sentence mention Z", it walks every row and asks the InputMap whether that
## row's key is really bound to that row's action.
##
## This is the file that exists because the objective card told players to press
## C for eight versions after C stopped mining.
func _legend() -> void:
	var seen := {}
	for row: Dictionary in Defs.KEY_GUIDE:
		var id: String = String(row["id"])
		_check(not seen.has(id), "안내 표에 같은 id가 두 번 있지 않다: %s" % id)
		seen[id] = true
		_check(not (row.get("keys", []) as Array).is_empty(), "%s 에 키가 적혀 있다" % id)
		_check(String(row.get("label", "")) != "", "%s 에 뜻이 적혀 있다" % id)
		_check(row.has("action") != row.has("code"),
			"%s 는 액션이거나 키코드다 — 둘 다이거나 둘 다 아니면 검사할 수 없다" % id)
		if row.has("action"):
			_check_action(row)
		else:
			_check_code(row)

	# The switch works in both directions. A guide that advertises a key the game
	# no longer answers to is the fault this whole file exists for, and a guide
	# that hides a key that does work is the same fault backwards.
	var was: bool = Defs.GACHA_ENABLED
	Defs.GACHA_ENABLED = false
	_check(not _guide_has("GACHA"), "가챠가 꺼져 있으면 G를 말하지 않는다")
	Defs.GACHA_ENABLED = true
	_check(_guide_has("GACHA"), "가챠가 켜져 있으면 G를 말한다")
	Defs.GACHA_ENABLED = was

	# And the keys the player actually needs are all in there. Named one by one
	# rather than counted, because a table that lost a row would still have rows.
	for id: String in ["MOVE", "RUN", "USE", "TAKE", "TURN", "TOOL", "BUILD",
			"QUEST", "MAP", "LOG", "ZOOM", "MENU"]:
		_check(_guide_has(id), "안내에 %s 가 있다" % id)
	print("HINTS: 조작 안내 %d줄 확인" % Defs.KEY_GUIDE.size())

func _guide_has(id: String) -> bool:
	for row: Dictionary in Defs.key_guide_rows():
		if String(row["id"]) == id:
			return true
	return false

## The row names an InputMap action: every key it draws must be one of that
## action's events, and the action must exist.
func _check_action(row: Dictionary) -> void:
	var action: String = String(row["action"])
	var id: String = String(row["id"])
	_check(InputMap.has_action(action), "%s 의 액션이 존재한다: %s" % [id, action])
	if not InputMap.has_action(action):
		return
	var bound: Array[String] = []
	for event: InputEvent in InputMap.action_get_events(action):
		var key := event as InputEventKey
		if key == null:
			continue
		var code: int = key.physical_keycode if key.physical_keycode != 0 else key.keycode
		bound.append(OS.get_keycode_string(code))
	# 이동은 네 방향이 네 액션이므로 한 줄이 대표한다. 나머지는 정확히 맞아야 한다.
	if id == "MOVE":
		for pair: Array in [["move_up", "W"], ["move_down", "S"],
				["move_left", "A"], ["move_right", "D"]]:
			var names: Array[String] = []
			for event: InputEvent in InputMap.action_get_events(String(pair[0])):
				var key2 := event as InputEventKey
				if key2 == null:
					continue
				var c2: int = key2.physical_keycode if key2.physical_keycode != 0 else key2.keycode
				names.append(OS.get_keycode_string(c2))
			_check(names.has(String(pair[1])),
				"%s 가 %s 에 묶여 있다: %s" % [String(pair[1]), String(pair[0]), str(names)])
		return
	for label: String in row["keys"]:
		var want: String = "Shift" if label == "Shift" else label
		_check(bound.has(want),
			"%s 안내의 '%s' 가 실제로 %s 에 묶여 있다: %s" % [id, label, action, str(bound)])

## How a key is spelled on screen versus what Godot calls it. Three keys have a
## glyph a player recognises and a name they do not -- nobody reads "Minus" on a
## keyboard -- so the guide draws the glyph. The pairs are written down here so
## the drawn spelling is still checked against a real key rather than trusted.
const KEY_SPELLING := {"Esc": "Escape", "-": "Minus", "=": "Equal"}

## The row names a raw keycode that Main reads directly. The drawn label has to
## be that key -- the guide cannot invent a key that is not there.
func _check_code(row: Dictionary) -> void:
	var code: int = int(row["code"])
	var name: String = OS.get_keycode_string(code)
	var first: String = String((row["keys"] as Array)[0])
	var want: String = String(KEY_SPELLING.get(first, first))
	_check(name == want,
		"%s 안내의 첫 키 '%s' 가 실제 키 이름 '%s' 와 같다" % [String(row["id"]), first, name])
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
	# Derived from the tables rather than listed here. The list this replaced was
	# ["수정조각", "구리광석", "에너지결정"] -- and 에너지결정 has not existed since
	# 1.0.8, so a third of the check was proofreading a word the game cannot
	# print, while 에너지 코어 was renamed in 1.0.30 without anyone noticing it
	# was never covered. A hand-kept list of the names in a game that renames
	# things is a list that tests the wrong century.
	for word: String in Defs.ITEM_NAMES + Defs.ITEM_SHORT + Defs.MACHINE_NAMES:
		var final: bool = Defs.has_final(word)
		_check(Defs.topic(word) == ("은" if final else "는"),
			"%s + 은/는 -> %s" % [word, Defs.topic(word)])
		_check(Defs.object_of(word) == ("을" if final else "를"),
			"%s + 을/를 -> %s" % [word, Defs.object_of(word)])
		_check(Defs.subject(word) == ("이" if final else "가"),
			"%s + 이/가 -> %s" % [word, Defs.subject(word)])
	# The two the rename moved across the boundary, spelled out so the change is
	# readable rather than only derived.
	_check(not Defs.has_final("에너지 코어"), "에너지 코어는 받침이 없다 (코어부품은 있었다)")
	_check(Defs.has_final("열석"), "열석은 받침이 있다")

	# The sentence the build list actually prints for a machine that waits for
	# two materials. The particle follows the last name in the list, which is the
	# word it is standing next to.
	var line: String = Defs.unlock_line(Defs.M_GENERATOR)
	_check(line.contains("에너지 코어를"), "발전기 해금 문구의 조사가 맞다: %s" % line)
	# Not Hangul at all, and words the fallback has to survive.
	_check(Defs.topic("Grim") == "는" and Defs.topic("") == "는", "한글이 아니면 기본형")
	_check(Defs.subject("자원") == "이", "자원 -> 이")

	# And the sentences themselves, built the way the game builds them.
	var sim: Sim = main.sim
	sim.setup(4242)
	var seam: Vector2i = sim.ore.keys()[0]
	var reason: String = sim.can_build(Defs.M_GENERATOR, seam + Vector2i(0, 40))
	_check(not reason.contains("수정조각가"), "부족 안내의 조사가 맞다: %s" % reason)
	_check(reason.contains("수정조각이") or reason == "" or not reason.contains("수정조각"),
		"부족 안내: %s" % reason)

func _check(condition: bool, message: String) -> void:
	if condition:
		return
	print("  FAIL: ", message)
	failures += 1
