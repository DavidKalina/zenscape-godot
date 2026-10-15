extends "res://studies/character_study.gd"
## The city serpent yard (docs/design/roguelike/city-serpent-round1.md): the
## rune serpent as the underground city's train, on a basalt plaza over the
## abyss, in the underground look (`--underground`, torch by default;
## `--underground=haze`). Its line (one closed B-spline built from the
## pieces' own `way`s) runs north up the trough beside the waiting dais,
## through the threading ring, dives off the plaza's end, rises out of the
## dark round the coil pillar and winds up it beside the ramp, rolls past
## the cap, and loops back over the abyss to the dais: about a minute and a
## half a lap. Two collars ride it, each a saddle and a lantern.
##   the dais      east: wait in the shrine; the tick stones across the
##                 trough light one a second as it comes; run off the lip
##                 onto its back or its saddle as it goes by
##   the ring      north-east, over the trough: climb an abutment and the
##                 crown courses to its cap and watch it thread under you
##   the coil      north, over the abyss, a bridge to its foot: ride the
##                 collar up beside the ramp, step off onto the ramp or the
##                 cap; past the cap the collar shrugs a rider onto it
##   the ash bowl  west, in a court a long drop under the plaza: walk off
##                 the plank's end into the ash (caught), off its side onto
##                 the stone (stunned)
##   the shuttle   south: a slab ferrying across a gap (moving ground on its
##                 own: ride it, jump off it and keep its pace)
## Keys: 1 dais, 2 on the front collar's saddle, 3 coil cap, 4 the plank, 5
## ring crown, 6 the shuttle stop, 7 the bridge; R all back (the serpent
## to its loop); C the serpent called (a dozen seconds from the dais); P the
## serpent held still (and on again); L torch / haze; F1 numbers.
##   godot --path . res://studies/city_serpent_yard.tscn -- --no-title
##     [--underground=haze|torch] [--day] [--serpent-at=<mark|m>]
##     [--serpent-speed=<x>] [--girth=<x>] [--no-shuttle]
const Kit = preload("res://scripts/city_kit_serpent.gd")
const RuneSerpent = preload("res://scripts/rune_serpent.gd")
const Underground = preload("res://scripts/underground/underground.gd")
const GiantStone = preload("res://scripts/kit_isle/greybox/giant_stone.gd")
const GroundCover = preload("res://scripts/underground/ground_cover.gd")
const CityFire = preload("res://scripts/city_fire.gd")
const LaunchArgs = preload("res://scripts/launch_args.gd")

const YARD_LOST := -40.0
const HEMI := {"torch":0.12,"haze":0.55}
## The plaza west of the trough, the strip east of it (x, z), their slab's
## depth; the trough's x (its floor the dais's).
const PLAZA := Rect2(-14.0,-50.0,53.5,90.0)
const STRIP_WIDE := 12.0
const DEEP := 12.0
## The dais (its middle; its trough on its east, the line up the trough's
## middle); the ring's middle over the line (its height, its z); the coil's
## axis (its z; its x a line radius west of the line).
const DAIS_AT := Vector3(32.9,0.0,0.0)
const RING_Y := 7.5
const RING_Z := -42.0
const COIL_Z := -105.0
## The coil's foot (radians from +x toward -z): just east of due south, so
## the bridge lands on its level landing.
const COIL_FOOT := -PI*0.5+0.1745
## The bridge to the coil's foot: its width, its pier's z.
const BRIDGE_WIDE := 6.0
const PIERS := [-62.0,-74.0]
## The lower court, a long drop under the plaza's west edge (its floor), the
## ash bowl in it, the plank out over the bowl, the giant steps back up.
const COURT := Rect2(-44.0,-20.0,30.0,40.0)
const COURT_Y := -9.6
const BOWL_AT := Vector3(-30.0,COURT_Y,0.0)
const PLANK := Rect2(-25.0,-1.5,11.0,3.0)
## The shuttle: its slab's x, its run's ends (z), its far pad (x, z).
const SHUTTLE_X := 10.0
const SHUTTLE_RUN := Vector2(42.6,67.4)
const SHUTTLE_PACE := 4.0
const SHUTTLE_HOLD := 2.0
const PAD := Rect2(4.0,69.6,12.0,10.4)
## Far pillars in the abyss (drawn only): [x, top, z, radius].
const FAR := [[-80.0,30.0,-150.0,12.0],[95.0,46.0,-200.0,11.0],[-20.0,70.0,-260.0,15.0],[150.0,10.0,-60.0,9.0],[-110.0,-24.0,40.0,12.0],[60.0,-30.0,170.0,13.0]]
## The serpent: its girth, its roll kept while ridden; the collars' places
## back from its snout (m); its paces by stretch (m/s, by the front
## collar's place on its line), eased at PACE_EASE (m/s²).
const GIRTH := 1.0
const BANK_SHARE := 0.45
const COLLARS_AT := [24.0,54.0]
const PACE := {"loop":13.0,"approach":7.0,"station":7.0,"ring":8.5,"coil":9.0,"couple":7.5,"top":6.0,"leave":9.0}
const PACE_EASE := 1.6
## The shrug: tossed toward the cap (m/s in, up).
const SHRUG := Vector2(8.5,5.0)
## The wake: a body inside its girth not riding it is shoved out
## (m/s out, up), not more often than WAKE_EVERY (s).
const WAKE_SHOVE := Vector2(4.5,4.0)
const WAKE_EVERY := 0.6
const PILOT_AT := Vector3(34.0,1.6,3.0)

