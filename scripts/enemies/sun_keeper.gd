extends "res://scripts/enemies/enemy.gd"
## The Sun-Keepers (card h1). "Set here to hold the sun up. Nobody came to say it
## had gone." Tall thin figures of lime plaster over clay, a disc of hammered
## mica for a face. They can only stand where light falls, and the torch in
## your hand is light.
##
## The rule, as built:
##   - A foot is set down only on lit floor (`light_on`): a lit SightLight
##     reaching it (a cresset, a beacon, a held sun, a dropped torch) or the
##     wanderer's torch pool (POOL m round his flame, flat). Before each
##     stride it looks at where the foot will land; dark there, it stops at
##     the rim with that foot raised over the dark, swaying ("rim").
##   - The light under it went OUT (his torch doused, a cresset doused or
##     tipped): it has nothing to stand on and topples where it is, stiff as
##     a plank. Its head over the void, it goes over and is gone; on a floor
##     it lies as a heap (a step), and a heap lit again for `rise` s stands.
##   - The light under it went AWAY (he walked off with his torch lit): it
##     freezes mid-step, a statue ("statue"), and wakes when lit again.
##
## Hunting: woken by light, it turns to his torch within `sense` m (its mica
## disc flashes: the tell from far off), and walks to it stride by planted
## stride, a stork hold on the back foot each step, a beat too long. In
## `reach` it winds up (arms back, then up and out) and lays hands on him:
## the first time a shove, PilotMotor.knock + harm 1 ("a Sun-Keeper"); the
## `steal_after`th time it takes the torch ("thief"): his torch goes out, it
## holds it high and walks to its `goal` (the study's `keeper_goal`, else
## away from him), a lit Beacon every Olmec in draw turns to. Knocked down
## (an Olmec barging it, a run or slide into it), it drops the torch where
## it stands (`DroppedTorch`, a pool of its own): walk over it to take it
## back. Gone into the void with it, the torch is gone: light another at
## any fire (city_kit_fires.gd: touching a burning piece relights it).
##
## Greybox: plaster boxes and drums in the city's stone mesher, posed in
## code (no clips yet). Sounds are synth placeholders (VOICES).
const Fires = preload("res://scripts/city_kit_fires.gd")
const GiantStone = preload("res://scripts/kit_isle/greybox/giant_stone.gd")
const Flame = preload("res://scripts/flame.gd")

const GROUP := &"sun_keepers"
## The wanderer's torch pool: its radius (m, flat, at his size; the card's
## "about 8 m across"), and how far over and under his flame a floor is in it.
const POOL := 4.0
const POOL_OVER := 1.0
const POOL_UNDER := 4.0
## A SightLight lights a foot at this much (its light_at at the floor).
const LIT_MIN := 0.12
## The placeholder sounds ([s, Hz from, Hz to, noise share, low-pass, attack,
## tremolo Hz], studies/enemy_yard.gd `_synth`), and how far each carries.
const VOICES := {
	"keeper_step":[0.14,0.0,0.0,1.0,0.6,0.002,0.0],
	"keeper_wake":[1.0,0.0,0.0,1.0,0.9,0.3,0.0],
	"keeper_reach":[0.35,210.0,150.0,0.6,0.4,0.03,0.0],
	"keeper_crash":[0.8,70.0,35.0,0.85,0.25,0.002,0.0],
	"keeper_steal":[0.6,330.0,520.0,0.4,0.3,0.02,9.0],
	"keeper_drop":[0.3,500.0,300.0,0.5,0.4,0.005,0.0],
}
const REACH := {"keeper_step":22.0,"keeper_wake":26.0,"keeper_reach":18.0,"keeper_crash":40.0,"keeper_steal":30.0,"keeper_drop":20.0}
## The plaster and the clay under it, the mica.
const PLASTER := Color(0.83,0.8,0.72)
const CLAY := Color(0.62,0.42,0.24)
const MICA := Color(0.78,0.76,0.7)

## The figure's tallness (m) and its stride (m), from the pilot's numbers.
var tall := 1.7
var stride := 1.0
## Where a thief takes the torch (world), INF: away from him; the waypoints
## after it (the study's `keeper_goal`: a point, or an Array of them).
var goal := Vector3.INF
var route: Array = []
var _fall_from := 0.0
## What lit the floor under it last frame (a SightLight, &"torch" or null).
var lit_by: Variant = null
## Times it laid hands on him; shoves; steals; topples; strides; rim waits.
var touches := 0
var shoves := 0
var steals := 0
var topples := 0
var strides := 0
var rims := 0
## The torch it holds high as a thief (a Beacon: every Olmec turns to it).
var held_sun: Beacon
var torch_prop: Node3D
## The gait: "" standing, "lift", "swing", "plant", "hold"; the leg stepping.
var phase := ""
var phase_t := 0.0
var lead := 0
var _way := Vector3.ZERO
var _foot_from := Vector3.ZERO
var _foot_at := Vector3.ZERO
var _clock := 0.0
var _rim_look := 0.0
var _flash := 0.0
var _saw := false
var _lit_t := 0.0
var _fall_dir := Vector3.FORWARD
var _fall_axis := Vector3.RIGHT
var _angle := 0.0
var _shape: CollisionShape3D
# The rig: tilt (the topple, about the feet), hips, torso, head, the disc,
# arms at the shoulders, thighs at the hips, shins at the knees.
var _tilt: Node3D
var _hips: Node3D
var _torso: Node3D
var _head: Node3D
var _arm: Array[Node3D] = []
var _thigh: Array[Node3D] = []
var _shin: Array[Node3D] = []
var _disc_mat: StandardMaterial3D
var _frozen := false
var _seed := 0

