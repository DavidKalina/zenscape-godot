extends "res://studies/character_study.gd"
## The city light yard, round 2:
## the sun-mirror and the relief face (scripts/city_kit_light2.gd) on a basalt
## plaza over the abyss, in the underground look (`--underground`, torch by
## default; `--underground=haze`), a whole Olmec hunting (the chase, the
## periscope, chase routes).
##   the sun-mirror      the plaza's middle, a light shaft falling on it from
##                       the dark. Climb its pedestal and stamp a treadle (hop
##                       on it): it turns a notch that way. Its beam lights
##                       the far cresset east (every Olmec near turns to it),
##                       wakes the sun plaque west (glyph steps slide out of
##                       the wall: a way up), lights you for his eyes.
##   the sweeping mirror south-east, fed by a burning cresset: its beam rakes
##                       the way north between the drums; cross it in their
##                       shadow
##   the relief face     north: a cliff carved as a seated lord. Jump-catch
##                       his carving up the nose side (knee, bag, armlet,
##                       pectoral, collar, lip plug, ear spool, the helmet's
##                       snout and knot) to the top; light the cresset there
##                       and watch the Olmec climb the face after it, his
##                       hands coming over the helmet's crown.
## Keys:
##   T   your torch out (hide in the dark) or lit again (also: touch a fire)
##   L   torch / haze      K   the pieces as built (fires out, mirrors back)
##   R   all back          B   the Olmec back       J   his sight   F1 numbers
##   godot --path . res://studies/city_light2_yard.tscn -- --no-title
##     [--underground=haze|torch] [--day] [--body-knob=<k>=<v>] [--head-knob=...]
##     [--body-at=x,z] [--body-face=x,z] [--no-body] [--sight-overlay]
const EnemyField = preload("res://scripts/enemies/enemy_field.gd")
const InhalerHead = preload("res://scripts/enemies/inhaler_head.gd")
const HeadlessBody = preload("res://scripts/enemies/headless_body.gd")
const BodySpawner = preload("res://scripts/enemies/body_spawner.gd")
const EnemyYard = preload("res://studies/enemy_yard.gd")
const SightOverlay = preload("res://scripts/enemies/body_sight_overlay.gd")
const Breakables = preload("res://scripts/kit_isle/breakables.gd")
const Underground = preload("res://scripts/underground/underground.gd")
const Fires = preload("res://scripts/city_kit_fires.gd")
const Light2 = preload("res://scripts/city_kit_light2.gd")
const CityStone = preload("res://scripts/city_kit_stone.gd")
const LaunchArgs = preload("res://scripts/launch_args.gd")

const YARD_LOST := -40.0
## The stone's hemisphere fill under each look.
const HEMI := {"torch":0.12,"haze":0.55}
## The plaza (x, z), its top 0, its slab's depth; the paving's slab.
const PLAZA := Rect2(-52.0,-42.0,104.0,96.0)
const PLAZA_DEEP := 8.0
const PAVE := 8.0
## The relief cliff on the plaza's north edge (its face), its width, depth.
const RELIEF_AT := Vector3(0.0,0.0,-42.0)
const RELIEF_W := 44.0
const RELIEF_DEEP := 26.0
## The cresset on the relief's top (light it and he climbs after it).
const TOP_CRESSET := Vector3(-4.0,0.0,-54.0)
## The sun-mirror (its bearing 0 throws south, toward the start), its shaft.
const MIRROR_AT := Vector3(-6.0,0.0,2.0)
## The far cresset east, on the mirror's bearing 90.
const FAR_CRESSET := Vector3(36.0,0.0,2.0)
## The west block: its rect (x, z), top; the sun plaque on its east face on
## the mirror's bearing -90; the glyph steps it hides, up that face north.
const WEST := Rect2(-52.0,-22.0,14.0,46.0)
const WEST_TOP := 9.6
const WEST_CRESSET := Vector3(-45.0,WEST_TOP,-12.0)
## The sweeping mirror and the cresset that feeds it; its sweep.
const SWEEP_AT := Vector3(22.0,0.0,24.0)
const SWEEP_FIRE := Vector3(28.0,0.0,31.0)
const SWEEP := [-100.0,-48.0,7.0,1.2]
## Cover drums on the way north (their shadows hide you from the sweep):
## [x, z, radius, top].
const DRUMS := [[-2.0,22.0,1.5,5.0],[6.0,15.0,1.3,3.6],[-9.0,30.0,1.7,7.0],[10.0,33.0,1.2,2.4]]
## Far pillars in the abyss, each with a lit tower: [x, top, z, radius].
const FAR := [[-96.0,28.0,-150.0,14.0],[84.0,46.0,-190.0,12.0],[150.0,10.0,-60.0,11.0]]
## Where he is posted and you start.
const BODY_AT := Vector3(-3.0,0.0,-17.0)
const PILOT_AT := Vector3(0.0,0.0,44.0)

