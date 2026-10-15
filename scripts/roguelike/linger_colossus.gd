extends Node3D
## [linger] The linger threat as a colossal Olmec (docs/design/roguelike/
## linger-colossus-round1.md): a giant of the Olmec's
## weathered stone standing in the void off the layer's flank, in a cloud
## bank he rises through. The clock is how much of him has risen, read from
## any isle; there is no timer on the screen. Timed from the layer's start
## (its play), reset with each layer (made with the stage, freed with it).
##
##   1. He rises (RISE_AT): a deep rumble first, the cloud bank stirs, then
##      his crown breaks the cloud far off and he comes up in slow heaves
##      (SURGES), each a lurch, the bank pushed out round him, the ground's
##      tremble. By RISEN_AT his head and shoulders stand over the cloud,
##      his eyes dimly lit, his head turned after the wanderer.
##   2. He inhales (INHALE_AT, then every EVERY s): a long tell (TELL s: his
##      head tips back, the jaw drops, the eyes warm; the cloud bank streams
##      in over his shoulders to his mouth, the world's wind swings round
##      to blow toward him, dust and leaves lift and go) and then the draw
##      (DRAW s): a pull on the wanderer toward him, stage-wide. On the turf
##      he is slid toward him (a crouch braces: BRACE), and past TRIP s
##      unbraced he is torn off his feet and flung toward the void (a heart:
##      the motor's harm, "olmec"); hanging from a rim he holds; in the air
##      he is drawn; behind stone (anything within SHELTER m between him and
##      the colossus) the draw barely reaches him (SHELTERED).
##   He keeps rising slowly through stage 2 (to TOWER_R by TOWER_AT), so the
##   clock goes on reading. Stage 3 (round 2: his hands up out of the cloud
##   slamming isles, small Olmecs answering his call) hooks in at `stage3`.
##
## Gated by `RunFeatures.on(&"linger")` and `--linger=colossus` (the rune
## serpent is the default linger). Knobs (launch flags):
##   --linger-at=S     the clock starts at S s (fast-forward: 55 just before
##                     he rises, 118 just before the first inhale)
##   --linger-size=M   his head's height (m; by default sized off the layer)
##   --linger-off=M    how far off the layer's flank he stands (m)
##   --linger-pull=X   the draw's strength, times the wanderer's run (0.95)
## Driven by the run loop (scripts/roguelike/run_loop.gd `# [linger]`):
## `tick(delta)` in play.

const HeadLook = preload("res://scripts/enemies/inhaler_head_look.gd")
const BodyLook = preload("res://scripts/enemies/headless_body_look.gd")
const Cloud = preload("res://scripts/roguelike/linger_colossus_cloud.gd")
const Air = preload("res://scripts/roguelike/linger_colossus_air.gd")
const RunFeatures = preload("res://scripts/roguelike/run_features.gd")
const LaunchArgs = preload("res://scripts/launch_args.gd")
const LayerPlan = preload("res://scripts/roguelike/layer_plan.gd")
const EnemyYard = preload("res://studies/enemy_yard.gd")

## The stages' times (s from the layer's start).
const RISE_AT := 60.0
const STIR := 8.0
const RISEN_AT := 120.0
const INHALE_AT := 126.0
const EVERY := 22.0
const TOWER_AT := 240.0
## How much of him stands over the cloud (in his head heights, crown down):
## hidden, risen (head and shoulders), towering (to the chest; stage 3's).
const HIDDEN_R := -0.2
const RISEN_R := 1.45
const TOWER_R := 1.75
## The rise comes in heaves: this many between RISE_AT and RISEN_AT, each
## SURGE s (a sink, the heave up past, the settle), carrying this share of
## the rise (the rest a slow creep, so he is never quite still).
const SURGES := 6
const SURGE := 3.4
const SURGE_SHARE := 0.75
## His figure: the crown over the feet in head heights (the body's seat at
## SEAT_Y plus the head), and the head's share of the stone's height.
const CROWN := 3.05
## The inhale: the tell, the draw, the letting go (s).
const TELL := 3.6
const DRAW := 4.2
const RELEASE := 1.8
## The pull (times the wanderer's run, m/s), braced crouched, sheltered,
## in the air; the time unbraced at a full draw before he is torn off his
## feet, the fling then (times his run, and up in m).
const PULL := 0.95
const BRACE := 0.12
const SHELTERED := 0.08
const AIR_PULL := 1.4
const TRIP := 1.0
const FLING := 1.2
const FLING_UP := 1.6
## Stone this near (m) between him and the colossus shelters him.
const SHELTER := 16.0
## His head's height (m), how far off the isles' reach he stands (head
## heights), abreast of which share of the way, and his eyes risen over the
## start (head heights), the eyes under the crown (head heights).
const SIZE := 170.0
const OFF := 1.7
const ALONG := 0.3
const EYES_OVER := -0.3
const EYES_DOWN := 0.45
## The eyes: lit at rest once risen, and at the tell's height (dim, warm).
const EYE_REST := 0.22
const EYE_TELL := 0.65
const EYE_ENERGY := 1.6
## How fast his head turns after the wanderer (rad/s), and how far.
const TURN_RATE := 0.06
const TURN_MOST := 0.7
## The tremble on the eye at a heave (m of the camera's offset).
const SHAKE := 0.12

