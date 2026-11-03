class_name PopFrame
extends Control

## Everything around the play area, the same for every experiment: back and
## restart (icons), the money counter, the one upgrade button, the three-minute
## mark, and in dev mode the active-play clock.
##
## Layout follows the canvas: a portrait column, top bar, machine in the
## middle, the upgrade under the thumb.

signal back_pressed
signal restart_pressed
signal buy_pressed
signal sound_pressed
## Dev mode only (?dev=1): download this run's local log as JSON.
signal log_pressed

var back_button := PopIconButton.new()
var restart_button := PopIconButton.new()
var sound_button := PopIconButton.new()
var log_button := PopIconButton.new()
var money_view := PopMoneyView.new()
var upgrade_button := PopUpgradeButton.new()
var play: PopPlayView
## ?trial=1: the three-minute playtest protocol (design/PLAYTEST.md) -- the
## 3:00 clock appears for the tester. Without it a player never sees a clock:
## all three blind players of Step 08 read it as a deadline or a mystery.
var trial := false
var dev := false:
	set(v):
		dev = v
		log_button.visible = v
var clock_ms := 0
var accent := PopPalette.RED


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	back_button.icon = "back"
	restart_button.icon = "restart"
	back_button.name = "Back"
	restart_button.name = "Restart"
	sound_button.name = "Sound"
	log_button.name = "Log"
	log_button.icon = "log"
	log_button.visible = false
	sound_button.icon = "sound"
	money_view.name = "Money"
	upgrade_button.name = "Upgrade"
	for c: Control in [money_view, upgrade_button, back_button, restart_button, sound_button, log_button]:
		add_child(c)
	back_button.pressed.connect(func() -> void: back_pressed.emit())
	restart_button.pressed.connect(func() -> void: restart_pressed.emit())
	upgrade_button.pressed.connect(func() -> void: buy_pressed.emit())
	sound_button.pressed.connect(func() -> void: sound_pressed.emit())
	log_button.pressed.connect(func() -> void: log_pressed.emit())


## loud | soft | off
func set_sound(level_name: String) -> void:
	sound_button.icon = {"loud": "sound", "soft": "soft", "off": "mute"}.get(level_name, "sound")
	sound_button.queue_redraw()


func set_play(view: PopPlayView) -> void:
	if play != null:
		play.queue_free()
	play = view
	play.name = "Play"
	add_child(play)
	move_child(play, 0)
	_layout()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_layout()


func _layout() -> void:
	var w := size.x
	var h := size.y
	var col := minf(w, 720.0)
	var x0 := (w - col) / 2
	var bar := 128.0
	back_button.position = Vector2(x0 + 24, 28)
	back_button.size = Vector2(84, 84)
	restart_button.position = Vector2(x0 + col - 108, 28)
	restart_button.size = Vector2(84, 84)
	sound_button.position = Vector2(x0 + col - 200, 28)
	sound_button.size = Vector2(84, 84)
	log_button.position = Vector2(x0 + 24, 160)
	log_button.size = Vector2(72, 72)
	log_button.visible = dev
	money_view.position = Vector2(x0 + 120, 34)
	money_view.size = Vector2(col - 330, 76)
	var bh := clampf(h * 0.13, 120.0, 170.0)
	upgrade_button.size = Vector2(minf(col - 80, 520.0), bh)
	upgrade_button.position = Vector2((w - upgrade_button.size.x) / 2, h - bh - 48)
	if play != null:
		play.position = Vector2(x0, bar)
		play.size = Vector2(col, upgrade_button.position.y - bar - 16)


func refresh(rules: PopRules, p_clock_ms: int) -> void:
	money_view.set_money(rules.money)
	upgrade_button.set_offer(rules.level + 1, rules.cost(), rules.money)
	upgrade_button.set_gain(rules.payout(rules.level), rules.payout(rules.level + 1))
	if play != null:
		play.fx.target = money_view.coin_point() - play.global_position
	if p_clock_ms / 1000 != clock_ms / 1000 or (p_clock_ms >= PopSession.THREE_MINUTES_MS) != (clock_ms >= PopSession.THREE_MINUTES_MS):
		clock_ms = p_clock_ms
		queue_redraw()
	clock_ms = p_clock_ms


## Dev mode always; the trial protocol once three minutes have passed; else never.
func shows_clock() -> bool:
	return dev or (trial and clock_ms >= PopSession.THREE_MINUTES_MS)


func _draw() -> void:
	var w := size.x
	var col := minf(w, 720.0)
	var x0 := (w - col) / 2
	# A soft band behind the top bar and the floor under the machine.
	draw_rect(Rect2(0, 0, w, 140), Color(1, 1, 1, 0.18))
	draw_rect(Rect2(0, size.y * 0.62, w, size.y * 0.38), Color(PopPalette.BG_DEEP, 0.35))
	var three := clock_ms >= PopSession.THREE_MINUTES_MS
	if shows_clock():
		# The clock: dev mode always; for everyone once three minutes have passed.
		var font := ThemeDB.fallback_font
		var s := clock_ms / 1000
		var text := "%d:%02d" % [s / 60, s % 60]
		var fs := 30
		var p := Vector2(x0 + col / 2, 132)
		var tw := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var pill := Rect2(p.x - tw / 2 - 40, p.y - 22, tw + 64, 44)
		PopMachineArt._round_rect(self, pill, 22, Color(PopPalette.GOLD, 0.95) if three else Color(1, 1, 1, 0.7))
		draw_arc(Vector2(pill.position.x + 22, p.y), 12, 0, TAU, 20, PopPalette.INK, 3.0)
		draw_line(Vector2(pill.position.x + 22, p.y), Vector2(pill.position.x + 22, p.y - 8), PopPalette.INK, 3.0)
		draw_line(Vector2(pill.position.x + 22, p.y), Vector2(pill.position.x + 28, p.y), PopPalette.INK, 3.0)
		draw_string(font, Vector2(pill.position.x + 42, p.y + 11), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, PopPalette.INK)
