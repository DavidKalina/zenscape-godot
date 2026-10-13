extends Node
## The headless bodies' cliff spawns (docs/design/roguelike/headless-body-
## round2.md, layer-round9-bodies.md), shared by the body's study (studies/
## headless_body_isle.gd) and the generator (scripts/roguelike/
## layer_enemies.gd): each inhaler head (scripts/enemies/inhaler_head.gd)
## has one body (scripts/enemies/headless_body.gd) and the cliffs it may
## come up ([name, lip (the top edge over the face), out (x, z: the face's
## outward way)]). While a head has no body (at the start, after a reset,
## once its body fell off the world) for `wait` s, a body comes up the
## nearest of its cliffs that meets every rule, hauling itself over the lip
## in front of the walker:
##   - `near` to `far` m from him (flat), so he isn't stood over it;
##   - its lip within `level` m of his feet's height (he is up there);
##   - within `view` rad of the camera's look (he will see it come over);
##   - with `hidden` 1, the camera's line to where it hangs blocked by the
##     cliff itself;
##   - `natural` 0: only asked-for spawns (`spawn_on_demand`).
## A headless body no nearer its head for `stale` s (stuck: round 9 found
## spurs down the generator's cliffs it can't leave) is taken away once
## it is out of the camera's view, and its head's next comes up as above
## (0: never).
## Each cliff is fitted to the real face first (`fit`): the face found by
## rays under the lip, the lip on its real top; a cliff with no face there
## is passed over.
## One body per head: a spawn takes its head's old body away, and if that
## body had its head on its neck, the head goes home (`go_home`).
## The camera shakes with the bodies' landings and steps (`shake`).
## Far spawns (docs/design/roguelike/layer-round10-far-bodies.md): of the
## spells a head goes bodiless, `far_share` (rolled once a spell) look for
## a far cliff instead, to watch come up across a gulf:
##   - `far_from` to `far_to` m from the walker (flat), within `far_view`
##     rad of the camera's look and its haul on screen (ON_SCREEN in from
##     the edges), its face turned his way;
##   - not hidden: the camera's lines to its hands and chest at the lip
##     clear;
##   - it starts down to `far_climb` m lower on the face (as deep as the
##     face goes) and climbs it hand over hand, then hauls over.
## A spell that has waited `far_wait` s past `wait` with no spawn takes
## either kind (but `far_share` 1 takes only far ones, 0 only near ones).
const HeadlessBody = preload("res://scripts/enemies/headless_body.gd")

## The rules' defaults (the study's `--spawn-knob=`).
const RULES := {"wait":2.0,"near":8.0,"far":40.0,"level":3.5,"view":1.0,"hidden":1.0,"natural":1.0,"stale":120.0,
	"far_share":0.0,"far_from":60.0,"far_to":250.0,"far_view":0.45,"far_climb":10.0,"far_wait":20.0}
## The body's placeholder voices: [seconds, tone (Hz, 0 none), tone at the
## end, noise share, low-pass (0-1), attack (s), tremolo (Hz, 0 none)]
## (studies/enemy_yard.gd `_synth`).
const VOICES := {
	"body_step":[0.3,45.0,30.0,0.5,0.12,0.004,0.0],
	"body_listen":[0.9,0.0,0.0,1.0,0.06,0.2,6.0],
	"body_found":[0.7,90.0,60.0,0.3,0.3,0.05,0.0],
	"body_grip":[0.25,0.0,0.0,1.0,0.35,0.005,18.0],
	"body_windup":[0.8,0.0,0.0,1.0,0.1,0.3,10.0],
	"body_leap":[0.5,0.0,0.0,1.0,0.5,0.02,0.0],
	"body_land":[0.9,40.0,25.0,0.6,0.15,0.003,0.0],
	"body_shock":[1.6,30.0,20.0,0.75,0.09,0.002,0.0],
	"body_reach":[1.2,0.0,0.0,1.0,0.07,0.3,13.0],
	"body_whole":[1.0,70.0,110.0,0.3,0.25,0.01,0.0],
	"body_rumble":[2.6,34.0,22.0,0.7,0.035,0.25,5.0],
}
## A voice's reach (its player's `unit_size`, m) where it carries farther
## than the scene's own: the rumble heard across a gulf.
const REACH := {"body_rumble":90.0,"body_shock":30.0,"body_land":24.0}
## A far cliff's face turned at least this much (cos) toward the walker.
const FAR_FACING := 0.2
## A far spawn's haul this share of the screen in from its edges.
const ON_SCREEN := 0.12
## `vantages`' stands: these far off a cliff (m), tried in turn.
const VANTAGE := [130.0,170.0,90.0,210.0,70.0]
## The far search's beat (s): the rays aren't cast every frame.
const FAR_EVERY := 0.25
## Fitting a cliff (`fit`): the face looked for from FIT_OUT m out past the
## lip to FIT_IN m in, at FIT_DEPTHS m under it (each a steep face); the
## top looked for FIT_TOP m over and under the lip.
const FIT_OUT := 8.0
const FIT_IN := 5.0
const FIT_TOP := 3.0
## The face may be undercut this far in under the top (m); the lip is
## looked for at these offsets along the rim (m).
const FIT_UNDERCUT := 1.2
const FIT_ALONG := [0.0,1.5,-1.5,3.0,-3.0]

