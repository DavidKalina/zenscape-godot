extends "res://studies/character_study.gd"
## The city fires yard: the
## city kit's fire pieces (scripts/city_kit_fires.gd) on a basalt plaza over
## the abyss, in the underground look (`--underground`, torch by default;
## `--underground=haze`), with a whole Olmec hunting (the chase, the
## periscope, chase routes) and a headless body roaming. Light a fire by
## touching it with your torch: climb onto a plinth beside its bowl, or catch
## the bowl's lip. Every Olmec in reach turns to a lit fire and comes to look;
## you are plainer to him in its light; barge it and he tips it into a
## burning spill on his lane.
##   the great cresset   the plaza's middle: two tiers, a wide bowl
##   the fuse wall       west: a terrace wall with giant steps up its face
##                       and an oil runnel beside them; light its feed port
##                       at the wall's foot and the flame climbs the wall,
##                       lighting the steps, and over the top to the
##                       terrace's cresset
##   the beacon tower    east: a stepped tower of giant steps, its crown a
##                       cresset to light
##   the wick spire      south-west: a lone column, glyph steps spiralling
##                       up, a cresset in its crown cup (Mudge's home)
##   the layers above    far pillars in the abyss, each with a lit tower
## Keys:
##   T   your torch out (hide in the dark) or lit again (also: touch a fire)
##   L   torch / haze
##   K   the fires as built (all out, the tipped ones stood again)
##   R   all back: you, the bodies, the fires   B   the bodies back
##   J   the Olmec's sight overlay   F1 numbers
##   godot --path . res://studies/city_fires_yard.tscn -- --no-title
##     [--underground=haze|torch] [--day] [--body-knob=<k>=<v>] [--head-knob=...]
##     [--body-at=x,z] [--body-face=x,z] [--no-body] [--no-headless] [--sight-overlay]
const EnemyField = preload("res://scripts/enemies/enemy_field.gd")
const InhalerHead = preload("res://scripts/enemies/inhaler_head.gd")
const HeadlessBody = preload("res://scripts/enemies/headless_body.gd")
const BodySpawner = preload("res://scripts/enemies/body_spawner.gd")
const EnemyYard = preload("res://studies/enemy_yard.gd")
const SightOverlay = preload("res://scripts/enemies/body_sight_overlay.gd")
const Breakables = preload("res://scripts/kit_isle/breakables.gd")
const Underground = preload("res://scripts/underground/underground.gd")
const Fires = preload("res://scripts/city_kit_fires.gd")
const GiantStone = preload("res://scripts/kit_isle/greybox/giant_stone.gd")
const LaunchArgs = preload("res://scripts/launch_args.gd")

const YARD_LOST := -40.0
## The stone's hemisphere fill under each look.
## The plaza (x, z), its top 0, its slab's depth.
const PLAZA := Rect2(-48.0,-64.0,96.0,112.0)
const PLAZA_DEEP := 8.0
## The paving's slab (m).
const PAVE := 8.0
## The pieces.
const GREAT_AT := Vector3(0.0,0.0,6.0)
const TOWER_AT := Vector3(30.0,0.0,-28.0)
const SPIRE_AT := Vector3(-30.0,0.0,30.0)
## The terrace (x, z) and its top; its east face carries the steps and the
## runnel; its cresset.
const TERRACE := Rect2(-48.0,-50.0,32.0,40.0)
const TERRACE_TOP := 6.4
const TERRACE_CRESSET := Vector3(-27.0,TERRACE_TOP,-26.0)
## Cover on the plaza: [middle (x, z), radius, top] broken drums.
const DRUMS := [[Vector2(-4.0,-34.0),1.7,8.0],[Vector2(15.0,-6.0),1.5,5.5],[Vector2(12.0,24.0),1.9,9.0]]
## The layers above (and one below): far pillars, each [x, top, z, radius,
## tiers]; a lit beacon tower on each.
const FAR := [
	[-84.0,22.0,-150.0,14.0,4],
	[72.0,46.0,-196.0,12.0,3],
	[-14.0,80.0,-280.0,16.0,5],
	[124.0,12.0,-96.0,10.0,3],
	[-118.0,-30.0,-46.0,12.0,3],
	[150.0,64.0,-260.0,13.0,4],
]
## Where the bodies stand and you start.
const BODY_AT := Vector3(26.0,0.0,-50.0)
const HEADLESS_AT := Vector3(34.0,0.0,16.0)
const PILOT_AT := Vector3(0.0,0.0,30.0)

