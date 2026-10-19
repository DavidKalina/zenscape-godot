extends Node3D
## The drop pass (docs/design/home/spec-home.md, item 5), in the wreck
## cluster study with --home. In flight, `fly_drop` (E, pad B; scripts/
## pad.gd) opens the cargo bag: everything in it falls loose with the bag's
## velocity; the bag stays on its rope. Each one is judged where it first
## touches down:
##
## - on the drop field (the piece `home/drop_field`, studies/
##   wreck_cluster_home.gd `field`, its box FIELD_HALF about where it
##   stands): its hit (the fall's speed, plus the run's speed at RUN_SHARE,
##   since the straw lets it slide) under SAFE lands soft and banks once it
##   lies still (scripts/home/vault_host.gd `bank_from`); past SAFE it may
##   break, surely past SURE: it shatters, its value lost, gone till N;
## - off the field: it lands where it falls, a spill like any other,
##   fetched by hand (or lost under the isle).
##
## Flying low over the field with a load shows how once (per pass).

## The field forgives a hit under SAFE m/s; past it each one breaks with a
## chance rising to sure at SURE. The run's speed counts at RUN_SHARE (the
## straw takes the slide).
const SAFE := 13.0
const SURE := 20.0
const RUN_SHARE := 0.7
## A soft one banks after lying still this long, or this long after it
## landed at the most.
const BANK_STILL := 0.35
const BANK_MOST := 2.5
## The hint shows over the field below this height (m over the field).
const HINT_UNDER := 30.0
const Home = preload("res://studies/wreck_cluster_home.gd")
const LayoutOverrides = preload("res://scripts/layout_overrides.gd")
const GenesisAudio = preload("res://scripts/genesis_audio.gd")
const CarryHost = preload("res://scripts/carry/carry_host.gd")
const Models = preload("res://scripts/carry/treasure_models.gd")
const VaultHost = preload("res://scripts/home/vault_host.gd")

var study: Node3D = null
var field: Node3D = null
## Falling ones: {t, body, v (its velocity last physics frame), from (where
## it left the bag), landed (-1 till it lands, then s since), soft}.
var _falling: Array = []
## Drivers: drops (presses that let something fall), treasures let fall,
## soft landings banked, broken, landed off the field; the last hits.
var drops := 0
var let_fall := 0
var banked := 0
var broken := 0
var off_field := 0
var lost_value := 0
var hits: Array = []
var last_break := Vector3.INF
var _rng := RandomNumberGenerator.new()
var _crack: AudioStreamPlayer = null
var _thump: AudioStreamPlayer = null
var _hinted := false
var _rise_t := -99.0
var _stack := 0
static var _crack_take: AudioStreamWAV = null

func setup(host: Node3D) -> void:
	study = host
	name = "DropPass"
	process_priority = 105
	_rng.seed = 7717
	var e: Dictionary = LayoutOverrides.entries.get("home/drop_field",{})
	var n: Variant = e.get("node")
	field = n if n != null and is_instance_valid(n) else null
	_crack = AudioStreamPlayer.new()
	_crack.bus = GenesisAudio.BUS
	_crack.stream = _crack_stream()
	add_child(_crack)
	_thump = AudioStreamPlayer.new()
	_thump.bus = GenesisAudio.BUS
	_thump.stream = CarryHost._thud_stream()
	add_child(_thump)

func _carry() -> Variant:
	return study.get("carry") if study != null else null

## In the air, the plane's own (not on its wheels, not taking off).
func _in_flight() -> bool:
	if study == null or not bool(study.get("flying")): return false
	var hl: Variant = study.get("hand_landing")
	return hl != null and hl.flying() and study.get("takeoff") == null

func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed(&"fly_drop",false,true) or event.is_echo(): return
	if not _in_flight(): return
	if drop_load() > 0: get_viewport().set_input_as_handled()

