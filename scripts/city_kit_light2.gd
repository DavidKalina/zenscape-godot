extends RefCounted
## The Olmec city kit's light pieces, round 2 (docs/design/roguelike/
## city-light2-round1.md; cards in brainstorm/round3-olmec-city/
## kit-k6-light.md maker_mirror and kit-k3-climb-lanes.md oc_relief): the
## sun-mirror that throws light where you aim it, the light shaft that
## feeds it, the sun plaque a beam wakes, and the relief face, a cliff
## carved as one seated lord that the two bodies climb their own ways. All
## in the city's stone (scripts/city_kit_stone.gd).
##
## Pieces (`build(id, parent, xform, opts)`, or the builders):
##   maker_mirror    `mirror`: an obsidian disc in a turning yoke on a
##                   basalt pedestal. Fed light (a light shaft over it, a lit
##                   fire within FIRE_CATCH m, or another mirror's beam on
##                   it), it throws a beam along its bearing: a cheap visual
##                   rod, one ray a frame, a `BeamLight` (a SightLight
##                   stripe: standing in it shows you to the Olmec). The beam
##                   lights the first unlit fire it passes (any Beacon's
##                   owner with `light()`: a cresset, a crown), wakes a sun
##                   plaque, feeds the next mirror. `mode` "turn": stamp a
##                   treadle on its deck (land on it from a hop) and it
##                   turns a STEP that way, with a clack; "sweep": it drifts
##                   between two bearings on its own (a timed crossing);
##                   "fixed".
##   maker_shaft     `shaft`: a pale rod of dust-lit air falling from the
##                   dark above, a pool on the floor; feeds a mirror under it.
##                   A SightLight too.
##   maker_sunplaque `plaque`: a carved sun disc on a wall; a beam on it
##                   wakes it and its hidden glyph steps slide out of the
##                   wall, a route that wasn't there (walker-only).
##   oc_relief       `relief`: a cliff `width` m wide, TOP m tall, `deep` m
##                   back, its face carved as one seated lord in profile
##                   (the Blender model art/blender/city_relief/
##                   relief_build.py, assets/models/city_relief.glb, its
##                   baked maps projected by one Decal). The wanderer jump-
##                   catches the carving's deep bosses, a SET_OFF apart, up
##                   the nose side (clean walker-only boxes); the Olmec climbs
##                   the cliff's plain collision, and at the top his hands
##                   come over the helmet's crown, the cliff's lip.
##
## Register in a kit registry with `PIECES` (id -> what it is) and `build`.
const CityStone = preload("res://scripts/city_kit_stone.gd")
const Fires = preload("res://scripts/city_kit_fires.gd")
const RuinKit = preload("res://scripts/ruin_kit.gd")
const WorldScale = preload("res://scripts/world_scale.gd")
const Style = preload("res://scripts/ruin_stone_style.gd")
const GroundCover = preload("res://scripts/underground/ground_cover.gd")
const BEAM_SHADER := preload("res://shaders/city_beam.gdshader")
const GLOW_SHADER := preload("res://shaders/city_glow.gdshader")
const MIRROR_SHADER := preload("res://shaders/city_mirror.gdshader")
const RELIEF_MODEL := "res://assets/models/city_relief.glb"
const RELIEF_NORMAL := "res://assets/textures/city_relief_normal.png"
const RELIEF_CAVITY := "res://assets/textures/city_relief_cavity.png"

const PIECES := {
	"maker_mirror":"Sun-mirror: an obsidian disc on a turning pedestal; fed light, it throws a beam you aim (stamp a treadle) that lights fires and wakes plaques",
	"maker_shaft":"Light shaft: a rod of pale light from the dark above, a pool on the floor; feeds a mirror",
	"maker_sunplaque":"Sun plaque: a carved sun on a wall; a beam on it slides its hidden glyph steps out",
	"oc_relief":"Relief face: a cliff carved as a seated lord; you jump-catch his carving's bosses, the Olmec climbs the stone",
}

## The light's light: the beam's and the shaft's tint.
const SUN := Color(1.0,0.93,0.78)
## A mirror: the pedestal's radius and height (one SET_OFF), the disc's
## radius and its middle over the deck, the yoke's arms, the treadles
## (from, to across, half long, raised), all at his size 1.
const PED_R := 2.3
const DISC_R := 1.1
const DISC_Y := 1.75
const YOKE_R := 1.24
const TREADLE := [1.35,2.05,1.0,0.1]
## A turn: the step (deg) a stamp turns it, how long the turn takes (s).
const STEP := 15.0
const TURN_TIME := 0.35
## How far a beam goes (m), how near it passes an unlit fire's flame to
## light it (m), and the beam's look: the rod's radius, the stripe it
## lights for his sight (radius m, strength).
const REACH := 64.0
const CATCH := 1.6
const BEAM_R := 0.55
const STRIPE := [2.0,1.0]
## A lit fire within this (m) of the disc feeds it.
const FIRE_CATCH := 14.0
## A beam on a disc within this share of its radius feeds that mirror.
const RELAY := 1.5
## The visual layer only the relief's mesh is on, which its Decal projects onto.
const RELIEF_LAYER := 1 << 19
## The light's draw order among the transparent: last.
const LIGHT_PRIORITY := 100

static func size() -> float:
	return WorldScale.wanderer

static func set_off() -> float:
	return RuinKit.SET_OFF*size()

## Piece `id` (PIECES) stood in `parent` at `xform`, `opts` its own.
static func build(id: String, parent: Node3D, xform: Transform3D, opts := {}) -> Node3D:
	match id:
		"maker_mirror": return mirror(parent,xform,opts)
		"maker_shaft": return shaft(parent,xform,opts)
		"maker_sunplaque": return plaque(parent,xform,opts)
		"oc_relief": return relief(parent,xform,opts)
	push_error("city light2: no piece '%s'" % id)
	return null