var enemies: Node
var hub: Node3D
var overlay: Node3D
var under: Node3D
var fires: Node3D
var great: Node3D
var terrace_cresset: Node3D
var runnel: Node3D
var tower: Node3D
var spire: Node3D
var far_towers: Array = []
var _environment: Environment
var _sun: DirectionalLight3D
var _voices := {}
var _body_knobs := {}
var _head_knobs := {}
var _body_at := BODY_AT
var _body_face := Vector2(-1.0,0.6).normalized()
var _no_body := false
var _no_headless := false
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
	pack = "city_fires"
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
		elif arg == "--no-headless": _no_headless = true
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
	stations = [{"key":1,"name":"City fires yard","spawn":PILOT_AT,"face":start_face,"parts":[]}]

func _build_light() -> void:
	super._build_light()
	for n: Node in get_children():
		if n is WorldEnvironment: _environment = (n as WorldEnvironment).environment
		elif n is DirectionalLight3D: _sun = n
	camera.far = 1200.0

func _build_room() -> void:
	super._build_room()
	# No greybox signs here.
	for l: Node in find_children("*","Label3D",false,false): l.queue_free()
	_build_ground()
	fires = Node3D.new()
	fires.name = "Fires"
	add_child(fires)
	_build_fires()
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
		var knobs := {"chase":1,"chase_routes":1,"periscope":1}
		knobs.merge(_body_knobs,true)
		enemies.spawn(HeadlessBody,_body_at,_body_face,knobs)
		enemies.spawn(InhalerHead,_body_at,_body_face,_head_knobs.duplicate())
	if not _no_headless:
		enemies.spawn(HeadlessBody,HEADLESS_AT,Vector2(-1.0,0.0),_body_knobs.duplicate())
	overlay = SightOverlay.new()
	add_child(overlay)
	_wire()
	under = Underground.attach(self)
	print("city fires yard: great cresset lip %.2f m (plinth %.2f), terrace %.1f m, runnel %.1f m, tower %.1f m, spire %.1f m, %d far towers" % [great.lip_y,great.top,TERRACE_TOP,runnel.total,tower.top,spire.top,far_towers.size()])

## The plaza's paving, the terrace and its giant steps, the broken drums,
## the far pillars: basalt, collided as plain boxes and drums.
func _build_ground() -> void:
	var m := GiantStone.mesher()
	var shapes: Array = []
	var rng := RandomNumberGenerator.new()
	rng.seed = 41
	# The paving: slabs a seam apart, each its own little tilt of tone.
	var nx := int(PLAZA.size.x/PAVE)
	var nz := int(PLAZA.size.y/PAVE)
	for i in nx:
		for j in nz:
			var c := Vector3(PLAZA.position.x+PAVE*(i+0.5),0.0,PLAZA.position.y+PAVE*(j+0.5))
			var sink := rng.randf_range(0.0,0.04)
			m.box(Transform3D(Basis.IDENTITY,c+Vector3(0.0,-1.0-sink,0.0)),Vector3(PAVE-0.08,2.0,PAVE-0.08),0.06,-2.0,rng.randf_range(0.82,1.08))
	# Under the paving, the plaza's slab dropping into the abyss.
	var under_c := Vector3(PLAZA.get_center().x,-2.0-PLAZA_DEEP*0.5,PLAZA.get_center().y)
	m.box(Transform3D(Basis.IDENTITY,under_c),Vector3(PLAZA.size.x-1.0,PLAZA_DEEP,PLAZA.size.y-1.0),0.5,-2.0-PLAZA_DEEP,0.8)
	shapes.append(Fires.box_shape(Vector3(PLAZA.size.x,2.0+PLAZA_DEEP,PLAZA.size.y),Vector3(PLAZA.get_center().x,-(2.0+PLAZA_DEEP)*0.5,PLAZA.get_center().y)))
	# The terrace, and on its east face the giant steps up to its top.
	var t := Vector3(TERRACE.get_center().x,TERRACE_TOP*0.5,TERRACE.get_center().y)
	m.box(Transform3D(Basis.IDENTITY,t),Vector3(TERRACE.size.x,TERRACE_TOP,TERRACE.size.y),0.18,0.0)
	shapes.append(Fires.box_shape(Vector3(TERRACE.size.x,TERRACE_TOP,TERRACE.size.y),t))
	for s: Array in giant_steps():
		var sz: Vector3 = s[1]
		m.box(Transform3D(Basis.IDENTITY,s[0]),sz,0.08,0.0)
		shapes.append(Fires.box_shape(sz,s[0]))
	for d: Array in DRUMS:
		var p: Vector2 = d[0]
		var r := float(d[1])
		var top := float(d[2])
		m.cylinder(Transform3D(Basis.IDENTITY,Vector3(p.x,top*0.5,p.y)),r,top,14,0.18,0.0)
		shapes.append(Fires.cyl_shape(r,top,Vector3(p.x,top*0.5,p.y)))
	Fires.mesh_node(self,m,"Ground")
	# The underground's cover (the flags' kind) on the plaza and the terrace.
	Fires.cover_ring(self,PLAZA,TERRACE,0.0,41)
	Fires.cover_ring(self,TERRACE,Rect2(),TERRACE_TOP,42)
	Fires.solid(self,shapes,false,"GroundSolid")
	# The far pillars (unreachable: drawn only), each a tall hex drum.
	var fm := GiantStone.mesher()
	for f: Array in FAR:
		var top := float(f[1])
		var r := float(f[3])
		var tall := 400.0
		var at := Vector3(float(f[0]),0.0,float(f[2]))
		# A hex column out of the dark, a broad isle on it (collared,
		# stepped), and a lesser column leaning on its flank.
		fm.cylinder(Transform3D(Basis.IDENTITY,at+Vector3(0.0,top-6.0-tall*0.5,0.0)),r,tall,6,0.4,top-tall,1.0)
		fm.cylinder(Transform3D(Basis(Vector3.UP,0.5),at+Vector3(0.0,top-6.0,0.0)),r*1.55,8.0,6,0.6,top-14.0,0.85)
		fm.cylinder(Transform3D(Basis(Vector3.UP,0.2),at+Vector3(0.0,top-0.9,0.0)),r*1.45,1.8,6,0.3,top-3.0,0.95)
		fm.cylinder(Transform3D(Basis(Vector3.UP,0.9),at+Vector3(r*1.5,top-12.0-tall*0.5,r*0.4)),r*0.55,tall,6,0.3,top-tall,0.8)
	var far_mesh := Fires.mesh_node(self,fm,"FarPillars")
	far_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

