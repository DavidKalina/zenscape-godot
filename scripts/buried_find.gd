extends Node3D
## A find buried in the turf, broken open by the slam (docs/design/slam/
## round2.md: the dig, done with his weight). Any find can be buried: a rune token, a plane
## part, anything that hovers to be taken.
##
## - **Buried.** The find waits DEPTH m under the turf, hidden. Over it a
##   low hump of turf (MOUND) and a faint shimmer on it, breathing slowly
##   (SHIMMER, gold, never bright): easy to walk past, and the telescope
##   glints it from afar (scripts/telescope.gd `spottable`, with the
##   find's objective) so it can be spotted and walked to.
## - **Broken open.** A slam (scripts/slam.gd: this joins its group) that
##   hits hard enough (Slam `decent`: a drop of a few metres, so a hop
##   won't do) and touches within REACH m of it (flat, at the walker's
##   size, or its own radius if smaller; within LEVEL m up or down) breaks
##   the turf open in a burst: the hump and the shimmer gone, clods of turf
##   thrown up and out (CLODS), and the find comes up out of the ground
##   over RISE s, overshooting a little, to hover `over` m over the turf.
## - **Up.** Then it's the find's own: its owner lets it be taken as ever
##   (`takeable`), and it glints through the telescope in its own right.
##
## Use: make one, `setup(find, at, id)` with `at` the turf's point in the
## find's parent's frame, and add it as the find's sibling.
##
## Bare (`bare` true before it's added): no hump, no shimmer, no clods and
## deaf to the slam; something else hides the find and calls `reveal()`
## (a kit cache, scripts/kit_isle/kit_caches.gd: a find inside a breakable
## piece). With `from` set (the parent's frame) the find comes up out of
## that point, not out of the turf under it. The owner asks
## `takeable()` before letting the find be taken; `revealed` says when it
## breaks open. `reveal()` breaks it open from code.
const Telescope = preload("res://scripts/telescope.gd")
const Slam = preload("res://scripts/slam.gd")
const WorldScale = preload("res://scripts/world_scale.gd")

signal revealed

## Metres: the find under the turf; a slam's reach to it and up or
## down; the shimmer across; the hump (across, high).
const DEPTH := 0.6
const REACH := 2.4
const LEVEL := 1.6
const SHIMMER := 0.9
const MOUND := Vector2(1.5,0.16)
## The shimmer's colour and its breath: least and most alpha, s a breath.
const GLOW := Color(1.0,0.86,0.5)
const BREATH := Vector2(0.06,0.2)
const BREATH_TIME := 3.2
## Seconds the find takes to come up; its overshoot (share of its rise).
const RISE := 0.75
const OVERSHOOT := 0.12
## Clods thrown: how many, m/s out and up, s they fly and fade.
const CLODS := 12
const CLOD_OUT := Vector2(2.0,4.5)
const CLOD_UP := Vector2(3.0,6.0)
const CLOD_LIFE := 1.1
const CLOD_GRAVITY := 18.0

## "buried", "rising", "up".
var state := "buried"
var find: Node3D
var id := ""
## Where it lies (the turf's point, the parent's frame) and how high the
## find hovers over it once up.
var at := Vector3.ZERO
var over := 0.85
var size := WorldScale.wanderer
## No hump, shimmer or clods, and deaf to the slam (see the header).
var bare := false
## Where the find comes up from (the parent's frame); INF: DEPTH under `at`.
var from := Vector3.INF
var shimmer: MeshInstance3D
var mound: MeshInstance3D
var _t := 0.0
var _clods: Array[Dictionary] = []
var _clock := 0.0

## The find buried at `at` (its parent's frame), its ledger objective `id`
## (for the telescope's glint), hovering `hover` m over the turf once up.
func setup(find_node: Node3D, where: Vector3, objective := "", hover := 0.85) -> void:
	find = find_node
	at = where
	id = objective
	over = hover
	position = at
	name = "Buried_"+(find.name if find != null else "find")
	if find != null:
		find.visible = false
		find.position = at+Vector3.DOWN*DEPTH
		# Not glinting from under the turf: the shimmer glints instead.
		find.remove_from_group(Telescope.GROUP)

func _ready() -> void:
	if bare: return
	add_to_group(Slam.GROUP)
	if state != "buried": return
	mound = MeshInstance3D.new()
	mound.name = "Mound"
	var hump := SphereMesh.new()
	hump.radius = MOUND.x*0.5*size
	hump.height = MOUND.x*size
	hump.radial_segments = 16
	hump.rings = 6
	mound.mesh = hump
	mound.scale = Vector3(1.0,MOUND.y/MOUND.x,1.0)
	var turf := StandardMaterial3D.new()
	turf.albedo_color = Color(0.33,0.42,0.2)
	turf.roughness = 1.0
	mound.material_override = turf
	add_child(mound)
	shimmer = MeshInstance3D.new()
	shimmer.name = "Shimmer"
	var disc := QuadMesh.new()
	disc.size = Vector2.ONE*SHIMMER*size
	disc.orientation = PlaneMesh.FACE_Y
	shimmer.mesh = disc
	shimmer.position = Vector3.UP*(MOUND.y*size+0.02)
	shimmer.material_override = _glow_material()
	shimmer.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(shimmer)
	Telescope.spottable(shimmer,id)

