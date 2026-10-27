class_name Hud
extends Control

## The always-visible UI, kept to the corners so the island stays the picture:
##   top-left     Day N, seconds of the day, a donut of the day's progress
##   top-right    money; level with exact EXP; one line of key production
##   right edge   Research, Mailbox, Status (small); below them, a little
##                under the screen's middle, Hire (Step 59)
##   bottom-left  Settings, Shop (the Premium Shop, Step 59 -- real money,
##                never hiring)
## Margins respect the device's safe area (notches, rounded corners). Values
## are read from the simulation each frame but labels change only when the
## number does. Buttons emit `action`; what they open arrives in later steps.

signal action(name: StringName)
## After every layout pass: other bottom UI lines up with the corner buttons.
signal layout_changed

const MARGIN := 16.0
const GAP := 8.0

var sim: Simulation
## The white glass of the reading panels (Step 52); frames take it.
var card_theme: Theme
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
## Step 54: a few frames -- enough for one frame's burst of events to read as
## one pop; at 0.3 s the pop came visibly late after the tap. A pop still on
## screen grows with what follows (_pop_amount).
const FEEDBACK_WINDOW := 0.08
## How long an amount stays readable before it fades (Step 54: was 0.3 s of a
## 1.1 s rise -- gone before the eye got there).
const POP_HOLD := 0.8
const POP_SECONDS := 1.6
## A dark rim around every pop: readable over the bright sea and the grass.
const POP_OUTLINE := Color(0.03, 0.1, 0.24, 0.95)
var _pending_money := 0
## Money spent in the same moment, popped on its own: a $80 hire beside an
## $8 harvest read "-$72" to the blind players (Step 50).
var _pending_spent := 0
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
## Step 59: hiring a Momo, on its own at the right edge a little below the
## middle -- the island's growth, apart from the Premium Shop's purchases.
var hire_button: HudButton
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
## Step 54: the level's progress as a bar, and the level-up burst at the card.
var exp_bar: ExpBar
var level_fx: LevelUpFx
## The level before the levels gathered in this feedback window.
var _level_from := 0
var _shown := {}


## What the store holds, at a glance: up to STOCK_MAX items the island has
## now (wood, research notes, stone...), each its icon and count, under the
## day panel (Step 50: blind players never found where the wood and the
## flasks were counted -- only in Status > Store).
var stock_row: HBoxContainer
const STOCK_MAX := 4
## The settlement's next step, met needs out of all ("City 2/4"); a tap opens
## Status where they are listed (Step 50: every blind round found that goal
## only after 6-9 minutes, then called it the clearest thing to play for).
var goal_button: Button
var _stock_lib: SpriteLibrary
var _stock_shown := ""


func setup(p_sim: Simulation, lib: SpriteLibrary) -> void:
	sim = p_sim
	name = "Hud"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	theme = HudTheme.build(sim.data, LocaleService.font_for(LocaleService.current()))
	card_theme = HudTheme.build_card(sim.data, theme.default_font)

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

	# Step 54: money and the level are the HUD's first read -- larger than
	# anything else in it, the level with its bar.
	money_pill = _pill("MoneyPill", lib.atlas_texture("icon_coin"), 38.0)
	_money_label = _label(32)
	money_pill.get_child(0).add_child(_money_label)
	add_child(money_pill)

	exp_pill = _pill("ExpPill", lib.atlas_texture("icon_star"), 38.0)
	var exp_col := VBoxContainer.new()
	exp_col.add_theme_constant_override("separation", 2)
	exp_col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var exp_row := HBoxContainer.new()
	exp_row.add_theme_constant_override("separation", 8)
	exp_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_level_label = _label(24)
	_level_label.add_theme_color_override("font_color", sim.data.color("ui_accent"))
	_exp_label = _label(17)
	_exp_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_exp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	exp_row.add_child(_level_label)
	exp_row.add_child(_exp_label)
	exp_col.add_child(exp_row)
	exp_bar = ExpBar.new()
	exp_bar.name = "ExpBar"
	exp_bar.custom_minimum_size = Vector2(160, 12)
	exp_col.add_child(exp_bar)
	exp_pill.get_child(0).add_child(exp_col)
	add_child(exp_pill)
	level_fx = LevelUpFx.new()
	add_child(level_fx)

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
	_stock_lib = lib
	stock_row = HBoxContainer.new()
	stock_row.name = "Stock"
	stock_row.add_theme_constant_override("separation", 10)
	stock_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stock_row.visible = false
	add_child(stock_row)
	goal_button = Button.new()
	goal_button.name = "Goal"
	goal_button.focus_mode = Control.FOCUS_NONE
	goal_button.add_theme_font_size_override("font_size", 15)
	goal_button.custom_minimum_size = Vector2(0, 40)
	goal_button.pressed.connect(func() -> void: action.emit(&"status"))
	goal_button.visible = false
	add_child(goal_button)

	for spec: Array in [[&"research", "hud.research", "ui_research"], [&"mailbox", "hud.mailbox", "ui_mail"],
			[&"status", "hud.status", "ui_status"]]:
		side_buttons.append(_button(spec, lib))
	hire_button = _button([&"hire", "hud.hire", "ui_hire"], lib)
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
## Step 57: a letter's arrival is told by the mailbox button alone -- its dot
## shows at once and swells twice, its icon wiggles once. Letters that come
## close together (or a pile after a catch-up, which plays nothing) do not
## replay it: one news at most every NEWS_GAP_MS.
const NEWS_GAP_MS := 6000
var _news_at := -NEWS_GAP_MS


