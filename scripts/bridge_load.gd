extends Node3D
## A rope bridge that bears a load and strains under it (docs/design/
## bridge-snap/spec-bridge-snap.md). Opt-in: a live rope bridge (scripts/
## rope_bridge.gd) with one of these as its child carries weight; every
## other bridge never does and lives as before.
##
## The contract: any body on a deck tells it "I'm here, this many kg" each
## frame, `BridgeLoad.bear_at(world, kg, who)` (the bridge under `world`
## takes it, if any is loaded); the bridge sums what's on its deck. A body
## that stops telling it (gone, off the deck) drops out after FORGET s. The
## wanderer's own weight is WANDERER_KG; the study tells it his, his bag's
## and each brood guy's (scripts/brood/brood_knobs.gd RIDER_KG), and later
## enemies only have to call `bear_at`.
##
## Between STRAIN_KG and SNAP_KG it strains, `strain` rising 0 to 1 with the
## load: the deck sags deeper (sim `load` at the load's middle), creaks and
## groans come quicker, louder and lower, the deck jolts and sways harder,
## planks pop loose and fall (past PLANK_FROM), the hand ropes fray, strands
## whipping off (past FRAY_FROM). Past SNAP_KG `over_t` counts the seconds
## held there. Below STRAIN_KG it is the normal bridge.
##
## The snap: held past the limit SNAP_HOLD s, it parts at the load's middle
## (kept SNAP_IN from either end). The drawn bridge goes; two halves, plank
## chains pinned at each end, fall and swing down to hang against each
## cliff face (folding over the lip `lip` m out from each end), and
## `snapped` tells the host, who takes the deck away so everything on it
## falls. `mend` puts the whole bridge back.

signal snapped(t: float)
signal mended

const WANDERER_KG := 60.0
## The strain's start and the limit (kg on the deck). The wanderer with a
## full bag (24 kg) is 84: past the start (a creak now and then, he knows
## it's near) and under the limit; with RIDER_KG 2.5, five brood guys on
## the deck with him take it past.
const STRAIN_KG := 80.0
const SNAP_KG := 96.0
## A body counts on the deck within its width plus SIDE_SLACK m to a side
## and from DOWN_SLACK m under its planks' top to UP_SLACK over it.
const SIDE_SLACK := 0.3
const DOWN_SLACK := 0.6
const UP_SLACK := 1.2
## A body not heard from for FORGET s is off the deck.
const FORGET := 0.15
## The strain follows the load over EASE s.
const EASE := 0.25
## The extra sag at full strain, as shares of the sim's SAG_UNDER.
const SAG_SHARE := 3.0
## Creaks: every CREAK_EVERY s (slow at the strain's start, quick at its
## top, jittered a third), CREAK_DB loud, pitched CREAK_PITCH; each jolts
## the deck down JOLT m/s and sideways SWAY_PUSH m/s, the more strained.
const CREAK_EVERY := Vector2(2.4,0.35)
const CREAK_DB := Vector2(-12.0,3.0)
const CREAK_PITCH := Vector2(1.05,0.72)
const JOLT := 0.35
const SWAY_PUSH := 0.9
## Planks pop loose past PLANK_FROM of the strain, every PLANK_EVERY s.
const PLANK_FROM := 0.3
const PLANK_EVERY := Vector2(3.0,0.5)
## Strands fray off the hand ropes past FRAY_FROM, every FRAY_EVERY s,
## STRANDS at a time.
const FRAY_FROM := 0.5
const FRAY_EVERY := Vector2(2.6,0.45)
const STRANDS := Vector2i(2,4)
## Bits fallen past this far under the deck are gone (m).
const FALL_GONE := 45.0
const GRAVITY := 9.8
## Past the limit this long (s), it snaps, at the load's middle kept this
## far (t) from either end.
const SNAP_HOLD := 0.8
const SNAP_IN := 0.15
## The halves: links about LINK m long, stepped at STEP s, the links
## settled ITERS times a step, losing DAMP of their speed a second; the
## break flings them down SNAP_DROP m/s and sideways up to SNAP_SWAY.
const LINK := 0.5
const STEP := 1.0/120.0
const ITERS := 8
const DAMP := 0.6
const SNAP_DROP := 2.5
const SNAP_SWAY := 1.2
## What flies at the break: planks and strands.
const SNAP_PLANKS := 7
const SNAP_FRAYS := 3

