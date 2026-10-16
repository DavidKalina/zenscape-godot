extends RefCounted
## The city kit's refuges:
## places the Olmec can't follow, in the underground Olmec city's weathered
## basalt (the `city` kit family; scripts/city_kit.gd registers them, see
## the handoff). From the round 3 brainstorm's "refuge he can't enter":
##   city_mouserun  a walker-sized passage with a jog through a colossal wall
##                  he can't climb (k2 colossus_mouserun)
##   city_niches    a ladder of votive shelves, each with a small lamp, up a
##                  giant pier he can't climb, to a dark alcove (k2
##                  colossus_niche)
##   city_hush      the hush gallery: a servants' slit into a tier, a long
##                  dark hall behind it, a snuff trough across it, out by a
##                  side passage past a lamp that relights the torch (k6
##                  maker_hush)
##   city_slotwall  a thick wall with a chimney inside, climbed ledge to
##                  ledge, his arm slots at his shoulder on his side (k3
##                  oc_slot)
## Every size is read from the two bodies: the wanderer's (WorldScale,
## PhysicsGround, RuinKit's GRAB_TOP and SET_OFF, PilotMotor's STEP_UP) and
## the Olmec's (scripts/enemies/headless_body.gd `build_of` over its own
## default knobs: width, depth, neck, reach, climb_max): see `walker` and
## `olmec`. What he fits is solid stone (layer 1); what only the wanderer
## stands on inside (floors, shelves, ledges, the hall's piers) is
## walker-only (scripts/walker_only.gd), so the Olmec never plans onto it.
##
## Each piece is a Refuge (a Node3D, the inner class below): its stone (one
## mesh in the Olmec's stone, scripts/kit_isle/greybox/giant_stone.gd), its
## colliders, its lamps, and what it does as he plays:
##   hide     the boxes he is in it (the cue: scripts' RefugeCue, a dark
##            vignette and "hidden" while no Olmec sees him, "seen" if one does)
##   snuff    the hush trough: his torch (the underground look's, scripts/
##            underground/underground.gd) put out with a hiss when his feet
##            go in the water; a lit lamp relights it as he passes
##   shade    the hush hall is dark to the Olmec's sight (a SightLight that
##            takes the look's ambient down to the torch preset's, inside)
##   echo     the trough's splash carries out of the front mouth (the mouse run
##            is a true safe room: its step echo is off, `MOUSE_ECHO`): a Beacon there
##            (no light, scripts/enemies/beacon.gd) draws a calm Olmec round
##            to it to look, so no refuge is safe forever
## Metadata on each root: "kind", "bounds" (AABB, local), "mouths" (Array of
## {at, out}: local), "his_ground" (AABB where he stands to look, local),
## "tris".
##
## Usage: `var r := CityKitRefuges.piece("city_hush", 1)`; add it under the
## study (it finds the study's `motor` through the current scene).

const GiantStone = preload("res://scripts/kit_isle/greybox/giant_stone.gd")
const WorldScale = preload("res://scripts/world_scale.gd")
const RuinKit = preload("res://scripts/ruin_kit.gd")
const PhysicsGround = preload("res://scripts/pilot_physics_ground.gd")
const HeadlessBody = preload("res://scripts/enemies/headless_body.gd")
const Underground = preload("res://scripts/underground/underground.gd")
const PilotMotor = preload("res://scripts/pilot_motor.gd")
const GroundCover = preload("res://scripts/underground/ground_cover.gd")
const CityStone = preload("res://scripts/city_kit_stone.gd")

const PIECES := ["city_mouserun","city_niches","city_hush","city_slotwall"]
const NAMES := {"city_mouserun":"Mouse run","city_niches":"Votive niches","city_hush":"Hush gallery","city_slotwall":"Slotted wall"}

## The lamps' real flame (a Flame candle, scaled up to a lamp's wick) and how
## far it draws before the old bead takes over (m).
const Flame = preload("res://scripts/flame.gd")
const LAMP_FLAME := 1.25
const LAMP_FAR := 26.0
## Lamp flame and clay.
const FLAME := Color(1.0,0.6,0.25)
const CLAY := Color(0.36,0.2,0.12)
const WATER := Color(0.02,0.025,0.03)
## A lamp's light on him for the Olmec's sight (scripts/enemies/sight_light.gd).
const LAMP_SIGHT := 0.5
const LAMP_SIGHT_R := 2.6
## The drawn light: one OmniLight3D every LAMP_LIGHT_EVERY lamps (the rest
## glow only), its range and energy.
const LAMP_LIGHT_EVERY := 2
const LAMP_RANGE := 3.4
const LAMP_ENERGY := 1.6
## A relighting lamp relights his torch within this (m, flat-ish).
const RELIGHT_REACH := 1.3
## The echo: how far its beacon draws (m), how long it holds once he stops
## (s), how long a splash carries (s).
## The mouse run is a true safe room: his steps inside draw nothing to a mouth.
## Flip on to bring the old echo back (off by default).
const MOUSE_ECHO := false
const ECHO_DRAW := 45.0
const ECHO_HOLD := 6.0
const SPLASH_FOR := 3.0
## The arm slot's cuts through the leaf (its splay down inward).
const SLOT_STEPS := 4
## How long a calm Olmec stands looking down the hall, drawn by the glow (s).
const GLOW_DWELL := 10.0

# --- The two bodies ------------------------------------------------------------------------

## The wanderer's numbers (m): tall, radius, the grab, the climb's rise, a step.
static func walker() -> Dictionary:
	var w: float = WorldScale.wanderer
	return {"tall":PhysicsGround.HEAD*w,"radius":PhysicsGround.RADIUS*w,"grab":RuinKit.GRAB_TOP,
		"rise":RuinKit.SET_OFF,"stand":RuinKit.STAND,"step":PilotMotor.STEP_UP}

static var _olmec := {}

## The whole Olmec's numbers (m) at the wanderer's scale, from its own
## knobs: hh (head height), width, length, neck, arm, reach (its swat's flat
## reach), climb_max, eye (about where it looks from, its head on).
static func olmec() -> Dictionary:
	if not _olmec.is_empty(): return _olmec
	var unit := PhysicsGround.HEAD*WorldScale.wanderer
	var b: Node = HeadlessBody.new()
	var k: Dictionary = b.default_knobs({"walk":PilotMotor.WALK,"run":PilotMotor.RUN,"unit":unit,"gravity":20.0})
	b.free()
	var o := HeadlessBody.build_of(k,unit)
	o["reach"] = float(k.catch_reach)*float(o.hh)
	o["climb_max"] = float(k.climb_max)
	o["swat_dy"] = float(o.neck)*0.6
	# His eye worn whole, over his feet (measured: 8.07 m at wanderer 1,
	# the head's `_eye`, between its eyes).
	o["eye"] = float(o.neck)*1.23
	_olmec = o
	return o

# --- The pieces ------------------------------------------------------------------------------