func default_knobs(n: Dictionary) -> Dictionary:
	var s := float(n.size)
	return {
		# Its height in his body's height (the card's 1.5), its stride in its
		# height, its pace in his walk (planted steps: slower than him).
		"tall":1.5,"stride_k":0.6,"pace":0.67,"thief_pace":0.8,
		# The shares of a stride's time: lift, swing, plant, the stork hold.
		"lift":0.18,"swing":0.42,"plant":0.12,"hold":0.28,
		"turn":3.5,"sense":24.0*s,"reach":0.75*s,"windup":0.5,"recoil":0.9,
		"shove_out":3.0*s,"shove_up":0.7*s,"steal_after":2,"steal_out":1.2*s,
		"wake":0.6,"topple":0.65,"rise":1.2,"stand_up":0.8,
		# The held sun: its reach (in pools), how far it draws an Olmec (m).
		"sun":1.25,"draw":60.0*s,
		# Only a full run's pace (a slide, a long jump) knocks one over.
		"push_speed":float(n.run)*1.05,
	}

func _size(n: Dictionary) -> void:
	tall = float(n.unit)*float(knobs.tall)
	height = tall
	width = tall*0.26
	length = tall*0.18
	stride = tall*float(knobs.stride_k)

func harm_cause() -> String:
	return "a Sun-Keeper"

func _build() -> void:
	super._build()
	add_to_group(GROUP)
	_shape = body.get_child(0) as CollisionShape3D
	tell_sound = &"keeper_reach"
	_seed = hash(position)
	state = "statue"
	_frozen = true

# --- The figure ------------------------------------------------------------------------

