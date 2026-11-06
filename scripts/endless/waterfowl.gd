extends Node3D
## Waterfowl that take off from the water (the waterfowl takeoff moment,
## scripts/endless/moments/waterfowl_takeoff.gd): a few mallards, or a grey
## heron in the shallows. Each bird is a pivot of a few MeshInstance3Ds
## (body, a head or neck, two wings, the heron's legs), flushed by
## scripts/endless/life_reacts.gd: they sit tight on the water watching the
## plane come (heads turned to it) until it is NEAR or turning past them,
## then go as one, each a beat after the last (the heron croaks and
## crouches): a run along the surface beating its wings with spray at its
## feet (the fish's splashes, scripts/endless/endless_fish.gd, when the land
## has them) and a flurry of wingbeats, then a climb away from the plane.
## Built when the moment starts and freed when it ends; nothing idle.
##
## The models face +Z with their feet (a duck's waterline) at the origin, in
## metres at life size (scripts/life_models.gd's way); each is drawn at a
## share of the plane's span, as the flock's birds are, so they read at a
## takeoff's distance.

const Models = preload("res://scripts/life_models.gd")
const LifeReacts = preload("res://scripts/endless/life_reacts.gd")
const WorldScale = preload("res://scripts/world_scale.gd")

const DUCK := &"duck"
const HERON := &"heron"
## Wingtip to wingtip as built (m), and as drawn: this share of the plane's span.
const LIFE_SPAN := {DUCK:1.06,HERON:1.78}
const SPAN_SHARE := {DUCK:0.6,HERON:0.8}
## The flush's knobs per kind (scripts/endless/life_reacts.gd KNOBS).
const FLUSH := {
	DUCK:{"near":60.0,"hold":14.0,"run":1.1,"run_speed":7.0,"speed":15.0,"accel":5.0,"climb":5.0,"climb_for":6.0,"wander":0.18,"time":18.0},
	HERON:{"near":80.0,"hold":14.0,"run":0.55,"run_speed":2.6,"speed":9.0,"accel":2.5,"climb":2.6,"climb_for":7.0,"wander":0.1,"time":18.0},
}
## Wingbeats a second, and the beat's swing (rad) either side of its middle:
## on the water (the run) and in the air.
const BEAT := {DUCK:[7.5,6.0],HERON:[3.0,2.3]}
const SWING := {DUCK:[0.75,0.95],HERON:[0.95,1.05]}
## Shoulders (x either side, y, z) as built.
const SHOULDER := {DUCK:Vector3(0.07,0.12,0.05),HERON:Vector3(0.08,0.88,0.0)}
## Seconds between a running duck's footfalls (a few drops each), and
## between the rings they leave.
const PATTER := 0.09
const PATTER_RING := 0.27
## They go too once the plane, within PASSING m, heads more than PASSING_OFF
## rad off them: it is going by to one side and they would go unseen.
const PASSING := 120.0
const PASSING_OFF := 0.9
## The sounds: a flurry of wingbeats as each bird starts its run (deeper for
## the heron), the heron's croak as it rouses. dB, pitch range, and the
## voices' reach (the grass birds' numbers, scripts/endless/grass_birds.gd).
const WINGS := "res://assets/audio/kit/wings-%d.wav"
const CROAK := "res://assets/audio/heron-call.wav"
const WINGS_DB := {DUCK:-7.0,HERON:-5.0}
const WINGS_PITCH := {DUCK:Vector2(0.78,0.92),HERON:Vector2(0.52,0.6)}
const CROAK_DB := -4.0
const VOICE_UNIT := 26.0
const VOICE_FAR := 240.0
## Gone past this far from the plane (m), or when its flush is over.
const GONE := 450.0
## Shrinks away over its last seconds.
const FADE := 0.6

## The birds: {kind, root, body, head, wings [+x, -x], legs, react, at,
## beat, open, patter, ring, scale, drake}.
var birds: Array = []
var _fish: Node = null
var _game: Node = null
var _rng := RandomNumberGenerator.new()
## One voice a bird; how many sounds have started (a check reads it).
var _voices: Array[AudioStreamPlayer3D] = []
var sounds := 0

