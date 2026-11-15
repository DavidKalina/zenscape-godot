extends RefCounted
## The reveal (endless flight): a find whose row says `reveal` (finds_table.gd)
## and whose anchor is handed mid-flight (`finds.anchor`: a golden tree's thud,
## the whale's ring let out) holds the flight a moment while the camera goes to
## it: OUT s easing from the chase view to a shot of the find as it rises and
## shines (find_marks.gd Mark `appear`), HOLD s on it with a slow push in, then
## BACK s easing back to the very chase view it left, and the flight goes on.
## Any key, mouse or pad button skips straight to the ease back (SKIP_BACK s).
##
## The hold is photo mode's (photo_mode.gd): the game skips its `tick` while
## `step` says so, the physics server is stopped, and the reveal is
## `game.overlay`, so no other overlay opens over it and it waits while one is
## up (the shop, the logbook, the pause menu, photo mode), as it waits for the
## menu's stage, a beat route's pan and a crash's dip. Nothing of the flight
## moves while it holds: the plane, its input, the near misses and the lines,
## the day's clock. What the reveal shows does: the finds' marks and their beat
## (`finds.hold_step`), a golden tree's fall (`golden.hold_step`), particles,
## sound. Keys pressed during it are taken here, so the first tick after reads
## only what is held then.
##
## Two asked together queue: the second is framed straight from the first, and
## the camera goes back once. A find logged before its turn is dropped. None in
## a replay.

const Finds = preload("res://scripts/endless/finds.gd")

## The move out (s), the hold on the find (s), the move back (s), the move back
## when skipped (s).
const OUT := 0.85
const HOLD := 1.3
const BACK := 0.75
const SKIP_BACK := 0.4
## The shot: the find this many times its ring's width off (m, clamped), the
## lens (deg), pushed in to PUSH of the way over the hold.
const SPANS := 2.6
const DIST := Vector2(18.0,60.0)
const FOV := 52.0
const PUSH := 0.82
## The look this share of the row's `up` under the find, so what it rose out
## of (a stump, the whale's back) is in the frame under it.
const LOWER := 0.3
## The sight lines to the find's rim: how many round it, how far out (its
## rim's radius times).
const RIM_SIGHTS := 8
const RIM_WIDE := 1.25
## The ways tried round the find, from the side its anchor asked (finds
## `anchor`'s `side`, the end nearer the chase) or else the chase's side (rad),
## and the heights over it (rad): the first with a clear sight to its middle
## and its rim wins.
const YAWS := [0.0,0.4,-0.4,0.8,-0.8,1.3,-1.3,1.9,-1.9,2.5,-2.5,PI]
const ELEVATIONS := [0.3,0.48,0.18,0.66,0.9]
## The eye keeps this far over the land or the water (m), and the sight line
## this far from the plane (m).
const CLEAR := 2.5
const PLANE_CLEAR := 7.0
## How far a crown drawn spreads past its tree's solid (m).
const CROWN_PAD := 3.0
## The move's lift (a share of how far it goes, at most ARC_MOST m).
const ARC := 0.18
const ARC_MOST := 30.0
## A queued reveal the plane has left this far behind (m) is dropped.
const STALE := 1200.0

var game: Node
var active := false
## "off", "out", "hold", "back".
var phase := "off"
var t := 0.0
## Row indices waiting their turn, and the one on screen (-1 none).
var queue: Array = []
var now := -1
## Read by drivers: reveals begun, skipped, frames held; the last shot
## {id, eye, at, tried}.
var shown := 0
var skipped := 0
var held_frames := 0
var last := {}
var _was := Transform3D.IDENTITY
var _was_fov := 70.0
var _from := Transform3D.IDENTITY
var _from_fov := 70.0
var _left := Transform3D.IDENTITY
var _left_fov := 70.0
var _back_for := BACK
var _at := Vector3.ZERO
var _eye := Vector3.ZERO
var _eye_in := Vector3.ZERO

func _init(owner_game: Node) -> void:
	game = owner_game

## Row `i` of the finds has just appeared: true when it will be shown (now or
## once the way is free), false when not (logged already, a replay).
func ask(i: int) -> bool:
	if game.replay != null or game.finds == null: return false
	if game.finds.is_found(game.finds.rows[i]): return false
	if i == now or i in queue: return true
	queue.append(i)
	return true

## Whether `event` is taken: all of them while it holds; a press skips.
func handle(event: InputEvent) -> bool:
	if not active: return false
	var press: bool = (event is InputEventKey and event.pressed and not event.echo) \
		or (event is InputEventJoypadButton and event.pressed) \
		or (event is InputEventMouseButton and event.pressed)
	if press: skip()
	return true

