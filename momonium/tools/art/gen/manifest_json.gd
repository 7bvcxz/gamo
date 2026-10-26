extends RefCounted

## The manifest as it is written by hand: whole numbers without ".0" (JSON
## parsing made every number a float), except `scale`, which is always a float.
static func dump(v: Variant, indent: String = "", key: String = "") -> String:
	var inner := indent + "  "
	match typeof(v):
		TYPE_DICTIONARY:
			var d: Dictionary = v
			if d.is_empty():
				return "{}"
			var parts: PackedStringArray = []
			for k: String in d:
				parts.append(inner + JSON.stringify(k) + ": " + dump(d[k], inner, k))
			return "{\n" + ",\n".join(parts) + "\n" + indent + "}"
		TYPE_ARRAY:
			var a: Array = v
			if a.is_empty():
				return "[]"
			var parts: PackedStringArray = []
			for e: Variant in a:
				parts.append(inner + dump(e, inner, key))
			return "[\n" + ",\n".join(parts) + "\n" + indent + "]"
		TYPE_FLOAT:
			if key != "scale" and float(v) == floorf(float(v)):
				return str(int(v))
			return JSON.stringify(v)
	return JSON.stringify(v)
