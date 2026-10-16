extends "res://studies/character_study.gd"
## The Sun-Keepers yard: the Sun-Keepers (scripts/enemies/sun_keeper.gd), who
## can only stand where light falls, on a lit span over the void, in the
## underground look (`--underground`, torch by default).
##   south     you start on the south plaza. West of you a lone Keeper sleeps
##             in the dark: bring your torch near and it wakes and comes; put
##             the torch out (T) with it in your pool and it topples onto the
##             paving, a heap you can stand on; light up again and it stands.
##   the span  a narrow causeway north over the void, 34 m. A cresset by its
##             south head (unlit: touch it with the torch and it builds them
##             a road onto the span).
##   north     the household: three Keepers in their cresset's light at the
##             span's far head, waiting at the light's rim, one foot up.
##             Walk out with your torch lit: when your pool meets their light
##             they step out into it after you. Put the torch out while one
##             is on the span in your pool, and it goes over into the void.
##             Let one lay hands on you twice and it takes the torch and
##             walks off to the sun altar (NE) holding it high: a walking
##             beacon the Olmec turns to. Knock it down (run or slide into
##             it, or let the Olmec walk into it) and take the torch back.
## Keys: T (pad Y) your torch out / lit again · R all back · K the Keepers back
##   L torch / haze look · 1-5 stations · F1 numbers
##   godot --path . res://studies/strange_sunkeepers_yard.tscn -- --no-title
##     [--underground=haze|torch] [--no-body] [--olmec-chase] [--body-knob=k=v]
##     [--keeper-knob=k=v] [--no-sleeper] [--no-household]
const EnemyField = preload("res://scripts/enemies/enemy_field.gd")
const InhalerHead = preload("res://scripts/enemies/inhaler_head.gd")
const HeadlessBody = preload("res://scripts/enemies/headless_body.gd")
const BodySpawner = preload("res://scripts/enemies/body_spawner.gd")
const SunKeeper = preload("res://scripts/enemies/sun_keeper.gd")
const EnemyYard = preload("res://studies/enemy_yard.gd")
const Breakables = preload("res://scripts/kit_isle/breakables.gd")
const Underground = preload("res://scripts/underground/underground.gd")
const Fires = preload("res://scripts/city_kit_fires.gd")
const CityStone = preload("res://scripts/city_kit_stone.gd")
const LaunchArgs = preload("res://scripts/launch_args.gd")

const YARD_LOST := -40.0
const HEMI := {"torch":0.12,"haze":0.55}
## The plazas (x, z), their slab's depth; the span between (x, z), its
## depth. The span is the card's 2 m causeway, at his size.
const SOUTH := Rect2(-16.0,8.0,32.0,24.0)
const NORTH := Rect2(-24.0,-70.0,64.0,44.0)
const SLAB_DEEP := 6.0
const SPAN_W := 2.2
const SPAN_DEEP := 1.2
## The cressets: the household's (lit), the south head's (unlit).
const NORTH_FIRE := Vector3(4.6,0.0,-30.0)
const SOUTH_FIRE := Vector3(4.6,0.0,11.0)
## The household: three Keepers in their fire's light, facing the span.
const HOUSEHOLD := [Vector3(-1.0,0.0,-29.5),Vector3(1.0,0.0,-33.0),Vector3(-1.0,0.0,-35.0)]
## The sleeper on the south plaza, in the dark.
const SLEEPER := Vector3(-10.0,0.0,20.0)
## The sun altar: two low tiers (x, z, side, tier rise); a thief's goal.
const ALTAR := Vector3(22.0,0.0,-40.0)
const ALTAR_SIDE := 8.0
const ALTAR_RISE := 0.35
## The Olmec's post, far in the north plaza.
const BODY_AT := Vector3(14.0,0.0,-58.0)
const PILOT_AT := Vector3(0.0,0.0,26.0)
## Far pillars in the abyss, each with a lit tower: [x, top, z, radius].
const FAR := [[-70.0,22.0,-120.0,12.0],[90.0,36.0,-150.0,10.0],[-80.0,8.0,40.0,9.0]]