var rules := RULES.duplicate()
## Knob overrides for every body (the study's `--body-knob=`).
var body_knobs := {}
## The scene (a character study: its motor, camera, ground and world) and
## its EnemyField.
var scene: Node3D
var field: Node
## A body under this height is gone (fell off the world).
var lost_y := -INF
## Per head: {home (where it was set down, its `home()`), cliffs, body,
## bodiless (s)}.
var heads: Array = []
## Spawns made, the last cliff's name, cliffs passed over (no face).
var spawns := 0
var last_cliff := ""
var unfit := 0
## Bodies taken away stalled (`stale`).
var stale := 0
## Why the last `fit` failed ({reason: count}).
var fit_why := ""
## Far spawns made; the last spawn's distance from the walker (m, flat)
## and how far down the face it started (m).
var far_spawns := 0
var last_far := 0.0
var last_below := 0.0
var _rng := RandomNumberGenerator.new()
var _far_t := 0.0

func _init() -> void:
	name = "BodySpawner"

func setup(study: Node3D, enemies: Node, rule_overrides := {}, body_overrides := {}) -> void:
	scene = study
	field = enemies
	rules.merge(rule_overrides,true)
	body_knobs = body_overrides.duplicate()

## The head set down at `home` gets a body, coming up `cliffs`. Its index.
func add_head(home: Vector3, cliffs: Array) -> int:
	heads.append({"home":home,"cliffs":cliffs.duplicate(true),"body":null,"bodiless":0.0,"mode":""})
	return heads.size()-1

## Head `i` in the field now (it is made again on a reset), or null.
func head_of(i: int) -> Node3D:
	var home: Vector3 = heads[i].home
	for e in field.enemies:
		if is_instance_valid(e) and e.has_method("home") and (e.home() as Vector3).distance_to(home) < 0.5: return e
	return null

## Head `i`'s body now, or null.
func body_of(i: int) -> Node3D:
	var b: Variant = heads[i].body
	if b != null and is_instance_valid(b) and not b.gone and field.enemies.has(b): return b
	heads[i].body = null
	# One the scene set down itself (the study's stood start): its head's,
	# or any head's where there is one head.
	for e in field.enemies:
		if not is_instance_valid(e) or e.gone or e.get("head_home") == null: continue
		var home: Vector3 = e.head_home
		if (home == Vector3.INF and heads.size() == 1) or (home != Vector3.INF and home.distance_to(heads[i].home) < 0.5):
			heads[i].body = e
			return e
	return null

func bodies() -> Array:
	var out: Array = []
	for i in range(heads.size()):
		var b := body_of(i)
		if b != null: out.append(b)
	return out

# --- A frame -----------------------------------------------------------------------