## The plaster figure: long legs, a narrow torso, a tall head with the mica
## disc on its front (-Z), arms hanging. Clay shows through flaked plaster.
func _art(root: Node3D) -> void:
	var h := tall
	var leg := h*0.5
	var thigh := leg*0.52
	var shin := leg-thigh
	var torso_h := h*0.3
	var head_h := h*0.16
	var tw := h*0.24
	var td := h*0.13
	_tilt = Node3D.new()
	_tilt.name = "Tilt"
	root.add_child(_tilt)
	_hips = Node3D.new()
	_hips.name = "Hips"
	_hips.position = Vector3(0.0,leg,0.0)
	_tilt.add_child(_hips)
	_torso = Node3D.new()
	_torso.name = "Torso"
	_hips.add_child(_torso)
	var m := _mesher()
	# A tapering torso: a wide shoulder block over a narrower waist, a
	# collar, the flaking plaster as clay patches on the front and side.
	m.box(Transform3D(Basis.IDENTITY,Vector3(0.0,torso_h*0.3,0.0)),Vector3(tw*0.72,torso_h*0.6,td*0.9),0.03)
	m.box(Transform3D(Basis.IDENTITY,Vector3(0.0,torso_h*0.78,0.0)),Vector3(tw,torso_h*0.44,td),0.04)
	m.box(Transform3D(Basis.IDENTITY,Vector3(0.0,torso_h*1.02,0.0)),Vector3(tw*0.42,torso_h*0.08,td*0.7),0.02)
	_mesh(_torso,m,"Plaster")
	var c := _clay()
	c.box(Transform3D(Basis(Vector3.UP,0.2),Vector3(tw*0.18,torso_h*0.7,-td*0.5)),Vector3(tw*0.3,torso_h*0.22,0.02),0.0)
	c.box(Transform3D(Basis.IDENTITY,Vector3(-tw*0.3,torso_h*0.25,-td*0.46)),Vector3(tw*0.2,torso_h*0.3,0.02),0.0)
	c.box(Transform3D(Basis.IDENTITY,Vector3(tw*0.5,torso_h*0.6,0.0)),Vector3(0.02,torso_h*0.3,td*0.5),0.0)
	_mesh(_torso,c,"Clay")
	_head = Node3D.new()
	_head.name = "Head"
	_head.position = Vector3(0.0,torso_h*1.06,0.0)
	_torso.add_child(_head)
	var hm := _mesher()
	hm.box(Transform3D(Basis.IDENTITY,Vector3(0.0,head_h*0.12,0.0)),Vector3(tw*0.2,head_h*0.24,td*0.4),0.01)
	hm.cylinder(Transform3D(Basis.IDENTITY,Vector3(0.0,head_h*0.62,0.0)),tw*0.24,head_h*0.8,8,0.04)
	_mesh(_head,hm,"Plaster")
	# The mica disc: no features, only his torch looking back.
	var disc := MeshInstance3D.new()
	disc.name = "Mica"
	var dm := CylinderMesh.new()
	dm.top_radius = tw*0.3
	dm.bottom_radius = tw*0.3
	dm.height = 0.025
	dm.radial_segments = 16
	disc.mesh = dm
	_disc_mat = StandardMaterial3D.new()
	_disc_mat.albedo_color = MICA
	_disc_mat.metallic = 0.85
	_disc_mat.roughness = 0.18
	_disc_mat.emission_enabled = true
	_disc_mat.emission = Color(1.0,0.72,0.4)
	_disc_mat.emission_energy_multiplier = 0.0
	disc.material_override = _disc_mat
	disc.rotation.x = PI*0.5
	disc.position = Vector3(0.0,head_h*0.62,-tw*0.25)
	_head.add_child(disc)
	for side in 2:
		var sx := -1.0 if side == 0 else 1.0
		var arm := Node3D.new()
		arm.name = "Arm%d" % side
		arm.position = Vector3(sx*(tw*0.5+0.035),torso_h*0.92,0.0)
		_torso.add_child(arm)
		var am := _mesher()
		var arm_l := h*0.36
		am.box(Transform3D(Basis.IDENTITY,Vector3(0.0,-arm_l*0.5,0.0)),Vector3(0.07*h/1.7,arm_l,0.08*h/1.7),0.015)
		am.box(Transform3D(Basis.IDENTITY,Vector3(0.0,-arm_l-0.04,-0.01)),Vector3(0.08*h/1.7,0.1*h/1.7,0.05*h/1.7),0.01)
		_mesh(arm,am,"Plaster")
		_arm.append(arm)
		var t := Node3D.new()
		t.name = "Thigh%d" % side
		t.position = Vector3(sx*tw*0.2,0.0,0.0)
		_hips.add_child(t)
		var tm := _mesher()
		tm.box(Transform3D(Basis.IDENTITY,Vector3(0.0,-thigh*0.5,0.0)),Vector3(0.1*h/1.7,thigh,0.11*h/1.7),0.02)
		_mesh(t,tm,"Plaster")
		var s := Node3D.new()
		s.name = "Shin%d" % side
		s.position = Vector3(0.0,-thigh,0.0)
		t.add_child(s)
		var sm := _mesher()
		sm.box(Transform3D(Basis.IDENTITY,Vector3(0.0,-shin*0.5,0.0)),Vector3(0.08*h/1.7,shin,0.09*h/1.7),0.02)
		sm.box(Transform3D(Basis.IDENTITY,Vector3(0.0,-shin+0.03,-0.05)),Vector3(0.11*h/1.7,0.06,0.2*h/1.7),0.015)
		_mesh(s,sm,"Plaster")
		if side == 1:
			var sc := _clay()
			sc.box(Transform3D(Basis.IDENTITY,Vector3(0.0,-shin*0.4,-0.046*h/1.7)),Vector3(0.06,shin*0.3,0.01),0.0)
			_mesh(s,sc,"Clay")
		_thigh.append(t)
		_shin.append(s)
	# The torch it holds high as a thief: on the right hand, hidden till then.
	torch_prop = Node3D.new()
	torch_prop.name = "HeldTorch"
	torch_prop.position = Vector3(0.0,-h*0.36-0.06,0.0)
	_arm[1].add_child(torch_prop)
	var stick := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.035
	cyl.bottom_radius = 0.045
	cyl.height = 0.5
	stick.mesh = cyl
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color(0.2,0.12,0.07)
	stick.material_override = wood
	stick.rotation.x = PI
	stick.position = Vector3(0.0,-0.15,0.0)
	torch_prop.add_child(stick)
	var flame: Node3D = Flame.new()
	flame.set("kind","torch")
	flame.set("scale_by",0.72)
	flame.set("with_light",false)
	flame.set("with_smoke",false)
	flame.rotation.x = PI
	flame.position = Vector3(0.0,-0.42,0.0)
	torch_prop.add_child(flame)
	var omni := OmniLight3D.new()
	omni.light_color = Color(1.0,0.58,0.22)
	omni.light_energy = 2.0
	omni.omni_range = 12.0
	omni.omni_attenuation = 1.4
	omni.position = Vector3(0.0,-0.6,0.0)
	torch_prop.add_child(omni)
	held_sun = Beacon.new()
	held_sun.name = "HeldSun"
	held_sun.lit = false
	held_sun.radius = POOL*float(field.numbers().size)*float(knobs.sun)
	held_sun.strength = 1.0
	held_sun.draw = float(knobs.draw)
	held_sun.gather = 3.0
	held_sun.position = Vector3(0.0,-0.5,0.0)
	torch_prop.add_child(held_sun)
	torch_prop.visible = false
	_pose_upright()

func _mesher() -> GiantStone.Mesher:
	return GiantStone.Mesher.new(PLASTER)

func _clay() -> GiantStone.Mesher:
	return GiantStone.Mesher.new(CLAY)

func _mesh(parent: Node3D, m: GiantStone.Mesher, n: String) -> void:
	var mi := MeshInstance3D.new()
	mi.name = n
	mi.mesh = GiantStone.mesh_of(m)
	parent.add_child(mi)

# --- Light ---------------------------------------------------------------------------

## The torch pool's radius (m, flat) at his size.
static func pool_radius() -> float:
	return POOL*Fires.size()

## Whether floor point `p` is in the wanderer's torch pool (his torch lit).
static func in_torch_pool(tree: SceneTree, p: Vector3) -> bool:
	if not Fires.torch_lit(tree): return false
	var f := Fires.torch_point(tree)
	if f == Vector3.INF: return false
	var k := Fires.size()
	if p.y > f.y+POOL_OVER*k or p.y < f.y-POOL_UNDER*k: return false
	return Vector2(p.x-f.x,p.z-f.z).length() <= pool_radius()

