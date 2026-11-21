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
var look := {}                 ## Step 41: what they wear, their skin and hair (PopCastArt.look_for)
var calm := false              ## Step 41: reduced motion -- no sway, no breath, no hops
## Step 41: a customer's motion is the node's skew (a lean) and scale around their feet (the
## drawing is not redrawn): the walk sways with the distance walked (a step per stride, so
## the feet do not slide), standing they breathe on their own period, the impatient rock and
## pause, a received bag is a hop, the rare delight a bigger one.
var motion := "idle"           ## what the pose is doing now (walk, idle, queue, receive, delight)
var moving := false            ## walking this frame (a hop can play over a walk)
var _walked := 0.0
var _clock := 0.0
var _react := ""
var _react_t := 0.0
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
	var before := position
	_move(delta)
	if kind == CUSTOMER:
		_pose(delta, position.distance_to(before))


## Step 41: a person is forty-odd shapes; drawn once, those are still forty objects every frame
## (design/DECISIONS.md D-58). So each look and mood is drawn once into a texture at the
## screen's scale (a SubViewport rendered once, as the machines' icons are) and the actor
## draws that one texture; the order bubble and the bag they carry stay drawn shapes. Until
## the texture has rendered (two frames) the actor draws the shapes.
static var _baked := {}         ## key -> {"vp": SubViewport, "frame": int}
static var bakes_made := 0      ## Step 46: how many person textures were drawn (each a SubViewport)
static var bake_enabled := true ## Step 46: a dev switch for the measurement (false: the shapes)
static var _holder: Node = null
## Step 46: what a customer shows besides themselves -- the order bubble, the bag they carry --
## baked once per look and shared by everyone (a dozen shapes each, redrawn with every mood:
## on the web each redrawn polygon is GL ids never given back, QUALITY_GATES R-01).
static var _extras := {}         ## key -> {"vp": SubViewport, "frame": int}
var _extra_wait := ""            ## the extra being baked (redraw when it is ready)
var _bake_key := ""
var _bake_wait := false


func _person_rect() -> Rect2:
	return Rect2(Vector2(-size_px * 2.1, -size_px * 4.3), Vector2(size_px * 4.2, size_px * 4.65))


func _screen_k() -> float:
	if not is_inside_tree():
		return 1.0
	return clampf(snappedf((get_viewport().get_final_transform() * get_global_transform_with_canvas()).get_scale().y / maxf(0.01, scale.y), 0.25), 0.5, 3.0)


func _person_texture() -> Texture2D:
	if not is_inside_tree() or look.is_empty() or not bake_enabled:
		return null
	var k := _screen_k()
	var key := "%d|%s|%s|%.1f|%.2f" % [model_id, who, mood, size_px, k]
	_bake_key = key
	if not _baked.has(key):
		if _holder == null or not is_instance_valid(_holder):
			_holder = Node.new()
			_holder.name = "CastBakes"
			get_tree().root.add_child.call_deferred(_holder)
			_bake_wait = true
			return null
		if not _holder.is_inside_tree():
			_bake_wait = true
			return null
		var r := _person_rect()
		var vp := SubViewport.new()
		vp.size = Vector2i(ceili(r.size.x * k), ceili(r.size.y * k))
		vp.transparent_bg = true
		vp.disable_3d = true
		vp.render_target_update_mode = SubViewport.UPDATE_ONCE
		var n := Node2D.new()
		n.scale = Vector2(k, k)
		n.position = -r.position * k
		var lk := look.duplicate()
		var w := who
		var md := mood
		var hp := size_px
		n.draw.connect(func() -> void: PopCastArt.person(n, Vector2.ZERO, hp, lk, md, w))
		vp.add_child(n)
		_holder.add_child(vp)
		_baked[key] = {"vp": vp, "frame": Engine.get_frames_drawn()}
		bakes_made += 1
		if _baked.size() > 64:   # people come and go: the oldest looks are let go
			var old: String = _baked.keys()[0]
			(_baked[old]["vp"] as Node).queue_free()
			_baked.erase(old)
	var e: Dictionary = _baked[key]
	if Engine.get_frames_drawn() - int(e["frame"]) < 3:
		_bake_wait = true
		return null
	_bake_wait = false
	return (e["vp"] as SubViewport).get_texture()


## Step 41: how much of them shows near the door. Fading, they put their order bubble away
## (the door is under the shop's top-right corner, where the news paper is).
var faded := false
var arrived := false   ## in through the door (seen whole once): no more fading until they leave


func fade(alpha: float) -> void:
	modulate.a = alpha
	var f := alpha < 0.999
	if f != faded:
		faded = f
		queue_redraw()


func shows_bubble() -> bool:
	return kind == CUSTOMER and order_size > 0 and not carrying and not faded


## Step 41: a hop (a bag received) or the rare delight, played over whatever the pose is doing.
func react(what: String) -> void:
	_react = what
	_react_t = 0.0


var _sd := -1.0


func _seed() -> float:
	if _sd < 0.0:
		_sd = float(PopCastArt.mix(model_id, 9) % 1000) / 1000.0
	return _sd