const CREAKS := ["res://assets/audio/kit/creak-1.wav","res://assets/audio/kit/creak-2.wav","res://assets/audio/kit/creak-3.wav",
	"res://assets/audio/kit/creak-4.wav","res://assets/audio/kit/creak-5.wav","res://assets/audio/kit/creak-6.wav",
	"res://assets/audio/kit/rope-creak-1.wav","res://assets/audio/kit/rope-creak-2.wav","res://assets/audio/kit/rope-creak-3.wav",
	"res://assets/audio/kit/rope-creak-4.wav"]
const WHIPS := ["res://assets/audio/kit/rope-whip-1.wav","res://assets/audio/kit/rope-whip-2.wav","res://assets/audio/kit/rope-whip-3.wav"]
const RopeBridge = preload("res://scripts/rope_bridge.gd")
const PLANK_COLOUR := Color("7d6448")
const STRAND_COLOUR := Color("b39a6e")

## Every loaded bridge in the tree.
static var _all: Array = []

## The live rope bridge this loads (the parent).
var bridge: MeshInstance3D
## A name for the readout.
var title := "bridge"
## Its limits (kg), from the consts unless set.
var strain_kg := STRAIN_KG
var snap_kg := SNAP_KG
## The load now (kg), the strain (0 to 1, eased) and the seconds held past
## the limit; who's on it now ({who: [t, side, kg, sags, age]}).
var kg := 0.0
var strain := 0.0
var over_t := 0.0
var borne := {}
## Counts, for drivers: creaks played, planks popped, strands frayed.
var creaks := 0
var planks := 0
var frays := 0
## A readout on screen (a debug aid).
var readout: Label = null
## Snapped, where (t), and the halves: [{end (0 a, 1 b), pts, was (verlet),
## node, planks, ropes (MultiMeshes)}], points in the bridge's frame,
## pts[0] pinned at the end. How far out from each end the cliff's lip is
## (m, the host sets it): the halves fold over it.
var broken := false
var break_t := 0.5
var halves: Array = []
var lip := 0.0
var _left := 0.0
var _layers := 1

var _rng := RandomNumberGenerator.new()
var _creak_t := 1.0
var _plank_t := 1.0
var _fray_t := 1.0
var _bits: Array = []
var _sound: AudioStreamPlayer3D
var _whip: AudioStreamPlayer3D
var _streams := {}

## Hang one on `live` (a RopeBridge), `title` for the readout.
static func on(live: MeshInstance3D, name_for: String, seed_value := 0) -> Node:
	var held: Node = new()
	held.name = "Load"
	held.title = name_for
	held._rng.seed = seed_value
	live.add_child(held)
	return held

func _enter_tree() -> void:
	bridge = get_parent() as MeshInstance3D
	if not _all.has(self): _all.append(self)

func _exit_tree() -> void:
	_all.erase(self)

func _ready() -> void:
	process_priority = 50
	_sound = AudioStreamPlayer3D.new()
	_sound.unit_size = 14.0
	_sound.max_polyphony = 3
	add_child(_sound)
	_whip = AudioStreamPlayer3D.new()
	_whip.unit_size = 10.0
	_whip.max_polyphony = 3
	add_child(_whip)

# --- The contract --------------------------------------------------------------------

## A body at `world` weighing `kg` (kg) this frame, `who` it (any object or
## key, one entry each). The loaded bridge whose deck holds `world` bears
## it; `sags` false when its weight already sinks the deck another way (the
## wanderer's, by RopeBridge `tread`). Returns the bridge that took it, or
## null (on none).
static func bear_at(world: Vector3, kg_in: float, who: Variant, sags := true) -> Node:
	for held: Node in _all:
		if held.bear(world,kg_in,who,sags): return held
	return null

## `bear_at` for this bridge alone: true if `world` is on its deck.
func bear(world: Vector3, kg_in: float, who: Variant, sags := true) -> bool:
	if broken: return false
	var on := deck_spot(world)
	if on == Vector3.INF: return false
	borne[who] = [on.x,on.y,kg_in,sags,0.0]
	return true

