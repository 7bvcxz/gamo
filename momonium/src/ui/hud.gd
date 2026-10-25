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
## After every layout pass: other bottom UI lines up with the corner buttons.
signal layout_changed

const MARGIN := 16.0
const GAP := 8.0

var sim: Simulation
var day_panel: PanelContainer
var money_pill: PanelContainer
var exp_pill: PanelContainer
var production_label: Label
var side_buttons: Array[HudButton] = []
## Supply / draw in kW, once power is part of the island; tap for the details.
var power_pill: Button
var power_label: Label
## The Clock Tower's burst: a tiny dial -- gold and counting down while work
## goes twice as fast, dim and counting to the next burst otherwise.
var burst_pill: Control
## Feedback gathered within this many seconds pops once (see _on_sim_event).
const FEEDBACK_WINDOW := 0.3
var _pending_money := 0
var _pending_exp := 0
var _pending_level := 0
var _pending_research: Array = []
var _feedback_queued := false
var _live := {}
## Every pop shown, newest last (tests, the E2E bridge).
var pops: Array[String] = []
var burst_text := ""
var burst_active := false
var burst_fraction := 0.0
var corner_buttons: Array[HudButton] = []
var buttons: Dictionary = {}
## Right edge of the bottom-left buttons and the bottom margin, after layout.
var bottom_left_end := 168.0
var bottom_margin := MARGIN

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

	power_pill = Button.new()
	power_pill.name = "PowerPill"
	power_pill.custom_minimum_size = Vector2(150, 44)
	power_pill.focus_mode = Control.FOCUS_NONE
	power_pill.visible = false
	var pill_row := HBoxContainer.new()
	pill_row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pill_row.offset_left = 10
	pill_row.offset_right = -10
	pill_row.add_theme_constant_override("separation", 6)
	pill_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bolt := TextureRect.new()
	bolt.texture = lib.atlas_texture("ui_power")
	bolt.custom_minimum_size = Vector2(22, 22)
	bolt.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bolt.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	bolt.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bolt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pill_row.add_child(bolt)
	power_label = Label.new()
	power_label.add_theme_font_size_override("font_size", 17)
	power_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	power_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pill_row.add_child(power_label)
	power_pill.add_child(pill_row)
	power_pill.pressed.connect(func() -> void: action.emit(&"power"))
	add_child(power_pill)
	burst_pill = Control.new()
	burst_pill.name = "BurstPill"
	burst_pill.custom_minimum_size = Vector2(118, 34)
	burst_pill.size = Vector2(118, 34)
	burst_pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	burst_pill.visible = false
	burst_pill.draw.connect(_draw_burst)
	add_child(burst_pill)

	production_label = _label(15)
	production_label.name = "Production"
	production_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(production_label)

	for spec: Array in [[&"research", "hud.research", "ui_research"], [&"mailbox", "hud.mailbox", "ui_mail"],
			[&"status", "hud.status", "ui_status"]]:
		side_buttons.append(_button(spec, lib))
	for spec: Array in [[&"settings", "hud.settings", "ui_settings"], [&"shop", "hud.shop", "ui_shop"]]:
		corner_buttons.append(_button(spec, lib))

	resized.connect(_layout)
	sim.bus.emitted.connect(_on_sim_event)
	refresh(true)
	_layout()


## Feedback from the simulation, gathered for a moment so a burst -- the sale
## and a harvest in one frame, many Momo finishing together -- reads as one
## pop per kind, not a stack. Nothing pops while time away is being caught up
## (the welcome-back card sums it), and nothing at all with effects off.
func _on_sim_event(type: StringName, payload: Dictionary) -> void:
	if sim.replaying:
		return
	match type:
		&"money_changed":
			_pending_money += int(payload.get("delta", 0))
		&"exp_gained":
			_pending_exp += int(payload.get("amount", 0))
		&"level_up":
			_pending_level = maxi(_pending_level, int(payload["level"]))
		&"research_completed":
			_pending_research.append(payload)
		_:
			return
	if _feedback_queued:
		return
	_feedback_queued = true
	if is_inside_tree():
		get_tree().create_timer(FEEDBACK_WINDOW).timeout.connect(flush_feedback)
	else:
		flush_feedback()