var _environment: Environment
var _sun: DirectionalLight3D
## The serpent watches for these (rune_serpent.gd `watcher`): never flying.
var flying := false
var plane: Variant = null
## Night for the serpent's runes underground (it reads `_celestial`).
var _celestial: Variant = null
var under: Node3D
var pieces: Node3D
var dais: Node3D
var ring: Node3D
var coil: Node3D
var bowl: Node3D
var serpent: Node3D
var collars: Array = []
var shuttle: AnimatableBody3D
var girth := GIRTH
## Laid out from the dais and the serpent's girth (`_lay_out`).
var trough := Vector2.ZERO
var strip := Rect2()
var line_x := 0.0
var ring_at := Vector3.ZERO
var coil_at := Vector3.ZERO
var bridge := Rect2()
var held := false
var no_shuttle := false
## The route's marks (m round its way) and length.
var arcs := {}
var lap := 0.0
## Counts and the last of each, for the HUD and the drivers.
var boardings := 0
var shrugs := 0
var shoves := 0
var soft_landings := 0
var last_soft := {}
var last_stun := {}
var _pace := 9.0
var _was_on := ""
var _shuttle_t := 0.0
var _shove_t := 0.0
var _collar_arc: Array = []

func _ready() -> void:
	pack = "city_serpent"
	var args := LaunchArgs.user_args()
	var asked := false
	for a: String in args:
		if a == "--underground" or a.begins_with("--underground="): asked = true
	if not asked and not args.has("--day"):
		var with := PackedStringArray(args)
		with.append("--underground=torch")
		LaunchArgs.set_override(with)
	for a: String in LaunchArgs.user_args():
		if a.begins_with("--girth="): girth = clampf(float(a.get_slice("=",1)),0.6,2.0)
		elif a == "--no-shuttle": no_shuttle = true
	super._ready()

func _load_pack() -> void:
	start = PILOT_AT
	start_face = Vector2(1.0,0.0)
	lost = YARD_LOST
	_last_stood = start
	stations = [{"key":1,"name":"City serpent yard","spawn":PILOT_AT,"face":start_face,"parts":[]}]

func _build_light() -> void:
	super._build_light()
	for n: Node in get_children():
		if n is WorldEnvironment: _environment = (n as WorldEnvironment).environment
		elif n is DirectionalLight3D: _sun = n
	camera.far = 1200.0

func _build_room() -> void:
	super._build_room()
	for l: Node in find_children("*","Label3D",false,false): l.queue_free()
	pieces = Node3D.new()
	pieces.name = "Pieces"
	add_child(pieces)
	_lay_out()
	_build_ground()
	dais = Kit.dais(pieces,Transform3D(Basis.IDENTITY,DAIS_AT),{"girth":girth,"seed":11})
	ring = Kit.ring(pieces,Transform3D(Basis.IDENTITY,ring_at),{"girth":girth,"ground":-ring_at.y,"seed":21})
	coil = Kit.coil(pieces,Transform3D(Basis.IDENTITY,coil_at),{"girth":girth,"foot":COIL_FOOT,"seed":31})
	bowl = Kit.ashbowl(pieces,Transform3D(Basis.IDENTITY,BOWL_AT),{"radius":8.0,"rows":2,"seed":5})
	_build_fires()
	_build_serpent()
	if not no_shuttle: _build_shuttle()
	under = Underground.attach(self)
	if under != null: _celestial = {"state":{"zs_daylight":0.3}}
	print("city serpent yard: lap %.0f m, dais line %.2f m (saddle %.2f over its top), ring bore %.2f crown %.2f, coil top %.1f line r %.2f, ash at %.2f" % [lap,
		DAIS_AT.y+float(dais.line_y),float(dais.line_y)+Kit.saddle_top(girth)-float(dais.top),float(ring.bore),ring_at.y+float(ring.crown),float(coil.top),float(coil.line_r),BOWL_AT.y+float(bowl.ash_y)])

# --- The ground -----------------------------------------------------------------------------