var enemies: Node
var hub: Node3D
var overlay: Node3D
var under: Node3D
var pieces: Node3D
var relief: Node3D
var mirror: Node3D
var sweeper: Node3D
var shaft: Node3D
var plaque: Node3D
var far_cresset: Node3D
var top_cresset: Node3D
var west_cresset: Node3D
var sweep_fire: Node3D
var _environment: Environment
var _sun: DirectionalLight3D
var _voices := {}
var _body_knobs := {}
var _head_knobs := {}
var _body_at := BODY_AT
var _body_face := Vector2(0.5,1.0).normalized()
var _no_body := false
var _overlay_on := false

## Steps the enemies, hands each body the breakables hub, hides the figure
## while the head holds him.
class Slot extends Node:
	var field: Node
	var hub: Node
	func before(delta: float) -> void:
		for e in field.enemies:
			if is_instance_valid(e) and e.has_method("world_changed") and e.breaker == null: e.breaker = hub
		field.before(delta)
	func after(delta: float, events: Dictionary) -> void: field.after(delta,events)
	func pose(figure: Node3D) -> void:
		var held := false
		for e in field.enemies:
			if is_instance_valid(e) and e.get("swallowed"): held = true
		figure.visible = not held

func _ready() -> void:
	pack = "city_light2"
	var args := LaunchArgs.user_args()
	# The underground look by default (torch); --day leaves it off.
	var asked := false
	for a: String in args:
		if a == "--underground" or a.begins_with("--underground="): asked = true
	if not asked and not args.has("--day"):
		var with := PackedStringArray(args)
		with.append("--underground=torch")
		LaunchArgs.set_override(with)
	for arg: String in LaunchArgs.user_args():
		if arg == "--no-body": _no_body = true
		elif arg == "--sight-overlay": _overlay_on = true
		elif arg.begins_with("--body-face="):
			var f := arg.get_slice("=",1).split(",")
			_body_face = Vector2(float(f[0]),float(f[1]) if f.size() > 1 else 0.0).normalized()
		elif arg.begins_with("--body-at="):
			var p := arg.get_slice("=",1).split(",")
			_body_at = Vector3(float(p[0]),0.0,float(p[1]) if p.size() > 1 else 0.0)
		for pair in [["--body-knob=",_body_knobs],["--head-knob=",_head_knobs]]:
			if arg.begins_with(pair[0]):
				var kv: String = arg.trim_prefix(pair[0])
				pair[1][kv.get_slice("=",0)] = float(kv.get_slice("=",1))
	super._ready()

func _load_pack() -> void:
	start = PILOT_AT
	start_face = Vector2(0.0,-1.0)
	lost = YARD_LOST
	_last_stood = start
	var k := Light2.size()
	stations = [
		{"key":1,"name":"Start","spawn":PILOT_AT,"face":start_face,"parts":[]},
		{"key":2,"name":"The sun-mirror","spawn":MIRROR_AT+Vector3(0.0,0.0,4.5*k),"face":Vector2(0.0,-1.0),"parts":[]},
		{"key":3,"name":"The relief's foot","spawn":RELIEF_AT+Vector3(1.6*k,0.0,4.0*k),"face":Vector2(0.0,-1.0),"parts":[]},
		{"key":4,"name":"The relief's top","spawn":RELIEF_AT+Vector3(-4.0,17.6*k,-4.0),"face":Vector2(0.0,1.0),"parts":[]},
	]

