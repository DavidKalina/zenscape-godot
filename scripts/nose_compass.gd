extends Node3D
## A compass arrow on the plane's nose (docs/design/isle-lodestone.md): a
## faceted pale-gold arrow on a short brass post over the cowl, pointing at
## the target in 3D, up and down included. The post lifts it clear of the
## upper wing and the pilot's head as the chase camera sees them (round 1:
## anything under about 0.3 m over the wing's middle hides behind the head).
## It wakes when the lodestone seats: it rises out of the cowl, swings round
## to the target and glows; on course it brightens. Once its work is done
## (`quiet`: the isle's ring threaded, docs/design/isle-hall-chain.md) it
## stops tracking, folds down to lie along the nose and dims, gently.
##
## A child of the plane figure, in its frame (nose toward -z, up +y).

## Where the post stands on the cowl, how tall it is, and the arrow's length.
const FOOT := Vector3(0.0,0.13,-0.5)
const POST := 0.28
const LENGTH := 0.36
## How fast it swings to a new heading (1/s) and rises when woken (s).
const SWING := 7.0
const RISE := 0.45
const BRASS := Color("d6ad62")
const GLOW := Color("f0c56a")

## The point it points at, in world space.
var target := Vector3.ZERO
var _pivot: Node3D
var _arrow: Node3D
var _glow: StandardMaterial3D
var _risen := 0.0
## `pulse`: how long it lasts (s) and how bright it flares.
const PULSE := 1.2
const PULSE_GLOW := 7.0
var _pulse := 0.0
## `quiet`: how long the fold takes (s), how far it tips down (rad, its
## head toward the cowl), how dim it ends (its glow's energy, and its
## colour's share left) and how small (its scale).
const QUIET_TIME := 2.4
const QUIET_TIP := 0.38
const QUIET_GLOW := 0.06
const QUIET_DIM := 0.55
const QUIET_SCALE := 0.85
## 0 awake, 1 folded quiet; whether it is going quiet; the way it pointed
## when it began to.
var quieted := 0.0
var quieting := false
var _quiet_from := Quaternion.IDENTITY

func _init() -> void:
	name = "NoseCompass"
	var brass := StandardMaterial3D.new()
	brass.albedo_color = BRASS
	brass.metallic = 0.6
	brass.roughness = 0.35
	var post := MeshInstance3D.new()
	var rod := CylinderMesh.new()
	rod.top_radius = 0.008
	rod.bottom_radius = 0.016
	rod.height = POST
	rod.radial_segments = 6
	rod.rings = 1
	post.mesh = rod
	post.material_override = brass
	post.position = FOOT+Vector3.UP*POST*0.5
	add_child(post)
	var collar := MeshInstance3D.new()
	var ring := TorusMesh.new()
	ring.inner_radius = 0.022
	ring.outer_radius = 0.032
	ring.rings = 8
	ring.ring_segments = 4
	collar.mesh = ring
	collar.material_override = brass
	collar.position = FOOT+Vector3.UP*POST
	add_child(collar)
	_pivot = Node3D.new()
	_pivot.position = FOOT+Vector3.UP*POST
	add_child(_pivot)
	_glow = StandardMaterial3D.new()
	_glow.albedo_color = GLOW
	_glow.emission_enabled = true
	_glow.emission = GLOW
	_glow.emission_energy_multiplier = 0.8
	_glow.roughness = 0.4
	_arrow = Node3D.new()
	_pivot.add_child(_arrow)
	# The head: two crossed faceted wedges, so it reads from above and the side.
	for turn in [0.0,PI*0.5]:
		var head := MeshInstance3D.new()
		var wedge := PrismMesh.new()
		wedge.size = Vector3(0.14,0.15,0.03)
		head.mesh = wedge
		head.material_override = _glow
		head.rotation = Vector3(-PI*0.5,0.0,0.0)
		head.rotate_object_local(Vector3.UP,turn)
		head.position = Vector3(0.0,0.0,-LENGTH*0.5+0.075)
		_arrow.add_child(head)
	var shaft := MeshInstance3D.new()
	var bar := BoxMesh.new()
	bar.size = Vector3(0.026,0.026,LENGTH-0.14)
	shaft.mesh = bar
	shaft.material_override = _glow
	shaft.position = Vector3(0.0,0.0,0.07)
	_arrow.add_child(shaft)
	# The tail: a small flat fletch.
	var tail := MeshInstance3D.new()
	var fletch := PrismMesh.new()
	fletch.size = Vector3(0.11,0.07,0.016)
	tail.mesh = fletch
	tail.material_override = brass
	tail.rotation = Vector3(-PI*0.5,0.0,0.0)
	tail.position = Vector3(0.0,0.0,LENGTH*0.5-0.01)
	_arrow.add_child(tail)
	scale = Vector3.ONE*0.001

