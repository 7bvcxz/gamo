class_name TreeLevels
extends RefCounted

## Experiment F's tree, stage by stage: the price of growing into it, the coins
## a second it makes, and its shape -- each stage a different silhouette
## (branching, crown kind, blossoms, fruit, glow, twin trunks, a spiral, crystal
## leaves, a treehouse, clouds, a rainbow), never the same picture scaled up.
## Past the table the tree keeps growing (`endless`): taller, a shifting hue,
## the features in turn; cost x1.48, rate x1.4 a stage.
##
## Bought the moment it can pay: the first change at 12 s, a new silhouette
## every 14-22 s, the Crystal tree (stage 10) at 2:47, the Treehouse at 3:09.

## Shape keys: h (trunk height, px), w (trunk width), depth (branch levels),
## kids (branches per fork), spread (deg), ratio (child length), twist (deg a
## level), crown (leaves|blob|umbrella|layers|heart|crystal|cloud), r (leaf
## cluster radius), leaf/leaf2 (colours), blossom/fruit (count), glow,
## lanterns, house, clouds, rainbow, twin.
const STAGES: Array[Dictionary] = [
	{"name": "Sprout", "cost": 0, "rate": 1.0, "h": 34.0, "w": 6.0, "depth": 0, "crown": "leaves", "r": 12.0, "leaf": Color("#8ee05a"), "leaf2": Color("#5fb83a")},
	{"name": "Sapling", "cost": 12, "rate": 1.8, "h": 100.0, "w": 9.0, "depth": 1, "kids": 2, "spread": 56.0, "ratio": 0.45, "crown": "leaves", "r": 16.0, "leaf": Color("#86d85a"), "leaf2": Color("#57ad3a")},
	{"name": "Young Tree", "cost": 25, "rate": 3.0, "h": 150.0, "w": 14.0, "depth": 2, "kids": 2, "spread": 48.0, "ratio": 0.62, "crown": "blob", "r": 30.0, "leaf": Color("#78cf55"), "leaf2": Color("#4e9f38")},
	{"name": "Branching", "cost": 45, "rate": 4.8, "h": 200.0, "w": 20.0, "depth": 3, "kids": 2, "spread": 42.0, "ratio": 0.68, "crown": "blob", "r": 34.0, "leaf": Color("#6cc650"), "leaf2": Color("#3f9136")},
	{"name": "Wide Canopy", "cost": 75, "rate": 7.5, "h": 230.0, "w": 28.0, "depth": 3, "kids": 3, "spread": 72.0, "ratio": 0.6, "crown": "umbrella", "r": 46.0, "leaf": Color("#5fbd4d"), "leaf2": Color("#357f33")},
	{"name": "Blossom", "cost": 120, "rate": 11.5, "h": 260.0, "w": 30.0, "depth": 3, "kids": 3, "spread": 66.0, "ratio": 0.62, "crown": "blob", "r": 50.0, "leaf": Color("#7cc85a"), "leaf2": Color("#3f8a3a"), "blossom": 70, "petal": Color("#ffb7d5")},
	{"name": "Fruit", "cost": 190, "rate": 17.0, "h": 290.0, "w": 32.0, "depth": 3, "kids": 3, "spread": 64.0, "ratio": 0.64, "crown": "blob", "r": 54.0, "leaf": Color("#5bb84f"), "leaf2": Color("#2f7d34"), "fruit": 22, "fruit_col": Color("#ffcf3f")},
	{"name": "Glow", "cost": 300, "rate": 25.0, "h": 320.0, "w": 34.0, "depth": 3, "kids": 3, "spread": 64.0, "ratio": 0.66, "crown": "blob", "r": 56.0, "leaf": Color("#2fa07a"), "leaf2": Color("#1d6b58"), "fruit": 18, "fruit_col": Color("#ffe98a"), "glow": true, "lanterns": 7},
	{"name": "Twin Heart", "cost": 470, "rate": 36.0, "h": 360.0, "w": 30.0, "depth": 3, "kids": 2, "spread": 46.0, "ratio": 0.66, "crown": "heart", "r": 70.0, "leaf": Color("#ff8fb5"), "leaf2": Color("#d45c8a"), "blossom": 50, "petal": Color("#fff0f6"), "twin": true},
	{"name": "Spiral Pagoda", "cost": 720, "rate": 52.0, "h": 500.0, "w": 34.0, "depth": 4, "kids": 2, "spread": 40.0, "ratio": 0.7, "twist": 16.0, "crown": "layers", "r": 60.0, "leaf": Color("#3fb07f"), "leaf2": Color("#23765a"), "lanterns": 9},
	{"name": "Crystal", "cost": 1100, "rate": 75.0, "h": 560.0, "w": 36.0, "depth": 4, "kids": 2, "spread": 44.0, "ratio": 0.7, "crown": "crystal", "r": 40.0, "leaf": Color("#9ff0ff"), "leaf2": Color("#c792ff"), "glow": true},
	{"name": "Treehouse", "cost": 1650, "rate": 107.0, "h": 620.0, "w": 42.0, "depth": 4, "kids": 3, "spread": 56.0, "ratio": 0.62, "crown": "blob", "r": 66.0, "leaf": Color("#4fb45a"), "leaf2": Color("#2b7a3c"), "house": true, "lanterns": 8, "fruit": 14, "fruit_col": Color("#ff7a5c")},
	{"name": "Sky Tree", "cost": 2450, "rate": 152.0, "h": 720.0, "w": 48.0, "depth": 4, "kids": 3, "spread": 60.0, "ratio": 0.64, "crown": "cloud", "r": 74.0, "leaf": Color("#5cc76a"), "leaf2": Color("#2f8a4a"), "clouds": true, "blossom": 40, "petal": Color("#ffffff")},
	{"name": "Rainbow", "cost": 3600, "rate": 215.0, "h": 820.0, "w": 52.0, "depth": 4, "kids": 3, "spread": 62.0, "ratio": 0.66, "crown": "blob", "r": 80.0, "leaf": Color("#ff6b6b"), "leaf2": Color("#6b5bff"), "rainbow": true, "glow": true},
]
const ENDLESS_COST := 1.48
const ENDLESS_RATE := 1.4
const ENDLESS_FEATURES: Array[String] = ["blossom", "fruit", "glow", "lanterns", "clouds", "rainbow"]