var enemies: Node
var hub: Node3D
var under: Node3D
var pieces: Node3D
var north_fire: Node3D
var south_fire: Node3D
## Where a Keeper takes a stolen torch (sun_keeper.gd reads it): by the
## span's heads (it can't cross the void) up onto the sun altar.
var keeper_goal: Array = [Vector3(0.0,0.0,SOUTH.position.y+3.0),Vector3(0.0,0.0,NORTH.end.y-3.0),ALTAR+Vector3.UP*ALTAR_RISE*2.0]
## Hearts, the run's four (RunState.HEARTS): taken by PilotMotor `harmed`.
var hearts := 4
var _environment: Environment
var _sun: DirectionalLight3D
var _voices := {}
var _body_knobs := {}
var _keeper_knobs := {}
var _no_body := false
var _olmec_chase := false
var _sleeper := true
var _household := true

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
	pack = "strange_sunkeepers"
	var args := LaunchArgs.user_args()
	var asked := false
	for a: String in args:
		if a == "--underground" or a.begins_with("--underground="): asked = true
	if not asked and not args.has("--day"):
		var with := PackedStringArray(args)
		with.append("--underground=torch")
		LaunchArgs.set_override(with)
	for arg: String in LaunchArgs.user_args():
		if arg == "--no-body": _no_body = true
		elif arg == "--olmec-chase": _olmec_chase = true
		elif arg == "--no-sleeper": _sleeper = false
		elif arg == "--no-household": _household = false
		for pair in [["--body-knob=",_body_knobs],["--keeper-knob=",_keeper_knobs]]:
			if arg.begins_with(pair[0]):
				var kv: String = arg.trim_prefix(pair[0])
				pair[1][kv.get_slice("=",0)] = float(kv.get_slice("=",1))
	super._ready()

