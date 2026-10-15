extends "res://studies/character_study.gd"
## The city kit's gallery (scripts/city_kit.gd, docs/design/roguelike/
## city-kit-round1.md): its four pieces laid out as a place in the
## underground (scripts/underground/underground.gd: the torch look, or
## `--underground=haze`), played with the real pilot.
##
##   C  the low pillar-isle (crown 14.4 m down, a KitLand turf crown on a
##      bare pillar): the arrival. The epic stair climbs from it, its first
##      landing a fault over a chamber.
##   the causeway from the stair's summit (y 0) four spans to A, its first
##      span's middle bay breakable over C's crown (the lower road).
##   A  the great pillar-isle (crown y 0), the drum stair wound down its well,
##      its climb face's prism chain up its collars.
##   far pillars at other heights in the haze, the layers in the distance.
##
## The Olmec (`--olmec=stair`, the default): his body at the stair's foot,
## his head on its summit: he walks up, the fault landing drops under him,
## he climbs out of the chamber and goes on. `--olmec=causeway`: his body on
## the summit, his head at the causeway's far end: he walks out, the bay
## drops under him onto C. `--olmec=none`: no Olmec. `--no-fault`,
## `--no-bay`: those whole; `--broken=fault,bay`: those down from the
## start. `--body-at=x,y,z`: his body there. `--body-knob=k=v`, `--head-knob=k=v`.
##   1-7  stations (1 the arrival on C, 2 the summit, 3 the causeway's far
##        end, 4 the drum's rim, 5 a turn of the drum, 6 A's collar chain,
##        7 the cheek crest's head)
##   R    back to the start, the Olmec back; what broke stays broken
##   ./run-city-kit.command [--underground=haze] [--olmec=causeway]
const CityKit = preload("res://scripts/city_kit.gd")
const CityStone = preload("res://scripts/city_kit_stone.gd")
const Breakables = preload("res://scripts/kit_isle/breakables.gd")
## The ruin sounds' placeholder voices (the destruction round's).
const RuinVoices = preload("res://scripts/kit_isle/colonnade_breaks.gd")
const Underground = preload("res://scripts/underground/underground.gd")
const EnemyField = preload("res://scripts/enemies/enemy_field.gd")
const InhalerHead = preload("res://scripts/enemies/inhaler_head.gd")
const HeadlessBody = preload("res://scripts/enemies/headless_body.gd")
const BodySpawner = preload("res://scripts/enemies/body_spawner.gd")
const EnemyYard = preload("res://studies/enemy_yard.gd")
const KitLand = preload("res://scripts/kit_isle/kit_land.gd")
const KitLook = preload("res://scripts/kit_isle/kit_look.gd")
const KitFlora = preload("res://scripts/kit_isle/kit_flora.gd")
## The walked tops grass grows on (CityKit `walk_areas` kinds), and how
## thick (tufts a square metre at a drift's thickest: sparse, underground).
const GRASS_ON := ["crown","landing","summit","turn","tier"]
const GRASS_TUFTS := 2.2

const SEED := 4207
const WEATHERED := 0.45
## C: the low pillar (its crown a course set down three), its middle, its
## apothem.
const C_TOP := -3.0*CityKit.COURSE
const C_AT := Vector3(0.0,C_TOP,-8.0)
const C_APOTHEM := 44.0
## The stair's foot on C.
const STAIR_AT := Vector3(0.0,C_TOP,24.0)
## A's crown face toward the causeway lies at the causeway's far end.
const A_APOTHEM := CityKit.DRUM_RADIUS+CityKit.LANDING
const CITY_LOST := -80.0
## C's turf: the earth and the moss on it.
const EARTH := Color(0.11,0.095,0.075)
const MOSS := Color(0.12,0.13,0.075)

