extends "res://scripts/enemies/enemy.gd"
## The Weeper (docs/design/roguelike/weeper-round1.md; ideas-enemies.md 6):
## a stone mourner that moves only while the wanderer's camera isn't
## looking at it. Seen, it is frozen stone. Unseen, it closes on him a
## snap at a time, never seen moving: each snap sets it down nearer in a
## new pose (scripts/enemies/weeper_look.gd), nearer and more reaching as it
## comes (mourning, lifting, turning, reaching), with a grinding of stone
## heard where it went and a little dust falling off it there.
##
## Seen (`seen_by`): any of its marks (hem, chest, crown) on the camera's
## screen (grown by SEEN_MARGIN, so a camera swinging round meets it
## frozen) and, past CLEAR_NEAR, not hidden behind stone. Within CLEAR_NEAR
## on screen is seen even behind a pillar: no cheap shots out of what the
## camera's own walls hide.
##
## Its beat, while he is within WAKE (flat, RISE_WAKE up or down) and on his
## feet:
##   - **Snap**: unseen GAP s (jittered), it is set down STEP m nearer
##     along the ground (never over the void, up a wall or through one, at
##     most RISE up or DROP down), to a spot also out of sight, facing him,
##     stopping at the lunge's edge (LUNGE*HOLD_OFF). A snap that can't find
##     such a spot waits.
##   - **Lunge**: within LUNGE of him (on his level, the line between them
##     clear), out of the camera's frame (not merely behind a wall) for
##     LUNGE_BEAT s since its last snap, it is at him: set down at his back
##     in the seize pose and he is shoved on (PilotMotor `knock`, a heart
##     through `harm`), bent toward the nearest rim (EDGE_BEND). A heavy
##     grind the moment it comes into the lunge's reach is its warning.
##   - **Rest**: after a blow it stands REST s whatever he does.
## Fair: it is one stone in one place (each snap a bounded step on the
## ground, two Weepers never on one spot), seen it never moves, and it
## never strikes from where the camera would have shown it.
##
## A prop otherwise: its body is stone he can't walk through or push (it
## stands as heavy as it is), stood on it holds him.

const WeeperLook = preload("res://scripts/enemies/weeper_look.gd")
const EnemyYard = preload("res://studies/enemy_yard.gd")

## Its height, a share over the wanderer's (the pilot's unit).
const TALL := 1.3
## Seen: the screen grown by this share each way; past CLEAR_NEAR m from
## the camera a mark behind stone isn't seen; farther than SEEN_FAR it
## isn't seen at all (fog, the dark).
const SEEN_MARGIN := 0.08
const CLEAR_NEAR := 16.0
const SEEN_FAR := 90.0
## It wakes with him within WAKE m (flat) and RISE_WAKE m up or down.
const WAKE := 32.0
const RISE_WAKE := 8.0
## A snap: unseen GAP s (each one jittered by GAP_JITTER), STEP m at most,
## up RISE or down DROP m at most, the ground sampled every SAMPLE m on the
## way (any hole and it doesn't go that way); tried straight at him, then
## TURNS aside, each at full and at SHORT of the step.
const GAP := 0.75
const GAP_JITTER := 0.2
const STEP := 2.6
const RISE := 1.2
const DROP := 2.6
const SAMPLE := 0.45
const TURNS := [0.0,0.45,-0.45,0.9,-0.9]
const SHORT := 0.55
## The lunge: within LUNGE m (flat, LUNGE_RISE up or down), LUNGE_BEAT s
## unseen since its last snap; it stops short of the lunge at HOLD_OFF of
## it; it lands BEHIND m from his feet.
const LUNGE := 4.6
const LUNGE_RISE := 1.4
const LUNGE_BEAT := 0.9
const HOLD_OFF := 0.8
const BEHIND := 0.9
## The blow: he goes OUT m on, peaking UP m; bent toward the nearest rim
## within EDGE_LOOK m, at most EDGE_BEND rad off the way it came.
const OUT := 4.2
const UP := 0.7
const EDGE_LOOK := 7.0
const EDGE_BEND := 0.9
## Still after a blow (s), and after it first stands (s).
const REST := 3.5
const WAKE_REST := 1.5
## Its poses by how near it stands (m): mourning past the first, lifting,
## turning, reaching inside the last.
const BANDS := [18.0,11.0,6.5]
## Sounds: [seconds, tone (Hz), tone at the end, noise share, low-pass,
## attack, tremolo] (studies/enemy_yard.gd `_synth`); heard to REACH m.
const VOICES := {
	"weeper_grind":[0.55,52.0,40.0,0.82,0.07,0.04,19.0],
	"weeper_near":[1.0,44.0,30.0,0.7,0.05,0.12,11.0],
	"weeper_blow":[0.32,58.0,34.0,0.45,0.18,0.004,0.0],
}
const HEARD := {"weeper_grind":7.0,"weeper_near":10.0,"weeper_blow":12.0}
static var _voices := {}

