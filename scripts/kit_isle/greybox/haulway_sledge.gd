extends Node3D
## The Haul-Way's machine (scripts/kit_isle/greybox/gb_haulway.gd): the kit
## asks `haul_sledge` and `haul_fender`, built here (the card's
## docs/design/roguelike/brainstorm/round4-crossings/motif-m5-haulway.md).
##
## Two sledges, one slung under each hawser on a mast, a counterweight pair:
## sledge 0 waits at A's cradle while sledge 1 waits at B's; both set off
## together, pass at the relay pier, dwell, and come back. Each is moving
## ground (an AnimatableBody3D marked PhysicsGround.mark_moving, its deck
## level, moved each physics frame): PilotMotor `mover` carries him on it
## as the serpent's collars do, his own pace kept over it.
##   the tell    `tell` s before it sets off, the cradle's stone chocks drop.
##   the jolt    setting off, a stunned body on the deck is thrown on along
##               its way (a toss, still stunned); docking, anyone stood on it
##               is tossed a little toward the shore (`dock`, not stunned).
##   the fender  a stone block hung each side of the pier's capital swings
##               out over the inner edge of a deck passing the pier (its
##               windup a shiver first); stood in its sweep he is knocked
##               off across the deck (`knock`, this node the source).
## `--haul-at=S` starts the cycle S s in (drivers).
const PhysicsGround = preload("res://scripts/pilot_physics_ground.gd")
const GiantStone = preload("res://scripts/kit_isle/greybox/giant_stone.gd")

## The dock's toss (m/s along the way, up).
const DOCK := Vector2(3.0,2.2)
## The departure's throw of a stunned body (m/s along, up).
const JOLT := Vector2(2.5,1.5)
## The fender: windup (shiver), swing out, hold, swing back (s); its sweep (deg).
const FENDER_TIMES := [0.6,0.35,4.5,0.8]
const FENDER_SWING := 90.0

var motif: RefCounted
var study: Node
var motor: Variant
var offset := Vector3.ZERO
var sledges: Array = []
var shoes: Array = []
var chocks: Array = []
var fenders: Array = []
var clock := 0.0
## Counted for drivers: boardings (by sledge), jolts, docks, fender swings
## and hits; which sledge he is on now (-1 none).
var boardings := [0,0]
var jolts := 0
var docks := 0
var swings := 0
var fender_hits := 0
var on_now := -1
var _was_phase := ""
var _fender_t := [-1.0,-1.0]
var _fender_hit := [false,false]

var travel := 0.0
var cycle := 0.0

func setup(m: RefCounted, s: Node, at: Vector3) -> void:
	motif = m
	study = s
	motor = s.get("motor")
	offset = at
	var sd: Dictionary = m.LAYOUT.sledge
	var dist := float(sd.dwell_b)-float(sd.dwell_a)
	var v := float(sd.speed)
	var acc := float(sd.accel)
	var t_acc := v/acc
	travel = 2.0*t_acc+(dist-v*t_acc)/v
	cycle = 2.0*(float(sd.dwell)+travel)
	var hz: Array = m.LAYOUT.hawser.z
	for i in 2:
		sledges.append(_sledge(i,float(hz[i])))
	_chocks()
	_fenders()
	# Already under way when he arrives (`start` s into the cycle).
	clock = float(sd.get("start",0.0))
	for a: String in preload("res://scripts/launch_args.gd").user_args():
		if a.begins_with("--haul-at="): clock = float(a.get_slice("=",1))
	_place()
	print("haulway: travel %.1f s, cycle %.1f s, decks A %.2f B %.2f pier %.2f" % [travel,cycle,m.floor_a(),m.floor_b(),m.pier_top()])