## Bodies lost under `lost_y` taken away; a body up a cliff for each head
## bodiless `wait` s, where the rules say.
func step(delta: float) -> void:
	if field == null: return
	_far_t += delta
	var far_beat := _far_t >= FAR_EVERY
	if far_beat: _far_t = 0.0
	for i in range(heads.size()):
		var b := body_of(i)
		if b != null and b.position.y < lost_y: _take_away(b)
		elif b != null and float(rules.stale) > 0.0 and not b.whole and b.stalled > float(rules.stale) and not in_view(b.position):
			stale += 1
			_take_away(b)
		if body_of(i) != null or head_of(i) == null:
			heads[i].bodiless = 0.0
			heads[i].mode = ""
			continue
		heads[i].bodiless += delta
		if float(rules.natural) < 0.5 or float(heads[i].bodiless) < float(rules.wait): continue
		var share := float(rules.far_share)
		if heads[i].mode == "": heads[i].mode = "far" if _rng.randf() < share else "near"
		var waited := float(heads[i].bodiless)-float(rules.wait) >= float(rules.far_wait)
		if share > 0.0 and (heads[i].mode == "far" or waited) and far_beat:
			var f := pick_far(i)
			if not f.is_empty():
				spawn_climber(i,int(f.cliff),f.fitted,float(f.below),true)
				continue
		if share < 1.0 and (heads[i].mode == "near" or waited):
			var c := pick_cliff(i,true)
			if c >= 0: spawn_climber(i,c)

## The camera shaken by the bodies' quakes, less the further off.
func shake(camera: Camera3D) -> void:
	if camera == null: return
	var q := 0.0
	for b: Node3D in bodies():
		var near := clampf(1.0-camera.global_position.distance_to(b.global_position)/60.0,0.0,1.0)
		q = maxf(q,float(b.quake)*near)
	if q > 0.001:
		var t := Time.get_ticks_msec()/1000.0
		camera.position += Vector3(sin(t*61.0),sin(t*53.0+1.0),sin(t*47.0+2.0))*q*0.5

# --- Picking a cliff ---------------------------------------------------------------

## The cliff of head `i` a body should come up now: the nearest meeting
## every rule (`strict`), or, not strict, the nearest meeting the most (out
## of sight, then `near` to `far` m, then level, then in view); -1 none.
func pick_cliff(i: int, strict: bool) -> int:
	var feet: Vector3 = scene.motor.feet
	var best := -1
	var best_score := INF
	var cliffs: Array = heads[i].cliffs
	for c in range(cliffs.size()):
		var lip: Vector3 = cliffs[c][1]
		var out: Vector2 = cliffs[c][2]
		var d := Vector2(lip.x-feet.x,lip.z-feet.z).length()
		var ranged := d >= float(rules.near) and d <= float(rules.far)
		var level := absf(feet.y-lip.y) <= float(rules.level)
		if strict and not (ranged and level): continue
		var seen := in_view(lip)
		if strict and not seen: continue
		var hid := hidden(lip,out)
		var score := d
		if strict:
			if not hid: continue
		else:
			score += (0.0 if ranged else 1000.0)+(0.0 if hid else 500.0)+(0.0 if level else 200.0)+(0.0 if seen else 100.0)
		if score < best_score:
			best_score = score
			best = c
	return best

## Whether the camera's line to a body hanging under `lip` is blocked.
func hidden(lip: Vector3, out: Vector2) -> bool:
	var camera: Camera3D = scene.get("camera")
	if float(rules.hidden) < 0.5 or camera == null: return true
	var hands := lip+Vector3(out.x,0.0,out.y)*2.0-Vector3.UP*1.5
	var q := PhysicsRayQueryParameters3D.create(camera.global_position,hands,scene.ground.mask)
	return not scene.get_world_3d().direct_space_state.intersect_ray(q).is_empty()

## Whether `lip` is within `view` rad (or `cone`) of the camera's look (flat).
func in_view(lip: Vector3, cone := -1.0) -> bool:
	var camera: Camera3D = scene.get("camera")
	if camera == null: return true
	var look := -camera.global_basis.z
	var to := lip-camera.global_position
	var a := Vector2(look.x,look.z)
	var b := Vector2(to.x,to.z)
	if a.length() < 0.01 or b.length() < 0.01: return true
	return absf(a.angle_to(b)) <= (float(rules.view) if cone < 0.0 else cone)