var look: Node3D
## Whether the camera saw it on the last step; how long it has gone unseen
## since its last snap; snaps and blows, counted.
var seen := false
var unseen_for := 0.0
var snaps := 0
var blows := 0
## The distance to him at its last step (m, flat), for the driver.
var gap_to_him := INF
var stood := false
var _gap := GAP
var _rest := 0.0
var _rng := RandomNumberGenerator.new()
var _near_said := false
var _layer_was := 1

func _size(n: Dictionary) -> void:
	height = float(n.unit)*TALL
	width = height*0.34
	length = height*0.3

func default_knobs(_n: Dictionary) -> Dictionary:
	# `pose`: the pose it is laid in; `still`: never moves (stills, a prop).
	return {"seed":0,"pose":"mourn","still":false}

func harm_cause() -> String:
	return "a Weeper"

func _art(root: Node3D) -> void:
	_rng.seed = hash([int(knobs.get("seed",0)),position])
	look = WeeperLook.new()
	look.name = "Look"
	root.add_child(look)
	look.build(height,int(knobs.get("seed",0)))
	look.pose(str(knobs.pose),_rng,_rng.randf() < 0.5)
	skin.visible = false
	_layer_was = body.collision_layer
	body.collision_layer = 0
	_rest = WAKE_REST
	_gap = GAP+_rng.randf_range(-GAP_JITTER,GAP_JITTER)

# Heavy stone: he can't push it, and it never carries him.
func touch(_m: PilotMotor, _v_pre: Vector3) -> void:
	pass

func bucks() -> bool:
	return false

func tint(_colour: Color) -> void:
	pass

func step(delta: float) -> void:
	if gone: return
	moved = Vector3.ZERO
	var cam := get_viewport().get_camera_3d() if is_inside_tree() else null
	if not stood:
		_stand(cam)
		return
	seen = cam != null and seen_by(cam,position)
	var m: PilotMotor = field.motor
	var to := Vector3(m.feet.x-position.x,0.0,m.feet.z-position.z)
	gap_to_him = to.length()
	_rest = maxf(0.0,_rest-delta)
	# Solid again once its rest after a blow is over.
	if _rest <= 0.0 and body.collision_layer == 0:
		body.collision_layer = _layer_was
		body.force_update_transform()
	if seen:
		unseen_for = 0.0
		return
	unseen_for += delta
	if _rest > 0.0 or cam == null or bool(knobs.still): return
	if gap_to_him > WAKE or absf(m.feet.y-position.y) > RISE_WAKE: return
	# Down or thrown, he is let be: it waits for him to get up.
	if m.recovering() or m.seized(): return
	if gap_to_him <= LUNGE and absf(m.feet.y-position.y) <= LUNGE_RISE and unseen_for >= LUNGE_BEAT and not _framed(cam,position) and _clear_to(m.feet):
		_lunge(m)
		return
	if unseen_for >= _gap and gap_to_him > LUNGE*HOLD_OFF+0.2: _snap(m,cam)

## Stood on the ground under where it was laid, once there is ground (the
## isle stood: it comes with it).
func _stand(_cam: Camera3D) -> void:
	var g: float = field.floor_under(position,3.0,8.0,body.get_rid())
	if g == -INF: return
	position.y = g
	stood = true
	skin.visible = true
	body.collision_layer = _layer_was
	body.force_update_transform()
	var m: PilotMotor = field.motor
	_face(m.feet)

