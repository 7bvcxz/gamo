extends RefCounted
class_name UIFont

## Bundled so Korean UI renders identically in the editor, on desktop and in the
## web export. Godot's built-in font has no CJK glyphs.
const FONT: Font = preload("res://assets/NotoSansCJK-Regular.ttc")