## What lights floor point `p` for a Keeper's foot: a lit SightLight reaching
## it, &"torch" (his pool), or null (dark). By day (no dark at all) &"day".
static func light_on(tree: SceneTree, p: Vector3) -> Variant:
	if tree == null: return null
	if LightLevel.daylight() and LightLevel.look(tree) == null: return &"day"
	var q := p+Vector3.UP*0.3
	for l in tree.get_nodes_in_group(SightLight.GROUP):
		if l is SightLight and (l as SightLight).is_inside_tree() and (l as SightLight).light_at(q) >= LIT_MIN: return l
	if in_torch_pool(tree,p): return &"torch"
	return null

## Whether the light that held it last frame went out (not away).
func _went_out(tree: SceneTree) -> bool:
	if lit_by == null: return false
	if lit_by is StringName:
		return lit_by == &"torch" and not Fires.torch_lit(tree)
	if not is_instance_valid(lit_by): return true
	var l := lit_by as SightLight
	return l == null or not l.lit or not l.is_inside_tree()

## The keeper holding his torch now, or null.
static func thief_of(tree: SceneTree) -> Node3D:
	if tree == null: return null
	for k in tree.get_nodes_in_group(GROUP):
		if is_instance_valid(k) and str(k.get("state")) == "thief": return k as Node3D
	return null

## Whether his torch is out of his hands (held by a keeper, or lying where
## one dropped it).
static func torch_taken(tree: SceneTree) -> bool:
	return thief_of(tree) != null or not tree.get_nodes_in_group(DroppedTorch.GROUP).is_empty()

# --- A frame ---------------------------------------------------------------------------

func step(delta: float) -> void:
	rotation.y = facing
	super.step(delta)
	if gone: return
	_pose(delta)

func think(delta: float) -> void:
	var tree := get_tree()
	_clock += delta
	state_t += delta
	if state == "idle": _to("watch")
	if state in ["topple","heap","rise","fall"]:
		_think_down(delta,tree)
		return
	if _barged(tree): return
	var m: PilotMotor = field.motor
	if state == "thief":
		_think_thief(delta,tree,m)
		return
	# The floor under it: lit, or not (mid-stride, either foot's).
	var src: Variant = light_on(tree,position)
	if src == null and phase in ["lift","swing","plant"]: src = light_on(tree,_foot_at)
	if src == null and phase in ["lift","swing"]: src = light_on(tree,_foot_from)
	if src == null:
		vel = Vector3.ZERO
		if _went_out(tree):
			lit_by = null
			topple(_fall_way())
			return
		lit_by = null
		if state != "statue": _freeze()
		return
	lit_by = src
	if state == "statue":
		_to("wake")
		_frozen = false
		field.sound(&"keeper_wake",global_position)
		return
	var seen := Fires.torch_lit(tree) and _senses(m)
	if seen and not _saw: field.sound(&"keeper_reach",global_position)
	_saw = seen
	var to := Vector3(m.feet.x-position.x,0.0,m.feet.z-position.z)
	match state:
		"wake":
			vel = Vector3.ZERO
			if state_t >= float(knobs.wake): _to("watch")
		"reach":
			vel = Vector3.ZERO
			_turn_to(to,delta,0.5)
			if state_t >= float(knobs.windup): _lay_hands(m,tree)
		"recoil":
			vel = Vector3.ZERO
			if state_t >= float(knobs.recoil): _to("watch")
		_:
			if not seen:
				# Nothing to walk to: it finishes the stride it is in and stands.
				if phase == "" or phase == "hold":
					phase = ""
					vel = Vector3.ZERO
					if state != "watch": _to("watch")
				else: _gait(delta,_way,float(knobs.pace),tree)
				return
			var reach := width*0.5+float(knobs.radius)+float(knobs.reach)
			if to.length() <= reach and absf(m.feet.y-position.y) < tall*0.8 and (phase == "" or phase == "hold"):
				phase = ""
				vel = Vector3.ZERO
				_to("reach")
				field.sound(&"keeper_reach",global_position)
				return
			if phase == "" or phase == "hold": _turn_to(to,delta,1.0)
			_gait(delta,to,float(knobs.pace),tree)

## His torch in its sense: lit, within `sense` m flat, not far over or under.
func _senses(m: PilotMotor) -> bool:
	var d := Vector2(m.feet.x-position.x,m.feet.z-position.z).length()
	return d <= float(knobs.sense) and absf(m.feet.y-position.y) < tall*4.0

func _to(s: String) -> void:
	state = s
	state_t = 0.0

func _turn_to(to: Vector3, delta: float, share: float) -> void:
	if Vector2(to.x,to.z).length() < 0.05: return
	var want := PilotMotor.facing_of(Vector2(to.x,to.z))
	facing = facing+clampf(wrapf(want-facing,-PI,PI),-float(knobs.turn)*share*delta,float(knobs.turn)*share*delta)

