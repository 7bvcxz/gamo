extends "res://tests/framework/test_case.gd"

## Step 52: the UI in the concept art's two glasses. The HUD keeps its navy
## glass and white text; a panel you read is frosted white glass with navy
## ink. Views name a meaning (GoodLabel, a bar's track, a glyph icon) and each
## theme answers in colours that read on it. The bottom job cards are the
## concept's pastel cards, one colour per job.

const MainScene := preload("res://scenes/main.tscn")

var main: Node
var sim: Simulation
var hud: Hud


func before_each() -> void:
	main = MainScene.instantiate()
	tree.root.add_child(main)
	await tree.process_frame
	sim = main.get("sim")
	sim.time_scale = 0.0
	hud = main.get("hud")
	LocaleService.apply("en")


func after_each() -> void:
	main.queue_free()
	await tree.process_frame


## WCAG contrast of two colours (1..21).
static func _contrast(a: Color, b: Color) -> float:
	var la := _lum(a)
	var lb := _lum(b)
	return (maxf(la, lb) + 0.05) / (minf(la, lb) + 0.05)


static func _lum(c: Color) -> float:
	var f := func(v: float) -> float: return v / 12.92 if v <= 0.03928 else pow((v + 0.055) / 1.055, 2.4)
	return 0.2126 * f.call(c.r) + 0.7152 * f.call(c.g) + 0.0722 * f.call(c.b)


func test_reading_panels_are_white_glass_with_navy_ink() -> void:
	main.call("_on_hud_action", &"status")
	var frame: PanelFrame = main.get("status_frame")
	assert_true(frame.visible, "Status opens")
	assert_eq(frame.theme, hud.card_theme, "the frame wears the card theme")
	var card := frame.card.get_theme_stylebox("panel") as StyleBoxFlat
	assert_true(card.bg_color.r > 0.9 and card.bg_color.g > 0.9 and card.bg_color.b > 0.9 and card.bg_color.a > 0.8, "the card is frosted white (%s)" % card.bg_color)
	var title := frame.title_label
	assert_eq(title.get_theme_color("font_color"), HudTheme.INK, "its text is navy ink")
	# The HUD keeps the navy glass and white text.
	var day := hud.day_panel.get_theme_stylebox("panel") as StyleBoxFlat
	assert_true(day.bg_color.b > day.bg_color.r + 0.2 and day.bg_color.r < 0.3, "the HUD stays navy (%s)" % day.bg_color)
	assert_eq(hud.theme.get_color("font_color", "Label"), Color.WHITE, "with white text")


func test_every_meaning_reads_on_its_own_glass() -> void:
	var white := Color(0.97, 0.98, 1.0)
	var navy := Color("#163f78")
	for variation: String in ["GoodLabel", "BadLabel", "GoldLabel", "InfoLabel"]:
		var on_card := hud.card_theme.get_color("font_color", variation)
		var on_hud := hud.theme.get_color("font_color", variation)
		assert_true(_contrast(on_card, white) >= 3.0, "%s on white glass: contrast %.1f" % [variation, _contrast(on_card, white)])
		assert_true(_contrast(on_hud, navy) >= 3.0, "%s on navy glass: contrast %.1f" % [variation, _contrast(on_hud, navy)])
	assert_true(_contrast(HudTheme.INK, white) >= 7.0, "ink on white: %.1f" % _contrast(HudTheme.INK, white))
	for key: String in ["track", "glyph", "line"]:
		assert_true(hud.card_theme.has_color(key, "Ink") and hud.theme.has_color(key, "Ink"), "both themes answer %s" % key)
	assert_true(_contrast(hud.card_theme.get_color("glyph", "Ink"), white) >= 4.5, "a glyph icon reads on white glass")
	var sel := hud.card_theme.get_stylebox("normal", "SelectedButton") as StyleBoxFlat
	assert_true(_contrast(sel.bg_color, white) >= 3.0, "the chosen tab stands out of the card")


func test_a_white_glyph_icon_turns_to_ink_in_a_panel() -> void:
	var lib := SpriteLibrary.load_atlas()
	var icon := PanelViews.icon(lib, "ui_status", 30.0)
	assert_true(icon is GlyphIcon, "a line icon is a glyph icon")
	main.call("_on_hud_action", &"status")
	var frame: PanelFrame = main.get("status_frame")
	frame.body.add_child(icon)
	await tree.process_frame
	assert_eq(icon.self_modulate, hud.card_theme.get_color("glyph", "Ink"), "navy in a reading card")
	var painted := PanelViews.icon(lib, "ui_harvest", 30.0)
	assert_false(painted is GlyphIcon, "a painted icon keeps its colours")
	painted.free()


func test_tabs_mark_the_current_one_by_style() -> void:
	main.call("_on_hud_action", &"status")
	var frame: PanelFrame = main.get("status_frame")
	assert_eq((frame.tabs[0]["button"] as Button).theme_type_variation, &"SelectedButton", "the open tab is filled")
	assert_eq((frame.tabs[1]["button"] as Button).theme_type_variation, &"", "the others are plain")
	frame.show_tab(1)
	assert_eq((frame.tabs[1]["button"] as Button).theme_type_variation, &"SelectedButton", "and it follows the tab")


func test_job_cards_are_the_concepts_pastel_cards() -> void:
	var bs: BuildingSystem = sim.system(&"buildings")
	var farm := bs.place_instant("farm", Vector2i(1, 0))
	await tree.process_frame
	(main.get("selection") as SelectionController).select_building(farm)
	await tree.process_frame
	var panel: ContextPanel = main.get("panel")
	assert_eq(panel.cards.size(), 3, "sow, water, harvest")
	var want := [Color("#fdf0dc"), Color("#dcf1fc"), Color("#fff0bf")]
	for i in 3:
		var box := panel.cards[i].get_theme_stylebox("normal") as StyleBoxFlat
		assert_eq(box.bg_color, want[i], "card %d is %s" % [i, want[i].to_html(false)])
		var time: Label = panel.cards[i].find_child("Time", true, false)
		assert_true(_contrast(time.get_theme_color("font_color"), want[i]) >= 4.5, "its ink reads on it")
	assert_true(panel.cards[0].get_meta("current", false), "the next job wears the rim")