static var _mat: StandardMaterial3D = null
static var _meshes := {}

## The birds of `kind` (DUCK or HERON) at the water `spot` ({at: the
## water's surface, bed, way: the flat way they run}), `count` of them
## (a heron is one), their draws from `draw_seed`.
func setup(game: Node, spot: Dictionary, kind: StringName, count: int, draw_seed: int) -> void:
	name = "Waterfowl"
	_game = game
	_rng.seed = draw_seed
	var fish: Variant = game.get("fish")
	if fish is Node and (fish as Node).has_method("_spray_add"): _fish = fish
	var at: Vector3 = spot.at
	var way: Vector3 = spot.way
	var plane_at: Vector3 = game.plane.position
	var n := 1 if kind == HERON else count
	for i in n:
		var p := at
		if i > 0:
			# Scattered round the first, each on water.
			var tries := 0
			while tries < 8:
				tries += 1
				var off := Vector3(_rng.randf_range(-6.0,6.0),0.0,_rng.randf_range(-6.0,6.0))
				var q := at+off
				var land: float = game.field.height(q.x,q.z)
				var w: float = game.water_at(Vector3(q.x,land,q.z),land)
				if w-land > 0.08:
					p = Vector3(q.x,w,q.z)
					break
			if tries >= 8: continue
		_add_bird(kind,p,float(spot.get("bed",at.y-1.0)),way,plane_at,i)
	for i in birds.size():
		var v := AudioStreamPlayer3D.new()
		v.bus = &"SFX"  # FlightSound.SFX
		v.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
		v.unit_size = VOICE_UNIT
		v.max_distance = VOICE_FAR
		v.panning_strength = 0.7
		v.doppler_tracking = AudioStreamPlayer3D.DOPPLER_TRACKING_DISABLED
		add_child(v)
		_voices.append(v)

