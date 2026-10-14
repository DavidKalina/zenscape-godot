extends Node3D
## A treasure chest the pilot opens (docs/design/roguelike/chest-round1.md):
## the kit's carved chest (RuinKit `tomb_chest`, its base without the lid),
## and a lid of the same stone on a hinge along the back edge.
##
## - **Closed.** It stands as a prop, its lid a stone slab (the lid has
##   collision, the base too: he can jump on it). Knobs: `runes` (how many
##   it spills), `locked` (a press only rattles it; a hard slam on the lid
##   breaks it open: scripts/slam.gd, the same `Slam.decent()` drop that
##   opens a buried find) and `loud` (how big a noise it makes, 1 = the
##   "big spike" of ideas-dragon.md's greed table).
## - **Opening** (`open`; the field calls it on a press or a slam). A wind-up
##   (WINDUP s): the lid cocks a crack open with a tremble, the body
##   squashes a touch. Then it flings back (SWING s, eased out past its
##   rest), settles with a damped bounce (SETTLE s) and stays open, a warm
##   glow breathing in the mouth. The noise goes out as the swing starts
##   (`opened`), and the runes are tossed out of the mouth a beat later.
## - **Spill.** Each rune is the sky's rune pickup (scripts/glyph_pickup.gd,
##   calm) thrown on an arc to a spot in front of the chest on the ground,
##   one after another (SPILL_GAP s). Once landed it is taken like any
##   foot rune (the walker's reach along the way he moved). `rune_taken`
##   goes out per rune with the number still lying: the run counts it
##   (RunState.take_rune) as for the generator's rune set.
## - **Open.** `state` "open" is final: closing is only `close()` for a
##   study's restart.
##
## Driven by `advance(delta)` (the field's `before`), so it ticks with the
## study's frames and a headless run is deterministic.
const RuinKit = preload("res://scripts/ruin_kit.gd")
const GlyphPickup = preload("res://scripts/glyph_pickup.gd")
const BuriedFind = preload("res://scripts/buried_find.gd")
const Lines = preload("res://scripts/collectible_lines.gd")
const Slam = preload("res://scripts/slam.gd")

## At the swing's start: the noise (world point of the chest, loudness),
## how it was opened ("press", "slam").
signal opened(at: Vector3, loud: float, how: String)
## A press on a locked chest.
signal rattled(at: Vector3)
## A rune taken: how many still lie (or are yet to be thrown).
signal rune_taken(left: int)

## The model's size against the kit's tomb chest (2.3 x 1.05 x 0.95 m),
## so it reads as a chest, not a sarcophagus.
const MODEL_SCALE := 0.65
## Seconds: the wind-up, the swing back, the settle; the toss of the first
## rune after the swing starts, between runes, and one rune's flight.
const WINDUP := 0.26
const SWING := 0.22
const SETTLE := 0.55
const SPILL_AT := 0.1
const SPILL_GAP := 0.07
const FLIGHT := Vector2(0.5,0.7)
## The lid's angle (deg, about the hinge, negative = up and back): the wind-up's
## crack, the swing's overshoot, where it rests.
const CRACK := -7.0
const OVERSHOOT := -122.0
const REST := -108.0
## Metres (the model's, times MODEL_SCALE): the arc's height, where the runes
## land (radius range in front, spread in degrees either side of straight
## ahead), and how high they hover over the ground they land on.
const ARC := 1.5
const LAND := Vector2(1.0,1.9)
const FAN := 110.0
const HOVER := 0.55
## The rattle of a locked chest (s).
const RATTLE := 0.3
const RUNE_SIZE := 0.7
const GLOW := Color(1.0,0.82,0.45)

## The knobs.
var runes := 5
var locked := false
var loud := 1.0
var seed_value := 0
var weathered := 0.25

## "closed", "opening", "open".
var state := "closed"
## Seconds since it began to open.
var t := 0.0
## How it was opened ("" closed).
var how := ""
## The runes in flight or lying, as {holder, from, to, t0, dur, landed}, and
## how many are yet to be thrown (in `_queue`).
var live: Array[Dictionary] = []
var thrown := 0
var taken := 0
## A Callable(Vector3) -> float, the ground's height under a point (INF where
## there is none); the field sets it from the study's ground.
var ground_at := Callable()

