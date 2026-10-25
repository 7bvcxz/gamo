class_name LocaleService
extends RefCounted

## Which language the game speaks, and the font that goes with it.
##
## Strings are translation keys (data/i18n/*.csv, imported by Godot). Fonts are
## per-language subsets of Noto Sans CJK (tools/fonts/build_fonts.mjs): Han
## characters are drawn differently in Japanese, Chinese and Korean, so the
## current language's face goes first and the others are fallbacks for the odd
## character it does not carry.

const LANGUAGES: PackedStringArray = ["en", "ko", "ja", "zh_CN"]
const FONT_PATHS := {
	"ko": "res://assets/fonts/ui_ko.otf",
	"ja": "res://assets/fonts/ui_ja.otf",
	"zh_CN": "res://assets/fonts/ui_zh.otf",
}

static var _fonts: Dictionary = {}


## The best supported language for an OS locale such as "ko_KR" or "zh_Hans_CN".
static func detect(os_locale: String = OS.get_locale()) -> String:
	var lang := os_locale.split("_")[0].to_lower()
	match lang:
		"ko":
			return "ko"
		"ja":
			return "ja"
		"zh":
			return "zh_CN"
	return "en"


static func apply(code: String) -> void:
	TranslationServer.set_locale(code if LANGUAGES.has(code) else "en")


static func current() -> String:
	var loc := TranslationServer.get_locale()
	for code: String in LANGUAGES:
		if loc == code or loc.begins_with(code):
			return code
	return "en"


## The UI font for a language: its own face first, the others as fallbacks.
static func font_for(code: String) -> Font:
	if _fonts.has(code):
		return _fonts[code]
	var primary_key := code if FONT_PATHS.has(code) else "ko"
	var primary: FontFile = (load(FONT_PATHS[primary_key]) as FontFile).duplicate()
	var fallbacks: Array[Font] = []
	for key: String in ["ko", "ja", "zh_CN"]:
		if key != primary_key:
			fallbacks.append(load(FONT_PATHS[key]))
	primary.fallbacks = fallbacks
	_fonts[code] = primary
	return primary