func _build_light() -> void:
	super._build_light()
	for n: Node in get_children():
		if n is WorldEnvironment: _environment = (n as WorldEnvironment).environment
		elif n is DirectionalLight3D: _sun = n
	camera.far = 1200.0

func _build_room() -> void:
	super._build_room()
	for l: Node in find_children("*","Label3D",false,false): l.queue_free()
	_build_ground()
	pieces = Node3D.new()
	pieces.name = "Pieces"
	add_child(pieces)
	_build_pieces()
	enemies = EnemyField.new()
	enemies.study = self
	enemies.motor = motor
	enemies.lost = lost
	enemies.sound_hook = _voice
	add_child(enemies)
	hub = Breakables.new()
	hub.field = enemies
	hub.sound_hook = _voice
	add_child(hub)
	var slot := Slot.new()
	slot.field = enemies
	slot.hub = hub
	add_child(slot)
	foot_pieces = slot
	if not _no_body:
		var knobs := {"chase":1,"chase_routes":1,"periscope":1,"sight_walker_only":1}
		knobs.merge(_body_knobs,true)
		enemies.spawn(HeadlessBody,_body_at,_body_face,knobs)
		enemies.spawn(InhalerHead,_body_at,_body_face,_head_knobs.duplicate())
	overlay = SightOverlay.new()
	add_child(overlay)
	_wire()
	under = Underground.attach(self)
	print("city light2 yard: relief %d tris, %d holds (top %.1f m), mirror deck %.2f m, disc at %.2f m" % [relief.triangles,relief.holds.size(),relief.top*Light2.size(),mirror.deck_y,mirror.disc_centre().y])

## The plaza's paving, the west block, the drums, the far pillars: basalt,
## collided as plain boxes and drums.
func _build_ground() -> void:
	var m := CityStone.Mesher.new(CityStone.stone_colour(),0.2)
	var shapes: Array = []
	var rng := RandomNumberGenerator.new()
	rng.seed = 43
	var nx := int(PLAZA.size.x/PAVE)
	var nz := int(PLAZA.size.y/PAVE)
	for i in nx:
		for j in nz:
			var c := Vector3(PLAZA.position.x+PAVE*(i+0.5),-1.0-rng.randf_range(0.0,0.04),PLAZA.position.y+PAVE*(j+0.5))
			m.solid(CityStone.box(Transform3D(Basis.IDENTITY,c),Vector3(PAVE-0.08,2.0,PAVE-0.08)*0.5,0.06),-2.0,rng.randf_range(0.82,1.08))
	var under_c := Vector3(PLAZA.get_center().x,-2.0-PLAZA_DEEP*0.5,PLAZA.get_center().y)
	m.solid(CityStone.box(Transform3D(Basis.IDENTITY,under_c),Vector3(PLAZA.size.x-1.0,PLAZA_DEEP,PLAZA.size.y-1.0)*0.5,0.5),-2.0-PLAZA_DEEP,0.8)
	shapes.append(Fires.box_shape(Vector3(PLAZA.size.x,2.0+PLAZA_DEEP,PLAZA.size.y),Vector3(PLAZA.get_center().x,-(2.0+PLAZA_DEEP)*0.5,PLAZA.get_center().y)))
	# The west block (its east face carries the sun plaque and its hidden steps).
	var w := Vector3(WEST.get_center().x,WEST_TOP*0.5,WEST.get_center().y)
	m.solid(CityStone.box(Transform3D(Basis.IDENTITY,w),Vector3(WEST.size.x,WEST_TOP,WEST.size.y)*0.5,0.2),0.0)
	shapes.append(Fires.box_shape(Vector3(WEST.size.x,WEST_TOP,WEST.size.y),w))
	var course := Light2.set_off()*2.0
	var y := course
	while y < WEST_TOP-0.4:
		m.solid(CityStone.box(Transform3D(Basis.IDENTITY,Vector3(WEST.end.x+0.03,y,WEST.get_center().y)),Vector3(0.08,0.09,WEST.size.y*0.5-0.4),0.02),NAN,0.8)
		y += course
	for d: Array in DRUMS:
		var top := float(d[3])
		var at := Vector3(float(d[0]),0.0,float(d[1]))
		m.solid(CityStone.drum(Transform3D(Basis.IDENTITY,at),12,float(d[2]),float(d[2])*0.94,top,0.12),0.0,rng.randf_range(0.85,1.0))
		shapes.append(Fires.cyl_shape(float(d[2]),top,at+Vector3.UP*top*0.5))
	var mi := MeshInstance3D.new()
	mi.name = "Ground"
	mi.mesh = CityStone.mesh_of(m)
	add_child(mi)
	Fires.cover_ring(self,PLAZA,Rect2(),0.0,41,0.6)
	Fires.cover_ring(self,WEST.grow(-0.3),Rect2(),WEST_TOP,42,0.5)
	Fires.solid(self,shapes,false,"GroundSolid")
	# The far pillars (drawn only).
	var fm := CityStone.Mesher.new(CityStone.stone_colour(),0.1)
	for f: Array in FAR:
		var top := float(f[1])
		var r := float(f[3])
		var at := Vector3(float(f[0]),0.0,float(f[2]))
		fm.solid(CityStone.drum(Transform3D(Basis.IDENTITY,at+Vector3(0.0,top-400.0,0.0)),6,r,r,400.0,0.4),top-400.0,1.0)
		fm.solid(CityStone.drum(Transform3D(Basis(Vector3.UP,0.5),at+Vector3(0.0,top-6.0,0.0)),6,r*1.5,r*1.4,6.0,0.4),top-14.0,0.9)
	var far := MeshInstance3D.new()
	far.name = "FarPillars"
	far.mesh = CityStone.mesh_of(fm)
	far.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(far)

