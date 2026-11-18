class_name PopCastArt
extends RefCounted

## Step 41: the shop's customers. Five people of the cast (Step 36: classic, student, rush,
## kid, elder -- their silhouettes are their height, what they wear and what is on their
## head), each drawn with a look chosen from the customer's id: the colour of what they wear,
## their skin, their hair and its style, a print. No two neighbours in a queue share a look
## by accident (the old drawing paired body and skin colour, five combinations in all).
##
## Drawn once per look and mood (an actor redraws only when its mood changes); the motion --
## the walk's sway, the breath, the hop of a bag received -- is the node's rotation and scale
## around the feet (variants/factory/actor.gd), so the feet never leave their line.
##
## Original shapes, no reference to anyone's characters. The outfits are everyday clothes
## (a sweater, a hoodie, a suit, a t-shirt, a cardigan); skin tones span light to deep and
## are drawn the same way; nothing marks anyone's background.

const INK := PopPalette.INK
## What they wear (soft, so the popcorn and the bags stay the vivid things in the shop).
const CLOTH := [Color(0.435, 0.714, 0.91), Color(0.561, 0.878, 0.769), Color(1.0, 0.7, 0.42), Color(0.78, 0.6, 0.88),
	Color(0.95, 0.55, 0.6), Color(0.98, 0.84, 0.4), Color(0.55, 0.62, 0.86), Color(0.62, 0.8, 0.5)]
const SKINS := [Color(0.98, 0.87, 0.76), Color(0.96, 0.82, 0.68), Color(0.9, 0.72, 0.58), Color(0.85, 0.63, 0.48),
	Color(0.72, 0.54, 0.4), Color(0.55, 0.38, 0.27)]
const HAIRS := [Color(0.25, 0.17, 0.13), Color(0.42, 0.26, 0.15), Color(0.13, 0.11, 0.12), Color(0.78, 0.55, 0.28),
	Color(0.62, 0.3, 0.2), Color(0.35, 0.3, 0.32)]
## The hair a member of the cast may have. Step 36's marks stay on every look: the student's
## headphones, the kid's cap, the elder's white hair and glasses, the rush's tie.
const STYLES := {
	"classic": ["tuft", "bob", "short", "curly"],
	"student": ["short", "bun", "curly"],
	"rush": ["slick", "short", "bob"],
	"kid": ["cap", "cap_tails"],
	"elder": ["puffs", "bun"],
}
const TALL := {"kid": 1.35, "rush": 2.15, "elder": 1.7}


## A stable 31-bit mix of an id and a salt (the same customer looks the same every time they
## are drawn): the engine's integer hash (a 64-bit mix). The first multiply-and-shift mix
## written here gave customers 64 and 65 the same look in every part (the integration test
## found it).
static func mix(id: int, salt: int = 0) -> int:
	return hash(id * 1000003 + salt * 7919 + 17) & 0x7fffffff


## The look of customer `id` of the cast member `who`: independent picks for each part.
static func look_for(id: int, who: String) -> Dictionary:
	var styles: Array = STYLES.get(who, STYLES["classic"])
	return {
		"body": CLOTH[mix(id, 1) % CLOTH.size()],
		"skin": SKINS[mix(id, 2) % SKINS.size()],
		"hair": [Color(0.95, 0.95, 0.97), Color(0.78, 0.78, 0.8)][mix(id, 3) % 2] if who == "elder" else HAIRS[mix(id, 3) % HAIRS.size()],
		"style": String(styles[mix(id, 4) % styles.size()]),
		"print": mix(id, 5) % 3,
	}


## How they leave once they have paid: most wave a heart ("thanks") or smile ("happy");
## about one in nine is delighted (both arms up, star eyes) -- a rare reaction, never two the
## same way in a row for the same id.
static func exit_mood(id: int) -> String:
	var r := mix(id, 6) % 9
	if r == 0:
		return "delight"
	return "thanks" if r % 2 == 1 else "happy"


static func tall_of(who: String) -> float:
	return float(TALL.get(who, 1.8))


## The box a customer of `head` takes around their feet (for the tests: what they may cover):
## their arms and hair either side, the top of their head -- or of their order bubble when it
## shows (art/factory_art.gd order_bubble: its tail 3.75 heads up, its top 1.6 heads above it).
static func bounds(foot: Vector2, head: float, who: String, bubble: bool) -> Rect2:
	var hs := head * (0.86 if who == "kid" else 1.0)
	var top := head * tall_of(who) + hs * 1.85
	if bubble:
		var lift := float({"rush": 0.4, "kid": -0.4}.get(who, 0.0))
		top = maxf(top, head * (3.75 + lift + 1.6))
	return Rect2(foot - Vector2(head * 1.4, top), Vector2(head * 2.8, top))


