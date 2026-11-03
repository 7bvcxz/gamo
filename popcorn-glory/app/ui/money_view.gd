class_name PopMoneyView
extends Control

## The one currency: a coin and a number, nothing else. It bumps when money
## comes in so the eye goes there.

var money := 0
var _coin := Vector2.ZERO        # where the coin was drawn, in this control
var _shown := -1
var _bump := 0.0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func set_money(v: int) -> void:
	if v > money:
		_bump = 1.0
	money = v


## Where flying coins land: the drawn coin (it moves as the number grows).
func coin_point() -> Vector2:
	if _coin == Vector2.ZERO:
		return global_position + size / 2
	return global_position + _coin


func _process(delta: float) -> void:
	if _bump > 0.0:
		_bump = maxf(0.0, _bump - delta * 5.0)
		queue_redraw()
	elif _shown != money:
		queue_redraw()


func _draw() -> void:
	_shown = money
	var h := size.y
	var s := 1.0 + 0.12 * _bump
	var font := ThemeDB.fallback_font
	var text := _format(money)
	var fs := int(h * 0.62 * s)
	var tw := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var total := h * 0.9 + 12.0 + tw
	var x0 := (size.x - total) / 2
	_coin = Vector2(x0 + h * 0.45, h * 0.5)
	PopMachineArt.draw_coin(self, _coin, h * 0.4 * s)
	draw_string(font, Vector2(x0 + h * 0.9 + 12.0, h * 0.5 + fs * 0.36), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, PopPalette.INK)


static func _format(v: int) -> String:
	var s := str(v)
	var out := ""
	var n := s.length()
	for i in n:
		out += s[i]
		var rest := n - 1 - i
		if rest > 0 and rest % 3 == 0:
			out += ","
	return out