## The trough's sides and the line's x from the dais (its trough is the
## serpent's width), the strip east of it, the ring on the line, the coil a
## line radius west of it, the bridge on the coil's axis.
func _lay_out() -> void:
	var h := Kit.CELL*1.5
	var tw := Kit.Kit.trough_width(girth)
	trough = Vector2(DAIS_AT.x+h,DAIS_AT.x+h+tw)
	line_x = DAIS_AT.x+h+tw*0.5
	strip = Rect2(trough.y,PLAZA.position.y,STRIP_WIDE,PLAZA.size.y)
	ring_at = Vector3(line_x,RING_Y,RING_Z)
	var shaft := 7.5
	var line_r := shaft+Kit.CELL*2.0+Kit.Kit.radius(girth)*Kit.FLANK_SHARE+1.35
	coil_at = Vector3(line_x-line_r,0.0,COIL_Z)
	var foot_z := coil_at.z+shaft+Kit.CELL*2.0
	bridge = Rect2(coil_at.x-BRIDGE_WIDE*0.5,foot_z-0.8,BRIDGE_WIDE,PLAZA.position.y-foot_z+0.8)

func _build_ground() -> void:
	var m := GiantStone.mesher()
	var shapes: Array = []
	var rng := RandomNumberGenerator.new()
	rng.seed = 41
	# The plaza and the strip: paving slabs over a deep slab.
	for r: Rect2 in [PLAZA,strip]:
		_pave(m,r,0.0,rng)
		Kit.Kit.span(m,shapes,Vector3(r.position.x,-DEEP,r.position.y),Vector3(r.end.x,-2.0,r.end.y),0.4,0.8)
		shapes.append(Kit.Kit.box_shape(Vector3(r.size.x,DEEP,r.size.y),Kit.Kit.at(Vector3(r.get_center().x,-DEEP*0.5,r.get_center().y))))
	# The trough north and south of the dais: its floor a course under the
	# dais's top (the dais lays its own stretch).
	var tf: float = float(dais_floor())
	for zr: Vector2 in [Vector2(PLAZA.position.y,DAIS_AT.z-6.6),Vector2(DAIS_AT.z+6.6,PLAZA.end.y)]:
		Kit.Kit.span(m,shapes,Vector3(trough.x,-DEEP,zr.x),Vector3(trough.y,tf,zr.y),0.06,0.78)
	# The lower court: its floor round the bowl's square, the plank, the
	# giant steps back up the plaza's face.
	var half := 10.4
	var b := Vector2(BOWL_AT.x,BOWL_AT.z)
	var court_lo := COURT_Y-8.0
	for rr: Rect2 in [Rect2(COURT.position.x,COURT.position.y,b.x-half-COURT.position.x,COURT.size.y),
			Rect2(b.x+half,COURT.position.y,COURT.end.x-b.x-half,COURT.size.y),
			Rect2(b.x-half,COURT.position.y,half*2.0,b.y-half-COURT.position.y),
			Rect2(b.x-half,b.y+half,half*2.0,COURT.end.y-b.y-half)]:
		_pave(m,rr,COURT_Y,rng)
		Kit.Kit.span(m,shapes,Vector3(rr.position.x,court_lo,rr.position.y),Vector3(rr.end.x,COURT_Y-2.0,rr.end.y),0.3,0.8)
		shapes.append(Kit.Kit.box_shape(Vector3(rr.size.x,COURT_Y-court_lo,rr.size.y),Kit.Kit.at(Vector3(rr.get_center().x,(COURT_Y+court_lo)*0.5,rr.get_center().y))))
	Kit.Kit.span(m,shapes,Vector3(PLANK.position.x,-1.2,PLANK.position.y),Vector3(PLANK.end.x,0.0,PLANK.end.y),0.1,0.95)
	# The plank's end: a lip stone and a stub of a feathered post.
	m.box(Kit.Kit.at(Vector3(PLANK.position.x+0.4,0.15,PLANK.position.y+0.4)),Vector3(0.5,0.3,0.5),0.06)
	var so: float = Kit.set_off()
	for k in range(1,6):
		var top := COURT_Y+so*k
		Kit.Kit.span(m,shapes,Vector3(PLANK.end.x-1.4*(6-k),COURT_Y-0.5,14.0),Vector3(PLANK.end.x,top,18.0),0.08,0.92)
	# The bridge to the coil, kerbs a step high along it, a pier into the haze.
	Kit.Kit.span(m,shapes,Vector3(bridge.position.x,-so,bridge.position.y),Vector3(bridge.end.x,0.0,bridge.end.y),0.1,0.95)
	for sx: float in [bridge.position.x,bridge.end.x-0.5]:
		Kit.Kit.span(m,shapes,Vector3(sx,0.0,bridge.position.y+2.0),Vector3(sx+0.5,0.4,bridge.end.y),0.06,1.02)
	for pz: float in PIERS:
		m.box(Kit.Kit.at(Vector3(bridge.get_center().x,-so-30.0,pz)),Vector3(4.4,60.0,4.4),0.3,NAN,0.85)
	# The shuttle's far pad.
	_pave(m,PAD,0.0,rng)
	Kit.Kit.span(m,shapes,Vector3(PAD.position.x,-DEEP,PAD.position.y),Vector3(PAD.end.x,-2.0,PAD.end.y),0.3,0.8)
	shapes.append(Kit.Kit.box_shape(Vector3(PAD.size.x,DEEP,PAD.size.y),Kit.Kit.at(Vector3(PAD.get_center().x,-DEEP*0.5,PAD.get_center().y))))
	Kit.Kit.stone_node(self,m,"Ground")
	Kit.Kit.solid(self,shapes,"GroundSolid")
	# The underground's ground cover on the plaza, the strip, the court, the pad.
	var cover_parts: Array[Rect2] = [Rect2(PLAZA.position.x,PLAZA.position.y,PLAZA.size.x,DAIS_AT.z-6.6-PLAZA.position.y),
		Rect2(PLAZA.position.x,DAIS_AT.z+6.6,PLAZA.size.x,PLAZA.end.y-DAIS_AT.z-6.6),Rect2(PLAZA.position.x,DAIS_AT.z-6.6,DAIS_AT.x-6.6-PLAZA.position.x-3.4,13.2),
		Rect2(strip.position.x+3.0,strip.position.y,strip.size.x-3.0,strip.size.y)]
	for i in cover_parts.size(): GroundCover.cover(self,cover_parts[i],"",0.002,71+i,{"tufts":1.0,"under":1.0,"fade":0.3})
	GroundCover.cover(self,PAD,"",0.002,79,{"tufts":1.0,"under":1.0,"fade":0.3})
	GroundCover.cover(self,Rect2(COURT.position.x,COURT.position.y,b.x-half-COURT.position.x,COURT.size.y),"",COURT_Y+0.002,80,{"tufts":1.0,"under":1.0,"fade":0.3})
	# The far pillars (drawn only).
	var fm := GiantStone.mesher()
	for f: Array in FAR:
		var top := float(f[1])
		var r := float(f[3])
		var tall := 400.0
		var p := Vector3(float(f[0]),0.0,float(f[2]))
		fm.cylinder(Transform3D(Basis.IDENTITY,p+Vector3(0.0,top-6.0-tall*0.5,0.0)),r,tall,6,0.4,top-tall,1.0)
		fm.cylinder(Transform3D(Basis(Vector3.UP,0.5),p+Vector3(0.0,top-6.0,0.0)),r*1.55,8.0,6,0.6,top-14.0,0.85)
		fm.cylinder(Transform3D(Basis(Vector3.UP,0.2),p+Vector3(0.0,top-0.9,0.0)),r*1.45,1.8,6,0.3,top-3.0,0.95)
	var far := Kit.Kit.mesh_node(self,GiantStone.mesh_of(fm),"FarPillars")
	far.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