# --- Helpers --------------------------------------------------------------------------------

static func _mesh_node(parent: Node3D, m: CityStone.Mesher, node_name: String) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = node_name
	mi.mesh = CityStone.mesh_of(m)
	parent.add_child(mi)
	return mi

static func _stone() -> CityStone.Mesher:
	return CityStone.Mesher.new(CityStone.stone_colour(),0.25)

static func _box(m: CityStone.Mesher, at: Vector3, sz: Vector3, bevel := 0.06, turn := 0.0, tone := 1.0) -> void:
	m.solid(CityStone.box(Transform3D(Basis(Vector3.UP,turn),at),sz*0.5,bevel),NAN,tone)

static func _body(parent: Node3D, shapes: Array, node_name: String, walker := false) -> StaticBody3D:
	return Fires.solid(parent,shapes,walker,node_name)

## The nearest point to `p` on the segment `a`..`b`.
static func _on_segment(p: Vector3, a: Vector3, b: Vector3) -> Vector3:
	var ab := b-a
	var t := clampf((p-a).dot(ab)/maxf(ab.length_squared(),1e-6),0.0,1.0)
	return a+ab*t

## The node a Beacon belongs to that lights (`light()` and `lit`): its
## cresset, crown or spill; null for a bare beacon.
static func _fire_of(b: Node) -> Node:
	var n := b.get_parent()
	while n != null:
		if n.has_method("light") and n.has_method("rim") and n.get("lit") != null: return n
		n = n.get_parent()
	return null

static func _glow_quad(parent: Node3D, size_m: float, strength: float, node_name: String) -> MeshInstance3D:
	var q := MeshInstance3D.new()
	q.name = node_name
	var mesh := QuadMesh.new()
	mesh.size = Vector2.ONE*size_m
	q.mesh = mesh
	var mat := ShaderMaterial.new()
	mat.shader = GLOW_SHADER
	# Drawn after the ground cover's tufts (they read the screen behind them).
	mat.render_priority = LIGHT_PRIORITY
	mat.set_shader_parameter("tint",SUN)
	mat.set_shader_parameter("strength",strength)
	q.material_override = mat
	q.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(q)
	return q

static func _rod(parent: Node3D, radius: float, node_name: String) -> MeshInstance3D:
	var r := MeshInstance3D.new()
	r.name = node_name
	var c := CylinderMesh.new()
	c.top_radius = radius
	c.bottom_radius = radius
	c.height = 1.0
	c.radial_segments = 14
	c.rings = 1
	c.cap_top = false
	c.cap_bottom = false
	r.mesh = c
	var mat := ShaderMaterial.new()
	mat.shader = BEAM_SHADER
	mat.render_priority = LIGHT_PRIORITY
	mat.set_shader_parameter("tint",SUN)
	r.material_override = mat
	r.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(r)
	return r

## A rod `node` laid from `a` to `b` (world), its radius kept.
static func _lay_rod(node: Node3D, a: Vector3, b: Vector3) -> void:
	var d := b-a
	var l := d.length()
	if l < 0.01:
		node.visible = false
		return
	var y := d/l
	var x := y.cross(Vector3.UP if absf(y.y) < 0.95 else Vector3.RIGHT).normalized()
	var z := x.cross(y).normalized()
	node.global_transform = Transform3D(Basis(x,y*l,z),(a+b)*0.5)
	var mat := (node as MeshInstance3D).material_override as ShaderMaterial
	mat.set_shader_parameter("length_m",l)

# --- The beam's light for his sight ------------------------------------------------------------

## A lit stripe the Olmec's sight reckons with (scripts/enemies/sight_light.gd):
## a segment `a`..`b` (world), lit full within FULL of `radius` of it,
## falling straight to 0 at `radius`.
class BeamLight extends SightLight:
	var a := Vector3.ZERO
	var b := Vector3.ZERO

	func light_at(p: Vector3) -> float:
		if not lit or radius <= 0.0: return 0.0
		var d := p.distance_to(preload("res://scripts/city_kit_light2.gd")._on_segment(p,a,b))
		if d >= radius: return 0.0
		return strength*clampf((radius-d)/(radius*(1.0-FULL)),0.0,1.0)

# --- The light shaft ---------------------------------------------------------------------------------

## A shaft in `parent` at `xform` (its foot, on the floor). opts: "height"
## (m, 48), "radius" (m, 1.5), "lit" (true), "strength" (1.0).
static func shaft(parent: Node3D, xform: Transform3D, opts := {}) -> LightShaft:
	var s := LightShaft.new()
	s.name = str(opts.get("name","LightShaft"))
	s.transform = xform
	s.height = float(opts.get("height",48.0))*size()
	s.radius = float(opts.get("radius",1.5))*size()
	s.strength = float(opts.get("strength",1.0))
	parent.add_child(s)
	s.stand_up()
	if not bool(opts.get("lit",true)): s.douse()
	return s