var model: Node3D
var base: Node3D
var hinge: Node3D
var lid_body: StaticBody3D
var glow: MeshInstance3D
var _glow_material: StandardMaterial3D
var _rattle := -1.0
var _last := Vector3.INF
var _player: AudioStreamPlayer3D

## Applies the knobs {runes, locked, loud, seed, weathered}.
func configure(knobs: Dictionary) -> void:
	runes = int(knobs.get("runes",runes))
	locked = bool(knobs.get("locked",locked))
	loud = float(knobs.get("loud",loud))
	seed_value = int(knobs.get("seed",seed_value))
	weathered = float(knobs.get("weathered",weathered))

## The model built (once): call after `configure` and before the chest is
## added to the tree.
func build() -> void:
	name = "TreasureChest"
	model = Node3D.new()
	model.name = "Model"
	model.scale = Vector3.ONE*MODEL_SCALE
	add_child(model)
	base = RuinKit.tomb_chest(seed_value,weathered,false)
	base.name = "Base"
	model.add_child(base)
	# The lid, of the same stone (the same label seeds the same tint), on a
	# hinge along its back edge.
	var half := Vector3(RuinKit.CHEST.x*0.5+0.07,RuinKit.CHEST.w*0.5,RuinKit.CHEST.y*0.5+0.07)
	var b := RuinKit.Build.new(seed_value,weathered*0.5,"Chest")
	var planes := RuinKit._box(b,half,0.02)
	for s: float in [-1.0,1.0]:
		for axis: Vector3 in [Vector3.BACK,Vector3.RIGHT]:
			var n := (axis*s+Vector3.UP*0.9).normalized()
			planes.append(Plane(n,n.dot(axis*s*(half.dot(axis.abs()))+Vector3.UP*(half.y-0.1))))
	b.solid(planes,Transform3D.IDENTITY,RuinKit._stone(b,1.05))
	var lid := b.finish()
	lid.name = "Lid"
	lid.position = Vector3(0.0,half.y,half.z)
	hinge = Node3D.new()
	hinge.name = "Hinge"
	hinge.position = Vector3(0.0,RuinKit.CHEST.z-RuinKit.CHEST.w,-half.z)
	hinge.add_child(lid)
	model.add_child(hinge)
	lid_body = lid.get_node("Body") as StaticBody3D
	# The warm light in the mouth, shown as the lid goes up.
	_glow_material = BuriedFind._glow_material()
	_glow_material.albedo_color = Color(GLOW,0.0)
	glow = MeshInstance3D.new()
	glow.name = "Glow"
	var disc := QuadMesh.new()
	disc.size = Vector2(RuinKit.CHEST.x*0.9,RuinKit.CHEST.y*1.5)
	disc.orientation = PlaneMesh.FACE_Y
	glow.mesh = disc
	glow.material_override = _glow_material
	glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	glow.position = Vector3(0.0,RuinKit.CHEST.z-RuinKit.CHEST.w+0.04,0.0)
	glow.visible = false
	model.add_child(glow)

# --- The size, as the field asks ------------------------------------------------

## Half the footprint (m, flat: x along the chest, z across), world size.
func half_extents() -> Vector2:
	return Vector2(RuinKit.CHEST.x,RuinKit.CHEST.y)*0.5*MODEL_SCALE

## How far, flat, a world point is from the chest's footprint (0 over it).
func gap(world: Vector3) -> float:
	var local := to_local(world)
	var half := half_extents()
	return Vector2(maxf(absf(local.x)-half.x,0.0),maxf(absf(local.z)-half.y,0.0)).length()

## The lid's top (world y) while shut.
func top() -> float:
	return global_position.y+RuinKit.CHEST.z*MODEL_SCALE

## Where the runes come out: the middle of the mouth, world.
func mouth() -> Vector3:
	return global_transform*Vector3(0.0,(RuinKit.CHEST.z-RuinKit.CHEST.w+0.15)*MODEL_SCALE,0.0)

## The run's rune count for this chest still to come: thrown or lying.
func runes_left() -> int:
	return (runes-thrown)+live.size()

# --- Opening ----------------------------------------------------------------------

## A press on the chest: opens it, or, locked, only rattles it. Returns
## whether it began to open.
func press() -> bool:
	if state != "closed": return false
	if locked:
		if _rattle < 0.0:
			_rattle = 0.0
			rattled.emit(global_position)
		return false
	return open("press")