static func piece(id: String, seed_value := 1, _weathered := 1.0) -> Node3D:
	match id:
		"city_mouserun": return mouserun(seed_value)
		"city_niches": return niches(seed_value)
		"city_hush": return hush(seed_value)
		"city_slotwall": return slotwall(seed_value)
	push_error("city_kit_refuges: no piece %s" % id)
	return null

## The mouse run, its giant face to +z and -z: a wall along x (LENGTH),
## THICK through (z), too tall for him to climb (climb_max and a margin);
## the run goes through it, walker-wide and walker-tall, in three legs with
## a jog so the far mouth isn't seen from the near one. Its floor stands a
## step over the yard (the cill) on walker-only stone.
static func mouserun(seed_value := 1) -> Node3D:
	var o := olmec()
	var wk := walker()
	var r := Refuge.new()
	r.name = "CityMouseRun"
	r.kind = "city_mouserun"
	var length := float(o.width)*7.0
	# Thick enough that his reach from either face can't touch the jog:
	# twice (his depth/2 + reach) over the run's middle.
	var thick := snappedf((float(o.length)*0.5+float(o.reach))*2.0*0.8,0.2)
	var tall := float(o.climb_max)+float(o.hh)*0.7
	var wide := float(wk.radius)*5.0
	var clear := float(wk.tall)*1.6
	var cill := float(wk.step)*0.8
	var jog := wide*1.6
	var hz := thick*0.5
	var top := cill+clear
	var legs: Array[AABB] = [
		_ab(Vector3(-wide*0.5,0.0,-wide*0.5),Vector3(wide*0.5,top,hz+1.0)),
		_ab(Vector3(-wide*0.5,0.0,-wide*0.5),Vector3(jog+wide*0.5,top,wide*0.5)),
		_ab(Vector3(jog-wide*0.5,0.0,-hz-1.0),Vector3(jog+wide*0.5,top,wide*0.5)),
	]
	var wall := _ab(Vector3(-length*0.5,0.0,-hz),Vector3(length*0.5,tall,hz))
	var m := CityMesher.new(GiantStone.stone_colour())
	m.dark = legs
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value*7919+11
	var solid := _body(r,"Stone")
	for b: AABB in _carve(wall,legs): _shape(solid,b)
	_courses(m,wall,legs,float(o.hh),rng,0.22)
	# The plinth: a course standing out at the foot of each face, its top
	# the cill (the run's worn lip), and a cornice at the top.
	for s: float in [-1.0,1.0]:
		var plinth := _ab(Vector3(-length*0.5-0.4,0.0,minf(s*hz,s*(hz+0.6))),Vector3(length*0.5+0.4,cill,maxf(s*hz,s*(hz+0.6))))
		_shape(solid,plinth)
		_blocks(m,plinth,[],rng,3.0,0.08,0.95)
		var cornice := _ab(Vector3(-length*0.5-0.3,tall-1.0,minf(s*hz,s*(hz+0.5))),Vector3(length*0.5+0.3,tall,maxf(s*hz,s*(hz+0.5))))
		_shape(solid,cornice)
		_blocks(m,cornice,[],rng,4.0,0.15,1.05)
	# The run's floor: walker-only, the cill's height.
	var floor_body := _body(r,"RunFloor",true)
	for leg in legs:
		var f := _ab(Vector3(leg.position.x,0.0,maxf(leg.position.z,-hz)),Vector3(leg.end.x,cill,minf(leg.end.z,hz)))
		_shape(floor_body,f)
	for leg in legs:
		var f := _ab(Vector3(leg.position.x,0.0,maxf(leg.position.z,-hz)),Vector3(leg.end.x,cill,minf(leg.end.z,hz)))
		m.box(Transform3D(Basis.IDENTITY,f.get_center()+Vector3(0.0,-0.02,0.0)),f.size+Vector3(0.0,-0.04,0.0),0.04,0.0,0.85)
	# The tell: a small cut lintel over each mouth, paler than the colossal
	# coursing round it, the size of a loaf.
	for mouth: Array in [[0.0,hz],[jog,-hz]]:
		var sz := signf(float(mouth[1]))
		m.box(Transform3D(Basis.IDENTITY,Vector3(float(mouth[0]),top+0.17,float(mouth[1])+sz*0.06)),Vector3(wide+0.5,0.34,0.3),0.05,top,1.35)
		m.box(Transform3D(Basis.IDENTITY,Vector3(float(mouth[0]),cill-0.05,float(mouth[1])+sz*0.25)),Vector3(wide+0.2,0.12,0.6),0.04,0.0,1.25)
	r.add_child(_mesh_of(m,"Stone"))
	r.set_meta("tris",m.triangles())
	# Fist niches with embers in the jog's back wall (the tenders').
	_lamp(r,Vector3(jog*0.5,cill+clear*0.62,-wide*0.5+0.06),Vector3(0,0,1),true,false)
	for leg in legs: _cover(r,_ab(Vector3(leg.position.x,0.0,maxf(leg.position.z,-hz)),Vector3(leg.end.x,cill,minf(leg.end.z,hz))),seed_value,true)
	_cover(r,wall,seed_value)
	r.hide_boxes = legs.duplicate()
	r.mouths = [{"at":Vector3(0.0,cill,hz),"out":Vector3(0,0,1)},{"at":Vector3(jog,cill,-hz),"out":Vector3(0,0,-1)}]
	r.echo_steps = MOUSE_ECHO
	if MOUSE_ECHO: r._add_echoes(float(o.width)*0.9)
	r.set_meta("kind",r.kind)
	r.set_meta("bounds",wall.grow(0.6))
	r.set_meta("mouths",r.mouths)
	r.set_meta("his_ground",_ab(Vector3(-length*0.5,0.0,hz+0.6),Vector3(length*0.5,0.0,hz+0.6+float(o.width)*2.0)))
	r.set_meta("sizes",{"length":length,"thick":thick,"tall":tall,"wide":wide,"clear":clear,"cill":cill,"jog":jog})
	return r

