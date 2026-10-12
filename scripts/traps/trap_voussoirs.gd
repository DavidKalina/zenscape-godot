extends "res://scripts/traps/trap.gd"
## Loose Voussoirs (docs/design/roguelike/ideas-traps.md module 1; built to
## the contract in scripts/traps/trap.gd): a row of deck slabs, never
## mortared, over a drop. Each falls `delay` s after the pilot's feet first
## land on it, and drops away; stood on while it goes, he falls with it.
## The slab is a walker's half second long and a runner's half second wide
## (`length`, `width`, from the motor's walk and run), and the delay is a
## share of the walker's crossing (DELAY_OF_WALK 0.75: 0.375 s at the
## knobs), so running (0.25 s on a slab) is safe and walking (0.5 s) isn't.
##
## The tell: slabs sit a few cm off true (a nudge across, a turn, a sink,
## `offset`) and darker than the decks; a dust puff and a grinding chirp
## (`tell_sound("grind")`) the first time a slab is touched, and a slab
## goes from its stone grey to the tell's orange as it nears falling. The
## first slab only tests (`first_tests`): it puffs and never falls, so the
## trap is seen before it bites. Over a drop to the void it costs 3, over
## a layer down 2.
##
## Knobs: `count` slabs, `length` and `width` (m), `delay` (s to falling),
## `gap_every` (every nth slab is missing, 0 none: a gap of one length),
## `first_tests`, `offset` (m of untruing), `fall_time` (s a fallen slab
## stays drawn, falling at the motor's gravity), `seed`.
##
## The chase (`chase`): the first touch also starts the row coming down
## behind him from the way in, a front setting off each slab it passes,
## `chase_warn` s from its orange to its fall. It starts at his walk
## (`chase_speed`) and gains `chase_accel` m/s each second, so it passes
## his run near the row's end: a run started late or slowed is caught, a
## run at speed just makes it, a long-jump chain makes it easily.
const DELAY_OF_WALK := 0.75
const THICK := 0.4
const STONE := Color(0.42,0.41,0.4)
const FALL_FROM := 10.0

## Slab states.
const SOUND := 0
const TOUCHED := 1
const FALLING := 2
const GONE := 3
const TESTED := 4

## One record per slab: node, body, material, local top-middle, state,
## seconds since touched, fall pace, seconds fallen.
var slabs: Array[Dictionary] = []
var landed_count := 0
var fallen_count := 0
## The chase's front (m along the row from the way in, -1 not started) and
## its pace.
var front := -1.0
var front_pace := 0.0

func _init() -> void:
	super()
	trap_name = "voussoirs"
	cost = 2
	under = "layer"
	verbs = PackedStringArray(["run"])

func defaults() -> Dictionary:
	var p := pilot()
	var run_len := p.walk*0.5
	return {
		"count":8,"length":run_len,"width":p.run*0.5,"delay":DELAY_OF_WALK*run_len/p.walk,
		"gap_every":0,"first_tests":true,"offset":0.04,"fall_time":2.5,"seed":7,
		"chase":true,"chase_speed":p.walk,"chase_accel":p.run*0.5,"chase_warn":0.12,
	}

func length() -> float:
	return float(knob("count"))*float(knob("length"))

func footprint() -> Rect2:
	var w := float(knob("width"))
	return Rect2(-w*0.5,-length(),w,length())

func build() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(knob("seed"))
	var slab_len := float(knob("length"))
	var wide := float(knob("width"))
	var off := float(knob("offset"))
	var every := int(knob("gap_every"))
	for i in range(int(knob("count"))):
		if every > 0 and (i+1)%every == 0: continue
		var top := Vector3(rng.randf_range(-off,off),-rng.randf_range(0.0,off*0.75),-(i+0.5)*slab_len)
		var body := StaticBody3D.new()
		body.position = top
		body.rotation.y = rng.randf_range(-off,off)*2.0
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(wide,THICK,slab_len-0.02)
		shape.shape = box
		shape.position.y = -THICK*0.5
		body.add_child(shape)
		var mesh := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = box.size
		mesh.mesh = bm
		mesh.position.y = -THICK*0.5
		var mat := paint(STONE)
		mesh.material_override = mat
		body.add_child(mesh)
		add_child(body)
		slabs.append({"body":body,"mat":mat,"top":top,"yaw":body.rotation.y,"index":i,"state":SOUND,"t":0.0,"vy":0.0,"fell":0.0})