class LightShaft extends Node3D:
	const Kit = preload("res://scripts/city_kit_light2.gd")
	const GROUP := &"light_shafts"
	signal lit_changed(on: bool)
	var height := 48.0
	var radius := 1.5
	var strength := 1.0
	var lit := true
	var rod: MeshInstance3D
	var pool: MeshInstance3D
	var spot: SpotLight3D
	var sight: BeamLight

	func _enter_tree() -> void:
		add_to_group(GROUP)

	func stand_up() -> void:
		rod = Kit._rod(self,radius,"Rod")
		var mat := rod.material_override as ShaderMaterial
		mat.set_shader_parameter("fade_in",0.55)
		mat.set_shader_parameter("fade_out",0.02)
		mat.set_shader_parameter("core",1.2)
		mat.set_shader_parameter("strength",0.22*strength)
		mat.set_shader_parameter("drift",0.6)
		pool = Kit._glow_quad(self,radius*3.4,0.7*strength,"Pool")
		pool.rotation.x = -PI*0.5
		pool.position.y = 0.03
		spot = SpotLight3D.new()
		spot.name = "Spot"
		spot.position = Vector3(0.0,minf(height,26.0),0.0)
		spot.rotation.x = -PI*0.5
		spot.spot_range = minf(height,26.0)+4.0
		spot.spot_angle = rad_to_deg(atan2(radius*1.3,minf(height,26.0)))
		spot.spot_angle_attenuation = 0.6
		spot.light_color = SUN
		spot.light_energy = 6.0*strength
		spot.shadow_enabled = false
		add_child(spot)
		sight = BeamLight.new()
		sight.name = "Sight"
		sight.radius = radius+0.6
		sight.strength = 0.9
		add_child(sight)
		_show()
		_place()

	func _ready() -> void:
		_place()

	func _place() -> void:
		if rod == null: return
		Kit._lay_rod(rod,global_position+Vector3.UP*height,global_position)
		sight.a = global_position
		sight.b = global_position+Vector3.UP*4.0

	func _show() -> void:
		rod.visible = lit
		pool.visible = lit
		spot.visible = lit
		sight.lit = lit

	func light() -> void:
		if lit: return
		lit = true
		_show()
		lit_changed.emit(true)

	func douse() -> void:
		if not lit: return
		lit = false
		_show()
		lit_changed.emit(false)

	## Whether `p` (world) stands in it.
	func covers(p: Vector3) -> bool:
		var g := global_position
		return lit and Vector2(p.x-g.x,p.z-g.z).length() <= radius+0.4 and p.y >= g.y-0.5 and p.y <= g.y+height

# --- The sun-mirror ------------------------------------------------------------------------------------

## A mirror in `parent` at `xform` (its foot; its bearing 0 throws along
## local +z). opts: "mode" ("turn", "sweep", "fixed"), "bearing" (deg, 0),
## "step" (deg, STEP), "pitch" (deg, 0: level), "reach" (m, REACH),
## "sweep" ([from deg, to deg, period s, hold s]), "source" (a node with
## `lit`: a shaft, a fire; else any shaft over it or lit fire near it),
## "seed".
static func mirror(parent: Node3D, xform: Transform3D, opts := {}) -> SunMirror:
	var m := SunMirror.new()
	m.name = str(opts.get("name","SunMirror"))
	m.transform = xform
	m.mode = str(opts.get("mode","turn"))
	m.bearing = float(opts.get("bearing",0.0))
	m.rest = m.bearing
	m.step = float(opts.get("step",STEP))
	m.pitch = float(opts.get("pitch",0.0))
	m.reach = float(opts.get("reach",REACH))*size()
	var sw: Array = opts.get("sweep",[-30.0,30.0,10.0,1.5])
	m.sweep = sw
	m.source = opts.get("source",null)
	m.seed_value = int(opts.get("seed",hash(xform.origin)))
	parent.add_child(m)
	m.stand_up()
	return m