## The votive niches: a giant square pier too tall for him to climb, a
## ladder of small shelves zigzagging up its +z face (each RuinKit.SET_OFF
## over the last, so each is grabbed from the one below), each with a clay
## lamp, to a dark alcove cut into the pier at the top.
static func niches(seed_value := 1) -> Node3D:
	var o := olmec()
	var wk := walker()
	var r := Refuge.new()
	r.name = "CityNiches"
	r.kind = "city_niches"
	var side := snappedf(float(o.width)*1.6,0.2)
	var tall := float(o.climb_max)+float(o.hh)*1.0
	var rise := float(wk.rise)
	var deep := float(wk.stand)*1.75
	var wide := float(wk.radius)*5.0
	var gap := float(wk.radius)*1.8
	var thick := 0.32
	var count := 7
	var cell_floor := rise*float(count+1)
	var cell_tall := float(wk.tall)*2.0
	var cell_wide := float(wk.radius)*8.0
	var cell_deep := float(wk.tall)*2.2
	var h := side*0.5
	var pier := _ab(Vector3(-h,0.0,-h),Vector3(h,tall,h))
	# The alcove sits over the last shelf's side, so its floor's front lip is
	# grabbed from that shelf.
	var last_x := _shelf_x(count-1,wide,gap)
	var cell := _ab(Vector3(last_x-cell_wide*0.5,cell_floor,h-cell_deep),Vector3(last_x+cell_wide*0.5,cell_floor+cell_tall,h+0.5))
	var m := CityMesher.new(GiantStone.stone_colour())
	m.dark = [cell.grow(-0.02)]
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value*6113+5
	var solid := _body(r,"Stone")
	for b: AABB in _carve(pier,[cell]): _shape(solid,b)
	_courses(m,pier,[cell],float(o.hh)*0.9,rng,0.2)
	# A plinth round its foot.
	var plinth := _ab(Vector3(-h-0.5,0.0,-h-0.5),Vector3(h+0.5,0.7,h+0.5))
	_shape(solid,plinth)
	_blocks(m,plinth,[],rng,2.6,0.1,0.92)
	var shelves := _body(r,"Shelves",true)
	for i in count:
		var y := rise*float(i+1)
		var x := _shelf_x(i,wide,gap)
		var s := _ab(Vector3(x-wide*0.5,y-thick,h),Vector3(x+wide*0.5,y,h+deep))
		_shape(shelves,s)
		# The shelf, a bracket under it, a lamp at its back corner.
		m.box(Transform3D(Basis.IDENTITY,s.get_center()),s.size,0.05,y-thick,1.08)
		m.box(Transform3D(Basis.IDENTITY,Vector3(x,y-thick-0.2,h+deep*0.3)),Vector3(wide*0.4,0.4,deep*0.6),0.06,y-thick-0.4,0.95)
		var lamp_x := x+(wide*0.5-0.2)*(1.0 if x < 0.0 else -1.0)
		_lamp(r,Vector3(lamp_x,y,h+0.18),Vector3(0,0,1),i % LAMP_LIGHT_EVERY == 0,true)
		# A glyph panel over each shelf: a shallow paler block on the face.
		m.box(Transform3D(Basis.IDENTITY,Vector3(x,y+0.75,h+0.04)),Vector3(0.5,0.5,0.1),0.03,y,1.3)
	# The alcove: dark, its floor the pier's stone; a lintel over it.
	m.box(Transform3D(Basis.IDENTITY,Vector3(last_x,cell_floor+cell_tall+0.25,h+0.12)),Vector3(cell_wide+0.6,0.5,0.3),0.06,cell_floor,1.25)
	r.add_child(_mesh_of(m,"Stone"))
	r.set_meta("tris",m.triangles())
	_cover(r,_ab(Vector3(cell.position.x,0.0,h-cell_deep),Vector3(cell.end.x,cell_floor,h)),seed_value,true)
	_cover(r,pier,seed_value)
	r.hide_boxes = [_ab(Vector3(cell.position.x,cell_floor,h-cell_deep),Vector3(cell.end.x,cell_floor+cell_tall,h))]
	r.mouths = [{"at":Vector3(last_x,cell_floor,h),"out":Vector3(0,0,1)}]
	r.set_meta("kind",r.kind)
	r.set_meta("bounds",pier.grow(deep+0.6))
	r.set_meta("mouths",r.mouths)
	r.set_meta("his_ground",_ab(Vector3(-h-6.0,0.0,h+0.5),Vector3(h+6.0,0.0,h+float(o.width)*3.0)))
	r.set_meta("sizes",{"side":side,"tall":tall,"rise":rise,"shelf_deep":deep,"shelf_wide":wide,"gap":gap,"cell_floor":cell_floor,"cell":[cell_wide,cell_tall,cell_deep]})
	return r

## The shelf `i`'s middle (x): alternating sides of the face's middle, `gap` apart.
static func _shelf_x(i: int, wide: float, gap: float) -> float:
	return (wide*0.5+gap*0.5)*(1.0 if i % 2 == 0 else -1.0)

