extends Node3D
## The trees the burrower passes near shudder (spec-burrower.md, 2): the
## heave under the roots shoves each tree away from the head, and it sways
## back and forth, ringing out (a damped spring per tree, slower for taller
## trees); the crown lags and overshoots the trunk. A burst of leaves comes off
## the crown once the shove bites and a trickle after it; the leaves flutter
## down, lie a moment and sink (a MultiMesh of small cards).
##
## Trees are the land's nodes (`Crown` child, meta `tall`), rooted at the
## ground, so tilting the node leans the whole tree from its foot.
##
## A land that `probes` (the game's) has no tree nodes: its spruces are
## MultiMesh instances. He drags a gust through them like the wind's, only
## more: a stamp every STOOD_STRIP m of his way, in a map only the trees read
## (scripts/endless/grass_react.gd `gust_strip`, shaders/wake_gust_stamp.gdshader,
## tree_wind.gdshaderinc zs_tree_gust). Each stamp spreads out from his line as
## it ages, so trees go over one after another, hold, and ease back into the wind's
## own sway, all from the stamp's age: nothing per tree. A tree gets a burst of
## needles as the head goes by it (nearest); only a line in `_felt` is kept, and
## only the trees round the head are asked after, every STOOD_EVERY s.

## The head shoves a tree within REACH m of its trunk, hardest at the trunk.
const REACH := 15.0
## The sway: base frequency (Hz) for a 10 m tree, damping ratio (low, so it
## rings), the shove's strength (rad/s^2 at full), the most lean (rad).
const FREQ := 0.62
const DAMP := 0.09
const SHOVE := 0.5
const MOST := 0.16
## The crown: lags the trunk and swings past it (a second spring on top).
const CROWN_FREQ := 1.15
const CROWN_DAMP := 0.12
const CROWN_GAIN := 1.5
## How long a shove keeps a tree dropping leaves.
const SHIVER_DECAY := 1.4
## Leaves: the most at once, a burst's count at full, the trickle's rate
## while shivering, a tree's wait before it bursts again.
const LEAVES := 420
const BURST := 90
const TRICKLE := 14.0
const COOL := 2.5
const BURST_AT := 0.12
const LEAF_FALL := 1.3
const LEAF_LIE := 2.2

## The stood trees (a land that `probes`): how far from the head one sheds
## needles, how often that is asked, the most a look does; the gust's reach
## each side of his line and the length of a stamp; the needles a burst and how
## much bigger than a leaf a card is (read from the chase camera, over the crowns).
const STOOD_REACH := 19.0
const STOOD_EVERY := 0.09
const STOOD_MOST := 7
const STOOD_GUST := 30.0
const STOOD_STRIP := 7.0
## The gust runs this far ahead of the head, or the wood would go over behind
## the plane: he leads it by about this.
const STOOD_LEAD := 30.0
## A sighting's gust (`sight`), wider and harder, to read from a few hundred
## metres.
const SIGHT_GUST := 110.0
const SIGHT_K := 1.6
const STOOD_BURST := Vector2(14.0,5.0)
const STOOD_CARD := 1.3
const STOOD_NEEDLE := Color("3f5a2c")

var land: Node
## His pass is a sighting: seen from far off (`SIGHT_GUST`).
var sight := false
## Too far for needles to show: only the gust.
var distant := false
## The grass's push map (scripts/endless/grass_react.gd), or null.
var react: Node
var stats := {"shoved": 0, "bursts": 0, "leaves": 0, "most_lean": 0.0}

var _trees: Array = []
var _leaves: Array = []
var _leaf_mm := MultiMesh.new()
var _rng := RandomNumberGenerator.new()
var _time := 0.0
var _ask := 0.0
## A stood tree under the head's reach (its foot in cm): Vector2(its last
## distance, the time it shook; -1 not yet).
var _felt := {}
## Where the gust's last stamp went down (INF: none yet).
var _trail := Vector2.INF

func _init() -> void:
	name = "TreeShudder"