## The cycle's phase now: [name, metres sledge 0 has come from A's cradle].
func phase(t := -1.0) -> Array:
	var sd: Dictionary = motif.LAYOUT.sledge
	var dwell := float(sd.dwell)
	var dist := float(sd.dwell_b)-float(sd.dwell_a)
	var p := fposmod(clock if t < 0.0 else t,cycle)
	if p < dwell: return ["at_a",0.0]
	p -= dwell
	if p < travel: return ["out",_along(p,dist)]
	p -= travel
	if p < dwell: return ["at_b",dist]
	p -= dwell
	return ["back",dist-_along(p,dist)]

## Seconds till sledge 0 next leaves A's cradle (drivers).
func till_leaves_a() -> float:
	var dwell := float(motif.LAYOUT.sledge.dwell)
	return fposmod(dwell-fposmod(clock,cycle),cycle)

func _along(p: float, dist: float) -> float:
	var sd: Dictionary = motif.LAYOUT.sledge
	var v := float(sd.speed)
	var acc := float(sd.accel)
	var t_acc := v/acc
	var d_acc := 0.5*acc*t_acc*t_acc
	if p < t_acc: return 0.5*acc*p*p
	if p < travel-t_acc: return d_acc+v*(p-t_acc)
	var r := travel-p
	return dist-0.5*acc*r*r

## Sledge i's deck middle x now (frame).
func deck_x(i: int) -> float:
	var sd: Dictionary = motif.LAYOUT.sledge
	var d := float(phase()[1])
	return float(sd.dwell_a)+d if i == 0 else float(sd.dwell_b)-d

func _physics_process(delta: float) -> void:
	clock += delta
	var ph: String = phase()[0]
	if ph != _was_phase and _was_phase != "":
		if ph == "out" or ph == "back": _jolt(ph)
		else: _dock(ph)
	_was_phase = ph
	_place()
	_tell()
	_fender_step(delta)
	_on_what()

func _place() -> void:
	for i in 2:
		var x := deck_x(i)
		var s: AnimatableBody3D = sledges[i]
		var z := float(motif.LAYOUT.hawser.z[i])
		s.global_transform = Transform3D(Basis.IDENTITY,offset+Vector3(x,motif.deck_top(x),z))
		var shoe: Node3D = shoes[i]
		shoe.global_transform = Transform3D(Basis(Vector3.BACK,atan(motif.cable_slope(x))),offset+Vector3(x,motif.cable_y(x),z))

## Which way sledge i goes now (+1 east, -1 west, 0 docked).
func _way(i: int) -> float:
	var ph: String = phase()[0]
	var w := 1.0 if ph == "out" else (-1.0 if ph == "back" else 0.0)
	return w if i == 0 else -w

func _rider_on() -> int:
	if motor == null or motor.platform == null or not is_instance_valid(motor.platform): return -1
	for i in 2:
		var s: Node = sledges[i]
		if motor.platform == s or motor.platform.get_parent() == s: return i
	return -1

func _jolt(ph: String) -> void:
	var i := _rider_on()
	if i < 0: return
	if str(motor.move) == "tumble":
		var w := _way(i)
		motor.toss(Vector3(w*JOLT.x,JOLT.y,0.0))
		jolts += 1
		print("haulway: jolt (%s) threw him on" % ph)

func _dock(ph: String) -> void:
	var i := _rider_on()
	if i < 0 or not motor.grounded: return
	# The shore he docked at: sledge 0 at B going east, at A west; 1 opposite.
	var east := (ph == "at_b") == (i == 0)
	motor.toss(Vector3((1.0 if east else -1.0)*DOCK.x,DOCK.y,0.0))
	docks += 1
	print("haulway: dock jolt (%s)" % ph)

func _on_what() -> void:
	var i := _rider_on()
	if i >= 0 and on_now != i:
		boardings[i] += 1
		print("haulway: aboard sledge %d at %s" % [i,str((motor.feet as Vector3).round())])
	if i >= 0: on_now = i
	elif motor != null and (motor.grounded or motor.on_ledge()): on_now = -1

# --- The sledge -------------------------------------------------------------------------------