var study: Node3D
var layer: Dictionary
## The clock (s since the layer began, plus --linger-at).
var t := 0.0
## How much of him stands over the cloud now (head heights).
var risen := HIDDEN_R
## The draw's share now (0..1), the stage's name.
var drawing := 0.0
var stage := 0
## The wanderer's pull this frame (m/s), whether sheltered; counts for tests.
var pulling := 0.0
var sheltered := false
var flung := 0
## Where he stands (x, z at his feet), the deck, his head's height.
var at := Vector3.ZERO
var deck_y := 0.0
var size := 100.0
var facing := 0.0

var body: Node3D
var head: Node3D
var cloud: MultiMeshInstance3D
var air: Node3D
var _strain := 0.0
var _head_yaw := 0.0
var _surge_heard := -1
var _stirred := false
var _breath := -1
var _shake := 0.0
var _bed: AudioStreamPlayer
var _breath_player: AudioStreamPlayer
var _rng := RandomNumberGenerator.new()
var _ray := PhysicsRayQueryParameters3D.new()
var _drawn := true
var _knobs := {}

## Whether the colossus is the linger this run.
static func wanted() -> bool:
	return RunFeatures.on(&"linger") and arg("linger","") == "colossus"

## A launch flag's value (the run's features' read, or the scene's own).
static func arg(name: String, fallback := "") -> String:
	var v := RunFeatures.value(name,"")
	if v != "": return v
	for a: String in LaunchArgs.user_args():
		if a.begins_with("--%s=" % name): return a.get_slice("=",1)
	return fallback

## Laid on `stage` for `plan` if wanted (else null): reset with the stage.
static func lay(scene: Node3D, on_stage: Node3D, plan: Dictionary) -> Node3D:
	if not wanted() or on_stage == null or plan.is_empty(): return null
	var c: Node3D = new()
	c.name = "LingerColossus"
	on_stage.add_child(c)
	c.setup(scene,plan)
	return c

func setup(scene: Node3D, plan: Dictionary) -> void:
	study = scene
	layer = plan
	_drawn = DisplayServer.get_name() != "headless"
	_rng.seed = int(plan.get("seed",1))*7+3
	t = float(arg("linger-at","0"))
	_knobs.pull = float(arg("linger-pull",str(PULL)))
	_place()
	_build()
	_pose(0.0)
	print("linger: the colossus stands %.0f m off, head %.0f m, deck %.0f (clock from %.0f s)" % [Vector2(at.x-_middle().x,at.z-_middle().z).length(),size,deck_y,t])

# --- Where he stands ----------------------------------------------------------------

var _mid := Vector3.ZERO
func _middle() -> Vector3:
	return _mid