func _load_pack() -> void:
	start = PILOT_AT
	start_face = Vector2(0.0,-1.0)
	lost = YARD_LOST
	_last_stood = start
	stations = [
		{"key":1,"name":"Start","spawn":PILOT_AT,"face":start_face,"parts":[]},
		{"key":2,"name":"Out on the span","spawn":Vector3(0.0,0.0,-10.0),"face":Vector2(0.0,-1.0),"parts":[]},
		{"key":3,"name":"The sleeper","spawn":SLEEPER+Vector3(9.0,0.0,0.0),"face":Vector2(-1.0,0.0),"parts":[]},
		{"key":4,"name":"The span's south head","spawn":Vector3(0.0,0.0,10.0),"face":Vector2(0.0,-1.0),"parts":[]},
		{"key":5,"name":"The sun altar","spawn":ALTAR+Vector3(0.0,ALTAR_RISE*2.0,6.0),"face":Vector2(0.0,-1.0),"parts":[]},
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
	north_fire = Fires.cresset(pieces,Transform3D(Basis.IDENTITY,NORTH_FIRE),{"size":"cresset","seed":13,"lit":true,"name":"HouseholdFire"})
	# Burning since before you came: old news, no Olmec heeds it.
	north_fire.beacon.draw = 1.0
	south_fire = Fires.cresset(pieces,Transform3D(Basis.IDENTITY,SOUTH_FIRE),{"size":"cresset","seed":17,"name":"SpanFire"})
	for c: Node in [north_fire,south_fire]:
		c.lit_changed.connect(_lit.bind(c))
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
	if _household:
		for at: Vector3 in HOUSEHOLD: enemies.spawn(SunKeeper,at,Vector2(0.0,1.0),_keeper_knobs.duplicate())
	if _sleeper: enemies.spawn(SunKeeper,SLEEPER,Vector2(1.0,0.0),_keeper_knobs.duplicate())
	if not _no_body:
		var knobs := {"chase":1 if _olmec_chase else 0,"chase_routes":1,"periscope":1,"sight_walker_only":1}
		knobs.merge(_body_knobs,true)
		enemies.spawn(HeadlessBody,BODY_AT,Vector2(0.0,1.0),knobs)
		enemies.spawn(InhalerHead,BODY_AT,Vector2(0.0,1.0),{})
	_wire()
	under = Underground.attach(self)
	motor.harmed.connect(_harmed)
	print("strange sunkeepers yard: %d keepers, span %.1f m wide, torch pool %.1f m" % [keepers().size(),SPAN_W*Fires.size(),SunKeeper.pool_radius()])

## The plazas, the span and its piers, the altar: basalt, collided as boxes.
func _build_ground() -> void:
	var k := Fires.size()
	var m := CityStone.Mesher.new(CityStone.stone_colour(),0.2)
	var shapes: Array = []
	var rng := RandomNumberGenerator.new()
	rng.seed = 47
	for r: Rect2 in [SOUTH,NORTH]:
		var c := Vector3(r.get_center().x,-SLAB_DEEP*0.5,r.get_center().y)
		m.solid(CityStone.box(Transform3D(Basis.IDENTITY,c),Vector3(r.size.x,SLAB_DEEP,r.size.y)*0.5,0.3),-SLAB_DEEP,rng.randf_range(0.85,1.0))
		shapes.append(Fires.box_shape(Vector3(r.size.x,SLAB_DEEP,r.size.y),c))
		# A broken underside: the slab hangs over the dark on a few root stones.
		for i in 4:
			var at := Vector3(rng.randf_range(r.position.x+4.0,r.end.x-4.0),-SLAB_DEEP-6.0,rng.randf_range(r.position.y+4.0,r.end.y-4.0))
			m.solid(CityStone.drum(Transform3D(Basis.IDENTITY,at),6,rng.randf_range(2.0,3.5),rng.randf_range(1.0,2.0),12.0,0.3),at.y-6.0,0.7)
	# The span: one causeway of worn slabs, a pier under every few.
	var w := SPAN_W*k
	var z0 := SOUTH.position.y
	var z1 := NORTH.end.y
	var n := int((z0-z1)/2.0)
	for i in n:
		var a := z1+(z0-z1)*float(i)/n
		var b := z1+(z0-z1)*float(i+1)/n
		var c := Vector3(0.0,-SPAN_DEEP*0.5-rng.randf_range(0.0,0.03),(a+b)*0.5)
		m.solid(CityStone.box(Transform3D(Basis(Vector3.UP,rng.randf_range(-0.01,0.01)),c),Vector3(w,SPAN_DEEP,b-a-0.05)*0.5,0.08),-SPAN_DEEP,rng.randf_range(0.8,1.05))
	shapes.append(Fires.box_shape(Vector3(w,SPAN_DEEP,z0-z1),Vector3(0.0,-SPAN_DEEP*0.5,(z0+z1)*0.5)))
	for z: float in [z1+9.0,(z0+z1)*0.5,z0-9.0]:
		m.solid(CityStone.drum(Transform3D(Basis.IDENTITY,Vector3(0.0,-SPAN_DEEP-30.0,z)),8,w*0.42,w*0.5,60.0,0.1),-SPAN_DEEP-60.0,0.75)
	# The sun altar: two low tiers a Keeper can step.
	for t in 2:
		var side := ALTAR_SIDE-t*3.0
		var y := ALTAR_RISE*(t+1)
		var c := Vector3(ALTAR.x,y-ALTAR_RISE*0.5,ALTAR.z)
		m.solid(CityStone.box(Transform3D(Basis.IDENTITY,c),Vector3(side,ALTAR_RISE,side)*0.5,0.05),0.0,0.95)
		shapes.append(Fires.box_shape(Vector3(side,ALTAR_RISE,side),c))
	var mi := MeshInstance3D.new()
	mi.name = "Ground"
	mi.mesh = CityStone.mesh_of(m)
	add_child(mi)
	Fires.cover_ring(self,SOUTH,Rect2(),0.0,41,0.6)
	Fires.cover_ring(self,NORTH,Rect2(ALTAR.x-ALTAR_SIDE*0.5,ALTAR.z-ALTAR_SIDE*0.5,ALTAR_SIDE,ALTAR_SIDE),0.0,42,0.6)
	Fires.solid(self,shapes,false,"GroundSolid")
	var fm := CityStone.Mesher.new(CityStone.stone_colour(),0.1)
	for f: Array in FAR:
		var top := float(f[1])
		var r := float(f[3])
		var at := Vector3(float(f[0]),0.0,float(f[2]))
		fm.solid(CityStone.drum(Transform3D(Basis.IDENTITY,at+Vector3(0.0,top-400.0,0.0)),6,r,r,400.0,0.4),top-400.0,1.0)
	var far := MeshInstance3D.new()
	far.name = "FarPillars"
	far.mesh = CityStone.mesh_of(fm)
	far.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(far)
	for f: Array in FAR:
		var t := Fires.tower(pieces if pieces != null else self,Transform3D(Basis.IDENTITY,Vector3(float(f[0]),float(f[1]),float(f[2]))),
			{"tiers":2,"base":7.0,"steps":false,"lit":true,"seed":30+int(f[0]),"name":"FarTower","beam":3.0})
		t.crown.beacon.draw = 1.0

func _lit(on: bool, c: Node3D) -> void:
	if on: _say("%s catches: its light is floor for the Keepers" % c.name.capitalize(),3.0)
	else: _say("%s goes out" % c.name.capitalize(),2.0)

## The Sun-Keepers on the field.
func keepers() -> Array:
	var out: Array = []
	if enemies == null: return out
	for e in enemies.enemies:
		if is_instance_valid(e) and e.is_in_group(SunKeeper.GROUP): out.append(e)
	return out

func _wire() -> void:
	var b := stone_body()
	var h := stone_head()
	if b == null or h == null: return
	b.make_whole(h)
	b.breaker = hub

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

func _harmed(amount: int, cause: String, _source: Object) -> void:
	hearts = maxi(0,hearts-amount)
	_say("-%d heart (%s): %d left" % [amount,cause,hearts] if hearts > 0 else "Felled by %s (R to start again)" % cause,2.5)

func reset_pieces() -> void:
	if not north_fire.lit and not north_fire.broken: north_fire.light()
	if south_fire.lit: south_fire.douse()
	for t in get_tree().get_nodes_in_group(SunKeeper.DroppedTorch.GROUP): t.queue_free()

func reset_all() -> void:
	reset_pieces()
	reset_enemies()
	Fires.set_torch(get_tree(),true)
	hearts = 4
	respawn()

func reset_enemies() -> void:
	if enemies == null: return
	enemies.reset()
	if figure != null: figure.visible = true
	_wire()

## T (pad Y): the torch out, or lit again (not while a Keeper has it).
func toggle_torch() -> void:
	var tree := get_tree()
	if Fires.torch_lit(tree):
		Fires.set_torch(tree,false)
		_say("Torch out: blind, and no floor for them",2.0)
	elif SunKeeper.torch_taken(tree):
		_say("A Sun-Keeper has your torch: knock it down and take it back, or light one at a fire",3.0)
	else:
		Fires.set_torch(tree,true)
		_say("Torch lit",1.5)

func tick(delta: float) -> void:
	if not scripted and Input.is_action_just_pressed(&"walk_torch") and not _tuning(): toggle_torch()
	super.tick(delta)
	if under != null:
		if _sun != null: _sun.visible = false
		_hemi()
	if camera == null: return
	var b := stone_body()
	var q := float(hub.quake)*0.7 if hub != null else 0.0
	if b != null: q = maxf(q,float(b.quake)*clampf(1.0-camera.global_position.distance_to(b.global_position)/60.0,0.0,1.0))
	if q > 0.001:
		var t := Time.get_ticks_msec()/1000.0
		camera.position += Vector3(sin(t*61.0),sin(t*53.0+1.0),sin(t*47.0+2.0))*q*0.5

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
			KEY_K:
				reset_enemies()
				reset_pieces()
				_say("The Keepers back where they stood",2.0)
				return
			KEY_L:
				if under != null:
					under.cycle()
					return
	super._unhandled_input(event)

func _show_toast(text: String) -> void:
	_say(text,2.0)

func _hint_text() -> String:
	return "Sun-Keepers: they stand only where light falls, and your torch is light · walk the span north with it lit: the household steps out into your pool · T (pad Y) torch out: one in your pool topples (off the span: gone) · west: a sleeper in the dark · twice in their hands and one takes your torch to the altar, the Olmec after it · R all back · K Keepers back · L look · F1 numbers"

func _show_hud() -> void:
	super._show_hud()
	if not _hud.visible: return
	var lines := PackedStringArray([_hud.text,""])
	var tree := get_tree()
	lines.append("hearts %d · torch %s · light on you %.2f" % [hearts,"lit" if Fires.torch_lit(tree) else ("TAKEN" if SunKeeper.torch_taken(tree) else "out"),LightLevel.exposure(tree,motor.feet+Vector3.UP)])
	for k in keepers():
		lines.append("keeper %s  z %.1f · touches %d · topples %d" % [k.state,k.position.z,k.touches,k.topples])
	var b := stone_body()
	if b != null:
		lines.append("olmec %s · beacon %s" % [b.state,str(b.beacon.get_parent().name) if b.beacon != null else "-"])
	_hud.text = "\n".join(lines)

func _voice(sound_name: StringName, at: Vector3) -> void:
	var key := String(sound_name)
	var spec: Variant = SunKeeper.VOICES.get(key,InhalerHead.VOICES.get(key,BodySpawner.VOICES.get(key)))
	if spec == null: return
	if not _voices.has(key): _voices[key] = EnemyYard._synth(spec)
	var player := AudioStreamPlayer3D.new()
	player.stream = _voices[key]
	player.position = at
	player.unit_size = float(SunKeeper.REACH.get(key,BodySpawner.REACH.get(key,30.0)))
	add_child(player)
	player.finished.connect(player.queue_free)
	player.play()