func setup(the_land: Node) -> void:
	land = the_land
	_rng.seed = 73
	for t: Node3D in land.trees:
		var crown: Node3D = t.get_node_or_null("Crown")
		var tall := float(t.get_meta("tall",10.0))
		var leaf := Color("4f6e2c")
		if crown != null and crown.get_child_count() > 0:
			var m: Material = (crown.get_child(0) as MeshInstance3D).material_override
			if m is StandardMaterial3D: leaf = (m as StandardMaterial3D).albedo_color
		_trees.append({"node": t, "crown": crown, "tall": tall, "base": t.basis,
			"crown_base": crown.basis if crown != null else Basis.IDENTITY,
			"crown_at": crown.position if crown != null else Vector3.UP*tall*0.55,
			"at": Vector2(t.position.x,t.position.z),
			# Taller trees sway slower.
			"w": TAU*FREQ*sqrt(10.0/tall), "cw": TAU*CROWN_FREQ*sqrt(10.0/tall),
			"lean": Vector2.ZERO, "vel": Vector2.ZERO, "clean": Vector2.ZERO, "cvel": Vector2.ZERO,
			"shiver": 0.0, "cool": 0.0, "burst": false, "trickle": 0.0, "leaf": leaf, "near": false})
	var card := QuadMesh.new()
	card.size = Vector2(0.36,0.24)
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.vertex_color_is_srgb = true
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.roughness = 0.9
	card.material = m
	_leaf_mm.transform_format = MultiMesh.TRANSFORM_3D
	_leaf_mm.use_colors = true
	_leaf_mm.mesh = card
	_leaf_mm.instance_count = LEAVES
	_leaf_mm.visible_instance_count = 0
	var mmi := MultiMeshInstance3D.new()
	mmi.name = "Leaves"
	mmi.multimesh = _leaf_mm
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mmi)

## A shove from the head at `head` (xz) with heave `k` (0..1; 0 when the
## burrower is down).
func tick(delta: float, head: Vector2, k: float) -> void:
	_time += delta
	for t: Dictionary in _trees:
		_step_tree(t,delta,head,k)
	if land.probes: _shake_stood(delta,head,k)
	_step_leaves(delta)

## No leaves in the air.
func settled() -> bool:
	return _leaves.is_empty()

## The stood trees round the head: each shakes once as it goes by, when the
## head stops closing on it (or right up to it).
func _shake_stood(delta: float, head: Vector2, k: float) -> void:
	_ask -= delta
	if _ask > 0.0: return
	_ask = STOOD_EVERY
	if k <= 0.02:
		_felt.clear()
		_trail = Vector2.INF
		return
	# The map follows him: it is 384 m a side, and a sighting is farther than
	# that from the eye. Only he writes it.
	if react != null: react.gust_eye = head
	_lay_gust(head,k)
	if distant: return
	var t: PackedFloat32Array = land.trees_near(head,STOOD_REACH)
	var shook := 0
	for q in range(0,t.size(),4):
		var at := Vector2(t[q],t[q+1])
		var key := Vector2i(roundi(at.x*100.0),roundi(at.y*100.0))
		var was: Vector2 = _felt.get(key,Vector2(INF,-1.0))
		var d := head.distance_to(at)
		var due := was.y < 0.0 or _time-was.y > COOL
		if due and (d > was.x or d < STOOD_REACH*0.4) and shook < STOOD_MOST:
			was.y = _time
			shook += 1
			_shake_one(at,t[q+2],t[q+3],head,minf(d,was.x),k)
		was.x = d
		_felt[key] = was
	if _felt.size() > 400:
		for key: Vector2i in _felt.keys():
			if _time-(_felt[key] as Vector2).y > COOL: _felt.erase(key)

## A stamp of the gust each STOOD_STRIP m of his way, only with trees in its
## reach (the map draws nothing, and costs nothing, on open ground).
func _lay_gust(head: Vector2, k: float) -> void:
	if _trail == Vector2.INF:
		_trail = head
		return
	var moved := head.distance_to(_trail)
	if moved < STOOD_STRIP: return
	var way := (head-_trail)/moved
	var at := head+way*STOOD_LEAD
	var reach := SIGHT_GUST if sight else STOOD_GUST
	if react != null and moved < STOOD_STRIP*6.0 and land.trees_near(at,reach).size() > 0:
		react.gust_strip(at,way,moved,reach,k*SIGHT_K if sight else clampf(k*1.3,0.0,1.0))
	_trail = head