## Opens it (a slam, or a press on one not locked). Returns whether it began.
func open(how_opened := "press") -> bool:
	if state != "closed": return false
	state = "opening"
	how = how_opened
	t = 0.0
	_rattle = -1.0
	locked = false
	# The lid no longer stops anyone once it goes up.
	if lid_body != null: lid_body.collision_layer = 0
	return true

## Back to shut with nothing in the air (a study's restart only).
func close() -> void:
	for r: Dictionary in live:
		if is_instance_valid(r.holder): (r.holder as Node).queue_free()
	live.clear()
	state = "closed"
	how = ""
	t = 0.0
	thrown = 0
	taken = 0
	_last = Vector3.INF
	if lid_body != null: lid_body.collision_layer = 1
	_pose(0.0)

## A slam (scripts/slam.gd) at `blast_at` (world): on the lid, hard enough
## (Slam `decent`), it breaks the lid open, locked or not.
func slam(blast_at: Vector3, _radius: float, strength: float) -> bool:
	if state != "closed" or strength < Slam.decent(): return false
	if gap(blast_at) > 0.4 or absf(blast_at.y-top()) > 1.0: return false
	return open("slam")

# --- A frame ------------------------------------------------------------------------

func advance(delta: float) -> void:
	if delta <= 0.0: return
	if _rattle >= 0.0:
		_rattle += delta
		if _rattle >= RATTLE: _rattle = -1.0
	if state != "closed":
		var before := t
		t += delta
		if before < WINDUP and t >= WINDUP:
			opened.emit(global_position,loud,how)
			_play()
		_toss()
		if state == "opening" and t >= WINDUP+SWING+SETTLE: state = "open"
	_pose(t if state != "closed" else 0.0)
	_fly()

## The runes whose turn has come are thrown.
func _toss() -> void:
	while thrown < runes and t >= WINDUP+SPILL_AT+float(thrown)*SPILL_GAP:
		_throw(thrown)
		thrown += 1

func _throw(i: int) -> void:
	var holder := GlyphPickup.make("rune",RUNE_SIZE,float(i)*1.3,true)
	holder.name = "Rune%d" % i
	add_child(holder)
	var from := mouth()
	holder.global_position = from
	holder.motes_on(true)
	var to := _land(i)
	live.append({"holder":holder,"from":from,"to":to,"t0":t,"dur":lerpf(FLIGHT.x,FLIGHT.y,float(i%3)/2.0),"landed":false})

## Where rune `i` comes down: a fan in front of the chest (the golden angle
## through the fan, the radius stepped), on whatever ground is there.
func _land(i: int) -> Vector3:
	var spread := deg_to_rad(FAN)
	var turn := fposmod(float(i)*0.618034,1.0)
	var angle := (turn*2.0-1.0)*spread
	var reach := lerpf(LAND.x,LAND.y,fposmod(float(i)*0.37+0.2,1.0))*MODEL_SCALE/0.65
	var flat := Vector3(sin(angle),0.0,cos(angle))
	for share: float in [1.0,0.65,0.35]:
		var local := flat*(reach*share+half_extents().y)
		var world := to_global(local)
		var ground := _floor(world)
		if ground > -INF: return Vector3(world.x,ground+HOVER,world.z)
	return Vector3(global_position.x,global_position.y+HOVER+0.4,global_position.z)+global_transform.basis.z*0.8

func _floor(p: Vector3) -> float:
	if not ground_at.is_valid(): return global_position.y
	var y: float = ground_at.call(p)
	return y if is_finite(y) else -INF

func _fly() -> void:
	for r: Dictionary in live:
		if r.landed or not is_instance_valid(r.holder): continue
		var u := clampf((t-float(r.t0))/float(r.dur),0.0,1.0)
		var holder: Node3D = r.holder
		var from: Vector3 = r.from
		var to: Vector3 = r.to
		holder.global_position = from.lerp(to,u)+Vector3.UP*(4.0*ARC*MODEL_SCALE/0.65*u*(1.0-u))
		if u >= 1.0: r.landed = true