## Whether `cam` would see it standing at `at`: a mark on the (grown)
## screen, in front of it, near enough, and (past CLEAR_NEAR) not behind
## stone.
func seen_by(cam: Camera3D, at: Vector3) -> bool:
	var eye := cam.global_position
	for mark: Vector3 in _marks(at):
		if not _on_screen(cam,mark): continue
		var d := eye.distance_to(mark)
		if d > SEEN_FAR: continue
		if d <= CLEAR_NEAR or _clear_line(eye,mark): return true
	return false

## Whether any mark at `at` is in the camera's frame at all (behind a wall
## or not): it never lunges from there.
func _framed(cam: Camera3D, at: Vector3) -> bool:
	for mark: Vector3 in _marks(at):
		if _on_screen(cam,mark) and cam.global_position.distance_to(mark) <= SEEN_FAR: return true
	return false

func _marks(at: Vector3) -> Array:
	var side := Basis(Vector3.UP,facing)*Vector3(width*0.5,0.0,0.0)
	return [at+Vector3.UP*height*0.08,at+Vector3.UP*height*0.55,at+Vector3.UP*height*0.95,
		at+Vector3.UP*height*0.5+side,at+Vector3.UP*height*0.5-side]

func _on_screen(cam: Camera3D, p: Vector3) -> bool:
	if cam.is_position_behind(p): return false
	var rect := cam.get_viewport().get_visible_rect()
	var s := cam.unproject_position(p)
	var grow := rect.size*SEEN_MARGIN
	return Rect2(rect.position-grow,rect.size+grow*2.0).has_point(s)