## Straight to the move back, and none of the queue after it.
func skip() -> void:
	if not active or phase == "back": return
	skipped += 1
	_drop_queue()
	_back(SKIP_BACK)

## One frame, before the game's `tick`: true while it holds the flight (the
## tick is skipped).
func step(delta: float) -> bool:
	if not active:
		if queue.is_empty() or not _free(): return false
		var i := _next()
		if i < 0: return false
		_begin(i)
	var real := minf(delta/maxf(Engine.time_scale,0.05),1.0/20.0)
	held_frames += 1
	t += real
	var cam: Camera3D = game.camera
	match phase:
		"out":
			var u := smoothstep(0.0,1.0,t/OUT)
			var eye := _from.origin.lerp(_eye,u)+Vector3.UP*_arc(_from.origin,_eye)*sin(PI*u)
			# The look comes onto the find faster than the eye arrives.
			var ahead := _from.origin-_from.basis.z*_from.origin.distance_to(_at)
			var look := ahead.lerp(_at,smoothstep(0.0,1.0,minf(t/(OUT*0.7),1.0)))
			_place(cam,eye,look)
			cam.fov = lerpf(_from_fov,FOV,u)
			if t >= OUT:
				phase = "hold"
				t = 0.0
		"hold":
			var u := smoothstep(0.0,1.0,t/HOLD)
			_place(cam,_eye.lerp(_eye_in,u),_at)
			cam.fov = FOV
			if t >= HOLD:
				var i := _next()
				if i >= 0: _turn_to(i)
				else: _back(BACK)
		"back":
			var u := smoothstep(0.0,1.0,t/_back_for)
			var qa := _left.basis.get_rotation_quaternion()
			var qb := _was.basis.get_rotation_quaternion()
			var eye := _left.origin.lerp(_was.origin,u)+Vector3.UP*_arc(_left.origin,_was.origin)*sin(PI*u)
			cam.global_transform = Transform3D(Basis(qa.slerp(qb,u)),eye)
			cam.fov = lerpf(_left_fov,_was_fov,u)
			if t >= _back_for: _end()
			return true
	if game.finds != null: game.finds.hold_step(real,cam.global_position)
	if game.golden != null: game.golden.hold_step(real)
	return true

## Whether the flight may be held now: no overlay, no menu, no pan, no dip.
func _free() -> bool:
	if game.overlay != null or game.photo.active: return false
	if game.stage != null: return false
	var beats: Variant = game.get("beats")
	if beats != null and str(beats.state) == "pan": return false
	return float(game.get("_fade_left")) <= 0.0

## The next row in the queue still worth showing (-1 none); those logged or
## left far behind meanwhile are shown as they are.
func _next() -> int:
	while not queue.is_empty():
		var i: int = queue.pop_front()
		var e: Dictionary = game.finds.rows[i]
		if game.finds.is_found(e) or (e.at as Vector3).distance_to(game.plane.position) > STALE:
			game.finds.show_mark(i)
			continue
		return i
	return -1

func _drop_queue() -> void:
	for i: int in queue: game.finds.show_mark(i)
	queue.clear()

func _begin(i: int) -> void:
	active = true
	game.overlay = self
	PhysicsServer3D.set_active(false)
	var cam: Camera3D = game.camera
	_was = cam.global_transform
	_was_fov = cam.fov
	_turn_to(i)

## Framed on row `i`, from wherever the camera is.
func _turn_to(i: int) -> void:
	var t0 := Time.get_ticks_usec()
	var cam: Camera3D = game.camera
	now = i
	shown += 1
	_from = cam.global_transform
	_from_fov = cam.fov
	var e: Dictionary = game.finds.rows[i]
	var ring: Vector3 = e.at
	_at = ring+Vector3.DOWN*float(e.get("up",0.0))*LOWER
	var d := clampf(Finds.ring_opening()*1.3*SPANS,DIST.x,DIST.y)
	var shot := _shot(_at,ring,d,e.get("reveal_side",Vector3.ZERO),Finds.ring_opening()*0.65)
	if FrameLog.on: FrameLog.add(&"r_shot",(Time.get_ticks_usec()-t0)/1000.0)
	var t1 := Time.get_ticks_usec()
	_eye = shot.eye
	_eye_in = _at+(_eye-_at)*PUSH
	last = {"id":str(e.id),"eye":_eye,"at":_at,"tried":shot.tried,"clear":shot.clear}
	game.finds.appear_mark(i,_eye)
	if FrameLog.on: FrameLog.add(&"r_appear",(Time.get_ticks_usec()-t1)/1000.0)
	phase = "out"
	t = 0.0
	print("reveal: %s at %s, eye %s (%d tried%s)" % [e.id,str(_at.snapped(Vector3.ONE)),str(_eye.snapped(Vector3.ONE)),int(shot.tried),"" if bool(shot.clear) else ", none clear"])