func dais_floor() -> float:
	return DAIS_AT.y+Kit.Kit.set_off()-Kit.Kit.course()

## Paving slabs a PAVE apart over `r` at `y`.
func _pave(m: GiantStone.Mesher, r: Rect2, y: float, rng: RandomNumberGenerator) -> void:
	var pave := 6.0
	var nx := maxi(1,int(roundf(r.size.x/pave)))
	var nz := maxi(1,int(roundf(r.size.y/pave)))
	var sx := r.size.x/nx
	var sz := r.size.y/nz
	for i in nx:
		for j in nz:
			var c := Vector3(r.position.x+sx*(i+0.5),y-1.0-rng.randf_range(0.0,0.035),r.position.y+sz*(j+0.5))
			m.box(Transform3D(Basis.IDENTITY,c),Vector3(sx-0.08,2.0,sz-0.08),0.06,y-2.0,rng.randf_range(0.82,1.06))

## Two bowls of fire flanking the shrine's door, the yard's warm light.
func _build_fires() -> void:
	var m := GiantStone.mesher()
	for sz: float in [-1.0,1.0]:
		var p := DAIS_AT+Vector3(-0.6,Kit.Kit.set_off(),sz*3.2)
		m.cylinder(Transform3D(Basis.IDENTITY,p+Vector3(0.0,0.45,0.0)),0.55,0.9,10,0.06,p.y)
		m.cylinder(Transform3D(Basis.IDENTITY,p+Vector3(0.0,1.05,0.0)),0.85,0.3,12,0.08,p.y)
		var fire: Node3D = CityFire.new()
		fire.name = "DaisFire%d" % int(sz+1.0)
		fire.set("flame",1.0)
		fire.set("bed",1.0)
		fire.set("light_range",14.0)
		fire.set("light_energy",3.0)
		fire.position = p+Vector3(0.0,1.22,0.0)
		pieces.add_child(fire)
		fire.call("burn")
	Kit.Kit.stone_node(pieces,m,"FireBowls")

# --- The serpent and its line ----------------------------------------------------------------