## Shows what gathered since the last pop, once.
func flush_feedback() -> void:
	_feedback_queued = false
	var money := _pending_money
	var exp_gain := _pending_exp
	var level := _pending_level
	var research := _pending_research.duplicate()
	_pending_money = 0
	_pending_exp = 0
	_pending_level = 0
	_pending_research.clear()
	if not FxPrefs.enabled:
		return
	if money != 0:
		pop_money(money)
	if exp_gain > 0:
		_pop_amount("exp", exp_pill, exp_gain, Color(1, 1, 1, 0.95))
	if level > 0:
		_pop(exp_pill, tr("fx.level_up") % level, Color("#ffe27a"), 0.45, true)
	if not research.is_empty() and buttons.has(&"research"):
		_pop(buttons[&"research"], research_text(research), Color("#b7f08a"), 0.0, true)


## What research just finished, in a line or two: one technology with what
## its new level does -- before and after, from the same effect data the
## simulation applies -- or how many at once.
func research_text(done: Array) -> String:
	var rs: ResearchSystem = sim.system(&"research")
	if done.size() > 1:
		return tr("fx.research_many") % done.size()
	var id := String(done[0]["id"])
	var lv := int(done[0].get("level", rs.level(id)))
	var text := tr("fx.research_done") % tr(String(rs.node(id).get("name", "")))
	var now := ResearchText.at_level(sim, id, lv) if lv > 0 else ""
	var before := ResearchText.at_level(sim, id, lv - 1) if lv > 1 else ""
	if now != "" and before != "" and before != now:
		text += "\n" + tr("fx.before_after").format({"before": before, "after": now})
	elif now != "":
		text += "\n" + now
	return text


## A short line beside `anchor`, drifting up and fading: to its left (the
## pills and side buttons sit at the right edge), so it never covers another
## control; long text wraps rather than leaving the screen.
func _pop(anchor: Control, text: String, color: Color, delay: float = 0.0, side: bool = false) -> void:
	var l := Label.new()
	l.text = text
	l.name = "Pop"
	l.add_theme_font_size_override("font_size", 20)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0.05, 0.15, 0.3, 0.8))
	l.add_theme_constant_override("outline_size", 6)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if side and text.length() > 18:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		l.custom_minimum_size.x = minf(340.0, anchor.position.x - 24.0)
	add_child(l)
	l.reset_size()
	if side:
		l.position = anchor.position + Vector2(-l.size.x - 10.0, anchor.size.y * 0.5 - 14.0)
	else:
		l.position = anchor.position + Vector2(anchor.size.x * 0.5 - l.size.x * 0.5, anchor.size.y + 2)
	l.position.x = clampf(l.position.x, 8.0, maxf(size.x - l.size.x - 8.0, 8.0))
	_log_pop(text)
	_animate(l, -16.0 if side else 34.0, 1.0 + (0.8 if text.length() > 18 else 0.0), delay)


## A "+$5" (or "-$10") beside the money pill, and a little bounce of the
## pill: the number changed, here is by how much.
func pop_money(delta: int) -> void:
	_pop_amount("money", money_pill, delta, Color("#ffe27a") if delta > 0 else Color("#ffb3a8"))
	if FxPrefs.moving():
		money_pill.pivot_offset = money_pill.size * 0.5
		var bump := create_tween()
		bump.tween_property(money_pill, "scale", Vector2(1.08, 1.08), 0.1)
		bump.tween_property(money_pill, "scale", Vector2.ONE, 0.18)