## The hush gallery: a tier he can stand in front of (and climb), its front
## face to +z, a servants' slit into it (walker-wide, tall enough that from
## his forecourt he looks along the hall: a lit torch inside is seen, a dark
## wanderer isn't), a long hall behind it with side bays between squat
## (walker-only) piers, a snuff trough across it, and an exit passage out of
## the tier's east side past a lamp that relights the torch.
static func hush(seed_value := 1) -> Node3D:
	var o := olmec()
	var wk := walker()
	var r := Refuge.new()
	r.name = "CityHush"
	r.kind = "city_hush"
	var hh := float(o.hh)
	var wide := float(wk.radius)*5.0
	var slit_tall := hh*1.25
	var front := wide
	var hall_wide := hh*2.0
	var aisle := wide*1.7
	var hall_deep := hh*3.0
	var hall_tall := slit_tall
	var floor_y := float(wk.step)*0.8
	var trough_at := hh*1.2
	var trough_wide := float(wk.radius)*3.6
	var tier_wide := hh*8.0
	var tier_deep := hall_deep+front+hh*1.0
	var tier_tall := hh*2.7
	var clear := float(wk.tall)*1.6
	var tw := tier_wide*0.5
	var tier := _ab(Vector3(-tw,0.0,-tier_deep),Vector3(tw,tier_tall,0.0))
	var back := -front-hall_deep
	var slit := _ab(Vector3(-wide*0.5,0.0,-front-0.5),Vector3(wide*0.5,slit_tall,0.6))
	var hall := _ab(Vector3(-hall_wide*0.5,0.0,back),Vector3(hall_wide*0.5,hall_tall,-front))
	var exit := _ab(Vector3(hall_wide*0.5-0.5,0.0,back),Vector3(tw+0.6,floor_y+clear,back+wide))
	var holes: Array[AABB] = [slit,hall,exit]
	var m := CityMesher.new(GiantStone.stone_colour())
	m.dark = [hall,exit,_ab(Vector3(slit.position.x,0.0,-front),Vector3(slit.end.x,slit_tall,-front*0.4))]
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value*4447+3
	var solid := _body(r,"Stone")
	for b: AABB in _carve(tier,holes): _shape(solid,b)
	_courses(m,tier,holes,hh*0.9,rng,0.2)
	# The brow: a heavy block drawn forward over the slit.
	var brow := _ab(Vector3(-hh*0.65,slit_tall,0.0),Vector3(hh*0.65,slit_tall+hh*0.42,hh*0.3))
	_shape(solid,brow)
	m.box(Transform3D(Basis.IDENTITY,brow.get_center()),brow.size,0.18,slit_tall,0.9)
	# A step before the slit (its cill) and the walker-only floor inside, all
	# but the trough.
	var cill := _ab(Vector3(-wide*0.5-0.3,0.0,0.0),Vector3(wide*0.5+0.3,floor_y,0.7))
	_shape(solid,cill)
	m.box(Transform3D(Basis.IDENTITY,cill.get_center()),cill.size,0.05,0.0,1.2)
	var trough := _ab(Vector3(-hall_wide*0.5,0.0,-front-trough_at-trough_wide),Vector3(hall_wide*0.5,floor_y,-front-trough_at))
	var floors: Array[AABB] = []
	floors.append(_ab(Vector3(-wide*0.5,0.0,-front),Vector3(wide*0.5,floor_y,0.0)))
	floors.append(_ab(Vector3(-hall_wide*0.5,0.0,trough.end.z),Vector3(hall_wide*0.5,floor_y,-front)))
	floors.append(_ab(Vector3(-hall_wide*0.5,0.0,back),Vector3(hall_wide*0.5,floor_y,trough.position.z)))
	floors.append(_ab(Vector3(hall_wide*0.5,0.0,back),Vector3(tw,floor_y,back+wide)))
	var walk := _body(r,"HallFloor",true)
	for f in floors:
		_shape(walk,f)
		m.box(Transform3D(Basis.IDENTITY,f.get_center()),f.size,0.03,0.0,0.6)
	# The trough's bed and its still black water (drawn only).
	m.box(Transform3D(Basis.IDENTITY,Vector3(0.0,-0.05,trough.get_center().z)),Vector3(hall_wide,0.1,trough_wide),0.02,-0.1,0.45)
	var water := MeshInstance3D.new()
	water.name = "TroughWater"
	var wb := BoxMesh.new()
	wb.size = Vector3(hall_wide-0.02,0.02,trough_wide-0.02)
	water.mesh = wb
	water.position = Vector3(0.0,floor_y-0.12,trough.get_center().z)
	var wm := StandardMaterial3D.new()
	wm.albedo_color = WATER
	wm.roughness = 0.04
	wm.metallic_specular = 0.9
	water.material_override = wm
	water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	r.add_child(water)
	# The squat piers between the side bays (walker-only: inside where he
	# can't fit, cover only if his sight is told so: `sight_walker_only`).
	var piers := _body(r,"HallPiers",true)
	var pier_w := float(wk.radius)*2.8
	var bay_z: Array[float] = []
	var pz := -front-trough_at-trough_wide-hh*0.55
	while pz > back+hh*0.6:
		bay_z.append(pz)
		pz -= hh*0.95
	for z in bay_z:
		for s: float in [-1.0,1.0]:
			var p := _ab(Vector3(minf(s*aisle*0.5,s*(aisle*0.5+pier_w)),floor_y,z-pier_w*0.5),Vector3(maxf(s*aisle*0.5,s*(aisle*0.5+pier_w)),hall_tall,z+pier_w*0.5))
			_shape(piers,p)
			m.box(Transform3D(Basis.IDENTITY,p.get_center()),p.size,0.12,floor_y,0.8)
	# A carved stele in the aisle past the trough, off its middle: in the
	# slit's line, walker-sized cover (walker-only, like the piers).
	var stele := _ab(Vector3(wide*0.5-0.35-0.0,floor_y,-front-trough_at-trough_wide-hh*0.42-0.22),Vector3(wide*0.5+0.35,floor_y+float(wk.tall)*1.55,-front-trough_at-trough_wide-hh*0.42+0.22))
	_shape(piers,stele)
	m.box(Transform3D(Basis.IDENTITY,stele.get_center()),stele.size,0.08,floor_y,1.15)
	r.add_child(_mesh_of(m,"Stone"))
	r.set_meta("tris",m.triangles())
	r.set_meta("stele",stele)
	# The relighting lamp in the exit passage's wall, near the far mouth.
	var lamp := _lamp(r,Vector3(tw-1.6,floor_y+clear*0.55,back+0.06),Vector3(0,0,1),true,true)
	r.relights = [lamp.position]
	for f in floors: _cover(r,f,seed_value,true)
	_cover(r,tier,seed_value)
	r.trough = trough
	r.hide_boxes = [hall,_ab(exit.position,Vector3(tw,exit.end.y,exit.end.z)),_ab(Vector3(slit.position.x,0.0,-front),Vector3(slit.end.x,slit_tall,0.0))]
	r.shade_boxes = [hall,exit]
	r.mouths = [{"at":Vector3(0.0,floor_y,0.0),"out":Vector3(0,0,1)},{"at":Vector3(tw,floor_y,back+wide*0.5),"out":Vector3(1,0,0)}]
	r.echo_splash = true
	r._add_echoes(float(o.width)*0.9)
	r._add_shade()
	# His lit torch inside glows at the slit: a calm Olmec comes to the
	# forecourt on the slit's line to look down the hall.
	r._add_glow(Vector3(0.0,slit_tall*0.5,0.4),Vector3(0.0,-slit_tall*0.5,hh*5.0))
	r.set_meta("kind",r.kind)
	r.set_meta("bounds",tier.grow(0.6))
	r.set_meta("mouths",r.mouths)
	r.set_meta("his_ground",_ab(Vector3(-tw,0.0,0.6),Vector3(tw,0.0,hh*6.0)))
	r.set_meta("sizes",{"slit":[wide,slit_tall],"hall":[hall_wide,hall_tall,hall_deep],"aisle":aisle,"trough":[trough_wide,floor_y],"tier":[tier_wide,tier_tall,tier_deep],"bays":bay_z.size()})
	return r