## One customer standing on `foot` (bottom centre), `head` the head's radius.
static func person(ci: CanvasItem, foot: Vector2, head: float, look: Dictionary, mood: String = "wait", who: String = "classic") -> void:
	var body: Color = look.get("body", CLOTH[0])
	var skin: Color = look.get("skin", SKINS[1])
	var hair: Color = look.get("hair", HAIRS[0])
	var style := String(look.get("style", "tuft"))
	var tall := tall_of(who)
	var hs := head * (0.86 if who == "kid" else 1.0)
	var line := maxf(2.0, head * 0.12)
	var shoulder := foot - Vector2(0, head * tall * 0.86)
	var arm := maxf(3.0, head * 0.34)
	var sleeve := body.darkened(0.12)
	# Arms behind the body: down at the sides, or up (a wave, a cheer).
	var up_r := mood == "thanks" or mood == "delight"
	var up_l := mood == "delight"
	for side: float in [-1.0, 1.0]:
		var up := up_r if side > 0.0 else up_l
		var s0 := shoulder + Vector2(side * head * 0.82, head * 0.1)
		var hand: Vector2
		if up:
			hand = s0 + Vector2(side * head * 0.55, -head * 1.45)
		else:
			hand = s0 + Vector2(side * head * 0.32, head * tall * 0.52)
		ci.draw_line(s0, hand, sleeve, arm)
		ci.draw_circle(hand, arm * 0.62, skin)
	# The body: a rounded torso, its collar and what marks the outfit.
	var torso := Rect2(foot - Vector2(head * 1.05, head * tall), Vector2(head * 2.1, head * tall))
	PopMachineArt._round_rect(ci, torso, head * 0.8, body)
	ci.draw_rect(Rect2(foot - Vector2(head * 1.05, head * 0.24), Vector2(head * 2.1, head * 0.24)), body.darkened(0.18))
	var neck := foot - Vector2(0, head * tall)
	match who:
		"rush":   # a jacket's lapels over a shirt, and a tie
			ci.draw_colored_polygon(PackedVector2Array([neck + Vector2(-head * 0.42, 0), neck + Vector2(head * 0.42, 0), neck + Vector2(0, head * tall * 0.45)]), Color(0.97, 0.97, 0.95))
			ci.draw_colored_polygon(PackedVector2Array([neck, neck + Vector2(head * 0.13, head * 0.2), neck + Vector2(0, head * tall * 0.55), neck + Vector2(-head * 0.13, head * 0.2)]), Color(0.75, 0.15, 0.2))
			ci.draw_line(neck + Vector2(-head * 0.42, 0), neck + Vector2(-head * 0.05, head * tall * 0.5), body.darkened(0.3), maxf(1.5, line * 0.7))
			ci.draw_line(neck + Vector2(head * 0.42, 0), neck + Vector2(head * 0.05, head * tall * 0.5), body.darkened(0.3), maxf(1.5, line * 0.7))
		"student":   # a hoodie's strings and a bag strap across
			ci.draw_line(foot - Vector2(head * 0.85, head * tall * 0.95), foot - Vector2(-head * 0.8, head * 0.2), body.darkened(0.38), maxf(2.0, head * 0.2))
			ci.draw_line(neck + Vector2(-head * 0.2, head * 0.05), neck + Vector2(-head * 0.22, head * 0.45), Color.WHITE, maxf(1.0, line * 0.5))
			ci.draw_line(neck + Vector2(head * 0.2, head * 0.05), neck + Vector2(head * 0.22, head * 0.45), Color.WHITE, maxf(1.0, line * 0.5))
		"elder":   # a cardigan: its edge and two buttons
			ci.draw_line(neck, foot - Vector2(0, head * 0.24), body.darkened(0.3), maxf(1.5, line * 0.6))
			ci.draw_circle(neck + Vector2(head * 0.16, head * tall * 0.35), head * 0.09, body.lightened(0.5))
			ci.draw_circle(neck + Vector2(head * 0.16, head * tall * 0.6), head * 0.09, body.lightened(0.5))
		"kid":   # a t-shirt with a star
			PopFactoryArt.star(ci, neck + Vector2(0, head * tall * 0.5), head * 0.3, body.lightened(0.55), body.lightened(0.55))
		_:   # a sweater: a round collar and a print (a stripe, dots or a pocket)
			ci.draw_arc(neck, head * 0.42, 0.2, PI - 0.2, 8, body.lightened(0.35), maxf(1.5, line * 0.7))
			match int(look.get("print", 0)):
				0:
					ci.draw_rect(Rect2(foot - Vector2(head * 1.0, head * tall * 0.5), Vector2(head * 2.0, head * 0.2)), body.lightened(0.35))
				1:
					for q in 3:
						ci.draw_circle(foot - Vector2(head * (0.5 - 0.5 * q), head * tall * (0.45 + 0.12 * (q % 2))), head * 0.08, body.lightened(0.45))
				_:
					ci.draw_rect(Rect2(foot - Vector2(head * 0.6, head * tall * 0.55), Vector2(head * 0.42, head * 0.36)), body.darkened(0.12))
	# The head.
	var c := foot - Vector2(0, head * tall + hs * 0.8)
	if mood == "sad":
		c += Vector2(head * 0.12, head * 0.18)   # head down
	_hair_back(ci, c, hs, style, hair)
	ci.draw_circle(c, hs, skin)
	ci.draw_arc(c, hs, 0, TAU, 24, INK, line)
	_hair_front(ci, c, hs, style, hair, body, line)
	if who == "student":   # headphones (Step 36's mark of the student: the band and two blue cups)
		ci.draw_arc(c, hs * 1.12, PI * 1.05, PI * 1.95, 12, INK, maxf(2.0, hs * 0.18))
		ci.draw_circle(c + Vector2(-hs * 1.05, hs * 0.05), hs * 0.26, Color(0.25, 0.55, 0.85))
		ci.draw_circle(c + Vector2(hs * 1.05, hs * 0.05), hs * 0.26, Color(0.25, 0.55, 0.85))
	if who == "elder":   # round glasses
		ci.draw_arc(c + Vector2(-hs * 0.36, -hs * 0.1), hs * 0.25, 0, TAU, 12, INK, maxf(1.5, line * 0.6))
		ci.draw_arc(c + Vector2(hs * 0.36, -hs * 0.1), hs * 0.25, 0, TAU, 12, INK, maxf(1.5, line * 0.6))
	_face(ci, c, hs, mood, line)
	if mood == "thanks":   # a heart over the raised hand
		PopFactoryArt.heart(ci, shoulder + Vector2(head * 1.35, -head * 1.95), head * 0.34)
	elif mood == "delight":   # sparkles either side of the head
		PopFactoryArt.glint(ci, c + Vector2(-hs * 1.55, -hs * 0.9), hs * 0.32, PopPalette.GOLD)
		PopFactoryArt.glint(ci, c + Vector2(hs * 1.6, -hs * 0.6), hs * 0.26, PopPalette.GOLD)