## The hidden glyph steps up the west block's east face, north from the
## plaque: [top middle in the plaque's space, size]. The plaque faces +x (its
## local +z), so its local x runs north-south: north is local +x.
static func glyph_steps() -> Array:
	var out: Array = []
	var rise := Light2.set_off()
	var deep := Fires.stand()*2.0
	var wide := 1.5
	var n := int(roundf(WEST_TOP/rise))
	for j in range(1,n+1):
		# Local x: along the wall (north is +x), local y: up from the plaque's
		# middle (at MIRROR disc height), local z: out of the wall.
		var top_y := rise*j-plaque_y()
		out.append([Vector3(1.6+wide*(j-1)+wide*0.5,top_y,deep*0.5),Vector3(wide,rise*j if j == 1 else rise*1.2,deep)])
	return out

## The plaque's middle over the plaza: the sun-mirror's disc height.
static func plaque_y() -> float:
	return Light2.set_off()+Light2.DISC_Y*Light2.size()

func _build_pieces() -> void:
	var k := Light2.size()
	relief = Light2.relief(pieces,Transform3D(Basis.IDENTITY,RELIEF_AT),{"width":RELIEF_W,"deep":RELIEF_DEEP,"seed":11,"name":"Relief"})
	top_cresset = Fires.cresset(pieces,Transform3D(Basis.IDENTITY,TOP_CRESSET+Vector3.UP*relief.top*k),{"size":"cresset","seed":13,"name":"ReliefCresset"})
	shaft = Light2.shaft(pieces,Transform3D(Basis.IDENTITY,MIRROR_AT),{"name":"Shaft"})
	mirror = Light2.mirror(pieces,Transform3D(Basis.IDENTITY,MIRROR_AT),{"mode":"turn","bearing":0.0,"seed":5,"name":"SunMirror"})
	far_cresset = Fires.cresset(pieces,Transform3D(Basis.IDENTITY,FAR_CRESSET),{"size":"cresset","seed":17,"name":"FarCresset"})
	# The plaque on the west block's east face (facing +x), at the disc's height.
	var face := Basis(Vector3.UP,PI*0.5)
	plaque = Light2.plaque(pieces,Transform3D(face,Vector3(WEST.end.x,plaque_y(),MIRROR_AT.z)),{"steps":_steps_south_to_north(),"name":"SunPlaque"})
	west_cresset = Fires.cresset(pieces,Transform3D(Basis.IDENTITY,WEST_CRESSET),{"size":"cresset","seed":19,"name":"WestCresset"})
	sweep_fire = Fires.cresset(pieces,Transform3D(Basis.IDENTITY,SWEEP_FIRE),{"size":"cresset","seed":23,"lit":true,"name":"SweepFire"})
	# Burning since before you came: old news, no Olmec heeds it.
	sweep_fire.beacon.draw = 1.0
	sweeper = Light2.mirror(pieces,Transform3D(Basis.IDENTITY,SWEEP_AT),{"mode":"sweep","sweep":SWEEP,"pitch":-5.5,"seed":7,"name":"SweepMirror"})
	for f: Array in FAR:
		var t := Fires.tower(pieces,Transform3D(Basis(Vector3.UP,float(f[0])*0.1),Vector3(float(f[0]),float(f[1]),float(f[2]))),
			{"tiers":3,"base":9.0,"steps":false,"lit":true,"seed":30+int(f[0]),"name":"FarTower","beam":3.0})
		t.crown.beacon.draw = 1.0
	for c: Node in [far_cresset,top_cresset,west_cresset]:
		c.lit_changed.connect(_lit.bind(c))
	mirror.turned.connect(func(b: float) -> void: _say("Clack. The mirror turns to %d°" % roundi(b),1.2))
	mirror.lit_target.connect(func(t: Node) -> void: _say("The beam lights the %s" % t.name.capitalize().to_lower(),2.5))
	plaque.woke.connect(func() -> void: _say("The sun wakes: glyph steps grind out of the wall",3.0))