## A sledge: the deck (one squared slab, rune-banded), a curb on its long
## sides, the mast up to the shoe (the shoe drawn apart: it turns with the
## hawser); sledge 0 carries the slab with a brow on its underside.
func _sledge(i: int, z: float) -> AnimatableBody3D:
	var sd: Dictionary = motif.LAYOUT.sledge
	var deck: Vector3 = sd.deck
	var curb: Vector2 = sd.curb
	var hang := float(sd.hang)
	var r := float(motif.LAYOUT.hawser.radius)
	var body := AnimatableBody3D.new()
	body.name = "Sledge%d" % i
	body.sync_to_physics = false
	body.collision_layer = 1
	body.collision_mask = 0
	PhysicsGround.mark_moving(body)
	add_child(body)
	var g: RefCounted = GiantStone.mesher()
	# The deck: the slab, its underside keel tapering.
	g.box(Transform3D(Basis.IDENTITY,Vector3(0.0,-deck.y*0.5,0.0)),deck,0.18,-deck.y,0.95)
	g.box(Transform3D(Basis.IDENTITY,Vector3(0.0,-deck.y-0.5,0.0)),Vector3(deck.x-2.4,1.0,deck.z-2.0),0.25,-deck.y-1.0,0.82)
	# The slab's courses: a seam band round its sides (two stones stacked).
	g.box(Transform3D(Basis.IDENTITY,Vector3(0.0,-deck.y*0.5,0.0)),Vector3(deck.x+0.12,0.12,deck.z+0.12),0.02,-deck.y,0.7)
	_box(body,deck,Vector3(0.0,-deck.y*0.5,0.0))
	# The curbs.
	for sz: float in [-1.0,1.0]:
		var at := Vector3(0.0,curb.y*0.5,sz*(deck.z*0.5-curb.x*0.5))
		g.box(Transform3D(Basis.IDENTITY,at),Vector3(deck.x-0.2,curb.y,curb.x),0.08,0.0,0.88)
		_box(body,Vector3(deck.x-0.2,curb.y,curb.x),at)
	# The mast to the shoe.
	var mast := hang-r-0.25
	g.cylinder(Transform3D(Basis.IDENTITY,Vector3(0.0,mast*0.5,0.0)),0.6,mast,10,0.08,0.0,0.85)
	g.box(Transform3D(Basis.IDENTITY,Vector3(0.0,0.4,0.0)),Vector3(1.8,0.8,1.8),0.12,0.0,0.9)
	_box(body,Vector3(1.2,mast,1.2),Vector3(0.0,mast*0.5,0.0))
	# Sledge 0's load: the slab with a brow (cover on the deck).
	if i == 0:
		# (On the inner side, the outer kept a lane to stand in.) A dressed
		# block with a brow on its face, half a head's height.
		var load_at := Vector3(4.0,1.3,(1.9 if z < 0.0 else -1.9))
		g.box(Transform3D(Basis(Vector3.UP,0.04),load_at),Vector3(4.2,2.6,3.6),0.3,0.0,1.0)
		g.box(Transform3D(Basis(Vector3.UP,0.04),load_at+Vector3(1.2,1.5,0.0)),Vector3(1.2,0.4,3.2),0.14,0.0,0.92)
		_box(body,Vector3(4.2,2.6,3.6),load_at)
	var mesh := MeshInstance3D.new()
	mesh.name = "Mesh"
	mesh.mesh = GiantStone.mesh_of(g)
	body.add_child(mesh)
	# A lantern on the mast (dim and warm): the sledges read moving in the dark.
	var ember := MeshInstance3D.new()
	var bulb := SphereMesh.new()
	bulb.radius = 0.3
	bulb.height = 0.6
	ember.mesh = bulb
	var hot := StandardMaterial3D.new()
	hot.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	hot.albedo_color = Color(1.0,0.62,0.3)
	ember.material_override = hot
	ember.position = Vector3(0.0,mast*0.55,0.55)
	body.add_child(ember)
	# Its halo, read across the gulf in the dark (a billboard, additive).
	var halo := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(3.2,3.2)
	halo.mesh = quad
	var glow := StandardMaterial3D.new()
	glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	glow.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glow.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	glow.no_depth_test = false
	var grad := Gradient.new()
	grad.set_color(0,Color(1.0,0.6,0.3,0.55))
	grad.set_color(1,Color(1.0,0.5,0.2,0.0))
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5,0.5)
	tex.fill_to = Vector2(0.5,0.0)
	glow.albedo_texture = tex
	halo.material_override = glow
	halo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	halo.position = ember.position
	body.add_child(halo)
	var light := OmniLight3D.new()
	light.light_color = Color(1.0,0.62,0.32)
	light.light_energy = 1.4
	light.omni_range = 11.0
	light.shadow_enabled = false
	light.position = ember.position+Vector3(0.0,0.0,0.3)
	body.add_child(light)
	# The shoe cupping the hawser's underside (drawn; its top kept under the
	# crest so the rail slide is clear).
	var sg: RefCounted = GiantStone.mesher()
	sg.box(Transform3D(Basis.IDENTITY,Vector3(0.0,-r-0.2,0.0)),Vector3(2.6,0.5,2.5),0.1,NAN,0.82)
	for sz: float in [-1.0,1.0]:
		sg.box(Transform3D(Basis.IDENTITY,Vector3(0.0,-r*0.5,sz*(r+0.12))),Vector3(2.4,r+0.3,0.28),0.06,NAN,0.8)
	var shoe := MeshInstance3D.new()
	shoe.name = "Shoe%d" % i
	shoe.mesh = GiantStone.mesh_of(sg)
	add_child(shoe)
	shoes.append(shoe)
	return body

