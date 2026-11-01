class_name PanelViews
extends RefCounted

## Small helpers the panel bodies share: a row of label + value, a section
## heading, an icon. Keeping them here keeps every panel one visual language.


static func label(text: String, font_size: int = 18, dim: bool = false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", font_size)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if dim:
		l.modulate = Color(1, 1, 1, 0.75)
	return l


static func row(key: String, value: String) -> HBoxContainer:
	var r := HBoxContainer.new()
	var k := label(key, 18, true)
	k.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	r.add_child(k)
	var v := label(value, 18)
	v.name = "Value"
	v.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	r.add_child(v)
	return r


static func icon(lib: SpriteLibrary, sprite: String, px: float = 32.0) -> TextureRect:
	var t: TextureRect = GlyphIcon.new() if sprite in GlyphIcon.GLYPHS else TextureRect.new()
	t.texture = lib.atlas_texture(sprite if lib.has(sprite) else "ui_sprout")
	t.custom_minimum_size = Vector2(px, px)
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return t


## Removes at once (so new children can reuse the names) and frees later.
## A close button with a drawn cross. Not the "✕" glyph: the UI fonts are
## per-language subsets without it, and the web has no system fonts to fall
## back on, so every ✕ in the game rendered as an empty box there.
static func close_button(px: float = 52.0) -> Button:
	var b := Button.new()
	b.name = "Close"
	b.custom_minimum_size = Vector2(px, px)
	b.focus_mode = Control.FOCUS_NONE
	b.draw.connect(func() -> void:
		var c := b.size * 0.5
		var r := px * 0.17
		for d: Vector2 in [Vector2(1, 1), Vector2(1, -1)]:
			b.draw_line(c - d * r, c + d * r, b.get_theme_color("glyph", "Ink"), maxf(px / 17.0, 2.5), true))
	return b


## Step 82: `act` runs when a press that began on `c` is let go on it -- a
## touch, or the left or right mouse button; never a wheel. A finger makes
## both a touch and a mouse press in the browser, so an overlay that
## answered the press alone vanished under the finger and the rest of that
## same tap reached the layer below it (Reset All Data's dim cancelled, then
## the Settings scrim behind it took the release and closed Settings too).
static func dismiss_on_tap(c: Control, act: Callable) -> void:
	var down := [false]
	c.gui_input.connect(func(e: InputEvent) -> void:
		var primary: bool = e is InputEventScreenTouch or (e is InputEventMouseButton and (e as InputEventMouseButton).button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT])
		if not primary:
			return
		if e.is_pressed():
			down[0] = true
		elif down[0]:
			down[0] = false
			act.call())
	c.visibility_changed.connect(func() -> void: down[0] = false)


## Step 81: lets a finger's drag that starts on something inside `sc` reach
## the scroll. A ScrollContainer scrolls by touch only from the presses it
## sees, and a STOP control (a Button, a card, a plain Control) keeps them: on
## a phone the research tree, the tab row and the status body did not move
## under a swipe. PASS still lets each of them have its tap. A slider keeps
## its drag to itself (a sideways slide must not scroll the page too).
static func let_swipes_through(sc: ScrollContainer) -> void:
	for n: Node in sc.find_children("*", "Control", true, false):
		var c := n as Control
		if c.mouse_filter == Control.MOUSE_FILTER_STOP and not c is Range and not c is ScrollContainer:
			c.mouse_filter = Control.MOUSE_FILTER_PASS


## Step 81: a scroll's bars, slim and quiet -- a rounded navy grabber on a
## faint track, PanelFrame.BAR wide -- instead of the engine's wide grey ones.
static func slim_bars(sc: ScrollContainer) -> void:
	for bar: ScrollBar in [sc.get_v_scroll_bar(), sc.get_h_scroll_bar()]:
		var track := StyleBoxFlat.new()
		track.bg_color = Color(0.12, 0.23, 0.38, 0.08)
		track.set_corner_radius_all(3)
		track.set_content_margin_all(PanelFrame.BAR * 0.5)
		bar.add_theme_stylebox_override("scroll", track)
		bar.add_theme_stylebox_override("scroll_focus", track)
		for pair: Array in [["grabber", 0.38], ["grabber_highlight", 0.52], ["grabber_pressed", 0.62]]:
			var g := StyleBoxFlat.new()
			g.bg_color = Color(0.12, 0.23, 0.38, float(pair[1]))
			g.set_corner_radius_all(3)
			g.set_content_margin_all(PanelFrame.BAR * 0.5)
			bar.add_theme_stylebox_override(String(pair[0]), g)


static func clear(c: Node) -> void:
	for child: Node in c.get_children():
		c.remove_child(child)
		child.queue_free()


static func money(amount: int) -> String:
	return ("-$" if amount < 0 else "$") + Hud._format_money(absi(amount))