## Off the layer's flank, broadside to its way (start to gate), on the side
## its isles reach least; his deck low under the isles, his head sized so
## that, risen, his eyes are about the way's middle height.
func _place() -> void:
	var lo := Vector3(INF,INF,INF)
	var hi := -lo
	for isle: Dictionary in layer.get("isles",[]):
		var r: Rect2 = LayerPlan._rect(isle)
		var s: Vector2 = LayerPlan._span(isle)
		lo = lo.min(Vector3(r.position.x,s.x,r.position.y))
		hi = hi.max(Vector3(r.end.x,s.y,r.end.y))
	var start: Vector3 = (layer.spawn as Dictionary).get("at",LayerPlan.MIDDLE)
	var exit_at: Vector3 = (layer.get("exit",{}) as Dictionary).get("at",start+Vector3.FORWARD*100.0)
	_mid = (start+exit_at)*0.5
	var way := Vector3(exit_at.x-start.x,0.0,exit_at.z-start.z)
	way = way.normalized() if way.length() > 1.0 else Vector3.FORWARD
	var side := Vector3(-way.z,0.0,way.x)
	# How far the isles reach out each side of the way.
	var reach_l := 0.0
	var reach_r := 0.0
	for isle: Dictionary in layer.get("isles",[]):
		var r: Rect2 = LayerPlan._rect(isle)
		for corner: Vector2 in [r.position,r.end,Vector2(r.position.x,r.end.y),Vector2(r.end.x,r.position.y)]:
			var d := Vector3(corner.x-_mid.x,0.0,corner.y-_mid.z).dot(side)
			reach_l = maxf(reach_l,d)
			reach_r = maxf(reach_r,-d)
	var sign_side := 1.0 if reach_l <= reach_r else -1.0
	var reach := minf(reach_l,reach_r)
	size = SIZE
	if arg("linger-size") != "": size = float(arg("linger-size"))
	# Risen, his eyes a little over the start's height: from the start he
	# looms at eye level, and as the way climbs he is below and still seen
	# (the play camera looks down).
	deck_y = start.y+EYES_OVER*size-(RISEN_R-EYES_DOWN)*size
	var off := reach+size*OFF
	if arg("linger-off") != "": off = reach+float(arg("linger-off"))
	# Abreast of the way's first third, ahead of the start on its flank.
	var along := start.lerp(exit_at,ALONG)
	at = Vector3(along.x,0.0,along.z)+side*sign_side*off
	at.y = deck_y
	# Facing the way's middle.
	var to := Vector3(along.x,0.0,along.z)-at
	facing = atan2(-to.x,-to.z)

# --- His figure ---------------------------------------------------------------------

func _build() -> void:
	top_level = true
	body = BodyLook.new()
	body.name = "Body"
	add_child(body)
	body.build(size/BodyLook.HH)
	head = HeadLook.new()
	head.name = "Head"
	add_child(head)
	head.build(size,int(layer.get("seed",7)))
	for g: GeometryInstance3D in find_children("*","GeometryInstance3D",true,false):
		g.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		g.extra_cull_margin = size
	var env := _env()
	var fog := env.fog_light_color if env != null else Color(0.75,0.78,0.82)
	var light := fog.lerp(Color(0.92,0.9,0.86),0.55)
	var shade := fog.lerp(Color(0.3,0.31,0.36),0.45)
	cloud = Cloud.new()
	cloud.name = "Cloud"
	add_child(cloud)
	cloud.setup(at,deck_y,size,light,shade,int(layer.get("seed",1)),Vector3(-sin(facing),0.0,-cos(facing)))
	air = Air.new()
	air.name = "Air"
	add_child(air)
	air.setup(study,_drawn)
	if _drawn:
		_bed = AudioStreamPlayer.new()
		_bed.stream = load("res://assets/audio/foley/land-bed-loop.wav")
		_bed.pitch_scale = 0.45
		_bed.volume_db = -80.0
		add_child(_bed)
		_breath_player = AudioStreamPlayer.new()
		_breath_player.stream = EnemyYard._synth([TELL+DRAW+0.6,0.0,0.0,1.0,0.035,TELL*0.85,0.0])
		_breath_player.volume_db = -4.0
		add_child(_breath_player)

func _env() -> Environment:
	var world := study.get_world_3d() if study != null else null
	if world != null and world.environment != null: return world.environment
	var cam := study.get_viewport().get_camera_3d() if study != null else null
	if cam != null and cam.environment != null: return cam.environment
	return null

# --- The clock ----------------------------------------------------------------------

## How far over the cloud he stands at clock `when` (head heights).
static func risen_at(when: float) -> float:
	if when < RISE_AT: return HIDDEN_R
	if when < RISEN_AT:
		var k := (when-RISE_AT)/(RISEN_AT-RISE_AT)
		var creep := k*(1.0-SURGE_SHARE)
		var surged := 0.0
		var gap := (RISEN_AT-RISE_AT)/SURGES
		for i in range(SURGES):
			var s := (when-RISE_AT-gap*i)/SURGE
			surged += _surge_curve(s)
		return lerpf(HIDDEN_R,RISEN_R,creep+surged*SURGE_SHARE/SURGES)
	var k2 := clampf((when-RISEN_AT)/(TOWER_AT-RISEN_AT),0.0,1.0)
	return lerpf(RISEN_R,TOWER_R,k2*k2*(3.0-2.0*k2))

## A heave's share made at `s` (0..1 of SURGE): a sink first, the heave up
## past its mark, the settle.
static func _surge_curve(s: float) -> float:
	if s <= 0.0: return 0.0
	if s >= 1.0: return 1.0
	if s < 0.2: return -0.06*sin(s/0.2*PI*0.5)
	if s < 0.7:
		var u := (s-0.2)/0.5
		return lerpf(-0.06,1.08,1.0-pow(1.0-u,3.0))
	var v := (s-0.7)/0.3
	return lerpf(1.08,1.0,v*v*(3.0-2.0*v))