func _box(body: CollisionObject3D, size: Vector3, at: Vector3) -> void:
	var c := CollisionShape3D.new()
	var s := BoxShape3D.new()
	s.size = size
	c.shape = s
	c.position = at
	body.add_child(c)

# --- The tell: the cradles' chocks ---------------------------------------------------------

## Two stone chocks on each cradle's lip under each docked deck's end; they
## drop `tell` s before it sets off and rise as it docks.
func _chocks() -> void:
	var sd: Dictionary = motif.LAYOUT.sledge
	var deck: Vector3 = sd.deck
	var hz: Array = motif.LAYOUT.hawser.z
	for end in 2:
		var x := float(sd.dwell_a)-deck.x*0.5-0.5 if end == 0 else float(sd.dwell_b)+deck.x*0.5+0.5
		var y: float = motif.floor_a() if end == 0 else motif.floor_b()
		for i in 2:
			for sz: float in [-1.2,1.2]:
				var g: RefCounted = GiantStone.mesher()
				g.box(Transform3D.IDENTITY,Vector3(0.9,0.8,0.9),0.1,NAN,0.8)
				var m := MeshInstance3D.new()
				m.name = "Chock"
				m.mesh = GiantStone.mesh_of(g)
				add_child(m)
				var at := offset+Vector3(x,y-0.6,float(hz[i])+sz)
				m.global_position = at
				chocks.append([m,at,end])

func _tell() -> void:
	var sd: Dictionary = motif.LAYOUT.sledge
	var tell := float(sd.tell)
	var dwell := float(sd.dwell)
	var p := fposmod(clock,cycle)
	# Down: the last `tell` s of a dwell at that end (end 0 A while sledge 0
	# waits there; both ends wait together).
	var into := -1.0
	if p < dwell: into = p
	elif p >= dwell+travel and p < 2.0*dwell+travel: into = p-dwell-travel
	var down := 0.0
	if into >= 0.0: down = clampf((into-(dwell-tell))/0.4,0.0,1.0)
	else: down = 1.0
	for c: Array in chocks:
		var m: Node3D = c[0]
		var at: Vector3 = c[1]
		m.global_position = at-Vector3.UP*0.9*down

# --- The fender -------------------------------------------------------------------------------