var _environment: Environment
var under: Node3D
var pieces: Array = []
var stair: Node3D
var causeway: Node3D
var pillar_a: Node3D
var pillar_c: Node3D
var drum: Node3D
## The cheek crests' bodies (the rail), times on them, the top pace on one.
var rails: Array[RID] = []
var rail_count := 0
var rail_top := 0.0
var on_rail := false
var enemies: Node
var breaks: Node3D
var olmec := "stair"
var _fault := 1
var _bay := 0
var _body_at := Vector3.INF
var _broken := PackedStringArray()
var _body_knobs := {}
var _head_knobs := {}
var _voices := {}
var _built_ms := 0
var _was_hemi := []
var flora: Node3D
var _no_flora := false

## Counts the cheek crests as rails (the walker on one, his top pace there),
## steps the Olmec, hands him the breaks, and hides the figure while the
## head holds him.
class Slot extends Node:
	var study: Node3D
	var field: Node
	var breaks: Node3D
	var _ray := PhysicsRayQueryParameters3D.new()
	func before(delta: float) -> void:
		if field == null: return
		for e in field.enemies:
			if is_instance_valid(e) and e.has_method("world_changed") and e.breaker == null: e.breaker = breaks
		field.before(delta)
	func after(delta: float, events: Dictionary) -> void:
		var m: Variant = study.motor
		var on := false
		if m.grounded:
			_ray.from = m.feet+Vector3.UP*0.3
			_ray.to = m.feet+Vector3.DOWN*0.6
			var hit := study.get_world_3d().direct_space_state.intersect_ray(_ray)
			on = not hit.is_empty() and (hit.rid as RID) in study.rails
		if on != study.on_rail:
			events["rail"] = on
			if on:
				study.rail_count += 1
				study.rail_top = 0.0
			study.on_rail = on
		if on: study.rail_top = maxf(study.rail_top,float(m.speed()))
		if field != null: field.after(delta,events)
	func pose(figure: Node3D) -> void:
		if field == null: return
		var held := false
		for e in field.enemies:
			if is_instance_valid(e) and e.get("swallowed"): held = true
		figure.visible = not held

func _ready() -> void:
	pack = "city_kit_gallery"
	for arg in preload("res://scripts/launch_args.gd").user_args():
		if arg.begins_with("--olmec="): olmec = arg.get_slice("=",1)
		elif arg == "--no-fault": _fault = 0
		elif arg == "--no-bay": _bay = -1
		elif arg.begins_with("--body-at="):
			var v := arg.get_slice("=",1).split(",")
			_body_at = Vector3(float(v[0]),float(v[1]),float(v[2]))
		elif arg.begins_with("--broken="): _broken = arg.get_slice("=",1).split(",")
		elif arg == "--no-flora": _no_flora = true
		for pair in [["--body-knob=",_body_knobs],["--head-knob=",_head_knobs]]:
			if arg.begins_with(pair[0]):
				var kv: String = arg.trim_prefix(pair[0])
				pair[1][kv.get_slice("=",0)] = float(kv.get_slice("=",1))
	if not _no_flora: ready_to_walk.connect(_grow_flora,CONNECT_ONE_SHOT)
	super._ready()

## The game's grass (scripts/kit_isle/kit_flora.gd) over the pieces' walked
## tops (CityKit `walk_areas`), once they stand in the physics space: the
## city isn't bare stone. A stand-in till the underground ground cover
## (look/underground-ground) dresses the same areas.
func _grow_flora() -> void:
	var began := Time.get_ticks_msec()
	var outlines: Array = []
	var turf: Array = []
	for p: Node3D in pieces:
		var areas := CityKit.walk_areas(p,GRASS_ON)
		if areas.is_empty(): continue
		turf.append(p.get_node("Body"))
		for a: Dictionary in areas: outlines.append(a.poly)
	var site := KitFlora.Site.new()
	site.ray = Vector2(90.0,-60.0)
	site.tufts = GRASS_TUFTS
	flora = KitFlora.grow(SEED,get_world_3d().direct_space_state,turf,outlines,site)
	flora.name = "Flora"
	# Grass only: the meadow's flowers don't grow in the dark.
	for m: Node in flora.find_children("*","MultiMeshInstance3D",true,false):
		if not String(m.name).begins_with("grass"): m.queue_free()
	add_child(flora)
	print("city kit gallery: grass %s, %d instanced triangles, grown in %d ms" % [flora.get_meta("counts"),int(flora.get_meta("triangles")),Time.get_ticks_msec()-began])