class SunMirror extends Node3D:
	const Kit = preload("res://scripts/city_kit_light2.gd")
	const GROUP := &"beam_targets"
	## Fed light or not; it turned (a stamp's step done: its bearing); its
	## beam lit something (the fire or plaque).
	signal fed_changed(on: bool)
	signal turned(bearing: float)
	signal lit_target(target: Node)
	var mode := "turn"
	## The way it throws (deg about up, 0 along local +z), and where it was built.
	var bearing := 0.0
	var rest := 0.0
	var step := STEP
	var pitch := 0.0
	var reach := REACH
	var sweep: Array = []
	var source: Variant = null
	var seed_value := 0
	var fed := false
	## The beam now (world): from the disc to where it ends, the surface it ends on.
	var beam_from := Vector3.ZERO
	var beam_to := Vector3.ZERO
	var beam_normal := Vector3.ZERO
	var beam_hit: Object = null
	## Counts: stamps that turned it, fires its beam lit.
	var turns := 0
	var lightings := 0
	var deck_y := 0.0
	var turn: Node3D
	var disc_mat := ShaderMaterial.new()
	var rod: MeshInstance3D
	var spot: MeshInstance3D
	var spot_light: OmniLight3D
	var coin_light: OmniLight3D
	var sight: BeamLight
	var bodies: Array[RID] = []
	var _from_yaw := 0.0
	var _to_yaw := 0.0
	var _turn_t := -1.0
	var _clock := 0.0
	var _relay_until := -1.0
	var _was_grounded := true
	var _ray := PhysicsRayQueryParameters3D.new()
	var _lit_glow := 0.0
	var _src_t := 0.0
	var _sources: Array = []

	func _enter_tree() -> void:
		add_to_group(GROUP)

	func stand_up() -> void:
		var k := Kit.size()
		deck_y = Kit.set_off()
		var m := Kit._stone()
		var shapes: Array = []
		# The pedestal: a squat basalt drum, a plinth course round its foot,
		# a lip course at the deck.
		m.solid(CityStone.drum(Transform3D(Basis.IDENTITY,Vector3.ZERO),12,PED_R*k*1.06,PED_R*k*1.06,0.35*k,0.06*k),NAN,0.9)
		m.solid(CityStone.drum(Transform3D(Basis.IDENTITY,Vector3.UP*0.35*k),12,PED_R*k*0.97,PED_R*k*0.95,deck_y-0.6*k,0.0),NAN,1.0)
		m.solid(CityStone.drum(Transform3D(Basis.IDENTITY,Vector3.UP*(deck_y-0.25*k)),12,PED_R*k,PED_R*k,0.25*k,0.05*k),NAN,1.05)
		m.runes(Vector3(-0.9*k,0.75*k,PED_R*k*0.97+0.01),Vector3(0.9*k,0.75*k,PED_R*k*0.97+0.01),Vector3.UP,Vector3.BACK,float(seed_value%97),0.5*k)
		shapes.append(Fires.cyl_shape(PED_R*k,deck_y,Vector3.UP*deck_y*0.5))
		# The treadles: a raised slab each side, chevrons cut toward -z
		# (the way the near rim goes when you stamp it).
		var t: Array = TREADLE
		for s: float in [-1.0,1.0]:
			var cx := s*(float(t[0])+float(t[1]))*0.5*k
			var w := (float(t[1])-float(t[0]))*k
			Kit._box(m,Vector3(cx,deck_y+float(t[3])*k*0.5,0.0),Vector3(w,float(t[3])*k,float(t[2])*2.0*k),0.03*k,0.0,1.12)
			for c in 3:
				var z := (0.55-0.55*c)*k
				for side: float in [-1.0,1.0]:
					Kit._box(m,Vector3(cx+side*w*0.2,deck_y+float(t[3])*k+0.02*k,z+0.12*k),Vector3(w*0.42,0.05*k,0.12*k),0.01,side*0.6,1.25)
			shapes.append(Fires.box_shape(Vector3(w,float(t[3])*k,float(t[2])*2.0*k),Vector3(cx,deck_y+float(t[3])*k*0.5,0.0)))
		Kit._mesh_node(self,m,"Pedestal")
		var body := Kit._body(self,shapes,"PedestalBody")
		bodies.append(body.get_rid())
		# The turning part: a collar, the yoke's two arms, the disc in its ring.
		turn = Node3D.new()
		turn.name = "Turn"
		turn.position = Vector3(0.0,deck_y,0.0)
		add_child(turn)
		var tm := Kit._stone()
		tm.solid(CityStone.drum(Transform3D(Basis.IDENTITY,Vector3.ZERO),10,0.85*k,0.8*k,0.35*k,0.05*k),NAN,1.0)
		for s: float in [-1.0,1.0]:
			Kit._box(tm,Vector3(s*YOKE_R*k,(DISC_Y*0.5+0.2)*k,0.0),Vector3(0.24*k,(DISC_Y+0.4)*k,0.42*k),0.04*k,0.0,0.95)
			Kit._box(tm,Vector3(s*YOKE_R*k,0.25*k,0.0),Vector3(0.5*k,0.3*k,0.7*k),0.05*k,0.0,0.9)
			Kit._box(tm,Vector3(s*(DISC_R+0.08)*k,DISC_Y*k,0.0),Vector3(0.24*k,0.24*k,0.24*k),0.05*k,0.0,1.1)
		# The ring: a stone frame of 12 chamfered blocks round the disc, the
		# inhaler's brow over its top (a heavier block).
		var ring_c := Vector3(0.0,DISC_Y*k,-0.06*k)
		for i in 12:
			var a := TAU*i/12.0
			var dir := Vector3(sin(a),cos(a),0.0)
			var at := ring_c+dir*(DISC_R+0.1)*k
			var heavy := i == 0
			var xf := Transform3D(Basis(Vector3.BACK,-a),at)
			tm.solid(CityStone.box(xf,Vector3(0.32*k if not heavy else 0.55*k,(0.13 if not heavy else 0.24)*k,0.2*k),0.03*k),NAN,0.92 if not heavy else 1.05)
		tm.solid(CityStone.drum(Transform3D(Basis(Vector3.RIGHT,PI*0.5),ring_c+Vector3(0.0,0.0,-0.32*k)),14,(DISC_R+0.02)*k,(DISC_R+0.02)*k,0.22*k,0.02*k),NAN,0.85)
		Kit._mesh_node(turn,tm,"Yoke")
		var disc := MeshInstance3D.new()
		disc.name = "Disc"
		disc.mesh = _disc_mesh(DISC_R*k,0.1*k)
		disc.position = ring_c
		disc_mat.shader = MIRROR_SHADER
		disc.material_override = disc_mat
		turn.add_child(disc)
		var db := Kit._body(turn,[Fires.box_shape(Vector3(DISC_R*2.0*k,DISC_R*2.0*k,0.3*k),ring_c+Vector3(0.0,0.0,-0.18*k))],"DiscBody")
		bodies.append(db.get_rid())
		# The beam's parts (hidden till fed).
		rod = Kit._rod(self,BEAM_R*k,"Beam")
		spot = Kit._glow_quad(self,BEAM_R*k*7.0,1.0,"BeamSpot")
		spot_light = OmniLight3D.new()
		spot_light.name = "BeamSpotLight"
		spot_light.light_color = SUN
		spot_light.omni_range = 9.0*k
		spot_light.light_energy = 3.0
		spot_light.shadow_enabled = false
		add_child(spot_light)
		coin_light = OmniLight3D.new()
		coin_light.name = "CoinLight"
		coin_light.light_color = SUN
		coin_light.omni_range = 7.0*k
		coin_light.light_energy = 1.6
		coin_light.position = ring_c+Vector3(0.0,0.0,0.8*k)
		turn.add_child(coin_light)
		sight = BeamLight.new()
		sight.name = "BeamSight"
		sight.radius = float(STRIPE[0])*k
		sight.strength = float(STRIPE[1])
		add_child(sight)
		sight.lit = false
		_ray.collision_mask = 1
		_ray.exclude = bodies
		_ray.hit_from_inside = false
		_to_yaw = deg_to_rad(bearing)
		_from_yaw = _to_yaw
		turn.rotation.y = _to_yaw
		# The ground cover on the deck's ring (nothing grows under the yoke).
		GroundCover.cover(self,_deck_ring(k),"",deck_y+0.002,seed_value,{"tufts":0.25,"under":0.0,"fade":0.0})
		_show_beam(false)

	## The deck's ring less the treadles and the collar, as a polygon (a
	## rough ring: the cover's skin tolerates the small overlap).
	func _deck_ring(k: float) -> PackedVector2Array:
		var out := PackedVector2Array()
		for i in 16:
			var a := TAU*i/16.0
			out.append(Vector2(sin(a),cos(a))*PED_R*k*0.93)
		return out

	## A shallow concave disc facing +z, UV its own (the middle at 0.5, 0.5).
	static func _disc_mesh(r: float, sag: float) -> ArrayMesh:
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var rings := 5
		var segs := 32
		var pts := []
		for j in rings+1:
			var row := []
			var rr := r*float(j)/rings
			for i in segs:
				var a := TAU*i/segs
				var p := Vector3(cos(a)*rr,sin(a)*rr,-sag*(1.0-pow(rr/r,2.0)))
				row.append(p)
			pts.append(row)
		for j in rings:
			for i in segs:
				var i2 := (i+1)%segs
				var quad := [pts[j][i],pts[j+1][i],pts[j+1][i2],pts[j][i2]]
				for tri: Array in [[0,1,2],[0,2,3]]:
					for q: int in [tri[0],tri[2],tri[1]]:
						var p: Vector3 = quad[q]
						# A concave face's normal: toward its focus, out of +z.
						st.set_normal(Vector3(-p.x*sag*2.0/(r*r),-p.y*sag*2.0/(r*r),1.0).normalized())
						st.set_uv(Vector2(p.x/r*0.5+0.5,-p.y/r*0.5+0.5))
						st.add_vertex(p)
		return st.commit()

	func disc_centre() -> Vector3:
		return turn.to_global(Vector3(0.0,DISC_Y*Kit.size(),-0.06*Kit.size()))

	## The way it throws now (world, unit).
	func beam_dir() -> Vector3:
		var p := deg_to_rad(pitch)
		return (turn.global_basis*Vector3(0.0,sin(p),cos(p))).normalized()

	## A stamp: a step its way (+1 turns the bearing up), with a clack.
	func stamp(way: int) -> void:
		if mode != "turn": return
		bearing += step*float(way)
		_from_yaw = turn.rotation.y
		_to_yaw = deg_to_rad(bearing)
		_turn_t = 0.0
		turns += 1

	## Back to the bearing it was built with.
	func reset() -> void:
		bearing = rest
		_to_yaw = deg_to_rad(bearing)
		_from_yaw = _to_yaw
		turn.rotation.y = _to_yaw
		_turn_t = -1.0
		_clock = 0.0
		turns = 0
		lightings = 0

	## The mirrors' and plaques' hook: a beam from `a` ending at `b` (world)
	## by `by`. On the disc, it feeds this mirror.
	func beam_touch(_a: Vector3, b: Vector3, by: Node) -> void:
		if by == self: return
		if b.distance_to(disc_centre()) <= DISC_R*Kit.size()*RELAY: _relay_until = _clock+0.2

	func _process(delta: float) -> void:
		_clock += delta
		_stamps()
		_turning(delta)
		_feed(delta)
		if fed: _throw()
		_lit_glow = move_toward(_lit_glow,1.0 if fed else 0.0,delta*3.0)
		disc_mat.set_shader_parameter("lit",_lit_glow)
		coin_light.visible = _lit_glow > 0.02
		coin_light.light_energy = 1.6*_lit_glow

	## A landing on a treadle (the wanderer's, from a hop or a fall) turns it.
	func _stamps() -> void:
		if mode != "turn": return
		var scene := get_tree().current_scene if get_tree() != null else null
		var motor: Variant = scene.get("motor") if scene != null else null
		if motor == null: return
		var g: bool = motor.grounded
		if g and not _was_grounded:
			var p := to_local(motor.feet as Vector3)/Kit.size()
			var t: Array = TREADLE
			if absf(p.y-(DISC_Y*0.0+RuinKit.SET_OFF+float(t[3]))) < 0.3 and absf(p.z) <= float(t[2])+0.15:
				var ax := absf(p.x)
				if ax >= float(t[0])-0.1 and ax <= float(t[1])+0.15: stamp(1 if p.x > 0.0 else -1)
		_was_grounded = g

	func _turning(delta: float) -> void:
		if mode == "sweep":
			var a := deg_to_rad(float(sweep[0]))
			var b := deg_to_rad(float(sweep[1]))
			var period := maxf(float(sweep[2]),0.5)
			var hold := float(sweep[3]) if sweep.size() > 3 else 0.0
			# A ping-pong eased between the ends, holding at each.
			var cycle := (period+hold)*2.0
			var t := fmod(_clock,cycle)
			var u := 0.0
			if t < hold: u = 0.0
			elif t < hold+period: u = (t-hold)/period
			elif t < hold*2.0+period: u = 1.0
			else: u = 1.0-(t-hold*2.0-period)/period
			u = u*u*(3.0-2.0*u)
			turn.rotation.y = lerpf(a,b,u)
			bearing = rad_to_deg(turn.rotation.y)
			return
		if _turn_t < 0.0: return
		_turn_t += delta
		var u := clampf(_turn_t/TURN_TIME,0.0,1.0)
		# A shove, then it settles into the next notch with a little overshoot.
		var e := 1.0-pow(1.0-u,3.0)+sin(u*PI)*0.08
		turn.rotation.y = lerp_angle(_from_yaw,_to_yaw,e)
		if u >= 1.0:
			turn.rotation.y = _to_yaw
			_turn_t = -1.0
			turned.emit(bearing)

	## Whether light falls on the disc: its source, any shaft over it, a lit
	## fire near it, or another mirror's beam on it.
	func _feed(delta: float) -> void:
		var was := fed
		var now := _clock < _relay_until
		if not now:
			_src_t -= delta
			if _src_t <= 0.0:
				_src_t = 0.5
				_sources = _find_sources()
			for s: Variant in _sources:
				if is_instance_valid(s) and bool((s as Node).get("lit")):
					if s is LightShaft and not (s as LightShaft).covers(disc_centre()): continue
					now = true
					break
		fed = now
		if fed != was:
			_show_beam(fed)
			fed_changed.emit(fed)

	func _find_sources() -> Array:
		if source != null and is_instance_valid(source): return [source]
		var out: Array = []
		var c := disc_centre()
		for s in get_tree().get_nodes_in_group(LightShaft.GROUP):
			if s is LightShaft and Vector2(c.x-s.global_position.x,c.z-s.global_position.z).length() <= (s as LightShaft).radius+0.6: out.append(s)
		for b in get_tree().get_nodes_in_group(Beacon.BEACONS):
			var f := Kit._fire_of(b)
			if f != null and (b as Node3D).global_position.distance_to(c) <= FIRE_CATCH*Kit.size(): out.append(f)
		return out

	func _show_beam(on: bool) -> void:
		rod.visible = on
		spot.visible = on
		spot_light.visible = on
		sight.lit = on

	## The beam this frame: one ray, the rod laid, what it meets lit.
	func _throw() -> void:
		var space := get_world_3d().direct_space_state
		var dir := beam_dir()
		var from := disc_centre()+dir*0.2*Kit.size()
		_ray.from = from
		_ray.to = from+dir*reach
		var hit := space.intersect_ray(_ray)
		var end := _ray.to
		beam_normal = -dir
		beam_hit = null
		if not hit.is_empty():
			end = hit.position
			beam_normal = hit.normal
			beam_hit = hit.collider
		beam_from = from
		beam_to = end
		Kit._lay_rod(rod,from,end)
		var spot_xf := Transform3D(Basis.looking_at(-beam_normal,Vector3.UP if absf(beam_normal.y) < 0.95 else Vector3.FORWARD),end+beam_normal*0.05)
		spot.global_transform = spot_xf
		spot.visible = not hit.is_empty()
		spot_light.global_position = end+beam_normal*0.8*Kit.size()
		sight.a = from
		sight.b = end
		# The first unlit fire along it catches.
		for b in get_tree().get_nodes_in_group(Beacon.BEACONS):
			var bb := b as Beacon
			if bb == null or bb.lit or not bb.is_inside_tree(): continue
			var p := bb.global_position
			if p.distance_to(Kit._on_segment(p,from,end+dir*0.6)) > CATCH*Kit.size(): continue
			var f := Kit._fire_of(bb)
			if f == null or bool(f.get("lit")) or bool(f.get("broken")): continue
			f.call("light")
			lightings += 1
			if f.get("mirror_lightings") != null: f.set("mirror_lightings",int(f.get("mirror_lightings"))+1)
			else: f.set_meta("mirror_lightings",int(f.get_meta("mirror_lightings",0))+1)
			lit_target.emit(f)
		for t in get_tree().get_nodes_in_group(GROUP):
			if t != self and t.has_method("beam_touch"): t.call("beam_touch",from,end,self)