## Opens the bag: every treasure in it falls loose with the bag's
## velocity, a little spread. How many fell.
func drop_load() -> int:
	var carry: Variant = _carry()
	if carry == null or carry.sling == null: return 0
	var sling: Node3D = carry.sling
	var n := 0
	while true:
		var t: Dictionary = carry.take_from_bag()
		if t.is_empty(): break
		var node: Node3D = t.node
		var h: float = t.measures.height
		var mid := node.global_transform*Vector3(0.0,h*0.5,0.0)
		var side := Vector3(_rng.randf_range(-1,1),0.0,_rng.randf_range(-1,1)).limit_length(1.0)
		var spin := Vector3(_rng.randf_range(-1,1),_rng.randf_range(-1,1),_rng.randf_range(-1,1)).limit_length(1.0)*1.5
		carry._loosen(t,Transform3D(node.global_basis,mid),(sling.vel as Vector3)+side*0.6,spin)
		var body: RigidBody3D = t.body
		body.contact_monitor = true
		body.max_contacts_reported = 2
		var f := {"t":t,"body":body,"v":body.linear_velocity,"from":mid,"landed":-1.0,"soft":false,"still":0.0}
		body.body_entered.connect(_on_touch.bind(f),CONNECT_ONE_SHOT)
		_falling.append(f)
		n += 1
	if n > 0:
		drops += 1
		let_fall += n
		_thump.pitch_scale = 0.7
		_thump.volume_db = -6.0
		_thump.play()
		print("drop: the bag opened, %d falling at %s (%.1f m/s)" % [n,sling.belly(),(sling.vel as Vector3).length()])
	return n

func _physics_process(_delta: float) -> void:
	# Each one's velocity before this step's contacts: its hit.
	for f: Dictionary in _falling:
		if f.landed < 0.0 and is_instance_valid(f.body): f.v = (f.body as RigidBody3D).linear_velocity

## `f` first touches something: on the field it is judged, off it, let be.
func _on_touch(_other: Node, f: Dictionary) -> void:
	if float(f.landed) >= 0.0: return
	f.landed = 0.0
	var body: RigidBody3D = f.body
	var at := body.global_position
	var v: Vector3 = f.v
	var hit := Vector2(v.y,Vector2(v.x,v.z).length()*RUN_SHARE).length()
	var t: Dictionary = f.t
	if not on_field(at):
		off_field += 1
		_falling.erase(f)
		print("drop: %s landed off the field at %s (%.1f m/s)" % [t.id,at,hit])
		return
	hits.append(hit)
	var p := clampf((hit-SAFE)/(SURE-SAFE),0.0,1.0)
	var fell := float(f.from.y)-at.y
	if p > 0.0 and _rng.randf() < p:
		_falling.erase(f)
		_break(t,hit,fell)
		return
	f.soft = true
	_thump.pitch_scale = 0.9+_rng.randf_range(-0.1,0.1)
	_thump.volume_db = -4.0
	_thump.play()
	print("drop: %s landed soft on the field (hit %.1f m/s, fell %.1f m)" % [t.id,hit,fell])

## Whether world `p` lies over the drop field (its box, a little slack).
func on_field(p: Vector3) -> bool:
	if field == null: return false
	var local := field.global_transform.affine_inverse()*p
	return absf(local.x) < Home.FIELD_HALF.x+0.5 and absf(local.z) < Home.FIELD_HALF.y+0.5 and absf(local.y) < 4.0

func _process(delta: float) -> void:
	if study == null or not bool(study.get("walk_ready")): return
	var carry: Variant = _carry()
	if carry == null: return
	for f: Dictionary in _falling.duplicate(): _settle(f,delta,carry)
	_hint(carry)