## A stone arm on an upright pivot at each long side of the pier's capital
## (its middle), a block at its end at about a passing deck's waist: at
## rest it lies along the capital's side; it swings out flat across the
## deck's inner half.
func _fenders() -> void:
	var f: Dictionary = motif.LAYOUT.fender
	var p: Dictionary = motif.LAYOUT.pier
	var hp: Vector2 = p.half
	var arm := float(f.arm)
	var blk: Vector3 = f.block
	for i in 2:
		var side := -1.0 if i == 0 else 1.0
		var hinge := Node3D.new()
		hinge.name = "Fender%d" % i
		add_child(hinge)
		hinge.global_position = offset+Vector3(float(p.x)+0.6,motif.pier_top()-float(f.drop),side*(hp.y-0.05))
		var g: RefCounted = GiantStone.mesher()
		# The pivot drum, the arm (along -x at rest), the block.
		g.cylinder(Transform3D(Basis.IDENTITY,Vector3(0.0,0.2,0.0)),0.35,1.4,10,0.05,NAN,0.8)
		g.box(Transform3D(Basis.IDENTITY,Vector3(-arm*0.5,0.3,0.0)),Vector3(arm,0.35,0.4),0.05,NAN,0.82)
		g.box(Transform3D(Basis.IDENTITY,Vector3(-arm,0.0,0.0)),blk,0.14,NAN,0.9)
		var m := MeshInstance3D.new()
		m.mesh = GiantStone.mesh_of(g)
		hinge.add_child(m)
		fenders.append([hinge,side])

## The swing: when a deck's middle comes within `window` m of the pier's,
## the windup (a shiver), out, held, back. Out or held, a body in the arm's
## sweep (the deck carrying him into the held arm) is knocked across the
## deck, outward.
func _fender_step(delta: float) -> void:
	var f: Dictionary = motif.LAYOUT.fender
	var px := float(motif.LAYOUT.pier.x)
	var times: Array = FENDER_TIMES
	var total := 0.0
	for t: float in times: total += t
	for i in 2:
		var near := absf(deck_x(i)-px) < float(f.window) and _way(i) != 0.0
		if _fender_t[i] < 0.0 and near:
			_fender_t[i] = 0.0
			_fender_hit[i] = false
			swings += 1
		var angle := 0.0
		var t: float = _fender_t[i]
		if t >= 0.0:
			t += delta
			var w := float(times[0])
			var o := float(times[1])
			var h := float(times[2])
			if t < w: angle = 3.0*sin(t*40.0)
			elif t < w+o: angle = FENDER_SWING*smoothstep(0.0,1.0,(t-w)/o)
			elif t < w+o+h: angle = FENDER_SWING
			elif t < total: angle = FENDER_SWING*(1.0-smoothstep(0.0,1.0,(t-w-o-h)/float(times[3])))
			if t >= total and not near: t = -1.0
			elif t >= total: angle = 0.0
			_fender_t[i] = t
		var hinge: Node3D = fenders[i][0]
		var side := float(fenders[i][1])
		# Turned about up: -x (rest) toward side*z (out).
		hinge.global_transform.basis = Basis(Vector3.UP,side*deg_to_rad(angle))
		if t >= float(times[0]) and t < float(times[0])+float(times[1])+float(times[2]) and not _fender_hit[i] and motor != null:
			var a := hinge.global_position
			var b := hinge.global_transform*Vector3(-float(f.arm),0.0,0.0)
			var body: Vector3 = motor.feet+Vector3.UP*0.9
			var q := Geometry3D.get_closest_point_to_segment(body,a,b)
			if Vector2(body.x-q.x,body.z-q.z).length() < 0.8 and motor.feet.y > q.y-2.5 and motor.feet.y < q.y+0.5:
				var kv: Vector2 = f.knock
				motor.knock(Vector3(0.0,kv.y,side*kv.x),self)
				_fender_hit[i] = true
				fender_hits += 1
				print("haulway: fender %d knocked him" % i)