## The glyph steps in the plaque's space: it faces +x, so its local +x
## runs world -z (north) and local +y up.
func _steps_south_to_north() -> Array:
	return glyph_steps()

func _lit(on: bool, c: Node3D) -> void:
	if on: _say("%s catches. Every Olmec near turns to it." % c.name.capitalize(),3.0)

## The pieces as built: fires out (the sweeper's fire burning), mirrors back,
## the plaque asleep.
func reset_pieces() -> void:
	for c: Node in [far_cresset,top_cresset,west_cresset]:
		if c.lit: c.douse()
	mirror.reset()
	sweeper.reset()
	plaque.reset()

func _wire() -> void:
	var b := stone_body()
	var h := stone_head()
	if b == null or h == null: return
	b.make_whole(h)
	b.breaker = hub
	if overlay != null:
		if overlay.body == null: overlay.setup_body(b)
		else: overlay.body = b
		overlay.visible = _overlay_on
		overlay._layer.visible = _overlay_on

## The whole Olmec (the body with its head on).
func stone_body() -> Node3D:
	if enemies == null: return null
	for e in enemies.enemies:
		if is_instance_valid(e) and e.has_method("make_whole"): return e
	return null

func stone_head() -> Node3D:
	if enemies == null: return null
	for e in enemies.enemies:
		if is_instance_valid(e) and e.has_method("mouth"): return e
	return null

func reset_all() -> void:
	reset_pieces()
	reset_body()
	Fires.set_torch(get_tree(),true)
	respawn()

func reset_body() -> void:
	if enemies == null: return
	enemies.reset()
	if figure != null: figure.visible = true
	_wire()

func tick(delta: float) -> void:
	super.tick(delta)
	if under != null:
		if _sun != null: _sun.visible = false
		_hemi()
	if camera == null: return
	var q := float(hub.quake)*0.7 if hub != null else 0.0
	var b := stone_body()
	if b != null: q = maxf(q,float(b.quake)*clampf(1.0-camera.global_position.distance_to(b.global_position)/60.0,0.0,1.0))
	if q > 0.001:
		var t := Time.get_ticks_msec()/1000.0
		camera.position += Vector3(sin(t*61.0),sin(t*53.0+1.0),sin(t*47.0+2.0))*q*0.5