## Every stood tree within `r` m of `at` shaken at once (a push-up through
## the crowns).
func shove(at: Vector2, r: float) -> void:
	if react != null: react.gust_disc(at,r*1.5,1.0)
	var t: PackedFloat32Array = land.trees_near(at,r)
	for q in range(0,mini(t.size(),4*STOOD_MOST),4):
		_shake_one(Vector2(t[q],t[q+1]),t[q+2],t[q+3],at,at.distance_to(Vector2(t[q],t[q+1])),1.0)

func _shake_one(at: Vector2, foot: float, tall: float, head: Vector2, d: float, k: float) -> void:
	stats.shoved = int(stats.shoved)+1
	var near := pow(clampf(1.0-d/STOOD_REACH,0.0,1.0),0.7)*clampf(k*1.3,0.0,1.0)
	var away := (at-head).normalized() if d > 0.01 else Vector2.RIGHT
	_burst_at(Vector3(at.x,foot+tall*0.72,at.y),tall,STOOD_NEEDLE,int(lerpf(STOOD_BURST.y,STOOD_BURST.x,near)),away,foot)

func _step_tree(t: Dictionary, delta: float, head: Vector2, k: float) -> void:
	var at: Vector2 = t.at
	var d := head.distance_to(at)
	var push := 0.0
	var away := Vector2.ZERO
	if k > 0.02 and d < REACH:
		push = k*pow(1.0-d/REACH,1.5)
		away = (at-head).normalized() if d > 0.01 else Vector2.RIGHT
	t.cool = maxf(float(t.cool)-delta,0.0)
	if push > 0.0:
		if not t.near:
			stats.shoved = int(stats.shoved)+1
			t.burst = false
		# The burst when the shove has bitten (not at the reach's edge).
		if not t.burst and push > BURST_AT and float(t.cool) <= 0.0:
			_burst(t,int(BURST*clampf(push*2.0,0.4,1.0)),away)
			t.cool = COOL
			t.burst = true
		t.near = true
		t.shiver = maxf(float(t.shiver),clampf(push*1.4,0.0,1.0))
	else:
		t.near = false
	# The trunk's spring: shoved away from the head while it passes.
	var w: float = t.w
	var lean: Vector2 = t.lean
	var vel: Vector2 = t.vel
	var acc := -w*w*lean-2.0*DAMP*w*vel+away*push*SHOVE*w
	vel += acc*delta
	lean += vel*delta
	if lean.length() > MOST: lean = lean.normalized()*MOST
	# The crown's spring rides on the trunk: driven by the trunk's swing,
	# it lags and carries on past.
	var cw: float = t.cw
	var clean: Vector2 = t.clean
	var cvel: Vector2 = t.cvel
	var cacc := -cw*cw*(clean-lean*CROWN_GAIN)-2.0*CROWN_DAMP*cw*cvel
	cvel += cacc*delta
	clean += cvel*delta
	t.lean = lean
	t.vel = vel
	t.clean = clean
	t.cvel = cvel
	stats.most_lean = maxf(float(stats.most_lean),lean.length())
	t.shiver = maxf(float(t.shiver)-SHIVER_DECAY*delta*maxf(float(t.shiver),0.25),0.0)
	var sh := float(t.shiver)
	if sh > 0.05:
		t.trickle = float(t.trickle)+TRICKLE*sh*delta
		while float(t.trickle) >= 1.0:
			t.trickle = float(t.trickle)-1.0
			_burst(t,1,Vector2.ZERO)
	var node: Node3D = t.node
	node.basis = _lean_basis(lean)*Basis(t.base)
	var crown: Node3D = t.crown
	if crown != null:
		# The crown's own lean past the trunk's, in the tree's frame.
		var extra := clean-lean
		var base: Basis = t.base
		var world := _lean_basis(extra)
		crown.basis = base.inverse()*world*base*Basis(t.crown_base)

## A lean toward `lean`'s direction by its length (rad), about the foot.
func _lean_basis(lean: Vector2) -> Basis:
	var a := lean.length()
	if a < 1e-5: return Basis.IDENTITY
	var dir := lean/a
	return Basis(Vector3(dir.y,0.0,-dir.x),a)