# --- The sun plaque --------------------------------------------------------------------------------------

## A plaque in `parent` at `xform` (its middle on a wall's face, facing
## local +z). opts: "steps" ([[top middle (local), size]] each, the hidden
## route: walker-only glyph steps that slide out of the wall along +z by
## their depth), "radius" (m, 0.9), "seed".
static func plaque(parent: Node3D, xform: Transform3D, opts := {}) -> SunPlaque:
	var p := SunPlaque.new()
	p.name = str(opts.get("name","SunPlaque"))
	p.transform = xform
	p.radius = float(opts.get("radius",0.9))*size()
	p.steps_spec = opts.get("steps",[])
	p.seed_value = int(opts.get("seed",hash(xform.origin)))
	parent.add_child(p)
	p.stand_up()
	return p

class SunPlaque extends Node3D:
	const Kit = preload("res://scripts/city_kit_light2.gd")
	signal woke
	var radius := 0.9
	var steps_spec: Array = []
	var seed_value := 0
	var awake := false
	var steps: Array[Node3D] = []
	var _out: Array[Vector3] = []
	var _t := -1.0
	var glow: MeshInstance3D
	var light: OmniLight3D

	func _enter_tree() -> void:
		add_to_group(SunMirror.GROUP)

	func stand_up() -> void:
		var k := Kit.size()
		var m := Kit._stone()
		# The sun: a round boss, a ring of rays round it.
		m.solid(CityStone.drum(Transform3D(Basis(Vector3.RIGHT,PI*0.5),Vector3(0.0,0.0,-0.05*k)),14,radius,radius*0.9,0.3*k,0.06*k),NAN,1.15)
		for i in 8:
			var a := TAU*i/8.0
			var d := Vector3(sin(a),cos(a),0.0)
			m.solid(CityStone.box(Transform3D(Basis(Vector3.BACK,-a),d*(radius+0.32*k)+Vector3(0.0,0.0,0.05*k)),Vector3(0.1*k,0.22*k,0.1*k),0.02*k),NAN,1.05)
		Kit._mesh_node(self,m,"Sun")
		glow = Kit._glow_quad(self,radius*3.0,0.0,"Glow")
		glow.position.z = 0.3*k
		light = OmniLight3D.new()
		light.light_color = SUN
		light.omni_range = 6.0*k
		light.light_energy = 0.0
		light.position = Vector3(0.0,0.0,1.0*k)
		light.shadow_enabled = false
		add_child(light)
		for s: Array in steps_spec:
			var top: Vector3 = s[0]
			var sz: Vector3 = s[1]
			var st := Node3D.new()
			st.name = "GlyphStep%d" % steps.size()
			var out := top-Vector3(0.0,sz.y*0.5,0.0)
			st.position = out-Vector3(0.0,0.0,sz.z)
			add_child(st)
			var sm := Kit._stone()
			Kit._box(sm,Vector3.ZERO,sz,0.05*k,0.0,1.05)
			sm.runes(Vector3(-sz.x*0.45,-sz.y*0.4,sz.z*0.5+0.005),Vector3(sz.x*0.45,-sz.y*0.4,sz.z*0.5+0.005),Vector3.UP,Vector3.BACK,float(seed_value+steps.size()),minf(sz.y*0.8,0.6*k))
			Kit._mesh_node(st,sm,"Stone")
			var body := WalkerOnly.box(st,sz,Transform3D.IDENTITY,"Body")
			(body.get_child(0) as CollisionShape3D).disabled = true
			st.visible = false
			steps.append(st)
			_out.append(out)

	## A beam ending on it wakes it.
	func beam_touch(_a: Vector3, b: Vector3, _by: Node) -> void:
		if awake: return
		if b.distance_to(global_position) <= radius*1.5: wake()

	func wake() -> void:
		if awake: return
		awake = true
		_t = 0.0
		for st in steps: st.visible = true
		woke.emit()

	func reset() -> void:
		awake = false
		_t = -1.0
		for i in steps.size():
			steps[i].position = _out[i]-Vector3(0.0,0.0,(steps_spec[i][1] as Vector3).z)
			steps[i].visible = false
			((steps[i].get_node("Body") as Node).get_child(0) as CollisionShape3D).disabled = true
		glow.visible = false
		light.light_energy = 0.0

	func _process(delta: float) -> void:
		if _t < 0.0: return
		_t += delta
		var e := clampf(_t/0.8,0.0,1.0)
		(glow.material_override as ShaderMaterial).set_shader_parameter("strength",1.4*e)
		light.light_energy = 2.2*e
		var done := true
		for i in steps.size():
			# One after the other, each grinding out with a shudder.
			var u := clampf((_t-0.5-0.35*i)/1.0,0.0,1.0)
			if u < 1.0: done = false
			var shake := sin(_t*60.0+i)*0.02*(1.0-u)*(1.0 if u > 0.0 else 0.0)
			steps[i].position = _out[i]-Vector3(0.0,0.0,(steps_spec[i][1] as Vector3).z*(1.0-u*u*(3.0-2.0*u)))+Vector3(shake,0.0,0.0)
			if u >= 1.0: ((steps[i].get_node("Body") as Node).get_child(0) as CollisionShape3D).disabled = false
		if done and _t > 4.0: _t = -1.0