## Its line: the trough past the dais, the ring, the dive off the plaza's
## end, the coil (a turn rising out of the dark under the bridge, then
## coupled to the ramp to its end and past the cap), and the loop home over
## the abyss. [points, marks].
func line() -> Array:
	var cps: Array = []
	var marks := {}
	var lx := trough.x+(trough.y-trough.x)*0.5
	var ly := DAIS_AT.y+float(dais.line_y)
	var add := func(p: Vector3, weave := 0.0) -> void: cps.append([p,weave,1.0,0.0])
	# The trough, south to north: the dais's own way, then on to the ring.
	marks["approach"] = cps.size()
	for z: float in [60.0,48.0,36.0,24.0]: add.call(Vector3(lx,ly,z))
	var dais_way: Array = dais.get_meta("way")
	var dais_xf: Transform3D = dais.global_transform if dais.is_inside_tree() else dais.transform
	for w: Array in dais_way:
		var p: Vector3 = dais_xf*(w[0] as Vector3)
		if p.z > 14.0 or p.z < -14.0: continue
		if absf(p.z) < 0.01: marks["station"] = cps.size()
		add.call(p)
	add.call(Vector3(lx,ly+0.4,-14.0))
	marks["ring"] = cps.size()
	var ring_xf: Transform3D = ring.transform
	for w: Array in ring.get_meta("way"): add.call(ring_xf*(w[0] as Vector3))
	# Off the plaza's end and down, to rise round the coil.
	var entry_y := -11.0
	var dive_from := ring_at.z-float(ring.outer)
	var dives := int((dive_from-coil_at.z)/12.0)
	for k in dives:
		var z := dive_from-(dive_from-coil_at.z)*float(k+1)/float(dives+1)
		add.call(Vector3(lx,lerpf(ring_at.y,entry_y,(dive_from-z)/(dive_from-coil_at.z)),z))
	# The coil: from its east point (φ 0), counter-clockwise; under the
	# bridge at its south (φ 270°), coupled to the ramp from COUPLE.
	var c: Node3D = coil
	var foot_phi := fposmod(rad_to_deg(COIL_FOOT),360.0)
	var couple := foot_phi+90.0
	var end_phi := foot_phi+360.0*float(c.turns)
	var over := 60.0
	var every := 30.0
	var shrink := (4.0+2.0*cos(deg_to_rad(every)))/6.0
	var under_y := -8.0
	marks["coil"] = cps.size()
	var phi := 0.0
	while phi <= end_phi+over+0.01:
		var y := 0.0
		var coupled := float(c.line_y(deg_to_rad(phi-foot_phi)))
		if phi <= 270.0: y = lerpf(entry_y,under_y,phi/270.0)
		elif phi < couple: y = lerpf(under_y,float(c.line_y(deg_to_rad(couple-foot_phi))),(phi-270.0)/(couple-270.0))
		else: y = coupled
		if absf(phi-couple) < every*0.5: marks["couple"] = cps.size()
		if absf(phi-end_phi) < every*0.5: marks["top"] = cps.size()
		if absf(phi-(end_phi+over*0.5)) < every*0.5: marks["shrug"] = cps.size()
		var p: Vector3 = coil_at+Vector3(cos(deg_to_rad(phi)),0.0,-sin(deg_to_rad(phi)))*float(c.line_r)/shrink
		add.call(Vector3(p.x,coil_at.y+y,p.z))
		phi += every
	# Away along its last tangent, then the loop home over the abyss.
	marks["leave"] = cps.size()
	var last_phi := deg_to_rad(phi-every)
	var tangent := Vector3(-sin(last_phi),0.0,-cos(last_phi))
	var from: Vector3 = (cps[cps.size()-1][0] as Vector3)
	for k in 2: add.call(from+tangent*14.0*(k+1)-Vector3(0.0,0.5*(k+1),0.0),0.1)
	marks["loop"] = cps.size()
	for p: Vector3 in [Vector3(62.0,14.0,-112.0),Vector3(80.0,13.0,-116.0),Vector3(98.0,12.0,-106.0),Vector3(110.0,11.0,-88.0),
			Vector3(114.0,10.0,-62.0),Vector3(116.0,8.0,-32.0),Vector3(116.0,6.0,0.0),Vector3(116.0,4.0,30.0),Vector3(114.0,2.5,58.0),
			Vector3(106.0,1.5,82.0),Vector3(92.0,0.5,98.0),Vector3(74.0,-0.4,104.0),Vector3(58.0,-1.0,98.0),Vector3(48.0,ly,86.0),Vector3(lx+0.3,ly,72.0)]:
		add.call(p,0.5 if p.x > 60.0 else 0.15)
	return [cps,marks]

func _build_serpent() -> void:
	var made := line()
	serpent = RuneSerpent.new()
	serpent.route = made[0]
	serpent.route_marks = made[1]
	serpent.start_mark = "loop"
	serpent.girth = girth
	serpent.heave_share = 0.0
	serpent.solid = true
	serpent.look_back = true
	add_child(serpent)
	serpent.setup(self)
	serpent.set_process(false)
	serpent.set_physics_process(false)
	arcs = serpent.marks()
	lap = float(serpent.route_length)
	# Its body is ground he rides: its capsules moving ground, their tops at
	# its crest (not its widest girth), so he stands on the stone he sees.
	var solid := serpent.get_node_or_null("Solid") as CollisionObject3D
	if solid != null:
		PhysicsGround.mark_moving(solid)
		for c: Node in solid.get_children():
			var cs := c as CollisionShape3D
			if cs == null or not (cs.shape is CapsuleShape3D): continue
			var cap := cs.shape as CapsuleShape3D
			var length := cap.height-cap.radius*2.0
			cap.radius = cap.radius/RuneSerpent.CAPSULE_SHARE*Kit.CREST_SHARE
			cap.height = length+cap.radius*2.0
	serpent._place_solid()
	var st: PackedFloat32Array = serpent.stations()
	collars.clear()
	_collar_arc.clear()
	for i in COLLARS_AT.size():
		var k := 0
		for j in st.size():
			if absf(st[j]-float(COLLARS_AT[i])) < absf(st[k]-float(COLLARS_AT[i])): k = j
		var c := Kit.collar(pieces,serpent,k,{"lamp":i == 0,"name":"Collar%d" % i})
		collars.append(c)
		_collar_arc.append(float(st[k]))
	_pace = float(serpent.speed())