## The places (world), from the pieces' sizes.
func stair_length() -> float:
	return CityKit.STAIR_FLIGHTS*CityKit.STAIR_STEPS*CityKit.TREAD+CityKit.STAIR_FLIGHTS*CityKit.LANDING

func summit_edge() -> Vector3:
	return STAIR_AT+Vector3(0.0,CityKit.STAIR_FLIGHTS*CityKit.COURSE,-stair_length())

func causeway_end() -> Vector3:
	return summit_edge()+Vector3(0.0,0.0,-CityKit.SPANS*CityKit.SPAN)

func a_centre() -> Vector3:
	return causeway_end()+Vector3(0.0,0.0,-A_APOTHEM)

func _load_pack() -> void:
	start = C_AT+Vector3(16.0,0.0,36.0)
	var at_stair := STAIR_AT+Vector3(0.0,0.0,-20.0)
	start_face = Vector2(at_stair.x-start.x,at_stair.z-start.z).normalized()
	lost = CITY_LOST
	_last_stood = start
	var sum := summit_edge()+Vector3(0.0,0.0,4.0)
	var far := causeway_end()+Vector3(0.0,0.0,6.0)
	var rim := a_centre()+CityKit.dir(0.0)*(CityKit.DRUM_RADIUS-CityKit.LANE*0.5)+Vector3(0.0,0.0,2.0)
	var turn_at: Array = CityKit.drum_at(0,PI)
	var turn := a_centre()+CityKit.dir(PI)*(float(turn_at[1])+1.0)+Vector3.UP*float(turn_at[0])
	var climb := a_centre()+_a_climb_foot()
	var crest := summit_edge()+Vector3(-(CityKit.LANE*0.5+CityKit.CHEEK*0.5),0.0,1.0)
	stations = [
		{"key":1,"name":"Arrival on C","spawn":start,"face":start_face,"parts":[]},
		{"key":2,"name":"The summit","spawn":sum,"face":Vector2(0.0,-1.0),"parts":[]},
		{"key":3,"name":"The causeway's far end","spawn":far,"face":Vector2(0.0,-1.0),"parts":[]},
		{"key":4,"name":"The drum's rim","spawn":rim,"face":Vector2(-1.0,0.0),"parts":[]},
		{"key":5,"name":"A turn of the drum","spawn":turn,"face":Vector2(-1.0,0.0),"parts":[]},
		{"key":6,"name":"A's collar chain","spawn":climb,"face":Vector2(-1.0,0.0),"parts":[]},
		{"key":7,"name":"The cheek crest","spawn":crest,"face":Vector2(0.0,1.0),"parts":[]},
	]

## A's climb face's foot (A-local): its lowest collar beside the chain.
func _a_climb_foot() -> Vector3:
	var d := CityKit.hex_dir(1)
	var t := Vector3(d.z,0.0,-d.x)
	var k := CityKit.COURSES
	var a_over := A_APOTHEM+(k-1)*CityKit.LEDGE
	var side := 1.0 if k%2 == 0 else -1.0
	var at := a_over*tan(PI/6.0)*0.3*side
	return d*(a_over+CityKit.LEDGE*0.6)+t*(at-side*3.0)+Vector3.UP*(-k*CityKit.COURSE)

func _build_light() -> void:
	_environment = Environment.new()
	_environment.background_mode = Environment.BG_COLOR
	_environment.background_color = Color(0.05,0.05,0.06)
	_environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	_environment.ssao_enabled = true
	var world := WorldEnvironment.new()
	world.environment = _environment
	add_child(world)
	camera = Camera3D.new()
	camera.fov = FOV
	camera.far = 900.0
	add_child(camera)
	camera.current = true