func _back(seconds: float) -> void:
	var cam: Camera3D = game.camera
	_left = cam.global_transform
	_left_fov = cam.fov
	_back_for = seconds
	phase = "back"
	t = 0.0

## Released: the camera exactly as the chase left it, the flight given back.
func _end() -> void:
	var cam: Camera3D = game.camera
	cam.global_transform = _was
	cam.fov = _was_fov
	active = false
	phase = "off"
	now = -1
	if game.overlay == self: game.overlay = null
	PhysicsServer3D.set_active(true)

## Where to watch `at` from, `d` m off, `ring` (the find, `rim` m round) in
## sight: {eye, tried, clear}. Round from the
## chase's side, low first: the eye over the land, nothing solid or a tree on
## the way, the plane off the line.
func _shot(at: Vector3, ring: Vector3, d: float, side: Vector3, rim: float) -> Dictionary:
	var cam: Camera3D = game.camera
	var chase := cam.global_position-at
	chase.y = 0.0
	if chase.length() < 1.0:
		chase = game.plane.position-at
		chase.y = 0.0
	var base := chase
	side.y = 0.0
	if side.length() > 0.1: base = side if side.dot(chase) >= 0.0 else -side
	base = base.normalized() if base.length() > 0.1 else Vector3.BACK
	var tried := 0
	for el: float in ELEVATIONS:
		for yaw: float in YAWS:
			tried += 1
			var way := base.rotated(Vector3.UP,yaw)*cos(el)+Vector3.UP*sin(el)
			var eye := at+way*d
			if not _clear(eye,ring): continue
			# The rim too, a little wide, and the look's point under it: no crown
			# in front of any of it.
			var across := way.cross(Vector3.UP).normalized()
			var up := across.cross(way).normalized()
			var seen := _clear(eye,at,false)
			for k in RIM_SIGHTS:
				if not seen: break
				var a := TAU*k/RIM_SIGHTS
				seen = _clear(eye,ring+(across*cos(a)+up*sin(a))*rim*RIM_WIDE,false)
			if seen: return {"eye":eye,"tried":tried,"clear":true}
	var high := at+(base*cos(1.1)+Vector3.UP*sin(1.1))*d
	return {"eye":high,"tried":tried,"clear":false}

func _clear(eye: Vector3, at: Vector3, whole := true) -> bool:
	if eye.y < float(game.eye_floor(eye))+CLEAR: return false
	var trees: Variant = game.get("trees")
	const STEPS := 24
	for k in STEPS:
		var p := eye.lerp(at,float(k)/STEPS)
		if game._solid(p): return false
		if trees != null and _crown(trees,p,CROWN_PAD): return false
	if not whole: return true
	# Nor a tree's crown just round the eye, filling the frame.
	if trees != null and _crown(trees,eye,CROWN_PAD*2.0): return false
	var p: Vector3 = game.plane.position
	if _off_segment(p,eye,at) < PLANE_CLEAR: return false
	return true

## Whether `p` is in a tree's crown, the solid's cone widened `pad` m (a crown
## drawn spreads past its solid).
static func _crown(trees: Object, p: Vector3, pad: float) -> bool:
	for off: Vector3 in [Vector3.ZERO,Vector3(pad,0,0),Vector3(-pad,0,0),Vector3(0,0,pad),Vector3(0,0,-pad)]:
		if bool(trees.inside(p+off)): return true
	return false

static func _off_segment(p: Vector3, a: Vector3, b: Vector3) -> float:
	var ab := b-a
	var k := clampf((p-a).dot(ab)/maxf(ab.length_squared(),0.0001),0.0,1.0)
	return p.distance_to(a+ab*k)

static func _arc(a: Vector3, b: Vector3) -> float:
	return minf(a.distance_to(b)*ARC,ARC_MOST)

static func _place(cam: Camera3D, eye: Vector3, look: Vector3) -> void:
	cam.global_position = eye
	var way := look-eye
	if way.length() < 0.01: return
	var up := Vector3.UP if absf(way.normalized().y) < 0.995 else Vector3.FORWARD
	cam.look_at(look,up)