# --- The relief face -------------------------------------------------------------------------------------

## A relief cliff in `parent` at `xform` (its foot's middle, on the wall
## plane the bodies collide with; the carving faces local +z). opts:
## "width" (m, 40: the cliff; the carving is 14), "deep" (m, 24: the top's
## depth back from the face), "seed", "cover" (true: the ground cover on
## its top).
static func relief(parent: Node3D, xform: Transform3D, opts := {}) -> Relief:
	var r := Relief.new()
	r.name = str(opts.get("name","Relief"))
	r.transform = xform
	r.width = float(opts.get("width",40.0))
	r.deep = float(opts.get("deep",24.0))
	r.seed_value = int(opts.get("seed",hash(xform.origin)))
	r.cover = bool(opts.get("cover",true))
	parent.add_child(r)
	r.stand_up()
	return r

class Relief extends Node3D:
	const Kit = preload("res://scripts/city_kit_light2.gd")
	var width := 40.0
	var deep := 24.0
	var seed_value := 0
	var cover := true
	## As authored (m at his size 1): the cliff's top, the carving's width,
	## where the wall the bodies collide with stands out of the carved field.
	var top := 17.6
	var panel := 14.0
	var collide_z := 0.5
	## The holds: [{"name", "box": AABB (in this node's space, scaled)}], foot first.
	var holds: Array = []
	var carving: MeshInstance3D
	var decal: Decal
	var triangles := 0

	## The local frame: the carving's own, scaled by his size; the wall
	## plane the bodies collide with is z = 0 here (the carved field is
	## behind it).
	func stand_up() -> void:
		var k := Kit.size()
		var model: Node3D = (load(RELIEF_MODEL) as PackedScene).instantiate()
		var wall := model.get_node_or_null("Wall") as Node3D
		if wall != null:
			top = wall.position.y
			collide_z = wall.position.z
			panel = wall.scale.x
		var src := model.get_node("Relief") as MeshInstance3D
		var art := Node3D.new()
		art.name = "Carving"
		art.scale = Vector3.ONE*k
		art.position = Vector3(0.0,0.0,-collide_z*k)
		add_child(art)
		carving = MeshInstance3D.new()
		carving.name = "Relief"
		carving.mesh = Kit._dressed_relief(src.mesh,CityStone.stone_colour())
		if CityStone._stone == null: CityStone.warm()
		carving.material_override = CityStone._stone
		carving.layers = 1 | RELIEF_LAYER
		art.add_child(carving)
		triangles = 0
		for s in carving.mesh.get_surface_count():
			triangles += (carving.mesh as ArrayMesh).surface_get_array_index_len(s)/3 if (carving.mesh as ArrayMesh).surface_get_array_index_len(s) > 0 else (carving.mesh as ArrayMesh).surface_get_array_len(s)/3
		# The baked maps, projected straight into the wall by one Decal (the
		# carving's layer only: not the wanderer, not the Olmec).
		decal = Decal.new()
		decal.name = "Bake"
		decal.texture_albedo = load(RELIEF_CAVITY)
		decal.texture_normal = load(RELIEF_NORMAL)
		decal.cull_mask = RELIEF_LAYER
		decal.size = Vector3(panel,3.0,top)
		decal.albedo_mix = 1.0
		decal.normal_fade = 0.35
		decal.distance_fade_enabled = true
		decal.distance_fade_begin = 70.0
		decal.distance_fade_length = 30.0
		# Its -y (the way it projects) into the wall; its +z (the map's
		# down) down the wall.
		decal.transform = Transform3D(Basis(Vector3.RIGHT,PI*0.5),Vector3(0.0,top*0.5,0.0))
		art.add_child(decal)
		# The holds: clean walker-only boxes (he never reads them).
		holds.clear()
		var shapes: Array = []
		for n: Node in model.get_children():
			if not n.name.begins_with("Hold_"): continue
			var e := n as Node3D
			var sz := e.scale*k
			var at := (e.position-Vector3(0.0,0.0,collide_z))*k
			holds.append({"name":str(n.name).substr(8),"box":AABB(at-sz*0.5,sz)})
			shapes.append(Fires.box_shape(sz,at))
		holds.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return (a.box as AABB).end.y < (b.box as AABB).end.y)
		Kit._body(self,shapes,"Holds",true)
		model.free()
		# The cliff: its stone either side of the carving and behind it, a
		# capping course over the carving's top (the helmet's crown, the lip
		# his hands come over); collided as one block, its face z = 0.
		var h := top*k
		var w := width*k
		var d := deep*k
		var pw := panel*k
		var m := Kit._stone()
		var side := (w-pw)*0.5
		for s: float in [-1.0,1.0]:
			Kit._box(m,Vector3(s*(pw*0.5+side*0.5),h*0.5,-d*0.5),Vector3(side,h,d),0.25*k)
		Kit._box(m,Vector3(0.0,h*0.5,-d*0.5-collide_z*k*0.5-0.05),Vector3(pw+0.2,h,d-collide_z*k-0.1),0.0,0.0,0.85)
		Kit._box(m,Vector3(0.0,h-0.2*k,-0.05*k),Vector3(pw+0.4*k,0.4*k,0.5*k),0.1*k,0.0,1.05)
		# Courses on the flanks: a band every few set-offs, so the cliff reads
		# as cut stone and the carving as its panel.
		var course := Kit.set_off()*3.0
		var y := course
		while y < h-0.5:
			for s: float in [-1.0,1.0]:
				Kit._box(m,Vector3(s*(pw*0.5+side*0.5),y,0.02*k),Vector3(side-0.6*k,0.18*k,0.12*k),0.03*k,0.0,0.8)
			y += course
		Kit._mesh_node(self,m,"Cliff")
		Kit._body(self,[Fires.box_shape(Vector3(w,h,d),Vector3(0.0,h*0.5,-d*0.5))],"CliffBody")
		if cover:
			GroundCover.cover(self,Rect2(-w*0.5+0.4,-d+0.4,w-0.8,d-0.6),"",h+0.002,seed_value,{"tufts":0.6,"fade":0.6})

	## The holds' tops (world), foot first: where he stands on each.
	func hold_tops() -> Array:
		var out: Array = []
		for hd: Dictionary in holds:
			var b: AABB = hd.box
			out.append(to_global(Vector3(b.get_center().x,b.end.y,b.get_center().z)))
		return out

	## The lip (world, its middle).
	func lip() -> Vector3:
		return to_global(Vector3(0.0,top*Kit.size(),0.0))