## Where `world` stands on the deck (Vector3(t, side, height over the
## planks), RopeBridge `_on_deck`), or INF if off it.
func deck_spot(world: Vector3) -> Vector3:
	if bridge == null or bridge.sim == null: return Vector3.INF
	var local: Vector3 = bridge.global_transform.affine_inverse()*world
	var half := float(bridge.sim.width)*0.5
	if not bridge._near_deck(local,half+SIDE_SLACK+bridge.SWAY_ROOM): return Vector3.INF
	var on: Vector3 = bridge._on_deck(local)
	if on.x <= 0.0 or on.x >= 1.0: return Vector3.INF
	if absf(on.y-float(bridge.sim.sway(on.x))) > half+SIDE_SLACK: return Vector3.INF
	if on.z < -DOWN_SLACK or on.z > UP_SLACK: return Vector3.INF
	return on

## The deck's top at `t`, `side` now (this bridge's frame).
func deck_point(t: float, side: float) -> Vector3:
	var a: Vector3 = bridge.a
	var b: Vector3 = bridge.b
	var tc := clampf(t,0.0,1.0)
	var p := a.lerp(b,tc)
	p.y = lerpf(a.y,b.y,tc)+float(bridge.bow)*pow(sin(PI*tc),2.0)+float(bridge.sim.drop(tc,side))
	return p+bridge.across*(side+float(bridge.sim.sway(tc)))

# --- Each frame ------------------------------------------------------------------------

func _process(delta: float) -> void:
	if bridge == null: return
	if broken:
		_swing(delta)
		_fall(delta)
		_read_out()
		return
	var total := 0.0
	var mid := Vector2.ZERO
	var share: float = WANDERER_KG
	for who: Variant in borne.keys():
		var e: Array = borne[who]
		e[4] = float(e[4])+delta
		if float(e[4]) > FORGET:
			borne.erase(who)
			continue
		var w := float(e[2])
		total += w
		mid += Vector2(float(e[0]),float(e[1]))*w
		if bool(e[3]) and w > 0.0: bridge.sim.load(float(e[0]),float(e[1]),w/share)
	kg = total
	if total > 0.0: mid /= total
	var want := clampf((total-strain_kg)/maxf(snap_kg-strain_kg,0.1),0.0,1.0)
	strain = move_toward(strain,want,delta/EASE)
	over_t = over_t+delta if total >= snap_kg else 0.0
	if strain > 0.001 and total > 0.0: _strain(delta,strain,mid)
	if over_t >= SNAP_HOLD:
		snap(mid.x)
		return
	_fall(delta)
	_read_out()

## The cues at strain `s` (0 to 1), the load's middle at `mid` (t, side).
func _strain(delta: float, s: float, mid: Vector2) -> void:
	bridge.sim.load(mid.x,mid.y,s*SAG_SHARE)
	_creak_t -= delta
	if _creak_t <= 0.0:
		_creak_t = lerpf(CREAK_EVERY.x,CREAK_EVERY.y,s)*_rng.randf_range(0.67,1.33)
		_creak(s,mid)
	if s >= PLANK_FROM:
		_plank_t -= delta
		if _plank_t <= 0.0:
			_plank_t = lerpf(PLANK_EVERY.x,PLANK_EVERY.y,(s-PLANK_FROM)/(1.0-PLANK_FROM))*_rng.randf_range(0.6,1.4)
			_pop_plank(mid)
	if s >= FRAY_FROM:
		_fray_t -= delta
		if _fray_t <= 0.0:
			_fray_t = lerpf(FRAY_EVERY.x,FRAY_EVERY.y,(s-FRAY_FROM)/(1.0-FRAY_FROM))*_rng.randf_range(0.6,1.4)
			_fray(s,mid)