## Its line's place of collar `i` now (m round its way).
func collar_arc(i := 0) -> float:
	return fposmod(float(serpent.s)-float(_collar_arc[i]),lap)

## Whether arc `a` lies from mark `from` on to mark `to` round the way.
func _between(a: float, from: String, to: String) -> bool:
	var f := float(arcs.get(from,0.0))
	var t := float(arcs.get(to,0.0))
	return fposmod(a-f,lap) < fposmod(t-f,lap)

## The pace for the front collar's place: the stretch it is on.
func _pace_goal() -> float:
	var a := collar_arc(0)
	var near_station := fposmod(float(arcs.station)-a,lap)
	if near_station < 45.0 or fposmod(a-float(arcs.station),lap) < 10.0: return PACE.station
	if _between(a,"station","ring"): return PACE.ring
	if _between(a,"ring","coil"): return PACE.coil
	if _between(a,"coil","couple"): return PACE.coil
	if _between(a,"couple","top"): return PACE.couple
	if _between(a,"top","leave"): return PACE.top
	if _between(a,"leave","loop"): return PACE.leave
	return PACE.loop

func _serpent_step(step: float) -> void:
	_pace = move_toward(_pace,_pace_goal(),PACE_EASE*step)
	serpent.pace_hold = _pace*float(serpent.get("_speed_scale"))
	serpent.bank_share = BANK_SHARE
	serpent.advance(step)
	serpent._place_solid()
	for c: Node3D in collars: c.follow(step)

## The serpent set `seconds` before its head reaches the dais (C).
func call_serpent(seconds := 12.0) -> void:
	var at := fposmod(float(arcs.station)-seconds*PACE.station-20.0,lap)
	serpent.place(at)
	_pace = PACE.station
	serpent._place_solid()
	for c: Node3D in collars: c.follow(0.0)

# --- The shuttle (moving ground on its own) ---------------------------------------------------

func _build_shuttle() -> void:
	shuttle = AnimatableBody3D.new()
	shuttle.name = "Shuttle"
	shuttle.sync_to_physics = false
	PhysicsGround.mark_moving(shuttle)
	var m := GiantStone.mesher()
	var shapes: Array = []
	Kit.Kit.span(m,shapes,Vector3(-2.2,-0.8,-2.2),Vector3(2.2,0.0,2.2),0.1,1.02)
	m.box(Kit.Kit.at(Vector3(0.0,-1.2,0.0)),Vector3(2.4,0.8,2.4),0.1,NAN,0.8)
	Kit.Kit.stone_node(shuttle,m)
	for s: Array in shapes:
		var c := CollisionShape3D.new()
		c.shape = s[0]
		c.transform = s[1]
		shuttle.add_child(c)
	add_child(shuttle)
	shuttle.global_position = Vector3(SHUTTLE_X,0.0,SHUTTLE_RUN.x)

## Where the shuttle is at `t` s on its round: held, along (eased), held, back.
static func shuttle_z(t: float) -> float:
	var run := SHUTTLE_RUN.y-SHUTTLE_RUN.x
	var go := run/SHUTTLE_PACE
	var round_t := 2.0*(go+SHUTTLE_HOLD)
	var u := fposmod(t,round_t)
	if u < SHUTTLE_HOLD: return SHUTTLE_RUN.x
	u -= SHUTTLE_HOLD
	if u < go: return SHUTTLE_RUN.x+run*_ease_run(u/go)
	u -= go
	if u < SHUTTLE_HOLD: return SHUTTLE_RUN.y
	u -= SHUTTLE_HOLD
	return SHUTTLE_RUN.y-run*_ease_run(u/go)

## Up to speed and down again over a fifth of the run each end.
static func _ease_run(x: float) -> float:
	var a := 0.2
	if x < a: return x*x/(2.0*a*(1.0-a))
	if x > 1.0-a: return 1.0-(1.0-x)*(1.0-x)/(2.0*a*(1.0-a))
	return (x-a*0.5)/(1.0-a)

# --- A frame ---------------------------------------------------------------------------------