static func stage(n: int) -> Dictionary:
	if n < STAGES.size():
		return STAGES[n]
	var k := n - STAGES.size() + 1
	var last: Dictionary = STAGES[STAGES.size() - 1].duplicate()
	last["name"] = "Wonder %d" % k
	last["cost"] = int(round(float(last["cost"]) * pow(ENDLESS_COST, k)))
	last["rate"] = snappedf(float(last["rate"]) * pow(ENDLESS_RATE, k), 0.1)
	last["h"] = float(last["h"]) + 80.0 * k
	last["w"] = float(last["w"]) + 3.0 * k
	last["r"] = float(last["r"]) + 4.0 * k
	last["rainbow"] = false
	var hue := fposmod(0.33 + 0.13 * k, 1.0)
	last["leaf"] = Color.from_hsv(hue, 0.55, 0.85)
	last["leaf2"] = Color.from_hsv(hue, 0.65, 0.55)
	var f := ENDLESS_FEATURES[(k - 1) % ENDLESS_FEATURES.size()]
	match f:
		"blossom":
			last["blossom"] = 60
			last["petal"] = Color.from_hsv(fposmod(hue + 0.5, 1.0), 0.3, 1.0)
		"fruit":
			last["fruit"] = 24
			last["fruit_col"] = Color.from_hsv(fposmod(hue + 0.4, 1.0), 0.7, 1.0)
		"glow", "lanterns":
			last["glow"] = true
			last["lanterns"] = 10
		"clouds":
			last["clouds"] = true
		"rainbow":
			last["rainbow"] = true
	last["twist"] = 10.0 if k % 3 == 0 else 0.0
	return last


static func cost(n: int) -> int:
	return int(stage(n)["cost"])


static func rate(n: int) -> float:
	return float(stage(n)["rate"])


static func instant_times(stages: int) -> Array[float]:
	var out: Array[float] = [0.0]
	var t := 0.0
	for n in range(1, stages + 1):
		t += float(cost(n)) / rate(n - 1)
		out.append(t)
	return out