## One frame of the planted walk toward `to` (flat) at `pace` of his walk:
## standing, it looks at where the foot will land (lit, a floor, no wall)
## and steps, or waits at the rim with that foot raised over the dark.
func _gait(delta: float, to: Vector3, pace: float, tree: SceneTree) -> void:
	var speed := float(field.numbers().walk)*pace
	var cycle := stride/maxf(speed,0.01)
	var shares: Array[float] = [float(knobs.lift),float(knobs.swing),float(knobs.plant),float(knobs.hold)]
	var total := 0.0
	for s: float in shares: total += s
	phase_t += delta
	match phase:
		"":
			vel = Vector3.ZERO
			var fwd := PilotMotor.forward(facing)
			var way := Vector3(fwd.x,0.0,fwd.y)
			# Facing it well enough first.
			if Vector2(to.x,to.z).length() > 0.05 and way.dot(Vector3(to.x,0.0,to.z).normalized()) < 0.85:
				return
			_rim_look -= delta
			if _rim_look > 0.0: return
			var foot := position+way*stride
			if not _can_step(foot,way,tree):
				if state != "rim" and state != "thief":
					_to("rim")
					rims += 1
				_rim_look = 0.15
				return
			if state != "walk" and state != "thief": _to("walk")
			_way = way
			_foot_from = position
			_foot_at = foot
			lead = 1-lead
			phase = "lift"
			phase_t = 0.0
		"lift":
			vel = Vector3.ZERO
			if phase_t >= cycle*shares[0]/total: _next("swing")
		"swing":
			var t := cycle*shares[1]/total
			# The stride's length over the swing's time: planted pace.
			vel = _way*(stride/t)
			if edge_ahead(Vector2(_way.x,_way.z),length*0.5+0.1):
				vel = Vector3.ZERO
				_next("plant")
			elif phase_t >= t: _next("plant")
		"plant":
			vel = Vector3.ZERO
			if phase_t < delta*1.5:
				strides += 1
				field.sound(&"keeper_step",global_position)
			if phase_t >= cycle*shares[2]/total: _next("hold")
		"hold":
			vel = Vector3.ZERO
			if phase_t >= cycle*shares[3]/total: _next("")

func _next(p: String) -> void:
	phase = p
	phase_t = 0.0

## Whether a foot can come down at `foot`: floor there (within a step), lit,
## and nothing standing in the way.
func _can_step(foot: Vector3, way: Vector3, tree: SceneTree) -> bool:
	var g: float = field.floor_under(foot,float(knobs.step_up),float(knobs.step_up)*2.0,body.get_rid())
	if g == -INF: return false
	if light_on(tree,Vector3(foot.x,g,foot.z)) == null: return false
	var off := _siblings_aside() if state == "thief" else {}
	var clear: bool = not field.blocked(position+Vector3.UP*float(knobs.wall_probe),way*(stride+length*0.5),body.get_rid())
	_siblings_back(off)
	return clear

## The other keepers' bodies out of the rays a moment (their layers, kept).
func _siblings_aside() -> Dictionary:
	var off := {}
	for k in get_tree().get_nodes_in_group(GROUP):
		if k == self or not is_instance_valid(k): continue
		var b: StaticBody3D = k.get("body")
		if b == null: continue
		off[b] = b.collision_layer
		b.collision_layer = 0
	return off

func _siblings_back(off: Dictionary) -> void:
	for b: Variant in off:
		if is_instance_valid(b): (b as StaticBody3D).collision_layer = int(off[b])

func _freeze() -> void:
	_to("statue")
	phase = ""
	_frozen = true

# --- Hands on him ----------------------------------------------------------------------

func _lay_hands(m: PilotMotor, tree: SceneTree) -> void:
	_to("recoil")
	var to := Vector2(m.feet.x-position.x,m.feet.z-position.z)
	var reach := width*0.5+float(knobs.radius)+float(knobs.reach)+0.35
	if to.length() > reach or absf(m.feet.y-position.y) > tall*0.8 or m.seized(): return
	touches += 1
	var way := to.normalized() if to.length() > 0.01 else PilotMotor.forward(facing)
	if touches >= int(knobs.steal_after) and Fires.torch_lit(tree) and thief_of(tree) == null:
		_steal(m,way,tree)
		return
	shoves += 1
	shove_pilot(m,way,float(knobs.shove_out),float(knobs.shove_up))

## It takes his torch and holds it high: his light goes out, its own sun
## stands round it (a Beacon), and it walks off to its goal.
func _steal(m: PilotMotor, way: Vector2, tree: SceneTree) -> void:
	steals += 1
	held_sun.light()
	torch_prop.visible = true
	Fires.set_torch(tree,false)
	m.knock(m.knock_velocity(way,float(knobs.steal_out),0.3),self)
	_cool = 0.3
	hit_pilot.emit(self)
	field.sound(&"keeper_steal",global_position)
	var g: Variant = field.study.get("keeper_goal") if field.study != null else null
	route = []
	if g is Vector3: route = [g]
	elif g is Array: route = _route_from(g as Array)
	goal = route.pop_front() if not route.is_empty() else Vector3.INF
	phase = ""
	_to("thief")

## The waypoints of `points` still ahead of it: from the nearest, or past it
## when it already stands between that one and the next.
func _route_from(points: Array) -> Array:
	if points.is_empty(): return []
	var best := 0
	for i in points.size():
		if position.distance_to(points[i]) < position.distance_to(points[best]): best = i
	if best+1 < points.size():
		var a: Vector3 = points[best]
		var b: Vector3 = points[best+1]
		if position.distance_to(b) < a.distance_to(b): best += 1
	return points.slice(best)

