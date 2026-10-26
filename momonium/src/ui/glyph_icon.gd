class_name GlyphIcon
extends TextureRect

## A white line icon (the HUD's buttons) shown inside a panel (Step 52): it
## takes the theme's glyph colour, so it is white on navy glass and navy ink
## on the white reading cards instead of vanishing into them.

const GLYPHS := ["ui_research", "ui_mail", "ui_status", "ui_settings", "ui_shop", "ui_build"]


func _notification(what: int) -> void:
	if what == NOTIFICATION_THEME_CHANGED or what == NOTIFICATION_ENTER_TREE:
		if has_theme_color("glyph", "Ink"):
			self_modulate = get_theme_color("glyph", "Ink")