## The serpent and its collars move on (and the shuttle), then the study's
## own frame (the motor rides what moved), then the rest: the countdown, the
## runes, the shrug, the wake's shove.
func tick(delta: float) -> void:
	var step := minf(delta,RuneSerpent.MAX_STEP)
	if serpent != null and not held: _serpent_step(step)
	if shuttle != null:
		_shuttle_t += delta
		shuttle.global_position = Vector3(SHUTTLE_X,0.0,shuttle_z(_shuttle_t))
	super.tick(delta)
	if serpent == null: return
	_count(delta)
	_shrug_check()
	_shove(delta)
	_wake(delta)
	_on_what()
	if under != null:
		if _sun != null: _sun.visible = false
		_hemi()

## The dais's countdown: seconds before its head is at the dais's middle.
func _count(_delta: float) -> void:
	var a := float(arcs.station)
	var s := float(serpent.s)
	var ahead := fposmod(a-s,lap)
	var behind := fposmod(s-a,lap)
	var passing := behind < RuneSerpent.LENGTH+8.0
	dais.update(ahead/maxf(float(serpent.speed()),1.0),passing)

## Past the cap (the "shrug" mark) a collar rolls; a rider on it is thrown
## toward the cap (in the frame it moves in: he keeps its pace too).
func _shrug_check() -> void:
	var mark := float(arcs.get("shrug",-1.0))
	if mark < 0.0: return
	for i in collars.size():
		var c: Node3D = collars[i]
		var a := collar_arc(i)
		var was: float = c.get_meta("arc",a)
		c.set_meta("arc",a)
		var went := fposmod(a-was,lap)
		if went <= 0.0 or went > 20.0 or fposmod(a-mark,lap) >= went: continue
		var inward := coil_at-c.global_position
		inward.y = 0.0
		inward = inward.normalized()
		var side := signf((c.global_transform.basis.x).dot(inward))
		c.shrug(side if side != 0.0 else 1.0)
		if c.carries(motor.platform) and (motor.grounded or motor.on_ledge()):
			shrugs += 1
			motor.toss(inward*SHRUG.x+Vector3.UP*SHRUG.y)
			_say("It shrugs you off onto the cap",2.0)

## A body in its girth, not riding it, shoved out of its way (its wake: a
## toss, never a stun or a hurt).
func _shove(delta: float) -> void:
	_shove_t = maxf(0.0,_shove_t-delta)
	if _shove_t > 0.0 or motor.on_ledge() or motor.recovering(): return
	var on_it := motor.platform != null and (motor.platform.get_parent() == serpent.get_node_or_null("Solid") or _collar_of(motor.platform) >= 0)
	if on_it: return
	var p := motor.feet+Vector3.UP*0.6
	var rings: PackedVector3Array = serpent.rings()
	var radii: PackedFloat32Array = serpent.radii()
	for i in range(rings.size()-1):
		var a := rings[i]
		var b := rings[i+1]
		var ab := b-a
		var t := clampf((p-a).dot(ab)/maxf(ab.length_squared(),1e-6),0.0,1.0)
		var q := a+ab*t
		if p.distance_to(q) < radii[i]*0.92:
			var out := p-q
			out.y = 0.0
			out = out.normalized() if out.length() > 0.05 else Vector3(-ab.z,0.0,ab.x).normalized()
			var ahead := -ab.normalized()*float(serpent.speed())*0.5
			motor.toss(out*WAKE_SHOVE.x+Vector3.UP*WAKE_SHOVE.y+ahead)
			shoves += 1
			_shove_t = WAKE_EVERY
			return

func _collar_of(node: Node) -> int:
	for i in collars.size():
		if (collars[i] as Node3D).call("carries",node): return i
	return -1

## Every piece's runes woken by the serpent's nearness.
func _wake(delta: float) -> void:
	var pts := PackedVector3Array()
	var rings: PackedVector3Array = serpent.rings()
	for i in range(0,rings.size(),3): pts.append(rings[i])
	pts.append(serpent.head())
	for p: Node3D in [dais,ring,coil,bowl]: Kit.wake(p,pts,delta)

## What he is on now: boardings counted.
func _on_what() -> void:
	var now := ""
	if motor.platform != null:
		var k := _collar_of(motor.platform)
		if k >= 0: now = "collar%d" % k
		elif motor.platform.get_parent() == serpent.get_node_or_null("Solid"): now = "back"
		elif motor.platform.get_parent() == shuttle or motor.platform == shuttle: now = "shuttle"
		else: now = str(motor.platform.name)
	if now != "" and _was_on == "" and (now.begins_with("collar") or now == "back"):
		boardings += 1
		_say("Aboard!" if now == "back" else "Into the saddle",1.5)
	if now != "": _was_on = now
	elif motor.grounded or motor.on_ledge(): _was_on = ""

## The stone's sky fill to the underground's ambient.
func _hemi() -> void:
	var p: Dictionary = under.get("p")
	var amb: Color = p.get("ambient",Color(0.2,0.27,0.4))
	var e := float(HEMI.get(str(under.get("preset")),0.2))
	RenderingServer.global_shader_parameter_set("zs_hemi_sky",Vector3(amb.r,amb.g,amb.b))
	RenderingServer.global_shader_parameter_set("zs_hemi_ground",Vector3(amb.r,amb.g,amb.b)*0.25)
	RenderingServer.global_shader_parameter_set("zs_hemi_energy",e)

