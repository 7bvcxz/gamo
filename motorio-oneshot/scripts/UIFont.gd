extends RefCounted
class_name UIFont

## Bundled so Korean UI renders identically in the editor, on desktop and in the
## web export. Godot's built-in font has no CJK glyphs.
##
## A subset cut from Noto Sans CJK by tools/build_font.cjs, carrying only the
## characters this game can draw. The full collection is 19 MB and Godot embeds
## it whole, which made it ninety percent of the download for a game that never
## draws a single Japanese or Chinese glyph. The source collection lives in
## tools/ and is excluded from the export.
##
## tests/test_font.gd fails if the scripts contain a character this file cannot
## render, so adding text and forgetting to rebuild the font is a failing test
## rather than a row of tofu boxes on a player's screen.
const FONT: Font = preload("res://assets/ui-font.otf")