static func _glow_material() -> StandardMaterial3D:
	var gradient := Gradient.new()
	gradient.set_color(0,Color(1,1,1,1))
	gradient.set_color(1,Color(1,1,1,0))
	var tex := GradientTexture2D.new()
	tex.gradient = gradient
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5,0.5)
	tex.fill_to = Vector2(1.0,0.5)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.albedo_texture = tex
	mat.albedo_color = Color(GLOW,BREATH.x)
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	return mat

## Whether it's still under the turf.
func covered() -> bool:
	return state == "buried"

## Whether the find is up, to be taken.
func takeable() -> bool:
	return state == "up"

## A slam (scripts/slam.gd) at `blast_at` (world): over it, hard enough
## (Slam `decent`), it breaks open.
func slam(blast_at: Vector3, radius: float, strength: float) -> void:
	if state != "buried" or not is_inside_tree() or strength < Slam.decent(): return
	var here := global_position
	var flat := Vector2(here.x-blast_at.x,here.z-blast_at.z).length()
	if flat <= minf(REACH*size,radius) and absf(here.y-blast_at.y) <= LEVEL*size: reveal()

## Broken open: the turf off in a burst, the find coming up.
func reveal() -> void:
	if state != "buried": return
	state = "rising"
	_t = 0.0
	if shimmer != null:
		shimmer.remove_from_group(Telescope.GROUP)
		shimmer.queue_free()
		shimmer = null
	if not bare: _throw_clods()
	if mound != null:
		mound.queue_free()
		mound = null
	if find != null:
		find.visible = true
		find.position = _start()
	revealed.emit()

## Where the find comes up from.
func _start() -> Vector3:
	return from if from != Vector3.INF else at+Vector3.DOWN*DEPTH

func _process(delta: float) -> void:
	advance(delta)

## One frame: the shimmer's breath, the find's rise, the clods' flight.
func advance(delta: float) -> void:
	if delta <= 0.0: return
	_clock += delta
	if shimmer != null:
		var breath := 0.5-0.5*cos(TAU*_clock/BREATH_TIME)
		(shimmer.material_override as StandardMaterial3D).albedo_color.a = lerpf(BREATH.x,BREATH.y,breath)
	if state == "rising":
		_t += delta
		var u := clampf(_t/RISE,0.0,1.0)
		# Up fast out of the ground, past its hover, settling back.
		var rise := 1.0-pow(1.0-u,3.0)
		var settle := sin(u*PI)*OVERSHOOT*(1.0-u)
		if find != null and from != Vector3.INF:
			var to := at+Vector3.UP*over
			find.position = from.lerp(to,rise)+Vector3.UP*settle*maxf(from.distance_to(to),0.5)
		elif find != null: find.position = at+Vector3.UP*(lerpf(-DEPTH,over,rise)+settle*(over+DEPTH))
		if u >= 1.0:
			state = "up"
			if find != null:
				find.position = at+Vector3.UP*over
				if id != "": Telescope.spottable(find,id)
	_fly_clods(delta)

## The clods' material, made once and shared (a new one a dig was a few ms
## of the frame it came up in).
static var _clod_material: StandardMaterial3D

func _throw_clods() -> void:
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.16,0.09,0.13)*size
	if _clod_material == null:
		_clod_material = StandardMaterial3D.new()
		_clod_material.albedo_color = Color(0.3,0.24,0.15)
		_clod_material.roughness = 1.0
	var mat := _clod_material
	for i in range(CLODS):
		var clod := MeshInstance3D.new()
		clod.mesh = mesh
		clod.material_override = mat if i%3 else (mound.material_override if mound != null else mat)
		clod.position = Vector3.UP*0.05
		add_child(clod)
		var a := TAU*(float(i)+randf()*0.5)/CLODS
		var out := Vector3(cos(a),0.0,sin(a))
		_clods.append({"node":clod,"v":out*randf_range(CLOD_OUT.x,CLOD_OUT.y)*size+Vector3.UP*randf_range(CLOD_UP.x,CLOD_UP.y)*size,
			"spin":Vector3(randf()-0.5,randf()-0.5,randf()-0.5)*14.0,"t":0.0})

func _fly_clods(delta: float) -> void:
	for i in range(_clods.size()-1,-1,-1):
		var c: Dictionary = _clods[i]
		c.t += delta
		var node: MeshInstance3D = c.node
		var v: Vector3 = c.v
		v.y -= CLOD_GRAVITY*delta
		c.v = v
		node.position += v*delta
		node.rotation += (c.spin as Vector3)*delta
		node.scale = Vector3.ONE*clampf(1.0-pow(float(c.t)/CLOD_LIFE,3.0),0.01,1.0)
		if c.t >= CLOD_LIFE:
			node.queue_free()
			_clods.remove_at(i)