func _creak(s: float, mid: Vector2) -> void:
	creaks += 1
	var t := clampf(mid.x+_rng.randf_range(-0.12,0.12),0.05,0.95)
	_sound.global_position = bridge.global_transform*deck_point(t,0.0)
	_sound.stream = _stream(CREAKS[_rng.randi()%CREAKS.size()])
	_sound.volume_db = lerpf(CREAK_DB.x,CREAK_DB.y,s)
	_sound.pitch_scale = lerpf(CREAK_PITCH.x,CREAK_PITCH.y,s)*_rng.randf_range(0.93,1.07)
	_sound.play()
	var lateral := SWAY_PUSH*s*(1.0 if _rng.randf() < 0.5 else -1.0)
	bridge.sim.kick(t,mid.y,JOLT*s,lateral,0.7)

## A plank pops out from under the deck near the load and falls, tumbling.
func _pop_plank(mid: Vector2) -> void:
	planks += 1
	var t := clampf(mid.x+_rng.randf_range(-0.15,0.15),0.04,0.96)
	var at := deck_point(t,0.0)+Vector3.DOWN*0.06
	var box := BoxMesh.new()
	box.size = Vector3(float(bridge.sim.width)*0.95,0.05,0.2)
	var m := StandardMaterial3D.new()
	m.albedo_color = PLANK_COLOUR*_rng.randf_range(0.85,1.1)
	m.roughness = 0.9
	var way: Vector3 = (bridge.b-bridge.a).normalized()
	var v: Vector3 = bridge.across*_rng.randf_range(-0.8,0.8)+Vector3.UP*_rng.randf_range(0.2,1.0)
	_spawn(box,m,Transform3D(Basis.looking_at(way,Vector3.UP),at),v,
		Vector3(_rng.randf_range(-6.0,6.0),_rng.randf_range(-2.0,2.0),_rng.randf_range(-6.0,6.0)))
	_whip.global_position = bridge.global_transform*at
	_whip.stream = _stream(CREAKS[_rng.randi()%6])
	_whip.pitch_scale = _rng.randf_range(1.3,1.6)
	_whip.volume_db = -4.0
	_whip.play()

## The hand rope at one side frays: strands whip off it, out and down.
func _fray(s: float, mid: Vector2) -> void:
	frays += 1
	var side_sign := 1.0 if _rng.randf() < 0.5 else -1.0
	var t := clampf(mid.x+_rng.randf_range(-0.2,0.2),0.05,0.95)
	var half := float(bridge.sim.width)*0.5
	var at := deck_point(t,side_sign*half)+Vector3.UP*float(bridge.hand_rope)
	var m := StandardMaterial3D.new()
	m.albedo_color = STRAND_COLOUR
	m.roughness = 0.95
	for i in range(_rng.randi_range(STRANDS.x,STRANDS.y)):
		var c := CylinderMesh.new()
		c.top_radius = 0.008
		c.bottom_radius = 0.012
		c.height = _rng.randf_range(0.35,0.8)
		c.radial_segments = 4
		c.rings = 1
		var out: Vector3 = bridge.across*side_sign*_rng.randf_range(1.5,3.5)+Vector3.UP*_rng.randf_range(0.5,2.0)+(bridge.b-bridge.a).normalized()*_rng.randf_range(-1.0,1.0)
		_spawn(c,m,Transform3D(Basis.from_euler(Vector3(_rng.randf()*TAU,_rng.randf()*TAU,_rng.randf()*TAU)),at),out,
			Vector3(_rng.randf_range(-14.0,14.0),_rng.randf_range(-14.0,14.0),_rng.randf_range(-14.0,14.0)))
	_whip.global_position = bridge.global_transform*at
	_whip.stream = _stream(WHIPS[_rng.randi()%WHIPS.size()])
	_whip.pitch_scale = _rng.randf_range(0.95,1.2)
	_whip.volume_db = lerpf(-6.0,2.0,s)
	_whip.play()

## A loose bit (a plank, a strand), in this bridge's frame, flung at `v`
## (m/s), spinning `spin` (rad/s), falling till it's gone.
func _spawn(mesh: Mesh, mat: Material, xf: Transform3D, v: Vector3, spin: Vector3) -> void:
	var n := MeshInstance3D.new()
	n.mesh = mesh
	n.material_override = mat
	n.transform = xf
	add_child(n)
	_bits.append({"node":n,"v":v,"spin":spin,"y0":xf.origin.y})