func _pose(delta: float, moved: float) -> void:
	_clock += delta
	if _bake_wait:
		var e: Dictionary = _baked.get(_bake_key, {})
		if e.is_empty() or Engine.get_frames_drawn() - int(e["frame"]) >= 3:
			queue_redraw()   # the texture is ready (or the holder is): draw it
	if _extra_wait != "":
		var x: Dictionary = _extras.get(_extra_wait, {})
		if x.is_empty() or Engine.get_frames_drawn() - int(x["frame"]) >= 3:
			_extra_wait = ""
			queue_redraw()
	if calm:
		skew = 0.0
		scale = Vector2.ONE
		motion = "idle"
		return
	var rot := 0.0
	var sy := 1.0
	moving = moved > 0.02
	if moving:
		motion = "walk"
		_walked += moved
		var ph := _walked / maxf(4.0, size_px * 1.2) * PI   # one step a stride (distance, not time)
		rot = sin(ph) * (0.035 if mood == "sad" else 0.07)
		sy = 1.0 + 0.035 * absf(cos(ph))
	else:
		var sd := _seed()
		motion = "queue" if mood == "impatient" else "idle"
		sy = 1.0 + 0.018 * sin(_clock * TAU / (2.4 + sd) + sd * 6.0)
		if mood == "impatient" and fmod(_clock + sd * 3.0, 3.0) < 1.6:   # rocks, then stops
			rot = 0.045 * sin(_clock * TAU * 1.7)
	if _react != "":
		_react_t += delta
		var dur := 0.45 if _react == "receive" else 0.75
		var k := _react_t / dur
		if k >= 1.0:
			_react = ""
		else:
			motion = _react
			sy *= 1.0 + (0.12 if _react == "receive" else 0.2) * sin(k * TAU) * (1.0 - k)
	# A lean, not a turn: the skew slides the head and leaves the feet's line where it is (a
	# rotation about the feet rocked the body on its corners -- the audit measured the foot
	# point moving 11 px, tools/sprite_audit.gd).
	skew = rot * 1.3
	scale = Vector2(1.0 - (sy - 1.0) * 0.6, sy)


func _move(delta: float) -> void:
	if easing_to:
		var d := target - position
		if d.length() < 1.0:
			position = target
			easing_to = false
		else:
			# Step 41: eased in at the end, but never faster than a walk -- a long way glided in
			# one slow frame (the old ease covered 80% of any distance at 0.13 s a frame).
			var stepv := d * minf(1.0, delta * 6.0)
			var most := maxf(40.0, size_px * 10.0) * delta
			if stepv.length() > most:
				stepv = stepv.normalized() * most
			position += stepv
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
			var tex := _person_texture()
			if tex != null:   # Step 41: the person baked once (one draw, not forty shapes a frame)
				draw_texture_rect(tex, _person_rect(), false)
			else:
				PopFactoryArt.customer(self, Vector2.ZERO, size_px, body, skin, mood, who, look)
			if shows_bubble():
				var lift := {"rush": 0.4, "kid": -0.4}.get(who, 0.0) as float   # Step 36: over their own head
				var hp := size_px
				var os := order_size
				var op := order_premium
				var ob := order_bargain
				var orr := order_recipe
				_draw_extra("bubble|%d|%s|%s|%s|%.1f" % [os, op, ob, orr, hp], Vector2(0, -size_px * (3.75 + lift)),
					Rect2(Vector2(-hp * 0.85 - 3.0, -hp * 1.75 - 3.0), Vector2(hp * 1.7 + 6.0, hp * 1.85 + 6.0)),
					func(c: CanvasItem, o: Vector2) -> void: PopFactoryArt.order_bubble(c, o, hp, os, op, ob, orr))
			if carrying:
				var bw := size_px * 0.9
				var rc := recipe
				var hd := hand
				_draw_extra("carry|%s|%s|%.1f" % [rc, hd, bw], Vector2(size_px * 1.2, -size_px * 0.4),
					Rect2(Vector2(-0.8 * bw - 4.0, -1.75 * bw - 4.0), Vector2(1.6 * bw + 8.0, 2.0 * bw + 8.0)),
					func(c: CanvasItem, o: Vector2) -> void: PopFactoryArt.sku_bag(c, o, bw, rc, false, 0, 2, hd))


## Step 46: an extra (`box` around `at`) as its shared baked picture, or as vectors while it bakes.
func _draw_extra(key: String, at: Vector2, box: Rect2, art: Callable) -> void:
	var tex := _extra_texture(key, box, art)
	if tex != null:
		draw_texture_rect(tex, Rect2(at + box.position, box.size), false)
	else:
		art.call(self, at)


func _extra_texture(key: String, box: Rect2, art: Callable) -> Texture2D:
	if not is_inside_tree() or not bake_enabled or _holder == null or not is_instance_valid(_holder) or not _holder.is_inside_tree():
		return null
	var k := _screen_k()
	var px := Vector2i(ceili(box.size.x * k), ceili(box.size.y * k))
	if px.x <= 0 or px.y <= 0:
		return null
	var ck := "%s|%d|%d" % [key, px.x, px.y]
	if not _extras.has(ck):
		var vp := SubViewport.new()
		vp.size = px
		vp.transparent_bg = true
		vp.disable_3d = true
		vp.render_target_update_mode = SubViewport.UPDATE_ONCE
		var n := Node2D.new()
		n.scale = Vector2(k, k)
		n.position = -box.position * k
		n.draw.connect(func() -> void: art.call(n, Vector2.ZERO))
		vp.add_child(n)
		_holder.add_child(vp)
		_extras[ck] = {"vp": vp, "frame": Engine.get_frames_drawn()}
		bakes_made += 1
		if _extras.size() > 64:   # orders come and go: the oldest are let go
			var old: String = _extras.keys()[0]
			(_extras[old]["vp"] as Node).queue_free()
			_extras.erase(old)
	var e: Dictionary = _extras[ck]
	if Engine.get_frames_drawn() - int(e["frame"]) < 3:
		_extra_wait = ck
		return null
	return (e["vp"] as SubViewport).get_texture()