## The inhale's place at `when`: [index, seconds into it] (index -1 none).
static func breath_at(when: float) -> Array:
	if when < INHALE_AT: return [-1,0.0]
	var i := int(floor((when-INHALE_AT)/EVERY))
	return [i,when-INHALE_AT-EVERY*i]

## The draw's share `into` s into an inhale: the tell's slow build, the
## draw full, let go.
static func draw_share(into: float) -> float:
	if into < TELL: return 0.0
	var d := into-TELL
	if d < 0.5: return smoothstep(0.0,0.5,d)
	if d < DRAW: return 1.0
	return 1.0-smoothstep(DRAW,DRAW+RELEASE,d)

## The tell's share (0..1): the head tipping back, the cloud streaming.
static func tell_share(into: float) -> float:
	if into < TELL: return smoothstep(0.0,TELL,into)
	if into < TELL+DRAW: return 1.0
	return 1.0-smoothstep(TELL+DRAW,TELL+DRAW+RELEASE,into)

# --- A frame ------------------------------------------------------------------------

func tick(delta: float) -> void:
	t += delta
	risen = risen_at(t)
	stage = 0 if t < RISE_AT else (1 if t < INHALE_AT else 2)
	var b := breath_at(t)
	var into: float = b[1]
	var tell := tell_share(into) if int(b[0]) >= 0 else 0.0
	drawing = draw_share(into) if int(b[0]) >= 0 else 0.0
	if int(b[0]) != _breath and int(b[0]) >= 0:
		_breath = int(b[0])
		if _breath_player != null: _breath_player.play()
	_sound(delta)
	_pose(delta,tell)
	var m: Variant = study.get("motor")
	var feet: Vector3 = m.feet if m != null else _mid
	var toward := Vector3(at.x-feet.x,0.0,at.z-feet.z).normalized()
	cloud.step(delta,head.mouth(),maxf(tell*0.6,drawing))
	air.step(delta,feet,toward,maxf(tell*0.55,drawing))
	_pull(delta,toward)
	_tremble(delta)
	stage3(delta)

## Stage 3 (round 2): his hands up out of the cloud on to the isles, small
## Olmecs answering his call. Hooks in here, past TOWER_R's rise.
func stage3(_delta: float) -> void:
	pass

func _pose(delta: float, tell := 0.0) -> void:
	visible = risen > HIDDEN_R-0.05 or t > RISE_AT-STIR
	var feet_y := deck_y+(risen-CROWN)*size
	body.position = Vector3(at.x,feet_y,at.z)
	body.rotation = Vector3(0.0,facing,0.0)
	body.want("idle",fposmod(t,float(body.lengths.idle)))
	body.advance(maxf(delta,0.0001),0.5)
	# The tell: his chest drawn up and back, the head tipping back with it.
	body.pitch("chest",-0.1*tell)
	body.pitch("spine",-0.05*tell)
	# His head after the wanderer, slowly; locked on through the tell.
	var m: Variant = study.get("motor")
	if m != null:
		var to: Vector3 = (m.feet as Vector3)-at
		var want := wrapf(atan2(-to.x,-to.z)-facing,-PI,PI)
		want = clampf(want,-TURN_MOST,TURN_MOST)
		var rate := TURN_RATE*(1.0+tell*2.0)
		_head_yaw = move_toward(_head_yaw,want,rate*delta) if delta > 0.0 else want
	var seat: Transform3D = body.seat()
	var turn := seat.basis.orthonormalized()*Basis(Vector3.UP,_head_yaw)*Basis(Vector3.RIGHT,0.16*tell)
	head.global_transform = Transform3D(turn,seat.origin)
	head.open(0.15*tell+0.85*drawing*0.9)
	var lit := (EYE_REST if risen > 0.5 else 0.0)+(EYE_TELL-EYE_REST)*tell
	head.glow(lit)
	head._eye_mat.emission_energy_multiplier = EYE_ENERGY*lit
	head._eye_mat.albedo_color = HeadLook.EYE_STONE.lerp(HeadLook.EYE_LIT,lit*0.4)

# --- The pull -----------------------------------------------------------------------