## The terrace's giant steps up its east face: [middle, size], northward,
## each SET_OFF higher, a stand deep.
static func giant_steps() -> Array:
	var out: Array = []
	var rise := Fires.set_off()
	# Two stands deep, so he stands clear of the wall (no wall run).
	var deep := Fires.stand()*2.0
	var wide := 1.5
	var face := TERRACE.end.x
	var n := int(roundf(TERRACE_TOP/rise))
	for j in range(1,n):
		var z0 := -14.0-wide*j
		out.append([Vector3(face+deep*0.5,rise*j*0.5,z0+wide*0.5),Vector3(deep,rise*j,wide)])
	return out

## The runnel's line on the terrace's east face (normal +x): from its feed
## port at the wall's foot, along, then up beside the steps, over the top,
## across to the terrace cresset's plinth and up its face.
static func runnel_line() -> Array:
	var face := TERRACE.end.x+0.004
	var rise := Fires.set_off()
	var pts: Array = []
	var nrm: Array = []
	var e := Vector3.RIGHT
	pts.append(Vector3(face,1.0,-6.0)); nrm.append(e)
	pts.append(Vector3(face,1.0,-12.5)); nrm.append(e)
	var n := int(roundf(TERRACE_TOP/rise))
	for j in range(1,n):
		var z := -14.0-1.5*j+0.75
		pts.append(Vector3(face,rise*j+0.95,z)); nrm.append(e)
	var top_z := -14.0-1.5*n
	pts.append(Vector3(face,TERRACE_TOP-0.02,top_z)); nrm.append((e+Vector3.UP).normalized())
	pts.append(Vector3(face-0.4,TERRACE_TOP+0.004,top_z-0.2)); nrm.append(Vector3.UP)
	var plinth_e := TERRACE_CRESSET.x+Fires.SIZES.cresset.tiers[0][0]*0.5*Fires.size()+0.004
	pts.append(Vector3(plinth_e,TERRACE_TOP+0.004,TERRACE_CRESSET.z)); nrm.append(Vector3.UP)
	pts.append(Vector3(plinth_e,TERRACE_TOP+Fires.set_off()-0.05,TERRACE_CRESSET.z)); nrm.append(e)
	return [pts,nrm]

