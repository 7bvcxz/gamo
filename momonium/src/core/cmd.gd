class_name Cmd
extends RefCounted

## Reads command fields that may arrive from code (Vector2i) or from the
## browser bridge and saves (JSON: [x, y] arrays, numbers as floats).


static func vec2i(command: Dictionary, field: String, fallback: Vector2i = Vector2i(-99999, -99999)) -> Vector2i:
	var value: Variant = command.get(field)
	match typeof(value):
		TYPE_VECTOR2I:
			return value
		TYPE_VECTOR2:
			return Vector2i(value)
		TYPE_ARRAY:
			if (value as Array).size() == 2:
				return Vector2i(int(value[0]), int(value[1]))
	return fallback


static func integer(command: Dictionary, field: String, fallback: int = 0) -> int:
	var value: Variant = command.get(field)
	return int(value) if typeof(value) in [TYPE_INT, TYPE_FLOAT] else fallback


static func text(command: Dictionary, field: String, fallback: String = "") -> String:
	var value: Variant = command.get(field)
	return String(value) if typeof(value) in [TYPE_STRING, TYPE_STRING_NAME] else fallback