## Frame: the pilot's feet on a sound slab start its fall; touched slabs
## warm toward the tell and drop when the delay is up; fallen ones fall.
func after(delta: float, _events: Dictionary) -> void:
	var under_him: Dictionary = {}
	if motor != null and motor.grounded and motor.rider == null: under_him = slab_at(motor.feet)
	var delay := float(knob("delay"))
	_chase(delta)
	for s: Dictionary in slabs:
		match s.state:
			SOUND:
				if s.index == under_him.get("index",-1): _touch(s)
			TOUCHED:
				s.t += delta
				_warm(s)
				if s.t >= delay:
					if bool(knob("first_tests")) and s.index == _first_index() and not s.get("chased",false):
						# It only tests: back to stone, never to fall.
						s.state = TESTED
						(s.mat as StandardMaterial3D).albedo_color = STONE
					else: _drop(s)
			FALLING:
				var node: Node3D = s.body
				s.vy += pilot_gravity()*delta
				node.position.y -= s.vy*delta
				s.fell += delta
				if s.fell >= float(knob("fall_time")):
					s.state = GONE
					node.visible = false
	tell_sight(_loudest())

## The front comes down the row, setting off each sound slab it reaches:
## each goes to the tell at once and falls `chase_warn` s later.
func _chase(delta: float) -> void:
	if not bool(knob("chase")): return
	if front < 0.0:
		if landed_count == 0: return
		front = 0.0
		front_pace = float(knob("chase_speed"))
	front_pace += float(knob("chase_accel"))*delta
	front += front_pace*delta
	var slab_len := float(knob("length"))
	var warn := float(knob("chase_warn"))
	for s: Dictionary in slabs:
		if front < float(s.index)*slab_len: continue
		if s.state == SOUND or s.state == TESTED or (s.state == TOUCHED and not s.get("chased",false)):
			var left := float(knob("delay"))-float(s.t) if s.state == TOUCHED else INF
			s.state = TOUCHED
			s.chased = true
			s.t = float(knob("delay"))-minf(warn,left)

func pilot_gravity() -> float:
	return motor.gravity if motor != null else PilotMotor.GRAVITY

## The sound slab or touched slab his feet (world) are on, or {}.
func slab_at(feet: Vector3) -> Dictionary:
	var local := to_local(feet)
	var half_w := float(knob("width"))*0.5
	var half_l := float(knob("length"))*0.5
	for s: Dictionary in slabs:
		if s.state == FALLING or s.state == GONE: continue
		var top: Vector3 = s.top
		if absf(local.x-top.x) <= half_w and absf(local.z-top.z) <= half_l and absf(local.y-top.y) < 0.25: return s
	return {}

func _first_index() -> int:
	return int(slabs[0].index) if not slabs.is_empty() else -1

func _touch(s: Dictionary) -> void:
	s.state = TOUCHED
	s.t = 0.0
	landed_count += 1
	var at := to_global(s.top as Vector3)
	tell_sound(&"grind",at)
	_dust(at)

func _drop(s: Dictionary) -> void:
	s.state = FALLING
	s.vy = 0.0
	fallen_count += 1
	(s.body as StaticBody3D).collision_layer = 0
	tell_sound(&"crumble",to_global(s.top as Vector3))

## Stone grey to the tell's orange as a touched slab nears falling.
func _warm(s: Dictionary) -> void:
	var share := clampf(float(s.t)/maxf(float(knob("delay")),0.01),0.0,1.0)
	(s.mat as StandardMaterial3D).albedo_color = STONE.lerp(TELL,share)

func _loudest() -> float:
	var most := 0.0
	for s: Dictionary in slabs:
		if s.state == TOUCHED: most = maxf(most,float(s.t)/maxf(float(knob("delay")),0.01))
	return most

## A little dust off the slab's top, one burst.
func _dust(at: Vector3) -> void:
	var puff := CPUParticles3D.new()
	puff.one_shot = true
	puff.amount = 10
	puff.lifetime = 0.7
	puff.explosiveness = 1.0
	puff.direction = Vector3.UP
	puff.spread = 70.0
	puff.initial_velocity_min = 0.6
	puff.initial_velocity_max = 1.4
	puff.gravity = Vector3(0.0,-1.0,0.0)
	var sphere := SphereMesh.new()
	sphere.radius = 0.08
	sphere.height = 0.16
	puff.mesh = sphere
	puff.material_override = paint(Color(0.7,0.68,0.62))
	add_child(puff)
	puff.global_position = at
	puff.emitting = true
	get_tree().create_timer(1.0).timeout.connect(puff.queue_free)

func reset() -> void:
	super()
	landed_count = 0
	fallen_count = 0
	front = -1.0
	front_pace = 0.0
	for s: Dictionary in slabs:
		var node: Node3D = s.body
		node.position = s.top
		node.visible = true
		(node as StaticBody3D).collision_layer = 1
		(s.mat as StandardMaterial3D).albedo_color = STONE
		s.state = SOUND
		s.t = 0.0
		s.vy = 0.0
		s.fell = 0.0
		s.chased = false