## The far cliff of head `i` a body should come up now, by the far rules,
## the nearest the middle of the view first: {cliff, fitted ([lip, out]),
## below (m down the face it starts)}, or {}.
func pick_far(i: int) -> Dictionary:
	var camera: Camera3D = scene.get("camera")
	if camera == null: return {}
	var feet: Vector3 = scene.motor.feet
	var look := -camera.global_basis.z
	var ranked: Array = []
	var cliffs: Array = heads[i].cliffs
	for c in range(cliffs.size()):
		var lip: Vector3 = cliffs[c][1]
		var out: Vector2 = (cliffs[c][2] as Vector2).normalized()
		var d := Vector2(lip.x-feet.x,lip.z-feet.z).length()
		if d < float(rules.far_from) or d > float(rules.far_to): continue
		# In view: its lip or the face it starts up in the frustum.
		if not in_view(lip,float(rules.far_view)): continue
		if not on_screen(lip-Vector3.UP*hang()*0.5): continue
		var to_him := Vector2(feet.x-lip.x,feet.z-lip.z).normalized()
		if out.dot(to_him) < FAR_FACING: continue
		var to := lip-camera.global_position
		ranked.append([absf(Vector2(look.x,look.z).angle_to(Vector2(to.x,to.z))),c])
	ranked.sort_custom(func(a: Array, z: Array) -> bool: return float(a[0]) < float(z[0]))
	for r: Array in ranked:
		var c: int = r[1]
		var cliff: Array = cliffs[c]
		var fitted := fit(cliff[1],cliff[2],float(cliff[3]) if cliff.size() > 3 else 0.0)
		if fitted.is_empty(): continue
		var at: Vector3 = fitted[0]
		var f3 := Vector3((fitted[1] as Vector2).x,0.0,(fitted[1] as Vector2).y)
		var below := face_below(at,fitted[1],float(rules.far_climb))
		# Seen where it hangs at the lip, hands and chest (the haul over
		# it); its start down the face may be under the walker's own rim.
		if not seen(at+f3*2.0-Vector3.UP*1.5) or not seen(at+f3*2.0-Vector3.UP*hang()*0.5): continue
		return {"cliff":c,"fitted":fitted,"below":below}
	return {}

## Whether `p` is on the camera's screen, inside ON_SCREEN of its edges.
func on_screen(p: Vector3) -> bool:
	var camera: Camera3D = scene.get("camera")
	if camera == null: return true
	if not camera.is_position_in_frustum(p): return false
	var size := camera.get_viewport().get_visible_rect().size
	var q := camera.unproject_position(p)/size
	return q.x >= ON_SCREEN and q.x <= 1.0-ON_SCREEN and q.y >= ON_SCREEN and q.y <= 1.0-ON_SCREEN

## Whether the camera's line to `p` is clear of the ground.
func seen(p: Vector3) -> bool:
	var camera: Camera3D = scene.get("camera")
	if camera == null: return true
	var q := PhysicsRayQueryParameters3D.create(camera.global_position,p,scene.ground.mask)
	return scene.get_world_3d().direct_space_state.intersect_ray(q).is_empty()

## How far down past its hang a body can start on the face under `lip`
## (`out` x, z) and climb it: its chest's way up the face found by rays,
## steep and unbroken (stepping in or out no more than 1.5 m a metre), to
## `most` m (whole metres; 0 under 2).
func face_below(lip: Vector3, out: Vector2, most: float) -> float:
	if most <= 0.0: return 0.0
	var space := scene.get_world_3d().direct_space_state
	var mask: int = scene.ground.mask
	var n := out.normalized()
	var f3 := Vector3(n.x,0.0,n.y)
	var b := HeadlessBody.build_of(_body_k(),float(field.numbers().unit))
	var chest := float(b.hang)-float(b.chest)
	var face := lip
	var got := 0.0
	var d := 1.0
	while d <= most:
		var p := Vector3(face.x,lip.y-chest-d,face.z)
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(p+f3*4.0,p-f3*3.0,mask))
		if hit.is_empty(): break
		var nn := hit.normal as Vector3
		if absf(nn.y) > 0.7 or Vector2(nn.x,nn.z).normalized().dot(n) < 0.5: break
		if absf(((hit.position as Vector3)-face).dot(f3)) > 1.5: break
		face = hit.position
		got = d
		d += 1.0
	return got if got >= 2.0 else 0.0