func _build_room() -> void:
	var began := Time.get_ticks_msec()
	CityStone.warm()
	var art := Node3D.new()
	art.name = "City"
	add_child(art)
	# C: the low pillar, its crown a flat paving (the stair stands on it).
	pillar_c = CityKit.pillar(SEED+1,WEATHERED,{"apothem":C_APOTHEM,"crown":"flat","climb":4,"courses":3,"depth":90.0})
	pillar_c.position = C_AT
	art.add_child(pillar_c)
	# The epic stair on C, its foot toward the arrival.
	stair = CityKit.stair(SEED+2,WEATHERED,{"fault":_fault})
	stair.position = STAIR_AT
	art.add_child(stair)
	# The causeway from the summit to A.
	causeway = CityKit.causeway(SEED+3,WEATHERED,{"bay":_bay,"drop":60.0})
	causeway.position = summit_edge()
	art.add_child(causeway)
	# A with its well, the drum stair in it.
	pillar_a = CityKit.pillar(SEED+4,WEATHERED,{"apothem":A_APOTHEM,"well":CityKit.DRUM_RADIUS,"climb":1})
	pillar_a.position = a_centre()
	art.add_child(pillar_a)
	drum = CityKit.drum_stair(SEED+5,WEATHERED,{"rim":false})
	drum.position = a_centre()
	art.add_child(drum)
	# The far pillars, the layers in the haze. The first bare, a KitLand
	# turf crown on it (how a motif makes a pillar its isle: CityKit
	# `crown_outline`).
	var far := [[Vector3(-120.0,18.0,-70.0),22.0,3],[Vector3(110.0,-34.0,-150.0),26.0,2],[Vector3(80.0,30.0,70.0),18.0,3],[Vector3(-150.0,-20.0,-220.0),30.0,2],[Vector3(-60.0,40.0,-300.0),20.0,3]]
	var k := 0
	for f: Array in far:
		var p := CityKit.pillar(SEED+20+k,WEATHERED,{"apothem":f[1],"courses":f[2],"climb":-1,"depth":120.0,"crown":"bare" if k == 0 else "paved"})
		p.position = f[0]
		art.add_child(p)
		pieces.append(p)
		if k == 0: p.add_child(_turf(float(f[1])))
		k += 1
	pieces.append_array([pillar_c,stair,causeway,pillar_a,drum])
	# The fire bowls (the only light): the stair's, the drum's, the
	# causeway's every other pier, A's.
	for piece: Node3D in [stair,causeway,drum,pillar_a]:
		var cressets: Array = (piece.get_meta("mounts") as Dictionary).cresset
		var n := 0
		for at: Vector3 in cressets:
			if piece == causeway and n%2 == 1:
				n += 1
				continue
			_cresset(piece.to_global(at),false)
			n += 1
	# The cheek crests count as rails.
	for r: Dictionary in stair.get_meta("rails"):
		rails.append((stair.get_node(String(r.body)) as CollisionObject3D).get_rid())
	var slot := Slot.new()
	slot.study = self
	add_child(slot)
	foot_pieces = slot
	# The breaks, and the Olmec.
	# The breakables hub (scripts/kit_isle/breakables.gd): his breaker; the
	# stair's fault and the causeway's bay are its pieces (their units,
	# scripts/city_breaks/floor_break.gd, in its group).
	breaks = Breakables.new()
	art.add_child(breaks)
	breaks.sound_hook = _voice
	# Broken from the start (--broken=fault,bay): as if he had been.
	for u: Node in floors():
		if String(u.kind) in _broken: u.break_now(breaks,(u as Node3D).global_position,Vector3.ZERO)
	if olmec != "none": _build_olmec(slot)
	# The look: the underground's (torch, or --underground=haze).
	under = (Underground as GDScript).new()
	under.name = "Underground"
	add_child(under)
	under.setup(self)
	_dress_hemi()
	_built_ms = Time.get_ticks_msec()-began
	print("city kit gallery: built %d ms, %d triangles" % [_built_ms,_triangles()])