## The slotted wall: a wall along x, THICK through, its +z face his; a
## chimney inside (between two leaves, CHIMNEY across), climbed by ledges
## that zigzag leaf to leaf a RuinKit.SET_OFF apart; a walker door at the
## foot of his face, an arm slot at his shoulder (he looks in, and swats
## what is in reach), and a window at the top of the far face onto a
## walker-only balcony. Its top he can climb to.
static func slotwall(seed_value := 1) -> Node3D:
	var o := olmec()
	var wk := walker()
	var r := Refuge.new()
	r.name = "CitySlotWall"
	r.kind = "city_slotwall"
	var hh := float(o.hh)
	var rise := float(wk.rise)
	# The far leaf is thick; his is thin (the card's "thin wall"): stopped
	# at his face, his swat reaches his half of the chimney (and his side's
	# ledges), never the far half.
	var leaf := float(wk.tall)*0.9
	var leaf_his := float(wk.tall)*0.4
	var chimney := float(wk.tall)*2.15
	var thick := chimney+leaf+leaf_his
	var hz := chimney*0.5+leaf_his
	var zb := -chimney*0.5-leaf
	var length := hh*3.6
	var run := float(wk.radius)*11.0
	var ledge := float(wk.stand)*1.55
	var floor_y := float(wk.step)*0.8
	var door := Vector2(float(wk.radius)*4.3,float(wk.tall)*1.6)
	var levels := 6
	var exit_y := floor_y+rise*float(levels)
	var inner_top := exit_y+float(wk.tall)*1.9
	var tall := inner_top+leaf*1.2
	var slot := Vector2(float(wk.radius)*4.3,float(wk.tall)*2.0)
	# His arm slot, an embrasure splayed down inward along his eye's line:
	# from his eye (`eye` over his feet, `stand_off` m out from his face)
	# to a wanderer's chest on his side's first ledge (the second up, the
	# one within his swat's height); the slot's middle follows that line
	# through the leaf in SLOT_STEPS cuts, `slot.y` tall. The floor and the
	# far leaf's ledges are out of his reach and his sight.
	var eye_y := float(o.eye)
	# Where he stops at a wall (his look ahead, braked: 2.2-3.2 m measured).
	var stand_off := float(o.length)*0.5+hh*0.4
	var aim := Vector2(leaf_his+ledge*0.5,floor_y+rise*2.0+float(wk.tall)*0.55)
	var slope := (eye_y-aim.y)/(stand_off+aim.x)
	var slot_mid := eye_y-slope*stand_off
	var slot_cuts: Array[AABB] = []
	for k in SLOT_STEPS:
		var d0 := leaf_his*float(k)/SLOT_STEPS
		var d1 := leaf_his*float(k+1)/SLOT_STEPS
		var mid := slot_mid-slope*(d0+d1)*0.5
		slot_cuts.append(_ab(Vector3(-slot.x*0.5,mid-slot.y*0.5,hz-d1-(0.1 if k == SLOT_STEPS-1 else 0.0)),Vector3(slot.x*0.5,mid+slot.y*0.5,hz-d0+(0.6 if k == 0 else 0.0))))
	var slot_box: AABB = slot_cuts[0]
	for c in slot_cuts: slot_box = slot_box.merge(c)
	var wall := _ab(Vector3(-length*0.5,0.0,zb),Vector3(length*0.5,tall,hz))
	var inner := _ab(Vector3(-run*0.5,0.0,-chimney*0.5),Vector3(run*0.5,inner_top,chimney*0.5))
	var door_box := _ab(Vector3(-door.x*0.5,0.0,chimney*0.5-0.1),Vector3(door.x*0.5,floor_y+door.y,hz+0.6))
	var window := _ab(Vector3(-door.x*0.5,exit_y,zb-0.6),Vector3(door.x*0.5,exit_y+door.y,-chimney*0.5+0.1))
	var holes: Array[AABB] = [inner,door_box,window]
	holes.append_array(slot_cuts)
	var m := CityMesher.new(GiantStone.stone_colour())
	m.dark = [inner]
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value*3301+9
	var solid := _body(r,"Stone")
	for b: AABB in _carve(wall,holes): _shape(solid,b)
	_courses(m,wall,holes,hh*0.8,rng,0.2)
	# Carved lintels over the door and the slot, a sill under the slot.
	for b: AABB in [door_box,slot_cuts[0]]:
		m.box(Transform3D(Basis.IDENTITY,Vector3(0.0,b.end.y+0.2,hz+0.08)),Vector3(b.size.x+0.8,0.4,0.3),0.06,b.end.y,1.3)
	m.box(Transform3D(Basis.IDENTITY,Vector3(0.0,slot_cuts[0].position.y-0.12,hz+0.12)),Vector3(slot.x+0.5,0.24,0.36),0.05,slot_cuts[0].position.y-0.3,1.15)
	# Ledges, leaf to leaf (walker-only), the chimney's floor and the
	# balcony past the window.
	var walk := _body(r,"Ledges",true)
	var fl := _ab(Vector3(-run*0.5,0.0,-chimney*0.5),Vector3(run*0.5,floor_y,hz))
	_shape(walk,fl)
	m.box(Transform3D(Basis.IDENTITY,fl.get_center()),fl.size,0.03,0.0,0.7)
	var ledges: Array[AABB] = []
	for i in range(1,levels+1):
		var y := floor_y+rise*float(i)
		var s := -1.0 if i % 2 == 1 else 1.0
		var z0 := s*chimney*0.5
		var l := _ab(Vector3(-run*0.5,y-0.28,minf(z0,z0-s*ledge)),Vector3(run*0.5,y,maxf(z0,z0-s*ledge)))
		# The top one, on the far leaf, runs on out through the window.
		if i == levels: l = _ab(l.position,Vector3(l.end.x,l.end.y,l.end.z))
		ledges.append(l)
		_shape(walk,l)
		m.box(Transform3D(Basis.IDENTITY,l.get_center()),l.size,0.05,y-0.28,1.05)
	var sill := _ab(Vector3(-door.x*0.5,exit_y-0.28,zb),Vector3(door.x*0.5,exit_y,-chimney*0.5))
	var balcony := _ab(Vector3(-door.x*0.9,exit_y-0.3,zb-ledge*1.6),Vector3(door.x*0.9,exit_y,zb))
	for b: AABB in [sill,balcony]:
		_shape(walk,b)
		m.box(Transform3D(Basis.IDENTITY,b.get_center()),b.size,0.05,b.position.y,1.1)
	r.add_child(_mesh_of(m,"Stone"))
	r.set_meta("tris",m.triangles())
	_cover(r,fl,seed_value,true)
	_cover(r,wall,seed_value)
	_cover(r,balcony,seed_value)
	r.hide_boxes = [inner]
	r.mouths = [{"at":Vector3(0.0,floor_y,hz),"out":Vector3(0,0,1)},{"at":Vector3(0.0,exit_y,zb),"out":Vector3(0,0,-1)}]
	r.set_meta("kind",r.kind)
	r.set_meta("bounds",wall.grow(ledge*1.6+0.6))
	r.set_meta("mouths",r.mouths)
	r.set_meta("his_ground",_ab(Vector3(-length*0.5,0.0,hz+0.3),Vector3(length*0.5,0.0,hz+float(o.width)*2.0)))
	r.set_meta("slot",slot_box)
	r.set_meta("sizes",{"thick":thick,"chimney":chimney,"leaf":leaf,"leaf_his":leaf_his,"zb":zb,"hz":hz,"tall":tall,"length":length,"run":run,"ledge":ledge,
		"door":door,"slot":[slot.x,slot.y,slot_mid,slope],"exit_y":exit_y,"levels":levels})
	return r

# --- Building ---------------------------------------------------------------------------------

static func _ab(a: Vector3, b: Vector3) -> AABB:
	return AABB(a,b-a).abs()

## A static body under `r` (solid layer 1, or walker-only).
static func _body(r: Node3D, body_name: String, walker_only := false) -> StaticBody3D:
	var b := StaticBody3D.new()
	b.name = body_name
	if walker_only: WalkerOnly.mark(b)
	r.add_child(b)
	return b

static func _shape(body: StaticBody3D, box: AABB) -> void:
	if box.size.x < 0.01 or box.size.y < 0.01 or box.size.z < 0.01: return
	var c := CollisionShape3D.new()
	var s := BoxShape3D.new()
	s.size = box.size
	c.shape = s
	c.position = box.get_center()
	body.add_child(c)