# --- Spawning ----------------------------------------------------------------------

## A body up cliff `c` of head `i` now: the head's one body (the old one
## goes, and if it had the head, the head goes home). Null where the cliff
## has no face to hang on (it is dropped from the head's cliffs).
## `fitted` (by `pick_far`) skips the fit; `below` m further down the face
## it starts (a far spawn, seen climbing).
func spawn_climber(i: int, c: int, fitted := [], below := 0.0, far := false) -> Node3D:
	var cliff: Array = heads[i].cliffs[c]
	if fitted.is_empty(): fitted = fit(cliff[1],cliff[2],float(cliff[3]) if cliff.size() > 3 else 0.0)
	if fitted.is_empty():
		unfit += 1
		(heads[i].cliffs as Array).remove_at(c)
		return null
	var h := head_of(i)
	var old := body_of(i)
	if old != null: _take_away(old)
	elif h != null and h.perch != null: h.go_home()
	var b: Node3D = field.add(HeadlessBody,fitted[0],-(fitted[1] as Vector2),body_knobs)
	b.head_home = heads[i].home
	# Ahead of its head in the field, so the head reads its neck where it
	# is this frame.
	field.enemies.erase(b)
	var at: int = field.enemies.find(h) if h != null else 0
	field.enemies.insert(maxi(at,0),b)
	b.cling(fitted[0],fitted[1],below,far)
	b.body.force_update_transform()
	heads[i].body = b
	heads[i].bodiless = 0.0
	spawns += 1
	last_cliff = str(cliff[0])
	var feet: Vector3 = scene.motor.feet
	last_far = Vector2(b.position.x-feet.x,b.position.z-feet.z).length()
	last_below = below
	if far: far_spawns += 1
	return b

## A body up head `i`'s best cliff now (every rule if one meets them, else
## the one meeting the most).
func spawn_on_demand(i := 0) -> Node3D:
	if i >= heads.size(): return null
	for strict: bool in [true,false]:
		var c := pick_cliff(i,strict)
		while c >= 0:
			var b := spawn_climber(i,c)
			if b != null: return b
			c = pick_cliff(i,strict)
	return null

## Stands to watch head `i`'s far spawn from (run_layer's B): ground
## VANTAGE m off each of its cliffs, out along the face (or turned up to
## 0.7 rad off it), each [at, face (x, z) toward the lip], the order tried.
func vantages(i: int) -> Array:
	var out: Array = []
	if i >= heads.size(): return out
	var space := scene.get_world_3d().direct_space_state
	for c: Array in heads[i].cliffs:
		var lip: Vector3 = c[1]
		var o: Vector2 = (c[2] as Vector2).normalized()
		for d: float in VANTAGE:
			if d < float(rules.far_from) or d > float(rules.far_to): continue
			for turn: float in [0.0,0.35,-0.35,0.7,-0.7]:
				var w := o.rotated(turn)
				var p := lip+Vector3(w.x,0.0,w.y)*d
				var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(p.x,lip.y+80.0,p.z),Vector3(p.x,lip.y-80.0,p.z),scene.ground.mask))
				if hit.is_empty() or (hit.normal as Vector3).y < 0.7: continue
				var at: Vector3 = (hit.position as Vector3)+Vector3.UP*0.05
				out.append([at,Vector2(lip.x-at.x,lip.z-at.z).normalized()])
	return out

## A far body up one of head `i`'s cliffs now if the far rules find one
## from where the walker stands (its old body taken away); null if not.
func spawn_far_now(i: int) -> Node3D:
	var f := pick_far(i)
	if f.is_empty(): return null
	heads[i].mode = "far"
	return spawn_climber(i,int(f.cliff),f.fitted,float(f.below),true)