func _add_bird(kind: StringName, at: Vector3, bed: float, way: Vector3, plane_at: Vector3, i: int) -> void:
	var drake := kind == DUCK and i%2 == 0
	var m: Dictionary = _meshes_for(kind,drake)
	var root := Node3D.new()
	root.name = "%s%d" % [kind,i]
	add_child(root)
	var body := MeshInstance3D.new()
	body.mesh = m.body
	root.add_child(body)
	var head := MeshInstance3D.new()
	head.mesh = m.head
	head.position = m.head_at
	root.add_child(head)
	var sh: Vector3 = SHOULDER[kind]
	var wings: Array = []
	for side: float in [1.0,-1.0]:
		var w := MeshInstance3D.new()
		w.mesh = m.wing_r if side > 0.0 else m.wing_l
		w.position = Vector3(sh.x*side,sh.y,sh.z)
		root.add_child(w)
		wings.append(w)
	var legs: MeshInstance3D = null
	if m.has("legs"):
		legs = MeshInstance3D.new()
		legs.mesh = m.legs
		legs.position = m.legs_at
		root.add_child(legs)
	for c: Node in root.get_children():
		(c as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var knobs: Dictionary = (FLUSH[kind] as Dictionary).duplicate()
	# Alert a beat, the first a little before the rest; a heron takes longer.
	knobs["wait"] = (0.45 if kind == HERON else 0.12)+0.22*i+_rng.randf_range(0.0,0.18)
	# Each a little off the group's way, all away from the plane.
	knobs["away"] = way.rotated(Vector3.UP,_rng.randf_range(-0.2,0.2))
	knobs["wobble"] = _rng.randf()*TAU
	var react: RefCounted = LifeReacts.begin(LifeReacts.FLUSH,at,plane_at,knobs)
	# A heron stands in the shallows: its feet on the bed, at most this deep.
	var feet := at
	if kind == HERON: feet.y = maxf(bed,at.y-0.3)
	var depth := at.y-feet.y
	react.surface = func(p: Vector3) -> float: return _surface(p,depth)
	var scale_k := float(SPAN_SHARE[kind])*float(WorldScale.span)/float(LIFE_SPAN[kind])
	birds.append({"kind":kind,"root":root,"body":body,"head":head,"wings":wings,"legs":legs,"react":react,
		"at":feet,"beat":_rng.randf()*TAU,"open":0.0,"patter":0.0,"ring":0.0,"scale":scale_k,"drake":drake,"t":0.0})
	_pose(birds.back(),0.0,plane_at)

## What a bird runs on under `p`: the water, `depth` under it for a wading
## heron, or the land where the water ends.
func _surface(p: Vector3, depth: float) -> float:
	var land: float = _game.field.height(p.x,p.z)
	var w: float = _game.water_at(Vector3(p.x,land,p.z),land)
	return maxf(land,w-depth)

## One frame; false once every bird is gone.
func step(delta: float, game: Node) -> bool:
	_game = game
	var plane_at: Vector3 = game.plane.position
	var plane_v: Vector3 = game.plane.velocity
	_rouse_all(plane_at,plane_v)
	var left := 0
	for i in birds.size():
		var b: Dictionary = birds[i]
		if b.root == null: continue
		var react: RefCounted = b.react
		var was: StringName = react.phase
		b.at = react.step(delta,b.at,plane_at,plane_v)
		b.t = float(b.t)+delta
		if react.roused and b.kind == HERON and not b.has("croaked"):
			b.croaked = true
			_sound(i,load(CROAK),CROAK_DB,_rng.randf_range(0.95,1.03))
		if was == LifeReacts.WAIT and react.phase != LifeReacts.WAIT:
			var pitch: Vector2 = WINGS_PITCH[b.kind]
			_sound(i,load(WINGS % _rng.randi_range(1,4)),float(WINGS_DB[b.kind]),_rng.randf_range(pitch.x,pitch.y))
		if was == LifeReacts.RUN and react.phase == LifeReacts.AIR: _lift_splash(b)
		if react.phase == LifeReacts.RUN: _patter(b,delta)
		var far := (b.at as Vector3).distance_to(plane_at) > GONE
		if react.phase == LifeReacts.DONE or far:
			(b.root as Node3D).queue_free()
			b.root = null
			continue
		left += 1
		_pose(b,delta,plane_at)
	return left > 0

## The flock goes as one: once one is roused (the plane NEAR it), or the
## plane is going by to one side of them, every bird is (each then waits its
## own beat).
func _rouse_all(plane_at: Vector3, plane_v: Vector3) -> void:
	var any := false
	var sitting := false
	for b: Dictionary in birds:
		if b.root == null: continue
		var react: RefCounted = b.react
		if react.roused: any = true
		else: sitting = true
	if not sitting: return
	if not any:
		var c := Vector3.ZERO
		var n := 0
		for b: Dictionary in birds:
			if b.root == null: continue
			c += b.at
			n += 1
		var to := Vector2(c.x/n-plane_at.x,c.z/n-plane_at.z)
		var way := Vector2(plane_v.x,plane_v.z)
		any = to.length() < PASSING and way.length() > 2.0 and absf(way.angle_to(to)) > PASSING_OFF
	if not any: return
	for b: Dictionary in birds:
		if b.root != null: (b.react as RefCounted).rouse()

## Plays `clip` at bird `i`.
func _sound(i: int, clip: AudioStream, db: float, pitch: float) -> void:
	if clip == null or i >= _voices.size(): return
	var v := _voices[i]
	v.global_position = birds[i].at
	v.stream = clip
	v.volume_db = db+_rng.randf_range(-1.5,1.5)
	v.pitch_scale = pitch
	v.play()
	sounds += 1

## Poses bird `b`: where it is, which way, its wings, head and legs by phase.
func _pose(b: Dictionary, delta: float, _plane_at: Vector3) -> void:
	var react: RefCounted = b.react
	var kind: StringName = b.kind
	var root: Node3D = b.root
	var phase: StringName = react.phase
	var wait := float(react.knobs.wait)
	var heron := kind == HERON
	# The wings open as it runs; the beat quickens from the run into the air.
	var air := phase == LifeReacts.AIR
	var going := phase == LifeReacts.RUN or air
	b.open = move_toward(float(b.open),1.0 if going else 0.0,delta/0.18)
	var beats: Array = BEAT[kind]
	var swings: Array = SWING[kind]
	var hz := float(beats[1] if air else beats[0])
	var swing := float(swings[1] if air else swings[0])
	if going: b.beat = float(b.beat)+delta*TAU*hz
	# A fast downstroke and a slower upstroke: the phase warped.
	var ph := float(b.beat)
	var stroke := sin(ph+0.45*sin(ph))
	# The body bobs against the wings; pitched up on the run, along its way in the air.
	var pitch := 0.0
	var dip := 0.0
	if phase == LifeReacts.WAIT and not react.roused:
		# Sitting tight: a duck rides the ripples, a heron stands still.
		if not heron:
			var bob := float(react.held)*2.1+float(b.beat)
			dip = 0.012*float(b.scale)*sin(bob)
			pitch = 0.03*sin(bob*0.7+1.0)
	elif phase == LifeReacts.WAIT:
		# The heron crouches before it goes (anticipation); a duck sits up.
		var k := smoothstep(wait-0.35,wait,float(react.in_phase))
		pitch = 0.18*k if heron else -0.08*k
		dip = -0.08*k if heron else 0.0
	elif phase == LifeReacts.RUN:
		pitch = -0.32 if not heron else -0.2
		dip = (0.04 if heron else 0.03)*stroke
		if heron: dip += 0.25*sin(PI*clampf(float(react.in_phase)/float(react.knobs.run),0.0,1.0))
	elif air:
		var v: Vector3 = react.velocity
		pitch = -atan2(v.y,Vector2(v.x,v.z).length())*0.7
		dip = 0.05*stroke*float(b.scale)
	var s := float(b.scale)
	var fade_from := float(react.knobs.time)-FADE
	if float(b.t) > fade_from: s *= clampf(1.0-(float(b.t)-fade_from)/FADE,0.0,1.0)
	var turn := Basis.looking_at(react.facing,Vector3.UP,true)*Basis(Vector3.RIGHT,pitch)
	root.transform = Transform3D(turn.scaled_local(Vector3.ONE*maxf(s,0.001)),(b.at as Vector3)+Vector3(0.0,dip,0.0))
	# Wings: folded along the back, opening into the beat.
	var open := float(b.open)
	var lift := swing*stroke+(0.25 if air else 0.45)
	for i in 2:
		var side := 1.0 if i == 0 else -1.0
		var folded := Quaternion(Vector3.UP,side*1.42)*Quaternion(Vector3.BACK,side*0.12)
		var spread := Quaternion(Vector3.BACK,side*lift)
		var q := folded.slerp(spread,open)
		var w: MeshInstance3D = b.wings[i]
		w.basis = Basis(q)*Basis.from_scale(Vector3(lerpf(0.5,1.0,open),1.0,1.0))
	# The head: turned to the plane while alert, then forward; a duck's neck
	# stretches out in the air, a heron's folds back.
	var head: MeshInstance3D = b.head
	if phase == LifeReacts.WAIT:
		var to_local: Vector3 = root.basis.orthonormalized().inverse()*react.look
		var yaw := clampf(atan2(to_local.x,to_local.z),-1.1,1.1)
		var up := clampf(asin(clampf(to_local.y,-1.0,1.0)),-0.2,0.5)
		head.basis = Basis(Vector3.UP,yaw)*Basis(Vector3.RIGHT,-up*0.6)
	elif heron:
		var fold := smoothstep(0.0,1.0,float(react.in_phase)) if air else 0.0
		head.basis = Basis(Vector3.RIGHT,-0.95*fold)
	else:
		head.basis = Basis(Vector3.RIGHT,1.05*float(b.open))
	if b.legs != null:
		var trail := smoothstep(0.0,0.8,float(react.in_phase)) if air else 0.0
		(b.legs as Node3D).basis = Basis(Vector3.RIGHT,1.45*trail)

## A running duck's feet slapping the water: a few drops, a ring now and then.
func _patter(b: Dictionary, delta: float) -> void:
	if _fish == null: return
	var react: RefCounted = b.react
	b.patter = float(b.patter)-delta
	b.ring = float(b.ring)-delta
	var at: Vector3 = b.at
	var w: float = _surface(at,0.0)
	var land: float = _game.field.height(at.x,at.z)
	if w <= land+0.02: return
	var s := float(b.scale)
	var v: Vector3 = react.velocity
	if float(b.patter) <= 0.0:
		b.patter = PATTER*(1.6 if b.kind == HERON else 1.0)
		var foot := Vector3(at.x,w+0.01,at.z)-Vector3(v.x,0.0,v.z).normalized()*0.12*s
		for k in 3:
			var a := _rng.randf()*TAU
			var dv := Vector3(cos(a)*0.6,_rng.randf_range(0.9,1.9),sin(a)*0.6)-v*0.15
			_fish._spray_add(foot,dv,_rng.randf_range(0.35,0.6),_rng.randf_range(0.025,0.045)*s*1.4,false,w)
		# A puff of white each footfall: the line of splashes reads from afar.
		_fish._spray_add(foot+Vector3(0.0,0.08,0.0),Vector3(0.0,_rng.randf_range(0.5,1.0),0.0)-v*0.1,_rng.randf_range(0.45,0.7),_rng.randf_range(0.22,0.32)*s,true,w)
	if float(b.ring) <= 0.0:
		b.ring = PATTER_RING
		_fish._ring(Vector3(at.x,w+0.025,at.z),0.9*s,0.9,0.22,0.45,0.5)

## The splash it leaves the water with.
func _lift_splash(b: Dictionary) -> void:
	if _fish == null: return
	var at: Vector3 = b.at
	var w: float = _surface(at,0.0)
	if w <= float(_game.field.height(at.x,at.z))+0.02: return
	var react: RefCounted = b.react
	_fish._splash(Vector3(at.x,w,at.z),react.velocity,0.8 if b.kind == DUCK else 1.0,true)

# --- The models -------------------------------------------------------------

static func material() -> StandardMaterial3D:
	if _mat == null:
		_mat = StandardMaterial3D.new()
		_mat.vertex_color_use_as_albedo = true
		_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		_mat.roughness = 0.95
	return _mat

## {body, head, head_at, wing_r, wing_l, (legs, legs_at)} for `kind`
## (a drake's or a hen's colours for a duck), built once.
static func _meshes_for(kind: StringName, drake: bool) -> Dictionary:
	var key := "%s%s" % [kind,"m" if drake else "f"]
	if _meshes.has(key): return _meshes[key]
	var mat := material()
	var out := {}
	if kind == HERON:
		out = {"body":Models.heron_body(mat),"head":Models.heron_neck(mat),"head_at":Vector3(0.0,0.86,0.12),
			"wing_r":Models.heron_wing(mat,false),"wing_l":Models.heron_wing(mat,true),
			"legs":Models.heron_legs(mat),"legs_at":Vector3(0.0,0.72,-0.06)}
	else:
		out = {"body":_duck_body(mat,drake),"head":_duck_head(mat,drake),"head_at":Vector3(0.0,0.11,0.15),
			"wing_r":_duck_wing(mat,false,drake),"wing_l":_duck_wing(mat,true,drake)}
	for part: String in ["body","head","wing_r","wing_l","legs"]:
		if out.has(part): out[part] = _outward(out[part])
	_meshes[key] = out
	return out

## `mesh` with its normals turned over: life_models.gd's Build winds its
## faces Godot's front way out but keeps the three.js normal, which points
## in, so the birds lit as if from inside (near black).
static func _outward(mesh: ArrayMesh) -> ArrayMesh:
	var arrays := mesh.surface_get_arrays(0)
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	for i in normals.size(): normals[i] = -normals[i]
	arrays[Mesh.ARRAY_NORMAL] = normals
	var out := ArrayMesh.new()
	out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	out.surface_set_material(0,mesh.surface_get_material(0))
	return out

## A mallard's body afloat, its waterline at y 0: grey with a chestnut
## breast and a dark stern (a drake), or mottled brown (a hen).
static func _duck_body(mat: Material, drake: bool) -> ArrayMesh:
	var b: Models.Build = Models.Build.new()
	var flank := Color(0.62,0.6,0.56) if drake else Color(0.5,0.39,0.27)
	var stern := Color(0.12,0.12,0.13) if drake else Color(0.38,0.29,0.2)
	b.spindle(Vector3(0,0.06,-0.26),Vector3(0,0.08,0.19),0.12,flank,6,0.45,0.08)
	b.spindle(Vector3(0,0.09,-0.3),Vector3(0,0.1,-0.06),0.07,stern,5,0.4,0.05)
	b.spindle(Vector3(0,0.05,0.0),Vector3(0,0.1,0.21),0.09,Color(0.4,0.22,0.15) if drake else flank.darkened(0.08),5,0.5,0.07)
	# A white tail fan.
	b.fan(Vector3(0,0.1,-0.27),[Vector3(-0.05,0.11,-0.33),Vector3(0,0.12,-0.36),Vector3(0.05,0.11,-0.33)],Color(0.86,0.85,0.8) if drake else stern)
	return b.commit(mat)

## The neck and head from their pivot at the breast's top: a green head, a
## white collar and a yellow bill (a drake), or brown with an orange bill.
static func _duck_head(mat: Material, drake: bool) -> ArrayMesh:
	var b: Models.Build = Models.Build.new()
	var head := Color(0.08,0.3,0.16) if drake else Color(0.45,0.35,0.24)
	b.spindle(Vector3(0,-0.02,-0.01),Vector3(0,0.12,0.03),0.04,head if drake else head.lightened(0.05),5,0.45)
	if drake: b.spindle(Vector3(0,0.02,0.0),Vector3(0,0.045,0.008),0.042,Color(0.92,0.92,0.9),5,0.5)
	b.icosahedron(Vector3(0,0.13,0.045),0.05,head,0.85)
	b.spindle(Vector3(0,0.125,0.08),Vector3(0,0.11,0.16),0.022,Color(0.86,0.72,0.2) if drake else Color(0.8,0.45,0.15),4,0.25,0.012)
	return b.commit(mat)

## One wing from the shoulder along +X (the left mirrors it), with the
## blue speculum near its trailing edge.
static func _duck_wing(mat: Material, left: bool, drake: bool) -> ArrayMesh:
	var b: Models.Build = Models.Build.new()
	var s := -1.0 if left else 1.0
	var c := Color(0.48,0.45,0.42) if drake else Color(0.45,0.36,0.26)
	var rim := [Vector3(0,0,0.07),Vector3(0.18*s,0.01,0.08),Vector3(0.36*s,0.0,0.03),Vector3(0.46*s,-0.01,-0.07),Vector3(0.3*s,0.0,-0.12),Vector3(0.12*s,0.0,-0.13),Vector3(0.0,0.0,-0.1)]
	b.fan(Vector3(0.0,0.0,-0.02),rim,c,c.darkened(0.35))
	b.fan(Vector3(0.14*s,0.004,-0.09),[Vector3(0.07*s,0.004,-0.075),Vector3(0.22*s,0.004,-0.085),Vector3(0.22*s,0.004,-0.125),Vector3(0.08*s,0.004,-0.12),Vector3(0.07*s,0.004,-0.075)],Color(0.18,0.25,0.62))
	return b.commit(mat)
