extends Node2D

## Step 18: one moving thing in the factory -- a lot of popcorn, a bag, or a
## customer -- tied to the model's id. Drawn once (and again only if its look
## changes); it moves by its position along waypoints, so a busy factory does
## not redraw polygons every frame (QUALITY_GATES R-01). The model has already
## moved the good; the actor only shows the journey (design/FACTORY_FLOW.md 9).

const LOT := "lot"
const BAG := "bag"
const CUSTOMER := "customer"
const NOZZLE := "nozzle"       ## Step 20: a packing head (it fills, then presses down to seal)

var kind := LOT
var model_id := 0
var size_px := 20.0
var body := Color.WHITE
var skin := Color.WHITE
var carrying := false          ## a customer holding the bag they bought
var open := false              ## a bag being filled (Step 20)
var fill := 0                  ## portions in it so far
var of := 2                    ## portions it will hold
var scoop := false             ## a nozzle that is the tier-0 scoop
var mood := "wait"             ## a customer's face (Step 21)
var order_size := 0            ## Step 23: the bag they want, shown in a bubble while they wait (0: none)
var order_premium := false     ## Step 29: they ask for the premium SKU (a gold bag in the bubble)
var order_bargain := false     ## Step 32: they ask for a bargain (a grey tagged bag)
var order_recipe := "plain"    ## Step 34: the flavor they want (its bag in the bubble)
var recipe := "plain"          ## Step 34: a lot's or a bag's flavor (and the bag a customer carries)
var hand := false              ## Step 35: finished by the hand (a glint on the lot, the gold seal on the bag)
var who := "classic"           ## Step 36: which of the cast (their silhouette)
## The journey: waypoints and the seconds for the whole of it. `steps` (reduced
## motion) holds at each waypoint instead of gliding between them.
var path: PackedVector2Array = PackedVector2Array()
var duration := 0.5
var t := 0.0
var steps := false
var done := false
## Customers ease towards a spot (the queue moves up) instead of following a path.
var target := Vector2.ZERO
var easing_to := false


func start(p: PackedVector2Array, seconds: float, step_mode: bool) -> void:
	path = p
	duration = maxf(0.05, seconds)
	t = 0.0
	steps = step_mode
	done = false
	easing_to = false
	position = p[0]


func walk_to(p: Vector2) -> void:
	target = p
	easing_to = true


func step(delta: float) -> void:
	if easing_to:
		var d := target - position
		if d.length() < 1.0:
			position = target
			easing_to = false
		else:
			position += d * minf(1.0, delta * 6.0)
		return
	if done or path.size() < 2:
		return
	t = minf(duration, t + delta)
	var k := t / duration
	if steps:
		k = floor(k * float(path.size() - 1) + 0.0001) / float(path.size() - 1)
	else:
		k = k * k * (3.0 - 2.0 * k)   # ease in and out
	position = _along(k)
	if t >= duration:
		done = true


func _along(k: float) -> Vector2:
	var total := 0.0
	for i in range(1, path.size()):
		total += path[i].distance_to(path[i - 1])
	var want := k * total
	for i in range(1, path.size()):
		var seg := path[i].distance_to(path[i - 1])
		if want <= seg or i == path.size() - 1:
			return path[i - 1].lerp(path[i], clampf(want / maxf(seg, 0.001), 0.0, 1.0))
		want -= seg
	return path[path.size() - 1]


func _draw() -> void:
	match kind:
		LOT:
			if PopFactoryArt.FLAVOR_LOOK.has(recipe) and recipe != "plain":   # Step 34: a coated lot
				for o: Vector2 in [Vector2(-0.55, 0.15), Vector2(0.5, 0.2), Vector2(0, -0.4)]:
					PopFactoryArt.flavor_popcorn(self, o * size_px, size_px * 0.62, recipe)
				if hand:
					PopFactoryArt.glint(self, Vector2(size_px * 0.55, -size_px * 0.7), size_px * 0.45)
			else:
				for o: Vector2 in [Vector2(-0.6, 0.1), Vector2(0.5, 0.15), Vector2(0, -0.45), Vector2(0.15, 0.5), Vector2(-0.3, 0.55)]:
					draw_circle(o * size_px, size_px * 0.5, Color(0.85, 0.64, 0.25))
				for o: Vector2 in [Vector2(-0.6, 0.1), Vector2(0.5, 0.15), Vector2(0, -0.45), Vector2(0.15, 0.5), Vector2(-0.3, 0.55)]:
					draw_circle(o * size_px, size_px * 0.4, PopPalette.CREAM)
		BAG:
			if recipe == "plain":
				PopFactoryArt.bag(self, Vector2.ZERO, size_px, PopTokens.MACHINE, open, fill, of)
			else:
				PopFactoryArt.sku_bag(self, Vector2.ZERO, size_px, recipe, open, fill, of, hand)
		NOZZLE:
			PopFactoryArt.nozzle(self, size_px, scoop)
		CUSTOMER:
			PopFactoryArt.customer(self, Vector2.ZERO, size_px, body, skin, mood, who)
			if order_size > 0 and not carrying:
				var lift := {"rush": 0.4, "kid": -0.4}.get(who, 0.0) as float   # Step 36: over their own head
				PopFactoryArt.order_bubble(self, Vector2(0, -size_px * (3.75 + lift)), size_px, order_size, order_premium, order_bargain, order_recipe)
			if carrying:
				PopFactoryArt.sku_bag(self, Vector2(size_px * 1.2, -size_px * 0.4), size_px * 0.9, recipe, false, 0, 2, hand)
