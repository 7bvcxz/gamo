class_name Hud
extends Control

## The always-visible UI, kept to the corners so the island stays the picture:
##   top-left     Day N, seconds of the day, a donut of the day's progress
##   top-right    money; level with exact EXP; one line of key production
##   right edge   Research, Mailbox, Land, Status (small)
##   bottom-left  Settings, Shop
## Margins respect the device's safe area (notches, rounded corners). Values
## are read from the simulation each frame but labels change only when the
## number does. Buttons emit `action`; what they open arrives in later steps.

signal action(name: StringName)

const MARGIN := 16.0
const GAP := 8.0

var sim: Simulation
var day_panel: PanelContainer
var money_pill: PanelContainer
var exp_pill: PanelContainer
var production_label: Label
var side_buttons: Array[HudButton] = []
var corner_buttons: Array[HudButton] = []
var buttons: Dictionary = {}

var _day_label: Label
var _seconds_label: Label
var _donut: Donut
var _money_label: Label
var _level_label: Label
var _exp_label: Label
var _shown := {}


func setup(p_sim: Simulation, lib: SpriteLibrary) -> void:
	sim = p_sim
	name = "Hud"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	theme = HudTheme.build(sim.data, LocaleService.font_for(LocaleService.current()))

	day_panel = PanelContainer.new()
	day_panel.name = "DayPanel"
	var day_row := HBoxContainer.new()
	day_row.add_theme_constant_override("separation", 12)
	var day_text := VBoxContainer.new()
	day_text.add_theme_constant_override("separation", -4)
	_day_label = _label(28)
	_seconds_label = _label(18)
	day_text.add_child(_day_label)
	day_text.add_child(_seconds_label)
	day_row.add_child(day_text)
	_donut = Donut.new()
	_donut.custom_minimum_size = Vector2(46, 46)
	day_row.add_child(_donut)
	day_panel.add_child(day_row)
	add_child(day_panel)

	money_pill = _pill("MoneyPill", lib.atlas_texture("icon_coin"))
	_money_label = _label(22)
	money_pill.get_child(0).add_child(_money_label)
	add_child(money_pill)

	exp_pill = _pill("ExpPill", lib.atlas_texture("icon_star"))
	_level_label = _label(16)
	_level_label.modulate = Color(1, 1, 1, 0.85)
	_exp_label = _label(18)
	exp_pill.get_child(0).add_child(_level_label)
	exp_pill.get_child(0).add_child(_exp_label)
	add_child(exp_pill)

	production_label = _label(15)
	production_label.name = "Production"
	production_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(production_label)

	for spec: Array in [[&"research", "hud.research", "ui_research"], [&"mailbox", "hud.mailbox", "ui_mail"],
			[&"land", "hud.land", "ui_land"], [&"status", "hud.status", "ui_status"]]:
		side_buttons.append(_button(spec, lib))
	for spec: Array in [[&"settings", "hud.settings", "ui_settings"], [&"shop", "hud.shop", "ui_shop"]]:
		corner_buttons.append(_button(spec, lib))

	resized.connect(_layout)
	refresh(true)
	_layout()


func _label(font_size: int) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", font_size)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _pill(node_name: String, icon: Texture2D) -> PanelContainer:
	var pill := PanelContainer.new()
	pill.name = node_name
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var tex := TextureRect.new()
	tex.texture = icon
	tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tex.custom_minimum_size = Vector2(26, 26)
	tex.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	row.add_child(tex)
	pill.add_child(row)
	return pill


func _button(spec: Array, lib: SpriteLibrary) -> HudButton:
	var b := HudButton.new(spec[0], spec[1], lib.atlas_texture(spec[2]))
	b.pressed.connect(func() -> void: action.emit(b.action))
	add_child(b)
	buttons[spec[0]] = b
	return b


func _process(_delta: float) -> void:
	refresh()