## An amount beside its pill. While the last one for the same pill is still
## fresh it grows instead (+$5 then +$3 reads +$8): two pops never stack on
## one spot.
func _pop_amount(key: String, anchor: Control, amount: int, color: Color) -> void:
	var live: Dictionary = _live.get(key, {})
	var now := Time.get_ticks_msec()
	var l: Label = live.get("label") if not live.is_empty() and is_instance_valid(live.get("label")) else null
	var total := amount
	if l != null and now - int(live["at"]) < 800 and signi(int(live["total"])) == signi(amount):
		total += int(live["total"])
		(live["tween"] as Tween).kill()
		l.modulate.a = 1.0
	else:
		l = Label.new()
		l.name = "Pop"
		l.add_theme_font_size_override("font_size", 24 if key == "money" else 20)
		l.add_theme_color_override("font_outline_color", Color(0.05, 0.15, 0.3, 0.8))
		l.add_theme_constant_override("outline_size", 6)
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(l)
	l.add_theme_color_override("font_color", color)
	if key == "money":
		l.text = ("+$%s" if total > 0 else "-$%s") % FxPrefs.compact(absi(total))
	else:
		l.text = "+%s EXP" % FxPrefs.compact(total)
	l.reset_size()
	l.position = anchor.position + Vector2(-l.size.x - 10.0, (anchor.size.y - l.size.y) * 0.5)
	_log_pop(l.text)
	_live[key] = {"label": l, "total": total, "at": now, "tween": _animate(l, -16.0, 1.1, 0.0)}


## Rises and fades -- or, with reduced motion, only fades where it is.
func _animate(l: Label, rise: float, seconds: float, delay: float) -> Tween:
	var tween := create_tween()
	if delay > 0.0:
		l.modulate.a = 0.0
		tween.tween_interval(delay)
		tween.tween_property(l, "modulate:a", 1.0, 0.12)
	if FxPrefs.moving():
		tween.tween_property(l, "position:y", l.position.y + rise, seconds).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.parallel().tween_property(l, "modulate:a", 0.0, seconds).set_delay(0.3)
	else:
		tween.tween_property(l, "modulate:a", 0.0, seconds).set_delay(0.5)
	tween.tween_callback(l.queue_free)
	return tween


func _log_pop(text: String) -> void:
	pops.append(text)
	if pops.size() > 40:
		pops.pop_front()


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
	var mail: MailSystem = sim.system(&"mail")
	var mail_button: HudButton = buttons.get(&"mailbox")
	if mail != null and mail_button != null and mail_button.badge != (mail.unread_count() > 0):
		mail_button.badge = mail.unread_count() > 0
	var power: PowerSystem = sim.system(&"power")
	if power != null:
		var show := power.in_use()
		if power_pill.visible != show:
			power_pill.visible = show
			_layout.call_deferred()
		if show:
			var text := "%s / %s kW" % [BuildingDetailView.amount(snappedf(power.supply(), 0.1)), BuildingDetailView.amount(snappedf(power.demand(), 0.1))]
			if power_label.text != text:
				power_label.text = text
			var r := power.ratio()
			power_pill.modulate = Color.WHITE if r >= 0.999 else (Color("#ffb347") if r > 0.0 else Color("#ff7a6e"))
	var research: ResearchSystem = sim.system(&"research")
	var research_button: HudButton = buttons.get(&"research")
	if research != null and research_button != null:
		var want := research.something_to_start()
		if research_button.badge != want:
			research_button.badge = want
	var specials: SpecialSystem = sim.system(&"specials")
	if specials != null:
		var b := specials.burst()
		if burst_pill.visible != bool(b["standing"]):
			burst_pill.visible = bool(b["standing"])
			_layout.call_deferred()
		if b["standing"]:
			burst_active = bool(b["active"])
			var left := int(ceil(int(b["remaining_ms"]) / 1000.0))
			burst_text = ("x2 " if burst_active else "") + "%d:%02d" % [left / 60, left % 60]
			var e := specials.effect("work_burst")
			var span := float(e.get("active_seconds", 30)) * 1000.0 if burst_active else float(int(b["cycle_ms"]) - int(float(e.get("active_seconds", 30)) * 1000.0))
			burst_fraction = clampf(float(int(b["remaining_ms"])) / maxf(span, 1.0), 0.0, 1.0)
			burst_pill.queue_redraw()
	# A red dot on Status when the settlement can be promoted.
	var tiers: TierSystem = sim.system(&"tiers")
	var status_button: HudButton = buttons.get(&"status")
	if tiers != null and status_button != null and status_button.badge != tiers.can_promote():
		status_button.badge = tiers.can_promote()
	var production := production_summary()
	_set_text(production_label, "prod", production, force)
	production_label.visible = production != ""