func _think_thief(delta: float, tree: SceneTree, m: PilotMotor) -> void:
	var to := Vector3.ZERO
	if goal != Vector3.INF: to = Vector3(goal.x-position.x,0.0,goal.z-position.z)
	else: to = Vector3(position.x-m.feet.x,0.0,position.z-m.feet.z).normalized()*10.0
	if to.length() < 0.8 and not route.is_empty():
		goal = route.pop_front()
		return
	if to.length() < 0.8 and (phase == "" or phase == "hold"):
		phase = ""
		vel = Vector3.ZERO
		return
	if phase == "" or phase == "hold": _turn_to(to,delta,1.0)
	_gait(delta,to,float(knobs.thief_pace),tree)

## The torch let go where it stands (on a floor: a DroppedTorch to take
## back; over the void: gone with it).
func _drop_torch(on_floor := true) -> void:
	if state != "thief" and not torch_prop.visible: return
	held_sun.douse()
	torch_prop.visible = false
	# Its hold on him starts over: next time a shove first, not the torch.
	touches = 0
	field.sound(&"keeper_drop",global_position)
	if not on_floor: return
	var g: float = field.floor_under(position,1.0,2.0,body.get_rid())
	if g == -INF: return
	var t := DroppedTorch.new()
	t.motor = field.motor
	field.add_child(t)
	t.global_position = Vector3(position.x,g,position.z)

# --- Knocked down ----------------------------------------------------------------------

## A walking Olmec ran into it: over it goes, his way.
func _barged(tree: SceneTree) -> bool:
	for e: Variant in Fires.olmecs(tree):
		var b := e as Node3D
		if b == null: continue
		var v: Vector3 = b.get("vel")
		var flat := Vector2(b.global_position.x-position.x,b.global_position.z-position.z)
		var reach := float(b.get("width"))*0.5+width
		if flat.length() > reach or absf(b.global_position.y-position.y) > tall*2.0: continue
		var way := Vector3(v.x,0.0,v.z)
		if way.length() < 0.6: way = Vector3(-flat.x,0.0,-flat.y)
		topple(way)
		return true
	return false

## Run or slid into at a full run's pace: it drops what it holds, stunned.
func pushed(speed: float) -> void:
	if state == "thief": _drop_torch()
	super.pushed(speed)

## Over it goes along `way` (flat, world), stiff as a plank.
func topple(way: Vector3) -> void:
	if state in ["topple","fall","heap","rise"] or gone: return
	if state == "thief": _drop_torch()
	var d := Vector3(way.x,0.0,way.z)
	_fall_dir = d.normalized() if d.length() > 0.01 else Vector3(PilotMotor.forward(facing).x,0.0,PilotMotor.forward(facing).y)
	var local := Basis(Vector3.UP,facing).inverse()*_fall_dir
	_fall_axis = Vector3.UP.cross(local).normalized()
	topples += 1
	phase = ""
	vel = Vector3.ZERO
	_frozen = false
	_to("topple")
	field.sound(&"keeper_wake",global_position)

## Which way it goes over: toward the void if there is void beside it
## (its head would hang over it), the nearer side first, else forward.
func _fall_way() -> Vector3:
	var fwd2 := PilotMotor.forward(facing)
	var fwd := Vector3(fwd2.x,0.0,fwd2.y)
	var right := fwd.cross(Vector3.UP).normalized()
	for share: float in [0.5,0.9]:
		for s: float in [1.0,-1.0]:
			var p := position+right*s*tall*share
			if field.floor_under(p,0.6,2.0,body.get_rid()) == -INF: return right*s
	return fwd

func _think_down(delta: float, tree: SceneTree) -> void:
	vel = Vector3(0.0,vel.y,0.0) if not grounded else Vector3.ZERO
	match state:
		"topple":
			var wob := 0.15
			var t := float(knobs.topple)
			if state_t < wob: _angle = -0.1*sin(state_t/wob*PI)
			else:
				var u := clampf((state_t-wob)/t,0.0,1.0)
				_angle = u*u*PI*0.5
				# Its head over the rim: the weight goes over, it falls.
				if _angle > 0.7:
					var head := position+_fall_dir*tall*0.85
					if field.floor_under(head,1.0,tall,body.get_rid()) == -INF:
						grounded = false
						vel = _fall_dir*2.2+Vector3.UP*0.6
						_fall_from = position.y
						_to("fall")
						return
				if u >= 1.0:
					_lie()
					_to("heap")
					field.sound(&"keeper_crash",global_position)
		"heap":
			var centre := position+_fall_dir*tall*0.5
			if light_on(tree,centre) != null or light_on(tree,position) != null: _lit_t += delta
			else: _lit_t = 0.0
			if _lit_t >= float(knobs.rise):
				_lit_t = 0.0
				_stand_collider()
				_to("rise")
				field.sound(&"keeper_wake",global_position)
		"rise":
			var u := clampf(state_t/float(knobs.stand_up),0.0,1.0)
			_angle = PI*0.5*(1.0-u)*(1.0-u)
			if u >= 1.0:
				_angle = 0.0
				lit_by = light_on(tree,position)
				_to("watch")
		"fall":
			pass