## Each frame: rise, swing toward the target in the plane's frame, glow
## brighter the closer to dead ahead.
func step(delta: float) -> void:
	_risen = minf(_risen+delta/RISE,1.0)
	var lift := 1.0-pow(1.0-_risen,3.0)
	scale = Vector3.ONE*maxf(lift,0.001)
	_pulse = maxf(_pulse-delta/PULSE,0.0)
	var surge := sin(_pulse*PI)
	if quieting:
		# No more tracking: from where it pointed, it eases round to lie
		# along the nose, tipped down, and dims.
		quieted = minf(quieted+delta/QUIET_TIME,1.0)
		var u := smoothstep(0.0,1.0,quieted)
		_pivot.basis = Basis(_quiet_from.slerp(rest().get_rotation_quaternion(),u))
		_glow.emission_energy_multiplier = lerpf(_glow_awake,QUIET_GLOW,u)+PULSE_GLOW*surge
		_glow.albedo_color = GLOW.lerp(GLOW*QUIET_DIM,u)
		_glow.albedo_color.a = 1.0
		_arrow.scale = Vector3.ONE*(lerpf(1.0,QUIET_SCALE,u)+0.3*surge)
		return
	if not is_inside_tree(): return
	var local := global_transform.affine_inverse()*target-_pivot.position
	if local.length() < 0.01: return
	var want := Basis.looking_at(local.normalized(),Vector3.UP if absf(local.normalized().y) < 0.98 else Vector3.BACK)
	var blend := 1.0-exp(-SWING*delta)
	_pivot.basis = Basis(_pivot.basis.get_rotation_quaternion().slerp(want.get_rotation_quaternion(),blend))
	var ahead := maxf((-_pivot.basis.z).dot(Vector3.FORWARD),0.0)
	_glow_awake = 0.8+1.6*pow(ahead,12.0)
	_glow.emission_energy_multiplier = _glow_awake+PULSE_GLOW*surge
	_arrow.scale = Vector3.ONE*(1.0+0.3*surge)

## Where it lies once quiet (in the plane's frame): along the nose, its
## head tipped down toward the cowl.
static func rest() -> Basis:
	return Basis(Vector3.RIGHT,-QUIET_TIP)

## Its work done: it stops tracking and, over QUIET_TIME s, folds down to
## lie along the nose and dims (a pulse already running plays out on top).
## `now`: folded at once (boarding again after).
func quiet(now := false) -> void:
	if quieting and not now: return
	quieting = true
	_quiet_from = _pivot.basis.get_rotation_quaternion()
	if now:
		quieted = 1.0
		_risen = 1.0
		step(0.0)

## Its tracking glow's energy, the last frame it tracked.
var _glow_awake := 0.8

## A pulse through it (the isle's ring threaded, docs/design/
## isle-hall-chain.md): it flares and swells a moment, then settles. Where
## it points does not change.
func pulse() -> void:
	_pulse = 1.0