func _set_text_button(b: Button, text: String) -> void:
	if b.text != text:
		b.text = text
		b.reset_size()


## One short line: crops waiting in the store and what they fetch at the next
## day boundary. Empty when the store holds nothing to sell.
func production_summary() -> String:
	var economy: EconomySystem = sim.system(&"economy")
	var inv: InventorySystem = sim.system(&"inventory")
	var crops := 0
	for item: String in inv.of_kind("crop"):
		crops += inv.count(item)
	if crops <= 0:
		return ""
	return tr("hud.store") % [crops, economy.pending_sale()]


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
	if OS.has_feature("web"):
		return margins_for(Vector2i.ZERO, Rect2i(), Vector2i.ONE, size)
	return margins_for(DisplayServer.screen_get_size(), DisplayServer.get_display_safe_area(), DisplayServer.window_get_size(), size)


## The margins for a screen of `screen` pixels whose safe area is `safe`, shown
## in a window of `window` pixels on a control of `control` units: the plain
## margin plus each edge's cut-out (a notch, a punch-hole camera, the gesture
## bar), scaled to the control.
static func margins_for(screen: Vector2i, safe: Rect2i, window: Vector2i, control: Vector2) -> Dictionary:
	var m := {"left": MARGIN, "top": MARGIN, "right": MARGIN, "bottom": MARGIN}
	if screen.x <= 0 or safe.size.x <= 0 or window.x <= 0 or window.y <= 0:
		return m
	var scale := control / Vector2(window)
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
	power_pill.reset_size()
	power_pill.position = Vector2(m["left"], day_panel.position.y + day_panel.size.y + GAP)
	var below := power_pill.position.y + (power_pill.size.y + GAP if power_pill.visible else 0.0)
	burst_pill.position = Vector2(m["left"], below)
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
	bottom_left_end = x
	bottom_margin = m["bottom"]
	layout_changed.emit()


## Screen rectangles of everything the HUD draws (tests check overlaps).
func occupied_rects() -> Array[Rect2]:
	var out: Array[Rect2] = [day_panel.get_rect(), money_pill.get_rect(), exp_pill.get_rect()]
	for b: HudButton in side_buttons + corner_buttons:
		out.append(b.get_rect())
	return out


func _draw_burst() -> void:
	var r := Rect2(Vector2.ZERO, burst_pill.size)
	burst_pill.draw_style_box(burst_pill.get_theme_stylebox("panel", "PanelContainer"), r)
	var c := Vector2(17, r.size.y * 0.5)
	var col := Color("#ffd45a") if burst_active else Color(1, 1, 1, 0.55)
	burst_pill.draw_arc(c, 10.0, 0.0, TAU, 24, Color(1, 1, 1, 0.18), 3.0, true)
	burst_pill.draw_arc(c, 10.0, -PI * 0.5, -PI * 0.5 + TAU * burst_fraction, 24, col, 3.0, true)
	burst_pill.draw_line(c, c + Vector2(0, -6), col, 2.0, true)
	burst_pill.draw_line(c, c + Vector2(4, 0), col, 2.0, true)
	var font := burst_pill.get_theme_default_font()
	burst_pill.draw_string(font, Vector2(34, r.size.y * 0.5 + 6), burst_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 17, col)
