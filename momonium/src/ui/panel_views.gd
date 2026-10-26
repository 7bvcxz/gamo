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


static func clear(c: Node) -> void:
	for child: Node in c.get_children():
		c.remove_child(child)
		child.queue_free()


static func money(amount: int) -> String:
	return ("-$" if amount < 0 else "$") + Hud._format_money(absi(amount))