# --- Soft ground: the walker's dust ------------------------------------------------------------

func _surface() -> String:
	return "sand" if not motor.soft_now.is_empty() else super._surface()

func _puff_at(at: Vector3) -> Vector3:
	if not motor.soft_now.is_empty(): at.y = maxf(at.y,motor.feet.y+float(motor.soft_now.get("depth",0.0)))
	return super._puff_at(at)

func _motor_events(events: Dictionary) -> void:
	super._motor_events(events)
	if events.has("soft") and float(events.soft) > 0.5:
		soft_landings += 1
		last_soft = {"drop":float(events.soft),"stunned":events.has("stunned"),"at":motor.feet}
		var at := _puff_at(figure.global_position)
		for i in 8:
			var way := Vector3.FORWARD.rotated(Vector3.UP,TAU*i/8.0)
			puffs.burst(at+way*0.4,"sand",0.9,way*3.0)
		puffs.burst(at,"sand",1.0)
		_say("The ash takes the fall (%.1f m)" % float(events.soft),2.0)
	if events.has("stunned"):
		last_stun = {"why":str(events.stunned),"down":float(events.get("downed",0.0)),"at":motor.feet}

# --- Stations and keys --------------------------------------------------------------------------

func go_to(key: int) -> void:
	match key:
		1: place(PILOT_AT,Vector2(1.0,0.0))
		2:
			var c: Node3D = collars[0]
			var f: Vector3 = c.call("forward")
			place(c.call("saddle_point",1.0),Vector2(f.x,f.z))
		3:
			var cap: Vector3 = coil_at+(coil.get_meta("ports") as Dictionary).cap_edge
			place(cap,Vector2(coil_at.x-cap.x,coil_at.z-cap.z).normalized())
		4: place(Vector3(PLANK.end.x-1.5,0.0,0.0),Vector2(-1.0,0.0))
		5: place(ring_at+Vector3(0.0,float(ring.crown),0.0),Vector2(0.0,1.0))
		6: place(Vector3(SHUTTLE_X,0.0,PLAZA.end.y-1.5),Vector2(0.0,1.0))
		7: place(Vector3(bridge.get_center().x,0.0,bridge.end.y-2.0),Vector2(0.0,-1.0))

func reset_all() -> void:
	if serpent != null:
		serpent.place(float(arcs.get("loop",0.0)))
		_pace = PACE.loop
		serpent._place_solid()
		for c: Node3D in collars: c.follow(0.0)
	_shuttle_t = 0.0
	respawn()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and not _name_panel.visible:
		var key := (event as InputEventKey).keycode
		match key:
			KEY_R:
				reset_all()
				return
			KEY_C:
				call_serpent()
				_say("The serpent is coming: watch the tick stones",2.5)
				return
			KEY_P:
				held = not held
				_say("Serpent held" if held else "Serpent on",1.5)
				return
			KEY_L:
				if under != null:
					under.cycle()
					return
		if key >= KEY_1 and key <= KEY_7:
			go_to(key-KEY_0)
			return
	super._unhandled_input(event)

# --- The HUD -------------------------------------------------------------------------------------

func _hint_text() -> String:
	return "City serpent: wait on the dais (the tick stones count it in), run off the lip onto its back or a saddle · ride up the coil, step off onto the ramp or the cap · drop into the ash bowl off the plank · 1-7 stations · C call it · P hold it · R all back · L torch/haze · F1 numbers"

func _show_hud() -> void:
	super._show_hud()
	if not _hud.visible or serpent == null: return
	var lines := PackedStringArray([_hud.text,""])
	var a := collar_arc(0)
	var where := "loop"
	for pair: Array in [["station","ring"],["ring","coil"],["coil","couple"],["couple","top"],["top","leave"],["leave","loop"]]:
		if _between(a,str(pair[0]),str(pair[1])): where = str(pair[0])
	var ahead := fposmod(float(arcs.station)-float(serpent.s),lap)/maxf(float(serpent.speed()),1.0)
	lines.append("serpent %.1f m/s · front collar at %s · dais in %.0f s (%d ticks lit) · lap %.0f m" % [float(serpent.speed()),where,ahead,int(dais.lit_ticks),lap])
	var gv: Vector3 = motor.ground_velocity()
	lines.append("on %s · own %.1f m/s · over the ground %.1f m/s · frame %.1f · boardings %d · shrugs %d · shoves %d" % [_was_on if _was_on != "" else "-",motor.speed(),Vector2(gv.x,gv.z).length(),Vector2(motor.frame_v.x,motor.frame_v.z).length(),boardings,shrugs,shoves])
	lines.append("soft %s · soft landings %d (last %s) · last stun %s" % ["ash" if not motor.soft_now.is_empty() else "-",soft_landings,str(last_soft.get("drop","-")),str(last_stun.get("why","-"))])
	_hud.text = "\n".join(lines)