## Lying: its collider along the floor its way, a step.
func _lie() -> void:
	_angle = PI*0.5
	var b := Basis(_fall_axis,PI*0.5)
	var half := absf((b*Vector3(width*0.5,0.0,0.0)).y)+absf((b*Vector3(0.0,0.0,length*0.5)).y)
	_shape.transform = Transform3D(b,b*Vector3(0.0,tall*0.5,0.0)+Vector3.UP*half)

func _stand_collider() -> void:
	_shape.transform = Transform3D(Basis.IDENTITY,Vector3(0.0,tall*0.5,0.0))

## Gone over the side: a stiff plank sliding off the rim, its feet with it;
## it comes down only on something a fall below (a ledge under the span),
## never back on the rim it went over.
func _move(delta: float) -> void:
	if state == "thief":
		# Holding its sun it slips past its own household on a narrow span.
		var off := _siblings_aside()
		super._move(delta)
		_siblings_back(off)
		return
	if state != "fall":
		super._move(delta)
		return
	vel.y -= float(knobs.gravity)*delta
	var was_y := position.y
	position += vel*delta
	_air_pose(delta)
	if vel.y <= 0.0 and position.y < _fall_from-1.0:
		var g: float = field.floor_under(position,was_y-position.y+0.05,0.05,body.get_rid())
		if g != -INF:
			position.y = g
			grounded = true
			vel = Vector3.ZERO
			landed()
			return
	if position.y < field.lost:
		gone = true
		field.gone_count += 1
		fell.emit(self)
		queue_free()

## Falling: it keeps turning over as it goes down.
func _air_pose(delta: float) -> void:
	_angle = minf(_angle+2.6*delta,PI*0.95)

func landed() -> void:
	if state == "fall" or state == "stun":
		_lie()
		_to("heap")
		field.sound(&"keeper_crash",global_position)

## Enemy.push_out: only standing (a heap is a step, its collider real).
func push_out(m: PilotMotor, slide: Callable, body_low: float, head: float) -> void:
	if state in ["topple","heap","rise","fall"]: return
	super.push_out(m,slide,body_low,head)

func touch(m: PilotMotor, v_pre: Vector3) -> void:
	if state in ["topple","heap","rise","fall"]: return
	super.touch(m,v_pre)

# --- The pose (procedural greybox: no clips yet) -----------------------------------------

func _pose_upright() -> void:
	for i in 2:
		_thigh[i].rotation = Vector3.ZERO
		_shin[i].rotation = Vector3.ZERO
		_arm[i].rotation = Vector3(0.06,0.0,0.0)

## The joints toward this state's key pose, quick (snappy, with holds).
func _pose(delta: float) -> void:
	if _tilt == null: return
	# The topple about the feet, raised by its thickness as it lies.
	_tilt.basis = Basis(_fall_axis,_angle) if absf(_angle) > 0.0001 else Basis.IDENTITY
	var lying := clampf(_angle/(PI*0.5),0.0,1.0)
	_tilt.position.y = lying*length*0.5
	# The mica's flash: his torch caught in it, by how square it faces him.
	var want_flash := 0.0
	var tree := get_tree()
	if state == "thief": want_flash = 1.0
	elif Fires.torch_lit(tree) and field.motor != null:
		var m: PilotMotor = field.motor
		var to := Vector2(m.feet.x-position.x,m.feet.z-position.z)
		if to.length() <= float(knobs.sense) and to.length() > 0.01:
			var f := PilotMotor.forward(facing).dot(to.normalized())
			want_flash = pow(maxf(f,0.0),6.0)*clampf(1.2-to.length()/float(knobs.sense),0.0,1.0)
	_flash = lerpf(_flash,want_flash,1.0-exp(-8.0*delta))
	if _disc_mat != null:
		var flick := 0.8+0.2*sin(_clock*23.0+float(_seed%7))
		_disc_mat.emission_energy_multiplier = 0.05+4.0*_flash*flick
	if _frozen or state == "statue": return
	if state in ["topple","heap","fall"]:
		# Stiff as a plank: arms tight, legs straight.
		_toward(delta,[0.0,0.0],[0.0,0.0],[0.0,0.0],0.0,0.0,22.0)
		return
	var th := [0.0,0.0]
	var sh := [0.0,0.0]
	var ar := [0.06,0.06]
	var lean := 0.0
	var sway := 0.0
	var dip := 0.0
	var a := lead
	var b := 1-lead
	var rate := 16.0
	match state:
		"wake":
			var u := clampf(state_t/float(knobs.wake),0.0,1.0)
			lean = 0.3*(1.0-u)
			sway = 0.05*sin(_clock*40.0)*(1.0-u)
			ar = [0.25*(1.0-u),0.25*(1.0-u)]
		"rim":
			# One foot raised over the dark, swaying, waiting.
			th[a] = 0.75
			sh[a] = -0.45
			ar = [-0.25,0.35]
			sway = 0.07*sin(_clock*2.2+float(_seed%5))
			lean = -0.04
		"reach":
			var u := clampf(state_t/float(knobs.windup),0.0,1.0)
			if u < 0.6:
				# Anticipation: back, arms drawn behind.
				lean = -0.14*u/0.6
				ar = [-0.45*u/0.6,-0.45*u/0.6]
			else:
				lean = 0.22
				ar = [1.55,1.55]
				rate = 30.0
		"recoil":
			var u := clampf(state_t/float(knobs.recoil),0.0,1.0)
			lean = 0.2*(1.0-u)
			ar = [1.4*(1.0-u),1.4*(1.0-u)]
		"thief":
			ar = [0.15,PI*0.92]
			_gait_pose(th,sh,a,b)
			lean = _gait_lean()
		"stun":
			lean = -0.2
			ar = [0.5,0.4]
		_:
			_gait_pose(th,sh,a,b)
			lean = _gait_lean()
			ar[a] = -0.18*_swing_u()
			ar[b] = 0.18*_swing_u()
			if phase == "plant": dip = -0.04*sin(clampf(phase_t/0.08,0.0,1.0)*PI)
			if phase == "hold":
				ar = [-0.3,0.3]
				sway = 0.04*sin(_clock*3.0)
	_toward(delta,th,sh,ar,lean,sway,rate)
	_hips.position.y = tall*0.5+dip
	# Squash on the plant, a hair of stretch in the swing.
	var sq := 1.0
	if phase == "plant": sq = 0.96
	elif phase == "swing": sq = 1.02
	skin.scale = skin.scale.lerp(Vector3(1.0/sqrt(sq),sq,1.0/sqrt(sq)),1.0-exp(-20.0*delta))