## `box` less every hole in `holes`, as boxes.
static func _carve(box: AABB, holes: Array) -> Array[AABB]:
	var out: Array[AABB] = [box]
	for hole: AABB in holes:
		var next: Array[AABB] = []
		for b in out: next.append_array(_cut(b,hole))
		out = next
	return out

## `b` less `h`: up to six boxes round it.
static func _cut(b: AABB, h: AABB) -> Array[AABB]:
	var i := b.intersection(h)
	if i.size.x < 0.001 or i.size.y < 0.001 or i.size.z < 0.001: return [b]
	var out: Array[AABB] = []
	var lo := b.position
	var hi := b.end
	if i.position.x > lo.x+0.001: out.append(_ab(lo,Vector3(i.position.x,hi.y,hi.z)))
	if i.end.x < hi.x-0.001: out.append(_ab(Vector3(i.end.x,lo.y,lo.z),hi))
	var x0 := i.position.x
	var x1 := i.end.x
	if i.position.y > lo.y+0.001: out.append(_ab(Vector3(x0,lo.y,lo.z),Vector3(x1,i.position.y,hi.z)))
	if i.end.y < hi.y-0.001: out.append(_ab(Vector3(x0,i.end.y,lo.z),Vector3(x1,hi.y,hi.z)))
	var y0 := i.position.y
	var y1 := i.end.y
	if i.position.z > lo.z+0.001: out.append(_ab(Vector3(x0,y0,lo.z),Vector3(x1,y1,i.position.z)))
	if i.end.z < hi.z-0.001: out.append(_ab(Vector3(x0,y0,i.end.z),Vector3(x1,y1,hi.z)))
	return out

## Colossal coursing over `box` less `holes`: courses about `course` m tall,
## blocks along its long side, staggered, each chamfered and toned a little
## apart (an unweathered cut face here and there).
static func _courses(m: RefCounted, box: AABB, holes: Array, course: float, rng: RandomNumberGenerator, bevel: float) -> void:
	var y := box.position.y
	var row := 0
	while y < box.end.y-0.05:
		var h := minf(course*rng.randf_range(0.6,1.25),box.end.y-y)
		if box.end.y-(y+h) < course*0.35: h = box.end.y-y
		var c := _ab(Vector3(box.position.x,y,box.position.z),Vector3(box.end.x,y+h,box.end.z))
		_blocks(m,c,holes,rng,course*2.3,bevel,1.0,row)
		y += h
		row += 1

## One course `c` cut into blocks along its longer side (about `along` m
## each), less `holes`.
static func _blocks(m: RefCounted, c: AABB, holes: Array, rng: RandomNumberGenerator, along: float, bevel: float, tone := 1.0, row := 0) -> void:
	var on_x := c.size.x >= c.size.z
	var n := c.size.x if on_x else c.size.z
	var at := 0.0
	var first := along*(0.5 if row % 2 == 1 else 1.0)*rng.randf_range(0.7,1.2)
	while at < n-0.05:
		var l := minf(first if at == 0.0 else along*rng.randf_range(0.7,1.3),n-at)
		if n-(at+l) < along*0.3: l = n-at
		var b := AABB(c.position+(Vector3(at,0,0) if on_x else Vector3(0,0,at)),Vector3(l,c.size.y,c.size.z) if on_x else Vector3(c.size.x,c.size.y,l))
		var t := tone*rng.randf_range(0.88,1.08)
		if rng.randf() < 0.06: t *= 1.18
		for piece: AABB in _carve(b,holes):
			if piece.size.x < 0.02 or piece.size.y < 0.02 or piece.size.z < 0.02: continue
			m.box(Transform3D(Basis.IDENTITY,piece.get_center()),piece.size,minf(bevel,piece.size[piece.get_shortest_axis_index()]*0.3),c.position.y,t)
		at += l

## The underground's ground cover (scripts/underground/ground_cover.gd) on a
## flat walk top: `box` (local AABB) at its top; `inside` (a dark run or
## hall): a thin skin of dust, no tufts or shoots. Nothing with the look off.
static func _cover(r: Node3D, box: AABB, seed_value: int, inside := false) -> void:
	var area := Rect2(box.position.x,box.position.z,box.size.x,box.size.z)
	GroundCover.cover(r,area,"dust" if inside else "",box.end.y,seed_value,
		{"tufts":0.0,"under":0.0,"amount":0.6,"fade":0.25} if inside else {"fade":0.6})

static func _mesh_of(m: RefCounted, mesh_name: String) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = mesh_name
	mi.mesh = m.mesh(stone_material(),null)
	return mi

## Dust instead of moss on what faces up (the underground has no rain), and
## the stone's lichen turned to dust and soot: the Olmec's shader
## (shaders/olmec_stone.gdshader), its own material.
const DUST := Color(0.42,0.38,0.33)
const DUST_LIGHT := Color(0.55,0.5,0.43)
const DUST_MOST := 0.38
## The tone left inside a refuge (its `dark` boxes).
const LAMPBLACK := 0.32

static func stone_material() -> ShaderMaterial:
	return CityStone.wear("refuge")

## The giant's mesher (scripts/kit_isle/greybox/giant_stone.gd) with dust
## for moss.
class CityMesher extends GiantStone.Mesher:
	## Inside these boxes (the piece's frame) the stone is lampblack: the
	## shader's fill isn't occluded, so a hall reads dark only by its tone.
	var dark: Array = []
	func _dress(p: Vector3, normal: Vector3) -> Array:
		var c := GiantStone.Style.shade(stone,_centre,p,normal,1.0)
		for d: AABB in dark:
			if d.grow(0.05).has_point(p):
				c *= LAMPBLACK
				break
		var occ := lerpf(GiantStone.FOOT_OCC,1.0,smoothstep(_foot,_foot+GiantStone.FOOT_RISE,p.y))
		if normal.y < -0.3: occ *= 0.8
		c = c*lerpf(GiantStone.AO_FLOOR,1.0,occ)*_tone
		var up := smoothstep(0.6,0.95,normal.y)
		if up > 0.0:
			var patch := clampf(_noise.get_noise_3dv(p*0.6)*0.9+0.5,0.0,1.0)
			var dust := DUST.srgb_to_linear().lerp(DUST_LIGHT.srgb_to_linear(),clampf(_noise.get_noise_3dv(p*2.0)+0.5,0.0,1.0))
			c = c.lerp(dust*_tone,up*patch*DUST_MOST)
		c.a = occ
		var rest := p*GiantStone.GRAIN
		return [c,Vector2(rest.x,rest.y),Vector2(rest.z,0.0)]

static var _lamp_mesh: Mesh = null
static var _flame_mesh: Mesh = null
static var _clay_mat: StandardMaterial3D = null
static var _flame_mat: StandardMaterial3D = null