## A body taken out of the field; the head it had goes home.
func _take_away(b: Node3D) -> void:
	var h: Node3D = b.head
	if h != null and is_instance_valid(h) and h.perch == b: h.go_home()
	field.enemies.erase(b)
	if b.get_parent() == field: field.remove_child(b)
	b.queue_free()

## Cliff `lip` (out `out`, x z) fitted to the real face: [lip on its real
## top at the face, out (the face's own)], or [] where there is no steep
## face under it down to `depth` m (0: its hang, the body's knobs'), no top
## over it, or something out past the face where the body would hang.
func fit(lip: Vector3, out: Vector2, depth := 0.0) -> Array:
	if depth <= 0.0: depth = hang()
	var n := out.normalized()
	var why := {}
	# Along the rim a little either way (the plan's lip is a cell's guess).
	for s: float in FIT_ALONG:
		var at := lip+Vector3(-n.y,0.0,n.x)*s
		var got := _fit_at(at,n,depth)
		if got.size() == 2: return got
		why[got[0]] = int(why.get(got[0],0))+1
	fit_why = str(why)
	return []

## The cliff fitted at `lip` (or [why it won't]).
func _fit_at(lip: Vector3, n: Vector2, depth: float) -> Array:
	var space := scene.get_world_3d().direct_space_state
	var mask: int = scene.ground.mask
	var o3 := Vector3(n.x,0.0,n.y)
	# The top: the outermost level ground near the lip's height, looked for
	# from a little out past it to FIT_IN in.
	var rim := Vector3.INF
	var t := 1.5
	while t >= -FIT_IN:
		var p := lip+o3*t
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(p.x,lip.y+FIT_TOP,p.z),Vector3(p.x,lip.y-FIT_TOP,p.z),mask))
		if not hit.is_empty() and (hit.normal as Vector3).y > 0.6:
			rim = hit.position
			break
		t -= 0.5
	if rim == Vector3.INF: return ["no top"]
	# The face under it, steep, at a few depths down past its chest at the
	# start, no more than FIT_UNDERCUT in under the lip.
	var face := Vector3.INF
	var normal := Vector3.ZERO
	for k: float in [0.15,0.45,0.7]:
		var y := rim.y-depth*k
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(rim.x,y,rim.z)+o3*FIT_OUT,Vector3(rim.x,y,rim.z)-o3*(FIT_UNDERCUT+0.6),mask))
		if hit.is_empty(): return ["no face"]
		if absf((hit.normal as Vector3).y) > 0.7: return ["face not steep"]
		if face == Vector3.INF:
			face = hit.position
			normal = hit.normal
	var flat := Vector2(normal.x,normal.z)
	if flat.length() < 0.1: return ["face flat"]
	flat = flat.normalized()
	# Its own way out within 50 degrees of the one asked.
	if flat.dot(n) < 0.64: return ["face turned"]
	var f3 := Vector3(flat.x,0.0,flat.y)
	var top := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(face.x,rim.y+FIT_TOP,face.z)-f3*0.8,Vector3(face.x,rim.y-FIT_TOP,face.z)-f3*0.8,mask))
	if top.is_empty() or (top.normal as Vector3).y < 0.6: return ["no top over the face"]
	var at := Vector3(face.x,(top.position as Vector3).y,face.z)
	# Room where it hangs: nothing under the lip out past the face.
	var room := at+f3*2.0
	if not space.intersect_ray(PhysicsRayQueryParameters3D.create(room-Vector3.UP*0.5,room-Vector3.UP*depth,mask)).is_empty(): return ["no room"]
	return [at,flat]

## How far under the lip a clinging body's feet hang (m), its knobs'.
func hang() -> float:
	if _hang < 0.0:
		var n: Dictionary = field.numbers()
		_hang = float(HeadlessBody.build_of(_body_k(),float(n.unit)).hang)
	return _hang

## The bodies' knobs (theirs, then `body_knobs`).
func _body_k() -> Dictionary:
	if _k.is_empty():
		var probe: Node3D = HeadlessBody.new()
		_k = probe.default_knobs(field.numbers())
		probe.free()
		_k.merge(body_knobs,true)
	return _k

var _k := {}

var _hang := -1.0