## A KitLand turf crown for a bare pillar of apothem `a`: dry umber earth
## and a dull moss in patches.
func _turf(a: float) -> Node3D:
	var patches := FastNoiseLite.new()
	patches.seed = SEED
	patches.frequency = 0.06
	var tone := func(mid: Vector2, _normal: Vector3, shimmer: float, _y: float) -> Color:
		var k := clampf(patches.get_noise_2dv(mid)*0.9+0.45,0.0,1.0)
		return EARTH.lerp(MOSS,k)*(0.92+0.16*shimmer)
	var land := KitLand.island({"outline":CityKit.crown_outline(a),"seed":SEED,"ground":func(_x: float, _z: float) -> float: return 0.0,
		"top":0.0,"depth":CityKit.COURSE*0.6,"hang":true,"resample":[60.0,96,40],"tone":tone,"cell":2.5})
	land.name = "Turf"
	return land

## The breaking floors (the fault, the bay).
func floors() -> Array:
	var out: Array = []
	for p: Node3D in [stair,causeway]:
		for d: Dictionary in p.get_meta("breaks",[]):
			out.append(p.get_node(String(d.unit)))
	return out

## How many floors of `kind` are down ("" any).
func down(kind := "") -> int:
	var n := 0
	for u: Node in floors():
		if not u.alive and (kind == "" or String(u.kind) == kind): n += 1
	return n

func _triangles() -> int:
	var n := 0
	for p: Node3D in pieces: n += int(p.get_meta("triangles",0))
	return n

## The stone's fill (its hemisphere emission) in the look's own air, not
## the sky's blue; set back as it was when the gallery goes.
func _dress_hemi() -> void:
	if _was_hemi.is_empty():
		for k: String in ["zs_hemi_sky","zs_hemi_ground","zs_hemi_energy"]:
			var g: Variant = ProjectSettings.get_setting("shader_globals/"+k)
			_was_hemi.append((g as Dictionary).get("value") if g is Dictionary else null)
	var amb: Color = under.p.ambient
	RenderingServer.global_shader_parameter_set("zs_hemi_sky",Vector3(amb.r,amb.g,amb.b))
	var low: Color = under.p.warm
	RenderingServer.global_shader_parameter_set("zs_hemi_ground",Vector3(low.r,low.g,low.b))
	RenderingServer.global_shader_parameter_set("zs_hemi_energy",0.55 if under.preset == "haze" else 0.35)

func _exit_tree() -> void:
	if _was_hemi.size() == 3 and _was_hemi[0] != null:
		RenderingServer.global_shader_parameter_set("zs_hemi_sky",_was_hemi[0])
		RenderingServer.global_shader_parameter_set("zs_hemi_ground",_was_hemi[1])
		RenderingServer.global_shader_parameter_set("zs_hemi_energy",_was_hemi[2])

## A fire bowl at `at` (world): a stone bowl, a flame, a warm light (a
## shadow only where `shadow`).
func _cresset(at: Vector3, shadow: bool) -> void:
	var node := Node3D.new()
	node.name = "Cresset"
	node.position = at
	add_child(node)
	var bowl := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.55
	cyl.bottom_radius = 0.3
	cyl.height = 0.5
	cyl.radial_segments = 10
	bowl.mesh = cyl
	bowl.material_override = CityStone._stone
	bowl.position = Vector3.UP*0.25
	node.add_child(bowl)
	var flame := MeshInstance3D.new()
	var sph := SphereMesh.new()
	sph.radius = 0.18
	sph.height = 0.6
	flame.mesh = sph
	var fm := StandardMaterial3D.new()
	fm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fm.albedo_color = Color(1.0,0.7,0.35)
	fm.emission_enabled = true
	fm.emission = Underground.FLAME
	fm.emission_energy_multiplier = 5.0
	flame.material_override = fm
	flame.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	flame.position = Vector3.UP*0.68
	node.add_child(flame)
	var light := OmniLight3D.new()
	light.light_color = Underground.FLAME
	light.light_energy = 3.0
	light.omni_range = 18.0
	light.omni_attenuation = 1.2
	light.shadow_enabled = shadow
	light.position = Vector3.UP*1.4
	node.add_child(light)