## The relief's low mesh dressed as the kit's stone: each vertex shaded as
## the kit shades a face (Style.shade), darkened by the occlusion baked in
## its colour's R, its worn high points (G) and the holds' polished lips (B)
## a little paler, moss on what faces up; rest place in UV/UV2 for the
## weathering grain. LODs made again (an ImporterMesh).
static func _dressed_relief(mesh: Mesh, stone: Color) -> ArrayMesh:
	var out := ImporterMesh.new()
	var noise := FastNoiseLite.new()
	noise.seed = 31
	noise.frequency = 0.5
	var moss := CityStone.MOSS.srgb_to_linear()
	var moss_light := CityStone.MOSS_LIGHT.srgb_to_linear()
	for s in range(mesh.get_surface_count()):
		var arrays := mesh.surface_get_arrays(s)
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		var baked: PackedColorArray = arrays[Mesh.ARRAY_COLOR] if arrays[Mesh.ARRAY_COLOR] != null else PackedColorArray()
		var colours := PackedColorArray()
		colours.resize(verts.size())
		var ra := PackedVector2Array()
		var rb := PackedVector2Array()
		ra.resize(verts.size())
		rb.resize(verts.size())
		for i in verts.size():
			var p := verts[i]
			var n := normals[i]
			var c := Style.shade(stone,Vector3(0.0,9.0,-2.0),p,n,1.0)
			var ao := 1.0
			var convex := 0.5
			var polish := 0.0
			if baked.size() == verts.size():
				ao = baked[i].r
				convex = baked[i].g
				polish = baked[i].b
			var occ := pow(clampf(ao,0.0,1.0),0.85)
			c = c*lerpf(0.88,1.14,convex)
			c = c.lerp(c*1.35,polish*0.55)
			var up := smoothstep(0.62,0.95,n.y)
			if up > 0.0:
				var patch := clampf(noise.get_noise_3dv(p)*1.1+0.35,0.0,1.0)
				var tone := moss.lerp(moss_light,clampf(noise.get_noise_3dv(p*3.0)+0.5,0.0,1.0))
				c = c.lerp(tone,up*patch*0.55*occ*(1.0-polish))
			c = c*lerpf(CityStone.AO_FLOOR,1.0,occ)
			c.a = occ
			colours[i] = c
			var rest := p*CityStone.GRAIN
			ra[i] = Vector2(rest.x,rest.y)
			rb[i] = Vector2(rest.z,0.0)
		arrays[Mesh.ARRAY_COLOR] = colours
		arrays[Mesh.ARRAY_TEX_UV] = ra
		arrays[Mesh.ARRAY_TEX_UV2] = rb
		out.add_surface(Mesh.PRIMITIVE_TRIANGLES,arrays)
	out.generate_lods(60.0,25.0,[])
	return out.get_mesh()