## The lid, the squash, the glow, at `s` seconds into the opening.
func _pose(s: float) -> void:
	if hinge == null: return
	var angle := 0.0
	var squash := 1.0
	var glow_a := 0.0
	if state == "closed":
		# A locked chest's rattle: the lid jumps a hair, twice over.
		if _rattle >= 0.0:
			var k := _rattle/RATTLE
			angle = -2.2*sin(k*TAU*2.0)*(1.0-k)
			model.rotation.z = 0.012*sin(k*TAU*3.0)*(1.0-k)
		else:
			model.rotation.z = 0.0
	else:
		model.rotation.z = 0.0
		if s < WINDUP:
			# Wind-up: a tremble, the lid cocking open a crack, the body down a touch.
			var u := s/WINDUP
			angle = CRACK*u*u+0.9*sin(u*TAU*3.0)*(1.0-u)
			squash = 1.0-0.035*sin(u*PI)
		elif s < WINDUP+SWING:
			var u := (s-WINDUP)/SWING
			var e := 1.0-pow(1.0-u,3.0)
			angle = lerpf(CRACK,OVERSHOOT,e)
			squash = 1.0+0.03*sin(u*PI)
			glow_a = 0.55*u
		else:
			var r := s-WINDUP-SWING
			var d := exp(-6.0*r)*cos(r*13.0)
			angle = REST+(OVERSHOOT-REST)*d
			glow_a = lerpf(0.55,0.32,clampf(r/SETTLE,0.0,1.0))
		if state == "open":
			angle = REST
			glow_a = 0.3+0.06*sin(Time.get_ticks_msec()/1000.0*2.0)
	hinge.rotation.x = deg_to_rad(angle)
	model.scale = Vector3(1.0,squash,1.0)*MODEL_SCALE if squash != 1.0 else Vector3.ONE*MODEL_SCALE
	if glow != null:
		glow.visible = glow_a > 0.001
		_glow_material.albedo_color = Color(GLOW,glow_a)

# --- Runes taken -----------------------------------------------------------------------

## The runes the pilot's middle swept past since the last call, the way the
## kit tokens and the generator's rune set take theirs. Returns how many.
func touch(point: Vector3) -> int:
	if point == Vector3.INF:
		_last = Vector3.INF
		return 0
	var from := _last if _last != Vector3.INF and _last.distance_to(point) <= 6.0 else point
	_last = point
	var n := 0
	for r: Dictionary in live.duplicate():
		var holder: Node3D = r.holder
		if not r.landed or not is_instance_valid(holder) or holder.taking: continue
		var near := Geometry3D.get_closest_point_to_segment(holder.global_position,from,point)
		if near.distance_to(holder.global_position) < Lines.WALKER_REACH+RUNE_SIZE*0.5:
			live.erase(r)
			holder.take(hash(holder.name) & 0xffff)
			taken += 1
			n += 1
			rune_taken.emit(runes_left())
	return n

# --- The noise -----------------------------------------------------------------------------

static var _clip: AudioStreamWAV

## The creak, the clack of the lid and the spill's jingle, once (greed is
## loud: it carries).
static func clip() -> AudioStreamWAV:
	if _clip != null: return _clip
	var rate := 22050
	var length := 1.1
	var data := PackedByteArray()
	var n := int(rate*length)
	data.resize(n*2)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in range(n):
		var s := float(i)/rate
		var v := 0.0
		# The hinge's creak: a rough rising tone.
		if s < 0.36:
			var f := 95.0+s*260.0
			var saw := fposmod(s*f,1.0)*2.0-1.0
			v += (saw*0.5+rng.randf_range(-0.35,0.35))*sin(PI*s/0.36)*0.55
		# The lid's clack on its stop: a short low knock.
		if s >= 0.26:
			var k := s-0.26
			v += sin(TAU*(70.0-60.0*k)*k)*exp(-k*14.0)*0.9
			v += rng.randf_range(-1.0,1.0)*exp(-k*60.0)*0.5
		# The jingle: a few high pings.
		for j in range(5):
			var at := 0.42+float(j)*0.07
			if s >= at:
				var k := s-at
				var f := 1500.0+float((j*7)%5)*330.0
				v += sin(TAU*f*k)*exp(-k*9.0)*0.28
		var q := int(clampf(v,-1.0,1.0)*32000.0)
		data.encode_s16(i*2,q)
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = rate
	wav.stereo = false
	wav.data = data
	_clip = wav
	return wav

func _play() -> void:
	if not is_inside_tree(): return
	_player = AudioStreamPlayer3D.new()
	_player.stream = clip()
	_player.unit_size = 14.0*maxf(loud,0.1)
	_player.volume_db = 3.0
	add_child(_player)
	_player.position = Vector3(0.0,0.5,0.0)
	_player.finished.connect(_player.queue_free)
	_player.play()