## A clay lamp at `at` (local) on a face looking `out`: the bowl and its
## flame (shared meshes), a drawn light if `light`, a SightLight if `sight`
## (he is lit by it for the Olmec). Returns the lamp node.
static func _lamp(r: Refuge, at: Vector3, out: Vector3, light: bool, sight: bool) -> Node3D:
	if _lamp_mesh == null:
		var bowl := CylinderMesh.new()
		bowl.top_radius = 0.1
		bowl.bottom_radius = 0.06
		bowl.height = 0.09
		bowl.radial_segments = 8
		bowl.rings = 1
		_lamp_mesh = bowl
		var f := SphereMesh.new()
		f.radius = 0.045
		f.height = 0.16
		f.radial_segments = 6
		f.rings = 3
		_flame_mesh = f
		_clay_mat = StandardMaterial3D.new()
		_clay_mat.albedo_color = CLAY
		_clay_mat.roughness = 0.9
		_flame_mat = StandardMaterial3D.new()
		_flame_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_flame_mat.albedo_color = Color(1.0,0.82,0.5)
		_flame_mat.emission_enabled = true
		_flame_mat.emission = FLAME
		_flame_mat.emission_energy_multiplier = 5.0
	var lamp := Node3D.new()
	lamp.name = "Lamp"
	lamp.position = at+out*0.12
	r.add_child(lamp)
	var bowl_mi := MeshInstance3D.new()
	bowl_mi.mesh = _lamp_mesh
	bowl_mi.material_override = _clay_mat
	bowl_mi.position = Vector3(0.0,0.045,0.0)
	bowl_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	lamp.add_child(bowl_mi)
	# The real flame (scripts/flame.gd), near; past LAMP_FAR the old glowing
	# bead stands in for it (a lamp's flame is 5 cm across: no volume reads
	# from there, and a far lamp is one pixel).
	var real: Node3D = Flame.new()
	real.set("kind","candle")
	real.set("scale_by",LAMP_FLAME)
	real.set("with_light",false)
	real.set("vis_end",LAMP_FAR)
	real.name = "Flame"
	real.position = Vector3(0.0,0.08,0.0)
	lamp.add_child(real)
	var bead := MeshInstance3D.new()
	bead.name = "FarFlame"
	bead.mesh = _flame_mesh
	bead.material_override = _flame_mat
	bead.position = Vector3(0.0,0.15,0.0)
	bead.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	bead.visibility_range_begin = LAMP_FAR
	bead.visibility_range_begin_margin = LAMP_FAR*0.1
	lamp.add_child(bead)
	if light:
		var l := OmniLight3D.new()
		l.light_color = FLAME
		l.light_energy = LAMP_ENERGY
		l.omni_range = LAMP_RANGE
		l.omni_attenuation = 1.6
		l.shadow_enabled = false
		l.light_specular = 0.3
		l.distance_fade_enabled = true
		l.distance_fade_begin = 45.0
		l.distance_fade_length = 15.0
		l.position = Vector3(0.0,0.25,0.0)+out*0.15
		lamp.add_child(l)
	if sight:
		var s := SightLight.new()
		s.strength = LAMP_SIGHT
		s.radius = LAMP_SIGHT_R
		s.position = Vector3(0.0,0.2,0.0)
		lamp.add_child(s)
	r.lamps.append(lamp)
	return lamp

# --- At play -----------------------------------------------------------------------------------

## The hush hall's darkness for the Olmec's sight: inside its boxes, it
## takes the light down by the look's ambient over the torch preset's (no
## change by day, or where the look is already that dark).
class Shade extends SightLight:
	var boxes: Array = []
	func light_at(p: Vector3) -> float:
		if not lit: return 0.0
		var local := (get_parent() as Node3D).to_local(p)
		for b: AABB in boxes:
			if b.grow(0.2).has_point(local):
				return -maxf(LightLevel.ambient-float(LightLevel.LOOK_AMBIENT.torch),0.0)
		return 0.0