func _fall(delta: float) -> void:
	for i in range(_bits.size()-1,-1,-1):
		var b: Dictionary = _bits[i]
		var n: MeshInstance3D = b.node
		var v: Vector3 = b.v
		v.y -= GRAVITY*delta
		v *= 1.0-0.25*delta
		b.v = v
		n.position += v*delta
		var spin: Vector3 = b.spin
		if spin.length() > 0.0: n.basis = Basis(spin.normalized(),spin.length()*delta)*n.basis
		if n.position.y < float(b.y0)-FALL_GONE:
			n.queue_free()
			_bits.remove_at(i)

# --- The snap ------------------------------------------------------------------------

## Parts the bridge at `t`: the drawn one goes (its walk deck with it, for
## the walker; the host clears its own boxes on `snapped`), two halves fall
## from the ends, planks and strands fly at the break.
func snap(t: float) -> void:
	if broken: return
	broken = true
	break_t = clampf(t,SNAP_IN,1.0-SNAP_IN)
	var at := deck_point(break_t,0.0)
	_layers = bridge.layers
	bridge.layers = 0
	bridge.set_process(false)
	RopeBridge._live.erase(bridge)
	borne.clear()
	kg = 0.0
	strain = 0.0
	over_t = 0.0
	for i in range(SNAP_PLANKS): _pop_plank(Vector2(break_t,0.0))
	for i in range(SNAP_FRAYS): _fray(1.0,Vector2(break_t,0.0))
	_sound.global_position = bridge.global_transform*at
	_sound.stream = _stream(CREAKS[_rng.randi_range(6,CREAKS.size()-1)])
	_sound.volume_db = 6.0
	_sound.pitch_scale = 0.6
	_sound.play()
	var sway := _rng.randf_range(-SNAP_SWAY,SNAP_SWAY)
	for end in [0,1]: halves.append(_half(end,sway))
	snapped.emit(break_t)

## The whole bridge back as it was built.
func mend() -> void:
	if not broken: return
	broken = false
	for h: Dictionary in halves: (h.node as Node).queue_free()
	halves.clear()
	bridge.layers = _layers
	bridge.set_process(true)
	if bridge.is_inside_tree() and not RopeBridge._live.has(bridge): RopeBridge._live.append(bridge)
	borne.clear()
	strain = 0.0
	over_t = 0.0
	mended.emit()

## One half, from end `end` (0 a, 1 b) to the break: a plank chain laid
## where the deck hangs now, flung down and `sway` m/s sideways.
func _half(end: int, sway: float) -> Dictionary:
	var t0 := 0.0 if end == 0 else 1.0
	var length := float(bridge.span)*absf(break_t-t0)
	var n := maxi(2,int(round(length/LINK)))
	var pts := PackedVector3Array()
	var was := PackedVector3Array()
	var kick: Vector3 = (Vector3.DOWN*SNAP_DROP+bridge.across*sway)*STEP
	for i in range(n+1):
		var t := lerpf(t0,break_t,float(i)/n)
		var p := deck_point(t,0.0)
		pts.append(p)
		was.append(p-kick*float(i)/n)
	var node := Node3D.new()
	node.name = "Half%d" % end
	add_child(node)
	var wood := StandardMaterial3D.new()
	wood.albedo_color = PLANK_COLOUR
	wood.roughness = 0.9
	var rope := StandardMaterial3D.new()
	rope.albedo_color = STRAND_COLOUR
	rope.roughness = 0.95
	var w := float(bridge.sim.width)
	var plank := BoxMesh.new()
	plank.size = Vector3(w*0.95,0.05,LINK*0.55)
	var cord := BoxMesh.new()
	cord.size = Vector3(0.045,0.045,1.0)
	var planks := _multi(node,plank,wood,n)
	var ropes := _multi(node,cord,rope,n*2)
	var h := {"end":end,"pts":pts,"was":was,"node":node,"planks":planks,"ropes":ropes,"link":length/n}
	_draw_half(h)
	return h

func _multi(parent: Node3D, mesh: Mesh, mat: Material, count: int) -> MultiMesh:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = count
	# Room for the whole fall (the links move every frame; no recomputed box).
	var reach := float(bridge.span)+FALL_GONE
	mm.custom_aabb = AABB(Vector3(-reach,-FALL_GONE*2.0,-reach),Vector3(reach*2.0,FALL_GONE*2.5,reach*2.0))
	var inst := MultiMeshInstance3D.new()
	inst.multimesh = mm
	inst.material_override = mat
	parent.add_child(inst)
	return mm