func letter_news() -> void:
	var b: HudButton = buttons.get(&"mailbox")
	if b == null:
		return
	b.badge = true
	var now := Time.get_ticks_msec()
	if now - _news_at >= NEWS_GAP_MS:
		_news_at = now
		b.pulse()


func _on_sim_event(type: StringName, payload: Dictionary) -> void:
	if type == &"game_loaded":
		# A loaded island's level is shown as it is, not slid to (Step 54).
		exp_bar.level = 0
	if sim.replaying:
		return
	match type:
		&"money_changed":
			var d := int(payload.get("delta", 0))
			if d >= 0:
				_pending_money += d
			else:
				_pending_spent += d
		&"exp_gained":
			_pending_exp += int(payload.get("amount", 0))
		&"level_up":
			if _pending_level == 0:
				_level_from = int(payload["level"]) - 1
			_pending_level = maxi(_pending_level, int(payload["level"]))
		&"research_completed":
			_pending_research.append(payload)
		&"letter_written":
			letter_news()
			return
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
	var spent := _pending_spent
	var exp_gain := _pending_exp
	var level := _pending_level
	var research := _pending_research.duplicate()
	_pending_money = 0
	_pending_spent = 0
	_pending_exp = 0
	_pending_level = 0
	_pending_research.clear()
	if not FxPrefs.enabled:
		return
	if money != 0:
		pop_money(money)
	if spent != 0:
		pop_money(spent)
	if exp_gain > 0:
		_pop_amount("exp", exp_pill, exp_gain, Color(1, 1, 1, 0.95))
	if level > 0:
		level_up(_level_from, level)
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
	l.add_theme_font_size_override("font_size", 24)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", POP_OUTLINE)
	l.add_theme_constant_override("outline_size", 10)
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
	_pop_amount("money" if delta > 0 else "spent", money_pill, delta, Color("#ffe27a") if delta > 0 else Color("#ffb3a8"))
	if FxPrefs.moving():
		money_pill.pivot_offset = money_pill.size * 0.5
		var bump := create_tween()
		bump.tween_property(money_pill, "scale", Vector2(1.08, 1.08), 0.1)
		bump.tween_property(money_pill, "scale", Vector2.ONE, 0.18)