## A soft one: banked once it lies still (or BANK_MOST after it landed);
## one carried off or lost by then is let be.
func _settle(f: Dictionary, delta: float, carry: Variant) -> void:
	var t: Dictionary = f.t
	if bool(t.lost) or t.body == null or t.body != f.body:
		_falling.erase(f)
		return
	if float(f.landed) < 0.0: return
	f.landed = float(f.landed)+delta
	var body: RigidBody3D = f.body
	if body.linear_velocity.length() < 0.6: f.still = float(f.still)+delta
	else: f.still = 0.0
	if not (body.freeze or float(f.still) >= BANK_STILL or float(f.landed) >= BANK_MOST): return
	_falling.erase(f)
	if not on_field(body.global_position):
		off_field += 1
		return
	carry._unloose(t)
	var vault: Variant = study.get("vault")
	if vault == null: return
	vault.bank_from(t)
	banked += 1

## `t` shatters where it hit: gone till N, its value lost.
func _break(t: Dictionary, hit: float, fell: float) -> void:
	var carry: Variant = _carry()
	var node: Node3D = t.node
	var at := node.global_position
	carry._unloose(t)
	node.visible = false
	t.lost = true
	broken += 1
	last_break = at
	var worth := int(VaultHost.VALUES.get(str(t.kind),0))
	lost_value += worth
	_shards(t,at,hit)
	_crack.pitch_scale = 0.9+_rng.randf_range(-0.12,0.12)
	_crack.play()
	_rise(at,"%s broke  -%d" % [VaultHost.NAMES.get(str(t.kind),str(t.kind)),worth])
	var moments: Variant = study.get("_moments")
	if moments != null: moments.pop("The %s broke on landing (%.0f m/s)  -%d" % [VaultHost.NAMES.get(str(t.kind),str(t.kind)),hit,worth],2.2)
	print("drop: %s broke on the field (hit %.1f m/s, fell %.1f m)" % [t.id,hit,fell])

## Shards of `t` flung from `at`: small pieces in its colours, tumbling out
## and settling on the straw, then gone; a puff of straw dust.
func _shards(t: Dictionary, at: Vector3, hit: float) -> void:
	var cols: Array = []
	for mi: Node in (t.node as Node).find_children("*","MeshInstance3D",true,false):
		var m: Material = (mi as MeshInstance3D).material_override
		if m == null and (mi as MeshInstance3D).mesh != null and (mi as MeshInstance3D).mesh.get_surface_count() > 0:
			m = (mi as MeshInstance3D).mesh.surface_get_material(0)
		if m is StandardMaterial3D: cols.append((m as StandardMaterial3D).albedo_color)
	if cols.is_empty(): cols = [Color("b89a5a")]
	var r := maxf(float(t.measures.radius),0.3)
	for i in 16:
		var piece := MeshInstance3D.new()
		var bm := BoxMesh.new()
		var s := r*_rng.randf_range(0.18,0.42)
		bm.size = Vector3(s,s*_rng.randf_range(0.3,0.8),s*_rng.randf_range(0.5,1.0))
		piece.mesh = bm
		var mat := StandardMaterial3D.new()
		mat.albedo_color = cols[i%cols.size()]
		mat.roughness = 0.6
		piece.material_override = mat
		add_child(piece)
		piece.global_position = at+Vector3.UP*r*0.6
		var out := Vector3(_rng.randf_range(-1,1),0.0,_rng.randf_range(-1,1)).normalized()*_rng.randf_range(1.5,3.0+hit*0.12)
		var up := _rng.randf_range(2.5,5.0)
		var land := at+out*0.6+Vector3(0.0,0.08,0.0)
		var spin := Vector3(_rng.randf_range(-12,12),_rng.randf_range(-12,12),_rng.randf_range(-12,12))
		var tw := create_tween()
		var start := piece.global_position
		var dur := _rng.randf_range(0.5,0.8)
		var fly := func(k: float) -> void:
			if not is_instance_valid(piece): return
			piece.global_position = start.lerp(land,k)+Vector3.UP*up*0.5*sin(k*PI)*(1.0-k*0.4)
			piece.rotation = spin*k*dur
		tw.tween_method(fly,0.0,1.0,dur)
		tw.tween_interval(_rng.randf_range(1.5,2.5))
		tw.tween_property(piece,"scale",Vector3.ONE*0.01,0.4)
		tw.tween_callback(piece.queue_free)
	var dust := CPUParticles3D.new()
	dust.one_shot = true
	dust.amount = 24
	dust.lifetime = 0.9
	dust.explosiveness = 0.95
	dust.direction = Vector3.UP
	dust.spread = 70.0
	dust.initial_velocity_min = 1.0
	dust.initial_velocity_max = 3.0
	dust.gravity = Vector3(0.0,-3.0,0.0)
	dust.scale_amount_min = 0.5
	dust.scale_amount_max = 1.0
	var q := QuadMesh.new()
	q.size = Vector2.ONE
	var dm := StandardMaterial3D.new()
	dm.albedo_color = Color(0.85,0.74,0.5,0.55)
	dm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	dm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	dm.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	var soft := GradientTexture2D.new()
	soft.fill = GradientTexture2D.FILL_RADIAL
	soft.fill_from = Vector2(0.5,0.5)
	soft.fill_to = Vector2(1.0,0.5)
	var g := Gradient.new()
	g.set_color(0,Color(1,1,1,1))
	g.set_color(1,Color(1,1,1,0))
	soft.gradient = g
	dm.albedo_texture = soft
	q.material = dm
	dust.mesh = q
	add_child(dust)
	dust.global_position = at+Vector3.UP*0.2
	dust.emitting = true
	get_tree().create_timer(1.5).timeout.connect(dust.queue_free)

