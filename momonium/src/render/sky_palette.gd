class_name SkyPalette
extends RefCounted

## Colours of the sky, sea and world light at any moment of the day,
## interpolated between the keyframes in art.day_cycle. A pure function of
## the day's progress, so the same instant always looks the same.

var _keys: Array[float] = []
var _looks: Array[Dictionary] = []
var sun_rise := 0.0
var sun_set := 0.72
var moon_rise := 0.7
var moon_set := 1.0


func _init(data: GameData) -> void:
	var cycle: Dictionary = data.get_value("art", "day_cycle", {})
	var looks: Dictionary = cycle.get("looks", {})
	for k: Dictionary in cycle.get("keys", []):
		_keys.append(float(k["t"]))
		_looks.append(_parse(looks.get(k["look"], {})))
	sun_rise = float(cycle.get("sun", {}).get("rise", 0.0))
	sun_set = float(cycle.get("sun", {}).get("set", 0.72))
	moon_rise = float(cycle.get("moon", {}).get("rise", 0.7))
	moon_set = float(cycle.get("moon", {}).get("set", 1.0))


static func _parse(look: Dictionary) -> Dictionary:
	var out := {}
	for key: String in look:
		var v: Variant = look[key]
		if typeof(v) == TYPE_ARRAY:
			var colors: Array[Color] = []
			for c: String in v:
				colors.append(Color.html(c))
			out[key] = colors
		elif typeof(v) == TYPE_STRING:
			out[key] = Color.html(v)
		else:
			out[key] = float(v)
	return out


## The look at `progress` (0..1): sky [top, mid, horizon], sea [horizon, mid,
## deep, shallow], ambient, cloud, cloud_shade, glint, glint_strength, stars.
func at(progress: float) -> Dictionary:
	var p := fposmod(progress, 1.0)
	var i := 0
	while i < _keys.size() - 2 and p >= _keys[i + 1]:
		i += 1
	var span := maxf(_keys[i + 1] - _keys[i], 0.0001)
	var t := smoothstep(0.0, 1.0, clampf((p - _keys[i]) / span, 0.0, 1.0))
	return _mix(_looks[i], _looks[i + 1], t)


static func _mix(a: Dictionary, b: Dictionary, t: float) -> Dictionary:
	var out := {}
	for key: String in a:
		var va: Variant = a[key]
		var vb: Variant = b.get(key, va)
		match typeof(va):
			TYPE_COLOR:
				out[key] = (va as Color).lerp(vb, t)
			TYPE_FLOAT:
				out[key] = lerpf(va, vb, t)
			_:
				var list: Array[Color] = []
				for j in (va as Array).size():
					list.append((va[j] as Color).lerp(vb[j], t))
				out[key] = list
	return out


## Sun height along its arc: 0 at the horizon, 1 at noon; negative when down.
func sun_elevation(progress: float) -> float:
	return _arc(progress, sun_rise, sun_set)


func moon_elevation(progress: float) -> float:
	return _arc(progress, moon_rise, moon_set)


## Sun position across the sky, 0 (left) .. 1 (right).
func sun_across(progress: float) -> float:
	return _across(progress, sun_rise, sun_set)


func moon_across(progress: float) -> float:
	return _across(progress, moon_rise, moon_set)


## Arcs may wrap past the end of the day (rise 0.94, set 0.66): times are
## measured from the rise, modulo one day.
static func _across(progress: float, rise: float, set_at: float) -> float:
	var span := fposmod(set_at - rise, 1.0)
	return clampf(fposmod(progress - rise, 1.0) / maxf(span, 0.0001), 0.0, 1.0)


static func _arc(progress: float, rise: float, set_at: float) -> float:
	var span := fposmod(set_at - rise, 1.0)
	var since := fposmod(progress - rise, 1.0)
	if since > span:
		return -1.0
	return sin(PI * since / maxf(span, 0.0001))
