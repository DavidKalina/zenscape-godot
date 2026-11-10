extends Node3D
## The curtain's punch and its voice (kind `curtain`, scripts/endless/kinds/
## curtain.gd), a child of the curtain's root in the piece's own frame.
##
## The punch: each frame the plane is within REACH m, its point in the piece's
## frame is tested against the falling sheet (the lip, falling out along
## `out` as a thrown body: `throw` m/s off the lip, so sqrt(2 drop / g) s
## later it is that many metres out). The plane crossing it, either way,
## between the pool and the lip and within the sheet's half-width (and
## SIDE_PAD), is a punch: the skin's `punch` says what happens (the waterfall:
## a spray burst, the screen wet, a splash). The sheet has no collider.
##
## The voice: the skin's `voice()` names a looping clip; it plays from the
## sheet's foot, louder the nearer the plane, on the bore's bus (so the stone
## room's reverb takes it in the cave when the flight's in a bore), and
## inside the space behind it drops (INSIDE_GAIN of it) and deepens
## (INSIDE_PITCH): the roar becomes a hollow boom.

const Land = preload("res://scripts/endless/kinds/curtain_land.gd")
const FlightSound = preload("res://scripts/endless/flight_sound.gd")
## How near (m, in the piece's frame) the plane must be for the test.
const REACH := 260.0
## How far past the sheet's side a crossing still counts (m).
const SIDE_PAD := 1.5
## The voice: heard VOICE_REACH m off, fading in squared; inside the space
## behind, INSIDE_GAIN of its gain at INSIDE_PITCH of its pitch.
const VOICE_REACH := 520.0
const INSIDE_GAIN := 0.45
const INSIDE_PITCH := 0.6
const G := 9.81

## The sheet (curtain.gd `sheet_of`), the land's shape (curtain_land.gd
## shape_of), the skin's script (null: no skin), the site's handle.
var sheet: Dictionary
var shape: PackedFloat32Array
var skin: GDScript
var handle := ""
## Public for probes: punches so far, the last one ({at, way, k, frame}),
## whether the plane is in the space behind, the voice's goal.
var punches := 0
var last_punch := {}
var inside := false
var voice_goal := 0.0
var _game: Node
var _was := NAN
var _voice: RefCounted
var _voice_def := {}

func _ready() -> void:
	if skin != null: _voice_def = skin.voice()

## The flight this curtain is in: the ancestor with a plane and `wet` (looked
## for each frame until found: the placed sites build before the plane is).
func _find_game() -> Node:
	var n := get_parent()
	while n != null and not (n.has_method("wet") and n.get("plane") != null): n = n.get_parent()
	return n

func _exit_tree() -> void:
	if _voice != null: _voice.set("goal",0.0)

func _process(_delta: float) -> void:
	if _game == null: _game = _find_game()
	if _game == null: return
	var plane: Variant = _game.get("plane")
	if plane == null: return
	var p: Vector3 = plane.position
	var q := global_transform.affine_inverse()*p
	var lip: Vector3 = sheet.lip
	var out: Vector3 = sheet.out
	var pool: Vector3 = sheet.pool
	var rel := q-lip
	var along := Vector2(rel.x,rel.z).dot(Vector2(out.x,out.z).normalized())
	var across := Vector2(rel.x,rel.z).dot(Vector2(-out.z,out.x).normalized())
	_voice_step(p,q)
	if q.length() > REACH:
		_was = NAN
		return
	# + in front of the sheet, - between it and the face.
	var d := along-float(sheet.throw)*sqrt(2.0*maxf(lip.y-q.y,0.0)/G)
	var on := absf(across) < float(sheet.half)+SIDE_PAD and q.y > pool.y-1.0 and q.y < lip.y+1.0
	if on and not is_nan(_was) and signf(d) != signf(_was): _punch(p,plane.velocity,across)
	_was = d if on else NAN

func _punch(at: Vector3, way: Vector3, across: float) -> void:
	var k := 1.0-0.4*smoothstep(0.5,1.0,absf(across)/maxf(float(sheet.half),0.1))
	punches += 1
	last_punch = {"at":at,"way":way,"k":k,"frame":Engine.get_process_frames()}
	if skin != null: skin.punch(get_parent(),at,way,k,_game)

## The voice's goal and pitch from where the plane is (world `p`, piece-frame
## `q`).
func _voice_step(p: Vector3, q: Vector3) -> void:
	if _voice_def.is_empty(): return
	var sound: Variant = _game.get("sound")
	if sound == null: return
	if _voice == null:
		# One voice per curtain for the game: a curtain streamed out and back
		# takes its old one up again (the sound keeps every bed it makes).
		var key := StringName("curtain_voice_"+handle.md5_text())
		if (sound as Node).has_meta(key): _voice = (sound as Node).get_meta(key)
		else:
			_voice = sound.bed_in_world(str(_voice_def.clip),FlightSound.BORE)
			(sound as Node).set_meta(key,_voice)
	var foot: Vector3 = to_global(Vector3(sheet.lip.x,sheet.pool.y,sheet.lip.z)+sheet.out*float(sheet.throw)*sqrt(2.0*float(sheet.drop)/G))
	var player: Variant = _voice.get("player")
	if player != null: (player as Node3D).global_position = foot
	var near := clampf(1.0-p.distance_to(foot)/VOICE_REACH,0.0,1.0)
	var gain := float(_voice_def.gain)*near*near
	var pitch := float(_voice_def.pitch)
	inside = false
	if Land.has_cave(shape):
		var tu := Land.cave_at(shape,Vector2(q.x,-q.z))
		inside = tu.x >= 0.0 and tu.x <= Land.cave_length(shape) and absf(tu.y) < shape[Land.I_CAVE_HALF] \
			and p.y < shape[Land.I_CAVE_FLOOR]+shape[Land.I_CAVE_TALL]+1.0
	if inside:
		gain *= INSIDE_GAIN
		pitch *= INSIDE_PITCH
	voice_goal = gain
	_voice.set("goal",gain)
	_voice.set("pitch_goal",pitch)