## A label rising off `at` and fading.
func _rise(at: Vector3, text: String) -> void:
	var l := Label3D.new()
	l.text = text
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.font_size = 64
	l.pixel_size = 0.008
	l.outline_size = 12
	l.modulate = Color(0.95,0.45,0.3)
	add_child(l)
	var now := Time.get_ticks_msec()*0.001
	_stack = _stack+1 if now-_rise_t < 1.2 else 0
	_rise_t = now
	var from := at+Vector3.UP*(1.5+0.9*_stack)
	l.global_position = from
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(l,"global_position",from+Vector3.UP*2.0,1.6).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.tween_property(l,"modulate:a",0.0,1.6).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	tw.chain().tween_callback(l.queue_free)

## Low over the field in flight with something in the bag: how to drop,
## once per pass.
func _hint(carry: Variant) -> void:
	if field == null or carry.sling == null: return
	var over := false
	if _in_flight() and float(carry.sling.load_kg) > 0.0:
		var p: Vector3 = study.get("plane").position
		var local := field.global_transform.affine_inverse()*p
		over = absf(local.x) < Home.FIELD_HALF.x+40.0 and absf(local.z) < Home.FIELD_HALF.y+12.0 and local.y < HINT_UNDER
	if over and not _hinted:
		var moments: Variant = study.get("_moments")
		if moments != null: moments.pop("Drop field: E / B opens the bag. Low and slow lands soft.",2.6)
	_hinted = over

## A short dry crack with a ringing tail (made once).
static func _crack_stream() -> AudioStreamWAV:
	if _crack_take != null: return _crack_take
	var rate := 22050
	var n := int(rate*0.5)
	var data := PackedByteArray()
	data.resize(n*2)
	var rng := RandomNumberGenerator.new()
	rng.seed = 33
	var lp := 0.0
	for i in range(n):
		var t := float(i)/rate
		var noise := rng.randf_range(-1.0,1.0)
		lp = lerpf(lp,noise,0.55)
		var crack := lp*exp(-t*28.0)
		var ring := (sin(TAU*1710.0*t)*0.5+sin(TAU*2390.0*t)*0.35)*exp(-t*9.0)*0.35
		var tink := sin(TAU*3150.0*t)*exp(-maxf(t-0.06,0.0)*16.0)*(1.0 if t > 0.06 else 0.0)*0.25
		var v := clampf((crack+ring+tink)*minf(t/0.002,1.0)*0.9,-1.0,1.0)
		data.encode_s16(i*2,int(v*32000.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = rate
	wav.data = data
	_crack_take = wav
	return wav