func _swing_u() -> float:
	return 1.0 if phase == "swing" else (0.5 if phase == "plant" else 0.0)

## The stepping leg (`a`) and the standing one (`b`) by the gait's phase:
## lift (knee up), swing (reaching), plant (down), hold (the back foot up in
## the stork hold, a beat too long).
func _gait_pose(th: Array, sh: Array, a: int, b: int) -> void:
	match phase:
		"lift":
			th[a] = 0.6
			sh[a] = -0.95
			th[b] = -0.05
		"swing":
			th[a] = 0.42
			sh[a] = -0.12
			th[b] = -0.32
			sh[b] = -0.1
		"plant":
			th[a] = 0.18
			th[b] = -0.25
			sh[b] = -0.2
		"hold":
			th[b] = 0.2
			sh[b] = -1.35

func _gait_lean() -> float:
	match phase:
		"lift": return -0.06
		"swing": return 0.12
		"plant": return 0.05
		"hold": return 0.0
	return 0.0

func _toward(delta: float, th: Array, sh: Array, ar: Array, lean: float, sway: float, rate: float) -> void:
	var k := 1.0-exp(-rate*delta)
	for i in 2:
		_thigh[i].rotation.x = lerpf(_thigh[i].rotation.x,float(th[i]),k)
		_shin[i].rotation.x = lerpf(_shin[i].rotation.x,float(sh[i]),k)
		_arm[i].rotation.x = lerpf(_arm[i].rotation.x,float(ar[i]),k)
		_arm[i].rotation.z = lerpf(_arm[i].rotation.z,(0.12 if state == "rim" or phase == "hold" else 0.03)*(-1.0 if i == 0 else 1.0),k)
	_hips.rotation.x = lerpf(_hips.rotation.x,-lean,k)
	_hips.rotation.z = lerpf(_hips.rotation.z,sway,k)
	_head.rotation.x = lerpf(_head.rotation.x,(0.35 if state == "wake" else 0.0),k)

## A torch a keeper let go, lying lit: a pool of its own (a SightLight a
## keeper can stand in), and his again when he walks over it.
class DroppedTorch extends Node3D:
	const GROUP := &"dropped_torch"
	const Kit = preload("res://scripts/city_kit_fires.gd")
	const FlameScript = preload("res://scripts/flame.gd")
	signal taken
	var motor: Object = null
	var light: SightLight

	func _ready() -> void:
		name = "DroppedTorch"
		add_to_group(GROUP)
		var stick := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.035
		cyl.bottom_radius = 0.045
		cyl.height = 0.5
		stick.mesh = cyl
		var wood := StandardMaterial3D.new()
		wood.albedo_color = Color(0.2,0.12,0.07)
		stick.material_override = wood
		stick.rotation.z = PI*0.5
		stick.position = Vector3(0.0,0.05,0.0)
		add_child(stick)
		var flame: Node3D = FlameScript.new()
		flame.set("kind","torch")
		flame.set("scale_by",0.6)
		flame.set("with_light",false)
		flame.set("with_smoke",false)
		flame.position = Vector3(0.28,0.08,0.0)
		add_child(flame)
		var omni := OmniLight3D.new()
		omni.light_color = Color(1.0,0.58,0.22)
		omni.light_energy = 1.6
		omni.omni_range = 9.0
		omni.position = Vector3(0.3,0.5,0.0)
		add_child(omni)
		light = SightLight.new()
		light.radius = Kit.size()*4.0
		light.strength = 1.0
		light.position = Vector3(0.0,0.5,0.0)
		add_child(light)

	func _physics_process(_delta: float) -> void:
		if motor == null or not is_inside_tree(): return
		var f: Vector3 = motor.get("feet")
		var me := global_position
		if Vector2(f.x-me.x,f.z-me.z).length() < 0.9*Kit.size() and absf(f.y-me.y) < 1.3:
			Kit.set_torch(get_tree(),true)
			taken.emit()
			queue_free()