## A level gained (or several in one moment): the burst at the EXP card, and
## the card itself pulsing once. With effects off the bar and numbers still
## change -- only the show is skipped (flush_feedback returns before here).
func level_up(from: int, to: int) -> void:
	_log_pop(tr("fx.level_up") % to)
	level_fx.play(exp_pill.get_rect(), from, to)
	if FxPrefs.moving():
		exp_pill.pivot_offset = exp_pill.size * 0.5
		var bump := create_tween()
		bump.tween_property(exp_pill, "scale", Vector2(1.12, 1.12), 0.12)
		bump.tween_property(exp_pill, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


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
		l.add_theme_font_size_override("font_size", 32 if key == "money" else 28)
		l.add_theme_color_override("font_outline_color", POP_OUTLINE)
		l.add_theme_constant_override("outline_size", 10)
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(l)
	l.add_theme_color_override("font_color", color)
	if key == "money" or key == "spent":
		l.text = ("+$%s" if total > 0 else "-$%s") % FxPrefs.compact(absi(total))
	else:
		l.text = "+%s EXP" % FxPrefs.compact(total)
	l.reset_size()
	l.position = anchor.position + Vector2(-l.size.x - 10.0, (anchor.size.y - l.size.y) * 0.5)
	if key == "spent":
		# Under the pill, apart from what came in.
		l.position.y += anchor.size.y * 0.7
	_log_pop(l.text)
	_live[key] = {"label": l, "total": total, "at": now, "tween": _animate(l, -16.0, POP_SECONDS, 0.0)}


## Rises and fades -- or, with reduced motion, only fades where it is.
func _animate(l: Label, rise: float, seconds: float, delay: float) -> Tween:
	var tween := create_tween()
	if delay > 0.0:
		l.modulate.a = 0.0
		tween.tween_interval(delay)
		tween.tween_property(l, "modulate:a", 1.0, 0.12)
	if FxPrefs.moving():
		tween.tween_property(l, "position:y", l.position.y + rise, seconds).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.parallel().tween_property(l, "modulate:a", 0.0, maxf(seconds - POP_HOLD, 0.2)).set_delay(POP_HOLD)
	else:
		tween.tween_property(l, "modulate:a", 0.0, maxf(seconds - POP_HOLD, 0.2)).set_delay(POP_HOLD)
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


func _pill(node_name: String, icon: Texture2D, icon_px: float = 26.0) -> PanelContainer:
	var pill := PanelContainer.new()
	pill.name = node_name
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var tex := TextureRect.new()
	tex.texture = icon
	tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tex.custom_minimum_size = Vector2(icon_px, icon_px)
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
	_set_text(_exp_label, "exp", tr("hud.exp") % [_format_money(prog.experience), _format_money(prog.next_level_exp())], force)
	# Forced (a load, a new language): set at once; otherwise it slides.
	exp_bar.show_progress(prog.level, prog.experience, prog.next_level_exp(), not force)
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
		# Step 57: the dot is news -- a topic that became available and has
		# not been shown yet; opening Research acknowledges it.
		var want := not research.new_topics().is_empty()
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
	# A dot on Hire when a Momo can be hired and there is work nobody looks
	# after (Step 50: the blind players never found what to buy next). Never
	# on the Premium Shop (Step 59).
	if hire_button != null and (force or Time.get_ticks_msec() >= _hire_check_at):
		# Twice a second is plenty, and a large island has many buildings.
		_hire_check_at = Time.get_ticks_msec() + 500
		var want_hire := _hire_worth_it()
		if hire_button.badge != want_hire:
			hire_button.badge = want_hire
	_refresh_stock()
	_refresh_goal()
	var production := production_summary()
	var shown_before := production_label.text
	_set_text(production_label, "prod", production, force)
	production_label.visible = production != ""
	# Placed by its width: laid out while empty, a new line grew past the
	# screen's right edge ("1 c…", found by the blind playtest, Step 45).
	if production_label.text != shown_before:
		_layout.call_deferred()


func _set_text_button(b: Button, text: String) -> void:
	if b.text != text:
		b.text = text
		b.reset_size()


## "City 2/4": the next tier and how many of its needs are met, or "".
func goal_text() -> String:
	var tiers: TierSystem = sim.system(&"tiers")
	if tiers == null or tiers.is_top():
		return ""
	var need := tiers.progress()
	var met := need.filter(func(p: Dictionary) -> bool: return bool(p["met"])).size()
	return tr("hud.goal").format({"tier": tr("tier." + tiers.tier_name(tiers.tier + 1)), "met": met, "of": need.size()})


func _refresh_goal() -> void:
	var text := goal_text()
	if goal_button.text != text:
		goal_button.text = text
		goal_button.visible = text != ""
		_layout.call_deferred()


## The items the store holds now, in data order (never what is sold the
## moment it is made), at most STOCK_MAX: [[item, count], ...].
func stock() -> Array:
	var inv: InventorySystem = sim.system(&"inventory")
	var economy: EconomySystem = sim.system(&"economy")
	var out: Array = []
	for item: String in sim.data.table("items").get("items", {}):
		if out.size() >= STOCK_MAX:
			break
		if inv.count(item) > 0 and not economy.sells_at_once(item):
			out.append([item, inv.count(item)])
	return out


func _refresh_stock() -> void:
	var items := stock()
	var sig := str(items)
	if sig == _stock_shown:
		return
	_stock_shown = sig
	for c: Node in stock_row.get_children():
		c.queue_free()
	for e: Array in items:
		var icon := TextureRect.new()
		icon.texture = _stock_lib.atlas_texture(String(sim.data.item(String(e[0])).get("icon", "")))
		icon.custom_minimum_size = Vector2(22, 22)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon.name = "Icon_" + String(e[0])
		stock_row.add_child(icon)
		var l := _label(15)
		l.name = "Count_" + String(e[0])
		l.text = str(int(e[1]))
		l.add_theme_color_override("font_outline_color", Color(0.05, 0.15, 0.3, 0.8))
		l.add_theme_constant_override("outline_size", 5)
		stock_row.add_child(l)
	var was := stock_row.visible
	stock_row.visible = not items.is_empty()
	if was != stock_row.visible or stock_row.visible:
		_layout.call_deferred()


## One short line: what the island's work earned in the last minute
## (finished work is money at once, Step 50). Empty before the first income.
func production_summary() -> String:
	var rate := (sim.system(&"economy") as EconomySystem).income_per_minute()
	if rate <= 0:
		return ""
	return tr("hud.rate") % _format_money(rate)


var _hire_check_at := 0


## Whether hiring now would put a Momo to work: affordable, and a building
## that nobody looks after.
func _hire_worth_it() -> bool:
	var momos: MomoSystem = sim.system(&"momo")
	if momos == null or not (sim.system(&"economy") as EconomySystem).can_afford(momos.hire_cost()):
		return false
	var bs: BuildingSystem = sim.system(&"buildings")
	for id: int in bs.ids():
		if momos.slots_of(id) > 0 and momos.watchers_of(id).is_empty() and bs.get_building(id)["state"] != BuildingSystem.CONSTRUCTING:
			return true
	return false


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
		card_theme.default_font = theme.default_font
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
	money_pill.custom_minimum_size = Vector2(200, 0)
	money_pill.reset_size()
	exp_pill.custom_minimum_size = Vector2(200, 0)
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
	below += burst_pill.size.y + GAP if burst_pill.visible else 0.0
	stock_row.reset_size()
	stock_row.position = Vector2(m["left"] + 4.0, below)
	if stock_row.visible:
		below += stock_row.size.y + GAP
	goal_button.reset_size()
	goal_button.position = Vector2(m["left"], below)
	production_label.reset_size()
	production_label.position = Vector2(w - m["right"] - production_label.size.x, exp_pill.position.y + exp_pill.size.y + 4)
	var y := exp_pill.position.y + exp_pill.size.y + 34
	for b: HudButton in side_buttons:
		b.position = Vector2(w - m["right"] - b.size.x, y)
		y += b.size.y + GAP
	hire_button.position = Vector2(w - m["right"] - hire_button.size.x, hire_y(y, h, m["bottom"], hire_button.size.y))
	var x: float = m["left"]
	for b: HudButton in corner_buttons:
		b.position = Vector2(x, h - m["bottom"] - b.size.y)
		x += b.size.x + GAP
	bottom_left_end = x
	bottom_margin = m["bottom"]
	layout_changed.emit()


## Where Hire stands (its top): a little below the middle of the screen
## (HIRE_AT of the height, at its centre), never on the side buttons above it
## (`below` is where they end) and clear of what a selected building shows
## at the bottom right -- the stage cards and, above them, the check and the
## bin (ContextPanel), which a short landscape window brings up to the
## middle.
const HIRE_AT := 0.56
const BOTTOM_RIGHT_RESERVED := ContextPanel.CARD_SIZE.y + 8.0 + 2.0 * (52.0 + 8.0)


static func hire_y(below: float, h: float, bottom: float, button_h: float) -> float:
	var want := h * HIRE_AT - button_h * 0.5
	var lowest := h - bottom - BOTTOM_RIGHT_RESERVED - GAP - button_h
	return maxf(below + GAP, minf(want, lowest))


## Screen rectangles of everything the HUD draws (tests check overlaps).
func occupied_rects() -> Array[Rect2]:
	var out: Array[Rect2] = [day_panel.get_rect(), money_pill.get_rect(), exp_pill.get_rect()]
	for b: HudButton in side_buttons + corner_buttons + [hire_button]:
		out.append(b.get_rect())
	if goal_button.visible:
		out.append(goal_button.get_rect())
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