## Updates every value from the simulation; labels change only on difference.
func refresh(force: bool = false) -> void:
	if sim == null:
		return
	var clock := sim.clock
	var secs := clock.time_in_day_ms() / 1000
	var economy: EconomySystem = sim.system(&"economy")
	var prog: ProgressionSystem = sim.system(&"progression")
	_set_text(_day_label, "day", tr("hud.day") % clock.day_number(), force)
	_set_text(_seconds_label, "secs", tr("hud.seconds") % [secs, clock.day_ms / 1000], force)
	_donut.progress = clock.day_progress()
	_set_text(_money_label, "money", _format_money(economy.money), force)
	_set_text(_level_label, "level", tr("hud.level") % prog.level, force)
	_set_text(_exp_label, "exp", tr("hud.exp") % [prog.experience, prog.next_level_exp()], force)
	var production := production_summary()
	_set_text(production_label, "prod", production, force)
	production_label.visible = production != ""


## One short line of what the island makes per day. Empty until something is
## produced (Step 15 onwards fills it), and then it is the only line.
func production_summary() -> String:
	return ""


func _set_text(label: Label, key: String, text: String, force: bool) -> void:
	if force or _shown.get(key) != text:
		_shown[key] = text
		label.text = text


static func _format_money(amount: int) -> String:
	var s := str(absi(amount))
	var out := ""
	while s.length() > 3:
		out = "," + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return ("-" if amount < 0 else "") + s + out


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and sim != null:
		theme.default_font = LocaleService.font_for(LocaleService.current())
		refresh(true)
		_layout.call_deferred()


## Safe area in this control's coordinates (notches, rounded corners), as
## margins. Falls back to a plain margin where the platform reports none.
func safe_margins() -> Dictionary:
	var m := {"left": MARGIN, "top": MARGIN, "right": MARGIN, "bottom": MARGIN}
	var screen := DisplayServer.screen_get_size()
	var safe := DisplayServer.get_display_safe_area()
	if screen.x <= 0 or safe.size.x <= 0 or OS.has_feature("web"):
		return m
	var scale := size / Vector2(DisplayServer.window_get_size())
	m["left"] += safe.position.x * scale.x
	m["top"] += safe.position.y * scale.y
	m["right"] += maxf(0.0, screen.x - safe.end.x) * scale.x
	m["bottom"] += maxf(0.0, screen.y - safe.end.y) * scale.y
	return m


func _layout() -> void:
	var m := safe_margins()
	var w := size.x
	var h := size.y
	day_panel.reset_size()
	day_panel.position = Vector2(m["left"], m["top"])
	money_pill.custom_minimum_size = Vector2(150, 0)
	money_pill.reset_size()
	exp_pill.custom_minimum_size = Vector2(150, 0)
	exp_pill.reset_size()
	var pill_w := maxf(money_pill.size.x, exp_pill.size.x)
	money_pill.size.x = pill_w
	exp_pill.size.x = pill_w
	money_pill.position = Vector2(w - m["right"] - pill_w, m["top"])
	exp_pill.position = Vector2(w - m["right"] - pill_w, money_pill.position.y + money_pill.size.y + GAP)
	production_label.reset_size()
	production_label.position = Vector2(w - m["right"] - production_label.size.x, exp_pill.position.y + exp_pill.size.y + 4)
	var y := exp_pill.position.y + exp_pill.size.y + 34
	for b: HudButton in side_buttons:
		b.position = Vector2(w - m["right"] - b.size.x, y)
		y += b.size.y + GAP
	var x: float = m["left"]
	for b: HudButton in corner_buttons:
		b.position = Vector2(x, h - m["bottom"] - b.size.y)
		x += b.size.x + GAP


## Screen rectangles of everything the HUD draws (tests check overlaps).
func occupied_rects() -> Array[Rect2]:
	var out: Array[Rect2] = [day_panel.get_rect(), money_pill.get_rect(), exp_pill.get_rect()]
	for b: HudButton in side_buttons + corner_buttons:
		out.append(b.get_rect())
	return out