func _build_fires() -> void:
	great = Fires.cresset(fires,Transform3D(Basis.IDENTITY,GREAT_AT),{"size":"great","seed":3,"name":"GreatCresset"})
	terrace_cresset = Fires.cresset(fires,Transform3D(Basis.IDENTITY,TERRACE_CRESSET),{"size":"cresset","seed":5,"name":"TerraceCresset"})
	var line := runnel_line()
	runnel = Fires.runnel(fires,Transform3D.IDENTITY,line[0],line[1],{"tail":terrace_cresset,"name":"FuseRunnel"})
	tower = Fires.tower(fires,Transform3D(Basis(Vector3.UP,deg_to_rad(-20.0)),TOWER_AT),{"seed":7,"name":"BeaconTower"})
	spire = Fires.spire(fires,Transform3D(Basis.IDENTITY,SPIRE_AT),{"seed":9,"name":"WickSpire"})
	far_towers.clear()
	for i in FAR.size():
		var f: Array = FAR[i]
		var t := Fires.tower(fires,Transform3D(Basis(Vector3.UP,float(i)*1.3),Vector3(float(f[0]),float(f[1]),float(f[2]))),
			{"tiers":int(f[4]),"base":9.0,"steps":false,"lit":true,"seed":20+i,"name":"FarTower%d" % i,"beam":3.0})
		# Far off, no Olmec here hears it: they are other layers'.
		t.crown.beacon.draw = 1.0
		far_towers.append(t)
	for c: Node in [great,terrace_cresset,tower.crown,spire.crown]:
		c.lit_changed.connect(_lit.bind(c))
		if c.has_signal("tipped"): c.tipped.connect(func(_d: Vector3) -> void: _say("Over it goes!",2.0))
	runnel.arrived.connect(func() -> void: _say("The flame reaches the cresset",2.5))

func _lit(on: bool, c: Node3D) -> void:
	if on: _say("%s catches. Every Olmec near turns to it." % c.name.capitalize(),3.0)

## The fires as built: the tipped ones stood again, all out.
func reset_fires() -> void:
	# Out of the tree now (its solids out of the space), freed after.
	remove_child(fires)
	fires.queue_free()
	fires = Node3D.new()
	fires.name = "Fires"
	add_child(fires)
	_build_fires()

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
		if is_instance_valid(e) and e.has_method("make_whole") and (e.get("head") != null or e.get("whole")): return e
	for e in enemies.enemies:
		if is_instance_valid(e) and e.has_method("make_whole"): return e
	return null

## The headless body roaming (no head of its own).
func roamer() -> Node3D:
	if enemies == null: return null
	var w := stone_body()
	for e in enemies.enemies:
		if is_instance_valid(e) and e.has_method("make_whole") and e != w: return e
	return null

func stone_head() -> Node3D:
	if enemies == null: return null
	for e in enemies.enemies:
		if is_instance_valid(e) and e.has_method("mouth"): return e
	return null

func reset_all() -> void:
	reset_fires()
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
	if camera == null: return
	var q := float(hub.quake)*0.7 if hub != null else 0.0
	var b := stone_body()
	if b != null: q = maxf(q,float(b.quake)*clampf(1.0-camera.global_position.distance_to(b.global_position)/60.0,0.0,1.0))
	if q > 0.001:
		var t := Time.get_ticks_msec()/1000.0
		camera.position += Vector3(sin(t*61.0),sin(t*53.0+1.0),sin(t*47.0+2.0))*q*0.5

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and not _name_panel.visible:
		match (event as InputEventKey).keycode:
			KEY_R:
				reset_all()
				return
			KEY_B:
				reset_body()
				_say("The bodies are back where they began",2.0)
				return
			KEY_K:
				reset_fires()
				_say("The fires as built: all out",2.0)
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
	return "City fires: touch a bowl with your torch to light it (climb onto its plinth or catch its lip) · every Olmec near turns to a lit fire · its light shows you to him · the runnel's port is at the terrace wall's foot · T torch out/in · L torch/haze · K fires out · R all back · B bodies back · J his sight · F1 numbers"

func _show_hud() -> void:
	super._show_hud()
	if not _hud.visible: return
	var lines := PackedStringArray([_hud.text,""])
	for b: Node3D in [stone_body(),roamer()]:
		if b == null: continue
		var s: RefCounted = b.sight
		lines.append("%s  %s %.1fs · %s · beacon %s (turns %d, visits %d) · sight %s %.2f" % ["olmec" if b == stone_body() else "body ",b.state,b.state_t,"hunting" if b.hunting else "calm",
			str(b.beacon.get_parent().name) if b.beacon != null else "-",b.beacon_turns,b.beacon_visits,str(s.state) if s != null else "-",float(s.awareness) if s != null else 0.0])
	var me: Vector3 = motor.feet+Vector3.UP
	lines.append("light on you %.2f (glow %.2f) · torch %s" % [LightLevel.exposure(get_tree(),me),LightLevel.glow(get_tree(),me),"lit" if Fires.torch_lit(get_tree()) else "out"])
	lines.append("great %s · terrace %s · runnel %s %.1f/%.1f m · tower %s · spire %s" % [_state(great),_state(terrace_cresset),"burning" if runnel.running else ("run" if runnel.done else "dry"),maxf(runnel.front,0.0),runnel.total,_state(tower.crown),_state(spire.crown)])
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