## Hair behind the head (what shows around its edge).
static func _hair_back(ci: CanvasItem, c: Vector2, hs: float, style: String, hair: Color) -> void:
	match style:
		"bob":
			PopMachineArt._round_rect(ci, Rect2(c + Vector2(-hs * 1.12, -hs * 0.9), Vector2(hs * 2.24, hs * 1.7)), hs * 0.7, hair)
		"bun":
			ci.draw_circle(c + Vector2(0, -hs * 1.05), hs * 0.42, hair)
		"puffs":   # white puffs with a grey edge (they vanished on the pale shop wall)
			for side: float in [-1.0, 1.0]:
				ci.draw_circle(c + Vector2(side * hs * 0.85, -hs * 0.2), hs * 0.46, Color(0.62, 0.62, 0.66))
				ci.draw_circle(c + Vector2(side * hs * 0.85, -hs * 0.2), hs * 0.39, hair)
		"cap_tails":
			ci.draw_circle(c + Vector2(-hs * 1.05, hs * 0.05), hs * 0.33, hair)
			ci.draw_circle(c + Vector2(hs * 1.05, hs * 0.05), hs * 0.33, hair)
		"curly":
			for q in 5:
				var a := PI * (1.05 + 0.225 * q)
				ci.draw_circle(c + Vector2(cos(a), sin(a)) * hs * 0.92, hs * 0.34, hair)