func _pull(delta: float, toward: Vector3) -> void:
	pulling = 0.0
	sheltered = false
	var m: Variant = study.get("motor")
	if m == null or drawing <= 0.0 or bool(study.get("flying")):
		_strain = maxf(0.0,_strain-delta)
		return
	if m.rider != null or m.swimming or m.seized(): return
	var chest: Vector3 = (m.feet as Vector3)+Vector3.UP*float(study.ground.head_top)*0.55
	sheltered = _shelter(chest,toward)
	var p: float = float(_knobs.pull)*float(m.run)*drawing*(SHELTERED if sheltered else 1.0)
	if m.on_ledge():
		# Hanging from a rim he holds.
		_strain = 0.0
		return
	if m.grounded and m.move != "tumble":
		var braced: bool = m.crouch
		if braced: p *= BRACE
		pulling = p
		var flat := Vector2(toward.x,toward.z)*p*delta
		var dest: Vector3 = study.ground.slide(m.feet,flat)
		m.carry(Transform3D(Basis.IDENTITY,Vector3(dest.x-m.feet.x,0.0,dest.z-m.feet.z)),0.0)
		if not braced and not sheltered and drawing > 0.7: _strain += delta
		else: _strain = maxf(0.0,_strain-delta*2.0)
		if _strain >= TRIP:
			_strain = 0.0
			flung += 1
			m.knock(toward*float(m.run)*FLING+Vector3.UP*sqrt(2.0*float(m.gravity)*FLING_UP),self)
			m.harm("olmec",1,self)
	else:
		pulling = p
		m.velocity += toward*p*AIR_PULL*delta

## Stone between him and the colossus, near: out of the draw. Looked for
## flat at his chest (his mouth may stand far under the isle's turf, and
## the turf itself is no shelter), and a little higher, so a wall to the
## shoulder shelters him crouched or standing.
func _shelter(chest: Vector3, toward: Vector3) -> bool:
	_ray.collision_mask = WalkerOnly.strip(study.ground.mask)
	var space := study.get_world_3d().direct_space_state
	for up: float in [0.0,0.5]:
		_ray.from = chest+Vector3.UP*up
		_ray.to = _ray.from+toward*SHELTER
		if space.intersect_ray(_ray).is_empty(): return false
	return true

# --- The rumble ----------------------------------------------------------------------

func _sound(_delta: float) -> void:
	# Before he comes, the cloud bank stirs and the deep rumble begins.
	if not _stirred and t >= RISE_AT-STIR:
		_stirred = true
		cloud.heave(0.5)
		_lurch(0.6)
	var gap := (RISEN_AT-RISE_AT)/SURGES
	var i := int(floor((t-RISE_AT)/gap)) if t >= RISE_AT else -1
	# The heaves: one at each of the rise's, and smaller on through stage 2.
	if t >= RISEN_AT: i = SURGES+int(floor((t-RISEN_AT)/(EVERY*0.5)))
	if i != _surge_heard and i >= 0 and t < TOWER_AT:
		_surge_heard = i
		cloud.heave(1.0 if i < SURGES else 0.4)
		_lurch(1.0 if i < SURGES else 0.5)
		_shake = maxf(_shake,1.0 if i < SURGES else 0.4)
	if _bed != null:
		var want := 0.0
		if t >= RISE_AT-STIR and t < RISEN_AT+4.0: want = 0.7
		elif t >= RISEN_AT: want = 0.25
		var gain := want+_shake*0.3
		_bed.volume_db = linear_to_db(maxf(gain,0.0001))-4.0
		if gain > 0.01 and not _bed.playing: _bed.play()
		elif gain <= 0.01 and _bed.playing: _bed.stop()

func _lurch(strength: float) -> void:
	if not _drawn: return
	var p := AudioStreamPlayer.new()
	p.stream = load("res://assets/audio/foley/land-lurch-%d.wav" % _rng.randi_range(1,6))
	p.pitch_scale = _rng.randf_range(0.45,0.55)
	p.volume_db = linear_to_db(clampf(strength,0.05,1.0))
	add_child(p)
	p.finished.connect(p.queue_free)
	p.play()

## The ground's tremble on the eye at a heave (the camera's own offsets).
func _tremble(delta: float) -> void:
	_shake = move_toward(_shake,0.0,delta*0.5)
	var cam := study.get_viewport().get_camera_3d()
	if cam == null: return
	var s := _shake*_shake*SHAKE
	cam.h_offset = sin(t*37.0)*s
	cam.v_offset = sin(t*29.0+1.3)*s*0.7

func _exit_tree() -> void:
	var cam := study.get_viewport().get_camera_3d() if study != null and study.is_inside_tree() else null
	if cam != null:
		cam.h_offset = 0.0
		cam.v_offset = 0.0