func _build_olmec(slot: Slot) -> void:
	enemies = EnemyField.new()
	enemies.study = self
	enemies.motor = motor
	enemies.lost = lost
	enemies.sound_hook = _voice
	add_child(enemies)
	breaks.field = enemies
	slot.field = enemies
	slot.breaks = breaks
	var body_at: Vector3
	var head_at: Vector3
	if olmec == "causeway":
		body_at = summit_edge()+Vector3(0.0,0.0,6.0)
		head_at = causeway_end()+Vector3(0.0,0.0,8.0)
	else:
		body_at = STAIR_AT+Vector3(0.0,0.0,CityKit.HEAD_LENGTH+5.0)
		head_at = summit_edge()+Vector3(0.0,0.0,CityKit.LANDING*0.5)
	var face := Vector2(head_at.x-body_at.x,head_at.z-body_at.z).normalized()
	var knobs := {"hear":400.0,"listen":1.2,"listen_every":12.0}
	knobs.merge(_body_knobs,true)
	if _body_at != Vector3.INF: body_at = _body_at
	enemies.spawn(HeadlessBody,body_at,face,knobs)
	var head_knobs := {"ring":2.0}
	head_knobs.merge(_head_knobs,true)
	enemies.spawn(InhalerHead,head_at,-face,head_knobs)

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

## R: him and his head back as they began; what broke stays broken.
func place(at: Vector3, face: Vector2) -> void:
	super.place(at,face)
	if enemies != null: enemies.reset()
	if figure != null: figure.visible = true

## The camera shakes with his steps and what falls.
func tick(delta: float) -> void:
	super.tick(delta)
	if camera == null: return
	var q := float(breaks.quake)*0.6 if breaks != null else 0.0
	var b := stone_body()
	if b != null: q = maxf(q,float(b.quake)*clampf(1.0-camera.global_position.distance_to(b.global_position)/60.0,0.0,1.0))
	if q > 0.001:
		var t := Time.get_ticks_msec()/1000.0
		camera.position += Vector3(sin(t*61.0),sin(t*53.0+1.0),sin(t*47.0+2.0))*q*0.5

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and (event as InputEventKey).keycode == KEY_L and under != null:
		under.cycle()
		_dress_hemi()
		return
	super._unhandled_input(event)

func _hint_text() -> String:
	return "The city kit: C (arrival) · the epic stair (crouch on a cheek crest to slide) · the causeway · A and its drum stair (drop off a turn's inside: the turn below) · A's collar chain · 1-7 stations · L look · R start · F1 numbers"

func _show_hud() -> void:
	super._show_hud()
	if not _hud.visible: return
	var lines := PackedStringArray([_hud.text,""])
	lines.append("city: %d triangles · built %d ms · rails %d (top %.1f m/s) · breaks: fault %d, bay %d, live %d" % [_triangles(),_built_ms,rail_count,rail_top,down("fault"),down("bay"),floors().reduce(func(n: int, u: Node) -> int: return n+(u.live as Array).size(),0)])
	var b := stone_body()
	if b != null: lines.append("body  %s %.1fs · %s · y %.1f · z %.1f" % [b.state,b.state_t,"whole" if b.whole else "searching",b.position.y,b.position.z])
	_hud.text = "\n".join(lines)

func _voice(sound_name: StringName, at: Vector3) -> void:
	var key := String(sound_name)
	var spec: Variant = InhalerHead.VOICES.get(key,BodySpawner.VOICES.get(key,RuinVoices.VOICES.get(key)))
	if spec == null: return
	if not _voices.has(key): _voices[key] = EnemyYard._synth(spec)
	var player := AudioStreamPlayer3D.new()
	player.stream = _voices[key]
	player.position = at
	player.unit_size = float(BodySpawner.REACH.get(key,RuinVoices.REACH.get(key,14.0)))
	add_child(player)
	player.finished.connect(player.queue_free)
	player.play()
