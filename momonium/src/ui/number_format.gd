class_name NumberFormat
extends RefCounted

## Large numbers people can read at a glance, in the way each language counts:
## English 1.2K / 3.4M / 5.6B, Korean 1.2만 / 3.4억 / 5.6조, Japanese 1.2万 /
## 3.4億, Chinese 1.2万 / 3.4亿. Small numbers stay whole.

const UNITS := {
	"en": [[1e12, "T"], [1e9, "B"], [1e6, "M"], [1e3, "K"]],
	"ko": [[1e12, "조"], [1e8, "억"], [1e4, "만"]],
	"ja": [[1e12, "兆"], [1e8, "億"], [1e4, "万"]],
	"zh_CN": [[1e12, "万亿"], [1e8, "亿"], [1e4, "万"]],
}


static func compact(value: float, code: String = "") -> String:
	var lang := code if code != "" else LocaleService.current()
	var sign := "-" if value < 0.0 else ""
	var v := absf(value)
	for unit: Array in UNITS.get(lang, UNITS["en"]):
		if v >= float(unit[0]):
			var n := v / float(unit[0])
			var text := String.num(n, 1 if n < 100.0 else 0)
			if text.ends_with(".0"):
				text = text.substr(0, text.length() - 2)
			return sign + text + String(unit[1])
	if v >= 100.0 or is_equal_approx(v, round(v)):
		return sign + str(int(round(v)))
	return sign + String.num(v, 1)