## The halves fall and swing (verlet, fixed steps), the links held to
## length, pinned at their ends, kept out of the cliff past the lip.
func _swing(delta: float) -> void:
	if halves.is_empty(): return
	_left = minf(_left+delta,STEP*8.0)
	while _left >= STEP:
		_left -= STEP
		for h: Dictionary in halves: _step_half(h)
	for h: Dictionary in halves: _draw_half(h)

func _step_half(h: Dictionary) -> void:
	var pts: PackedVector3Array = h.pts
	var was: PackedVector3Array = h.was
	var keep := 1.0-DAMP*STEP
	var g := Vector3.DOWN*GRAVITY*STEP*STEP
	for i in range(1,pts.size()):
		var p := pts[i]
		pts[i] = p+(p-was[i])*keep+g
		was[i] = p
	var link: float = h.link
	var end_at: Vector3 = bridge.a if int(h.end) == 0 else bridge.b
	var out: Vector3 = (bridge.b-bridge.a)
	out.y = 0.0
	out = out.normalized()*(1.0 if int(h.end) == 0 else -1.0)
	for k in range(ITERS):
		pts[0] = end_at
		for i in range(pts.size()-1):
			var d := pts[i+1]-pts[i]
			var l := d.length()
			if l < 0.0001: continue
			var fix := d*((l-link)/l)
			if i == 0: pts[i+1] -= fix
			else:
				pts[i] += fix*0.5
				pts[i+1] -= fix*0.5
		for i in range(1,pts.size()):
			# The cliff: past the end's ground and short of the lip.
			var rel := pts[i]-end_at
			var along := rel.dot(out)
			var under := -rel.y
			if along < lip and under > -0.03:
				if lip-along < under+0.03: pts[i] += out*(lip-along+0.02)
				else: pts[i].y = end_at.y+0.03
	h.pts = pts
	h.was = was

func _draw_half(h: Dictionary) -> void:
	var pts: PackedVector3Array = h.pts
	var planks: MultiMesh = h.planks
	var ropes: MultiMesh = h.ropes
	var half_w := float(bridge.sim.width)*0.5
	for i in range(pts.size()-1):
		var d := pts[i+1]-pts[i]
		var l := maxf(d.length(),0.001)
		var z := d/l
		var x: Vector3 = (bridge.across-z*z.dot(bridge.across)).normalized()
		var y := z.cross(x)
		var mid := (pts[i]+pts[i+1])*0.5
		planks.set_instance_transform(i,Transform3D(Basis(x,y,z),mid+y*0.025))
		var stretched := Basis(x,y,z*l)
		ropes.set_instance_transform(i*2,Transform3D(stretched,mid+x*half_w+y*0.05))
		ropes.set_instance_transform(i*2+1,Transform3D(stretched,mid-x*half_w+y*0.05))

## Half `i`'s points in the world (pts[0] at its end), for climbers.
func half_points(i: int) -> PackedVector3Array:
	var out := PackedVector3Array()
	if i >= halves.size(): return out
	var xf := bridge.global_transform
	for p: Vector3 in (halves[i].pts as PackedVector3Array): out.append(xf*p)
	return out

func _stream(path: String) -> AudioStream:
	if not _streams.has(path): _streams[path] = load(path)
	return _streams[path]

func _read_out() -> void:
	if readout == null: return
	var tag := "ok"
	if broken:
		readout.text = "%s: SNAPPED at %.0f%% of its span · R or a fall: mended" % [title,break_t*100.0]
		readout.modulate = Color(1.0,0.35,0.3)
		return
	if kg >= snap_kg: tag = "PAST THE LIMIT %.1f s" % over_t
	elif strain > 0.0: tag = "straining"
	readout.text = "%s: %.1f / %.0f kg (strain from %.0f) · strain %.2f · %s · %d on it" % [title,kg,snap_kg,strain_kg,strain,tag,borne.size()]
	readout.modulate = Color(1.0,1.0-strain*0.7,1.0-strain*0.85)