## A refuge piece at play: whether he is in it, its trough, lamps, shade
## and echoes; tells the RefugeCue each frame.
class Refuge extends Node3D:
	var kind := ""
	var hide_boxes: Array = []
	var shade_boxes: Array = []
	var mouths: Array = []
	var trough := AABB()
	var relights: Array = []
	var lamps: Array = []
	var echo_steps := false
	var echo_splash := false
	var echoes: Array = []
	var glow: Beacon = null
	var glow_count := 0
	## He is in it now; counts for checks.
	var inside := false
	var snuffs := 0
	var relit := 0
	var echo_count := 0
	var _still := 0.0
	var _splash_t := 0.0
	var _was_in_trough := false

	## A silent Beacon `off` m out of each mouth (unlit till he makes a sound).
	func _add_echoes(off: float) -> void:
		for mo: Dictionary in mouths:
			var b := Beacon.new()
			b.name = "Echo"
			b.strength = 0.0
			b.radius = 0.5
			b.draw = ECHO_DRAW
			b.gather = 3.0
			b.dwell = 8.0
			var out: Vector3 = mo.out
			b.position = Vector3(mo.at)+out*off+Vector3.UP*1.0
			b.lit = false
			add_child(b)
			echoes.append(b)

	## A Beacon at `at` (local) that is lit while his torch burns inside the
	## shade boxes; an Olmec drawn to it comes to `stand` (relative to it).
	func _add_glow(at: Vector3, stand: Vector3) -> void:
		var b := Beacon.new()
		b.name = "TorchGlow"
		b.strength = 0.0
		b.radius = 0.5
		b.draw = ECHO_DRAW
		b.gather = 0.5
		b.dwell = GLOW_DWELL
		b.position = at
		b.stand = stand
		b.lit = false
		add_child(b)
		glow = b

	func _add_shade() -> void:
		var s := Shade.new()
		s.name = "Shade"
		s.boxes = shade_boxes
		s.strength = 0.0
		s.radius = 0.0
		add_child(s)

	func _process(delta: float) -> void:
		var scene := get_tree().current_scene
		if scene == null: return
		var motor: Variant = scene.get("motor")
		if motor == null: return
		var feet: Vector3 = to_local(motor.feet)
		var chest := feet+Vector3.UP*0.5
		inside = false
		for b: AABB in hide_boxes:
			if b.grow(0.05).has_point(chest):
				inside = true
				break
		RefugeCue.of(scene).report(self,inside)
		_trough(scene,feet)
		_relight(scene,feet)
		_echo(delta,motor)
		_glow(feet)

	## The torch node of the underground look, or null.
	func _torch() -> Node3D:
		var u := LightLevel.look(get_tree())
		if u == null: return null
		return u.get("torch")

	func _trough(scene: Node, feet: Vector3) -> void:
		if trough.size == Vector3.ZERO: return
		var t := trough.grow(0.02)
		var wet := feet.x > t.position.x and feet.x < t.end.x and feet.z > t.position.z and feet.z < t.end.z and feet.y < trough.end.y-0.12
		if wet and not _was_in_trough:
			_splash_t = SPLASH_FOR
			var torch := _torch()
			if torch != null and torch.visible:
				torch.visible = false
				snuffs += 1
				_steam(torch.global_position+Vector3.UP*0.5)
				_tell(scene,"Hsss: your torch is out. In the dark he can't make you out")
		_was_in_trough = wet

	func _relight(scene: Node, feet: Vector3) -> void:
		var torch := _torch()
		if torch == null or torch.visible: return
		for p: Vector3 in relights:
			if Vector2(p.x-feet.x,p.z-feet.z).length() < RELIGHT_REACH and absf(p.y-feet.y) < 2.2:
				torch.visible = true
				relit += 1
				_tell(scene,"Your torch takes the lamp's flame: lit again")
				return

	## The echo: in the run, moving, his steps carry out of the nearer mouth;
	## a splash in the trough carries SPLASH_FOR s.
	func _echo(delta: float, motor: Variant) -> void:
		if echoes.is_empty(): return
		var sound := false
		if echo_steps and inside:
			var v: Vector3 = motor.velocity
			if Vector2(v.x,v.z).length() > 0.6: _still = 0.0
			else: _still += delta
			sound = _still < ECHO_HOLD
		if echo_splash and _splash_t > 0.0:
			_splash_t -= delta
			sound = true
		var near := -1
		if sound:
			var best := INF
			var feet: Vector3 = to_local(motor.feet)
			for i in mouths.size():
				var d := feet.distance_to(Vector3(mouths[i].at))
				if d < best:
					best = d
					near = i
			# The splash carries out of the front mouth (the hall's mouth).
			if echo_splash and not echo_steps: near = 0
		for i in echoes.size():
			var b: Beacon = echoes[i]
			var want := i == near
			if want and not b.lit: echo_count += 1
			if b.lit != want: b.lit = want

	## The torch's glow at the mouth: lit while it burns in the hall.
	func _glow(feet: Vector3) -> void:
		if glow == null: return
		var on := false
		var torch := _torch()
		if torch != null and torch.visible:
			for b: AABB in shade_boxes:
				if b.has_point(feet+Vector3.UP*0.5): on = true
		if on and not glow.lit: glow_count += 1
		if glow.lit != on: glow.lit = on

	func _tell(scene: Node, text: String) -> void:
		if scene.has_method("_say"): scene.call("_say",text,3.0)
		elif scene.has_method("_show_toast"): scene.call("_show_toast",text)

	func _steam(at: Vector3) -> void:
		var p := CPUParticles3D.new()
		p.one_shot = true
		p.amount = 40
		p.lifetime = 1.6
		p.explosiveness = 0.85
		p.direction = Vector3.UP
		p.spread = 35.0
		p.initial_velocity_min = 0.4
		p.initial_velocity_max = 1.0
		p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
		p.emission_sphere_radius = 0.12
		p.gravity = Vector3(0.0,0.6,0.0)
		p.scale_amount_min = 0.5
		p.scale_amount_max = 1.2
		var q := SphereMesh.new()
		q.radius = 0.035
		q.height = 0.07
		q.radial_segments = 6
		q.rings = 3
		p.mesh = q
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.8,0.8,0.82,0.16)
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		p.material_override = mat
		var curve := Curve.new()
		curve.add_point(Vector2(0.0,0.4))
		curve.add_point(Vector2(1.0,1.6))
		p.scale_amount_curve = curve
		get_tree().current_scene.add_child(p)
		p.global_position = at
		p.emitting = true
		p.finished.connect(p.queue_free)

## How hiding reads: a dark vignette closing in and "hidden" while he is in a
## refuge and no Olmec sees him; a warm one and "he sees you" while one does.
## One per scene (`of`).
class RefugeCue extends CanvasLayer:
	var _rect: TextureRect
	var _label: Label
	var _in := {}
	var _amount := 0.0
	var _seen := 0.0
	## True this frame: he is in a refuge and unseen.
	var hidden := false

	static func of(scene: Node) -> RefugeCue:
		var c: Node = scene.get_node_or_null("RefugeCue")
		if c != null: return c as RefugeCue
		var cue := RefugeCue.new()
		cue.name = "RefugeCue"
		cue.layer = 4
		scene.add_child(cue)
		return cue

	func _ready() -> void:
		_rect = TextureRect.new()
		var g := Gradient.new()
		g.set_color(0,Color(1,1,1,0.0))
		g.set_color(1,Color(1,1,1,1.0))
		g.add_point(0.38,Color(1,1,1,0.0))
		g.add_point(0.75,Color(1,1,1,0.55))
		var t := GradientTexture2D.new()
		t.gradient = g
		t.fill = GradientTexture2D.FILL_RADIAL
		t.fill_from = Vector2(0.5,0.5)
		t.fill_to = Vector2(1.05,0.5)
		t.width = 256
		t.height = 256
		_rect.texture = t
		_rect.stretch_mode = TextureRect.STRETCH_SCALE
		_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
		_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_rect)
		_label = Label.new()
		_label.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
		_label.position = Vector2(-160.0,-120.0)
		_label.size = Vector2(320.0,48.0)
		_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_label.add_theme_font_size_override("font_size",30)
		_label.add_theme_color_override("font_outline_color",Color(0,0,0,0.8))
		_label.add_theme_constant_override("outline_size",6)
		_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_label)

	func report(r: Node, inside: bool) -> void:
		_in[r.get_instance_id()] = inside

	func _process(delta: float) -> void:
		var any := false
		for v: bool in _in.values(): any = any or v
		var seen := _seen_now()
		hidden = any and not seen
		_amount = move_toward(_amount,1.0 if any else 0.0,delta*2.5)
		_seen = move_toward(_seen,1.0 if seen else 0.0,delta*4.0)
		var dark := Color(0.02,0.03,0.06)
		var warm := Color(0.55,0.12,0.04)
		var c := dark.lerp(warm,_seen)
		c.a = _amount*(0.85+0.12*_seen*sin(Time.get_ticks_msec()*0.012))
		_rect.modulate = c
		_rect.visible = _amount > 0.01
		_label.visible = _amount > 0.3
		_label.text = "he sees you" if _seen > 0.5 else "hidden"
		_label.add_theme_color_override("font_color",Color(1.0,0.6,0.4,_amount) if _seen > 0.5 else Color(0.75,0.82,0.95,_amount*0.85))

	## Whether any Olmec's sight is on him now.
	func _seen_now() -> bool:
		var scene := get_tree().current_scene
		if scene == null: return false
		var field: Variant = scene.get("enemies")
		if field == null or not (field is Node): return false
		var list: Variant = (field as Node).get("enemies")
		if not (list is Array): return false
		for e: Variant in list:
			if not is_instance_valid(e): continue
			var s: Variant = (e as Object).get("sight")
			if s != null and (s as Object).has_method("seeing") and s.seeing(): return true
		return false