## Hair on top of the head (and the kid's cap).
static func _hair_front(ci: CanvasItem, c: Vector2, hs: float, style: String, hair: Color, body: Color, line: float) -> void:
	match style:
		"tuft":
			ci.draw_arc(c + Vector2(hs * 0.1, -hs * 0.95), hs * 0.25, PI, TAU, 6, INK, maxf(2.0, line * 0.8))
		"short", "bob", "bun":
			ci.draw_colored_polygon(PopFactoryArt._arc_poly(c + Vector2(0, -hs * 0.04), hs * 1.0, PI * 1.02, PI * 1.98), hair)
			if style == "short":   # a side part
				ci.draw_line(c + Vector2(-hs * 0.3, -hs * 0.92), c + Vector2(-hs * 0.05, -hs * 0.45), hair.darkened(0.3), maxf(1.0, line * 0.5))
		"slick":
			ci.draw_colored_polygon(PopFactoryArt._arc_poly(c + Vector2(0, -hs * 0.08), hs * 0.98, PI * 1.05, PI * 1.98), hair)
			ci.draw_arc(c + Vector2(hs * 0.2, -hs * 0.55), hs * 0.32, PI * 1.1, PI * 1.8, 6, hair.lightened(0.3), maxf(1.0, line * 0.5))
		"curly":
			ci.draw_colored_polygon(PopFactoryArt._arc_poly(c, hs * 0.96, PI * 1.08, PI * 1.92), hair)
		"cap", "cap_tails":
			# the cap sits above the eyes, its brim to the side at the forehead (Step 36's brim
			# crossed the eyes)
			ci.draw_colored_polygon(PopFactoryArt._arc_poly(c + Vector2(0, -hs * 0.3), hs * 0.96, PI, TAU), body.lightened(0.15).lerp(Color(0.9, 0.25, 0.3), 0.6))
			ci.draw_line(c + Vector2(hs * 0.3, -hs * 0.36), c + Vector2(hs * 1.45, -hs * 0.36), Color(0.7, 0.15, 0.2), maxf(2.0, hs * 0.2))


## Eyes (with a catch-light), brows that follow the mood, cheeks and a mouth.
static func _face(ci: CanvasItem, c: Vector2, hs: float, mood: String, line: float) -> void:
	var e := hs * 0.15
	var lw := maxf(1.5, line * 0.75)
	for side: float in [-1.0, 1.0]:
		var ec := c + Vector2(side * hs * 0.36, -hs * 0.1)
		if mood == "delight":   # star eyes
			PopFactoryArt.star(ci, ec, e * 1.6, PopPalette.GOLD, INK)
		elif mood == "happy" or mood == "thanks":   # smiling eyes (closed arcs)
			ci.draw_arc(ec + Vector2(0, e * 0.4), e * 1.1, PI * 1.15, PI * 1.85, 6, INK, lw)
		else:
			ci.draw_circle(ec, e, INK)
			ci.draw_circle(ec + Vector2(-e * 0.35, -e * 0.4), maxf(0.8, e * 0.38), Color.WHITE)
		# brows: level, pinched (impatient), sloping out (sad), raised (happy)
		var b0 := ec + Vector2(-side * e * 1.2, -e * 2.3)
		var b1 := ec + Vector2(side * e * 1.2, -e * 2.3)
		match mood:
			"impatient":
				b0.y += e * 0.9
			"sad":
				b1.y += e * 0.9
			"happy", "thanks", "delight":
				b0.y -= e * 0.4
				b1.y -= e * 0.4
		ci.draw_line(b0, b1, INK, maxf(1.2, lw * 0.8))
	var m := c + Vector2(0, hs * 0.38)
	match mood:
		"happy", "thanks":
			ci.draw_arc(m + Vector2(0, -hs * 0.18), hs * 0.38, 0.25, PI - 0.25, 10, INK, line)
			_cheeks(ci, c, hs)
		"delight":   # an open smile
			ci.draw_colored_polygon(PopFactoryArt._arc_poly(m + Vector2(0, -hs * 0.12), hs * 0.36, 0.0, PI), INK)
			ci.draw_circle(m + Vector2(0, hs * 0.1), hs * 0.12, Color(0.95, 0.45, 0.45))
			_cheeks(ci, c, hs)
		"sad":
			ci.draw_arc(m + Vector2(0, hs * 0.22), hs * 0.3, PI + 0.4, TAU - 0.4, 10, INK, line)
		"impatient":
			ci.draw_line(m + Vector2(-hs * 0.26, 0), m + Vector2(hs * 0.26, 0), INK, line)
			var d := c + Vector2(hs * 0.95, -hs * 0.55)
			ci.draw_colored_polygon(PackedVector2Array([d + Vector2(0, -hs * 0.3), d + Vector2(hs * 0.16, 0), d + Vector2(0, hs * 0.12), d + Vector2(-hs * 0.16, 0)]), PopTokens.SKY)
		_:
			ci.draw_arc(m + Vector2(0, -hs * 0.1), hs * 0.22, 0.4, PI - 0.4, 8, INK, line)


static func _cheeks(ci: CanvasItem, c: Vector2, hs: float) -> void:
	ci.draw_circle(c + Vector2(-hs * 0.6, hs * 0.22), hs * 0.16, Color(1.0, 0.55, 0.55, 0.6))
	ci.draw_circle(c + Vector2(hs * 0.6, hs * 0.22), hs * 0.16, Color(1.0, 0.55, 0.55, 0.6))