func _clear_line(from: Vector3, to: Vector3) -> bool:
	var q := PhysicsRayQueryParameters3D.create(from,to)
	q.collision_mask = WalkerOnly.strip(field.study.ground.mask)
	q.exclude = [body.get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	return hit.is_empty() or (hit.position as Vector3).distance_to(to) < 0.35

## The way to his feet clear of stone at its chest and knees.
func _clear_to(feet: Vector3) -> bool:
	for up: float in [0.35,0.75]:
		var a := position+Vector3.UP*height*up
		var b := feet+Vector3.UP*height*up
		if field.blocked(a,b-a,body.get_rid()): return false
	return true

## Set down nearer him: the first spot of the tries that the ground holds
## and the camera doesn't see.
func _snap(m: PilotMotor, cam: Camera3D) -> void:
	var to := Vector2(m.feet.x-position.x,m.feet.z-position.z)
	var want := minf(STEP,to.length()-LUNGE*HOLD_OFF)
	if want < 0.3: return
	var way := to.normalized()
	for turn: float in TURNS:
		for share: float in [1.0,SHORT]:
			var w := way.rotated(turn)
			var at := _ground_to(Vector3(w.x,0.0,w.y),want*share)
			if at == Vector3.INF: continue
			if seen_by(cam,at): continue
			if _crowded(at): continue
			_move_to(at,m)
			return

## The spot `dist` m along `way` over ground all the way (sampled every
## SAMPLE m, each rise or fall within RISE/DROP of the last, no wall at
## its chest between), or INF.
func _ground_to(way: Vector3, dist: float) -> Vector3:
	var rid := body.get_rid()
	if field.blocked(position+Vector3.UP*height*0.6,way*(dist+width*0.5),rid): return Vector3.INF
	if field.blocked(position+Vector3.UP*float(knobs.wall_probe),way*(dist+width*0.5),rid): return Vector3.INF
	var y := position.y
	var n := maxi(int(ceil(dist/SAMPLE)),1)
	for k in range(1,n+1):
		var p := position+way*dist*float(k)/n
		p.y = y
		var g: float = field.floor_under(p,RISE+0.1,DROP+0.1,rid)
		if g == -INF or g-y > RISE or y-g > DROP: return Vector3.INF
		y = g
	var out := position+way*dist
	out.y = y
	return out

## Another Weeper on that spot.
func _crowded(at: Vector3) -> bool:
	for e in field.enemies:
		if e == self or not is_instance_valid(e) or not (e is Node3D): continue
		if (e as Node3D).position.distance_to(at) < width*2.0: return true
	return false

func _move_to(at: Vector3, m: PilotMotor) -> void:
	var was := position
	position = at
	moved = at-was
	_face(m.feet)
	body.force_update_transform()
	snaps += 1
	unseen_for = 0.0
	_gap = GAP+_rng.randf_range(-GAP_JITTER,GAP_JITTER)
	var d := Vector2(m.feet.x-at.x,m.feet.z-at.z).length()
	gap_to_him = d
	var name_ := "mourn"
	if d < float(BANDS[2]): name_ = "reach"
	elif d < float(BANDS[1]): name_ = "turn"
	elif d < float(BANDS[0]): name_ = "lift"
	look.pose(name_,_rng,_rng.randf() < 0.5)
	look.dust(1.0)
	if d <= LUNGE+0.3 and not _near_said:
		# Into the lunge's reach: the heavy grind, its warning.
		_near_said = true
		_voice(&"weeper_near")
	else: _voice(&"weeper_grind")
	if d > LUNGE+1.5: _near_said = false
	state = "snap"
	state_t = 0.0

func _face(at: Vector3) -> void:
	var flat := Vector2(at.x-position.x,at.z-position.z)
	if flat.length() < 0.01: return
	facing = PilotMotor.facing_of(flat)
	rotation.y = facing

## At him: set down at his back in the seize pose, and he is shoved on,
## bent toward the nearest rim.
func _lunge(m: PilotMotor) -> void:
	var way := Vector2(m.feet.x-position.x,m.feet.z-position.z).normalized()
	var at := m.feet-Vector3(way.x,0.0,way.y)*BEHIND
	var g: float = field.floor_under(at,1.0,2.0,body.get_rid())
	at.y = g if g != -INF else m.feet.y
	var was := position
	position = at
	moved = at-was
	_face(m.feet)
	body.force_update_transform()
	look.pose("seize",_rng,_rng.randf() < 0.5)
	look.dust(1.6)
	_voice(&"weeper_blow")
	_voice(&"weeper_grind")
	var shove := _toward_rim(m.feet,way)
	m.knock(m.knock_velocity(shove,OUT,UP),self)
	m.harm(harm_cause(),1,self)
	hit_pilot.emit(self)
	blows += 1
	_rest = REST
	# Set down between the camera and him: not solid while it rests, so
	# the camera isn't drawn in against its back (its body is the camera's
	# wall too) and the blow reads from the play camera.
	body.collision_layer = 0
	body.force_update_transform()
	unseen_for = 0.0
	_near_said = false
	state = "blow"
	state_t = 0.0

## `way` bent toward the nearest rim (no ground under) within EDGE_LOOK of
## `feet`, at most EDGE_BEND off it.
func _toward_rim(feet: Vector3, way: Vector2) -> Vector2:
	var best := way
	var nearest := INF
	var rid := body.get_rid()
	for k in range(-4,5):
		var turn := EDGE_BEND*float(k)/4.0
		var w := way.rotated(turn)
		var d := 1.0
		while d <= EDGE_LOOK:
			var p := feet+Vector3(w.x,0.0,w.y)*d
			if field.floor_under(p,1.0,4.0,rid) == -INF:
				# Nearer rims win; a straight one wins a tie.
				var score := d+absf(turn)*0.8
				if score < nearest:
					nearest = score
					best = w
				break
			d += 0.75
	return best

## Plays one of its sounds here (spatial, heard to HEARD m).
func _voice(key: StringName) -> void:
	# Logged as the field logs its enemies' calls; played here (a field's
	# own sound hook knows only its own enemies' voices).
	field.sounds.append([key,global_position])
	if not is_inside_tree(): return
	var k := String(key)
	if not _voices.has(k): _voices[k] = EnemyYard._synth(VOICES[k])
	var player := AudioStreamPlayer3D.new()
	player.stream = _voices[k]
	player.unit_size = float(HEARD.get(k,8.0))
	player.max_db = 3.0
	player.position = Vector3.UP*height*0.5
	add_child(player)
	player.finished.connect(player.queue_free)
	player.play()