## The stone's sky fill to the underground's: its ambient colour, dim.
func _hemi() -> void:
	var p: Dictionary = under.get("p")
	var amb: Color = p.get("ambient",Color(0.2,0.27,0.4))
	var e := float(HEMI.get(str(under.get("preset")),0.2))
	RenderingServer.global_shader_parameter_set("zs_hemi_sky",Vector3(amb.r,amb.g,amb.b))
	RenderingServer.global_shader_parameter_set("zs_hemi_ground",Vector3(amb.r,amb.g,amb.b)*0.25)
	RenderingServer.global_shader_parameter_set("zs_hemi_energy",e)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and not _name_panel.visible:
		match (event as InputEventKey).keycode:
			KEY_R:
				reset_all()
				return
			KEY_B:
				reset_body()
				_say("The Olmec is back at his post",2.0)
				return
			KEY_K:
				reset_pieces()
				_say("The pieces as built: fires out, mirrors back",2.0)
				return
			KEY_T:
				var on := not Fires.torch_lit(get_tree())
				Fires.set_torch(get_tree(),on)
				_say("Torch lit" if on else "Torch out: you are dark to him (touch a fire to light it again)",2.5)
				return
			KEY_J:
				_overlay_on = not _overlay_on
				_wire()
				return
			KEY_L:
				if under != null:
					under.cycle()
					return
	super._unhandled_input(event)

func _show_toast(text: String) -> void:
	_say(text,2.0)

# --- The HUD and the sounds -----------------------------------------------------------------

func _hint_text() -> String:
	return "City light 2: climb the sun-mirror's pedestal, hop on a treadle to turn it a notch · east: the far cresset · west: the sun plaque · the relief north: jump-catch his carving to the top, light its cresset · the sweeping beam shows you: cross in the drums' shadow · T torch · L look · K pieces · R all back · B Olmec back · J his sight · F1 numbers"

func _show_hud() -> void:
	super._show_hud()
	if not _hud.visible: return
	var lines := PackedStringArray([_hud.text,""])
	var b := stone_body()
	if b != null:
		var s: RefCounted = b.sight
		lines.append("olmec  %s %.1fs · %s · beacon %s (turns %d, visits %d) · sight %s %.2f" % [b.state,b.state_t,"hunting" if b.hunting else "calm",
			str(b.beacon.get_parent().name) if b.beacon != null else "-",b.beacon_turns,b.beacon_visits,str(s.state) if s != null else "-",float(s.awareness) if s != null else 0.0])
	var me: Vector3 = motor.feet+Vector3.UP
	lines.append("light on you %.2f (glow %.2f) · torch %s" % [LightLevel.exposure(get_tree(),me),LightLevel.glow(get_tree(),me),"lit" if Fires.torch_lit(get_tree()) else "out"])
	lines.append("mirror %d° %s (turns %d, lit %d) · sweeper %d° %s · far %s · plaque %s · top %s · west %s" % [roundi(mirror.bearing),"fed" if mirror.fed else "dark",mirror.turns,mirror.lightings,
		roundi(sweeper.bearing),"fed" if sweeper.fed else "dark",_state(far_cresset),"awake" if plaque.awake else "asleep",_state(top_cresset),_state(west_cresset)])
	_hud.text = "\n".join(lines)

func _state(c: Node3D) -> String:
	return "tipped" if c.broken else ("lit" if c.lit else "out")

func _voice(sound_name: StringName, at: Vector3) -> void:
	var key := String(sound_name)
	var spec: Variant = InhalerHead.VOICES.get(key,BodySpawner.VOICES.get(key))
	if spec == null: return
	if not _voices.has(key): _voices[key] = EnemyYard._synth(spec)
	var player := AudioStreamPlayer3D.new()
	player.stream = _voices[key]
	player.position = at
	player.unit_size = float(BodySpawner.REACH.get(key,30.0))
	add_child(player)
	player.finished.connect(player.queue_free)
	player.play()