# --- Leaves -----------------------------------------------------------------------

func _burst(t: Dictionary, n: int, away: Vector2) -> void:
	if n > 1: stats.bursts = int(stats.bursts)+1
	var node: Node3D = t.node
	var tall: float = t.tall
	var centre := node.global_transform*(Vector3(t.crown_at)+Vector3.UP*tall*0.3)
	_burst_at(centre,tall,t.leaf,n,away)

## `n` leaves out of a crown round `centre`, `tall` m its tree. With
## `floor_y` they land there (no land asked per leaf, per frame), as cards
## STOOD_CARD bigger.
func _burst_at(centre: Vector3, tall: float, leaf: Color, n: int, away: Vector2, floor_y := NAN) -> void:
	var size := 1.0 if is_nan(floor_y) else STOOD_CARD
	for i in n:
		if _leaves.size() >= LEAVES: _leaves.pop_front()
		var dir := Vector3(_rng.randf_range(-1,1),_rng.randf_range(-0.6,1),_rng.randf_range(-1,1)).normalized()
		var p := centre+dir*tall*_rng.randf_range(0.12,0.3)
		var out := dir*_rng.randf_range(0.6,2.4)+Vector3(away.x,0.0,away.y)*_rng.randf_range(0.5,2.5)
		out.y += _rng.randf_range(0.0,1.2) if n > 1 else 0.0
		var c: Color = leaf
		# Lighter than the crown, some turned yellow: they read against it.
		c = c.lerp(Color("a8bb4c"),_rng.randf_range(0.35,0.8)).lerp(Color("d0b04a"),_rng.randf()*_rng.randf()*0.6)
		_leaves.append({"p": p, "v": out, "age": 0.0, "rest": -1.0, "c": c,
			"axis": Vector3(_rng.randf_range(-1,1),_rng.randf_range(-1,1),_rng.randf_range(-1,1)).normalized(),
			"spin": _rng.randf_range(3.0,9.0), "turn": _rng.randf()*TAU, "phase": _rng.randf()*TAU,
			"sway": _rng.randf_range(1.6,3.0), "size": _rng.randf_range(0.7,1.4)*size, "floor": floor_y})

func _step_leaves(delta: float) -> void:
	var i := 0
	while i < _leaves.size():
		var l: Dictionary = _leaves[i]
		l.age = float(l.age)+delta
		var p: Vector3 = l.p
		var ground: float = land.height(p.x,p.z) if is_nan(float(l.floor)) else float(l.floor)
		if float(l.rest) < 0.0:
			var v: Vector3 = l.v
			# Heavy drag: a leaf falls slow and drifts, swinging side to side.
			v.y -= 9.0*delta
			v *= 1.0-minf(3.2*delta,0.5)
			v.y = maxf(v.y,-LEAF_FALL)
			var swing := sin(float(l.age)*float(l.sway)+float(l.phase))
			p += (v+Vector3(cos(float(l.phase)),0.0,sin(float(l.phase)))*swing*0.9)*delta
			l.v = v
			l.turn = float(l.turn)+float(l.spin)*delta
			if p.y <= ground+0.06:
				p.y = ground+0.06
				l.rest = 0.0
		else:
			l.rest = float(l.rest)+delta
			if float(l.rest) > LEAF_LIE: p.y -= delta*0.12
			if float(l.rest) > LEAF_LIE+2.0:
				_leaves.remove_at(i)
				continue
		l.p = p
		i += 1
	var n := _leaves.size()
	_leaf_mm.visible_instance_count = n
	for k in n:
		var l: Dictionary = _leaves[k]
		var b: Basis
		if float(l.rest) < 0.0:
			b = Basis(Vector3(l.axis),float(l.turn))
		else:
			# Lying flat in the grass.
			b = Basis(Vector3.RIGHT,-PI*0.5)*Basis(Vector3.FORWARD,float(l.turn))
		_leaf_mm.set_instance_transform(k,Transform3D(b.scaled(Vector3.ONE*float(l.size)),l.p))
		_leaf_mm.set_instance_color(k,l.c)
	stats.leaves = n
