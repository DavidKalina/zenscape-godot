extends Node3D
## Pollen for the forest (docs/scenic/brushes.md "Pollen", docs/scenic/handful.md).
## You release something; the world decides what becomes of it.
##
## With forest in hand a press gathers a soft, glinting cloud of pollen and
## seed-fluff in the air above the pointer. A click lets a small puff go; a
## short hold swells it before it goes (HOLD_SECONDS to the full cloud). While
## held the cloud drifts after the pointer; dragging paints nothing. Release
## lets it go: with no wind it floats straight down, spreading and thinning; in
## wind it is carried downwind as it sinks, landing further off and stretched
## out along the wind. The wind is read every frame (scripts/pollen_wind.gd,
## the world's wind and any gust passing), so a gust that comes through while
## it falls carries it. Each mote comes down at its own pace, and the land
## decides what, if anything, takes where it lands (NativeChunkEditor
## `_pollen_settled`, scripts/emergence.gd `_fertility`).
##
## The promise: a soft footprint on the ground (shaders/pollen_footprint.gdshader)
## shows where the cloud will settle. It shows under the pointer while aiming,
## follows the held cloud, and moves with the released one until it has
## settled, as the water ball's mark moves with the ball. In still air it is
## round and centred under the cloud; in wind it is a capsule shifted and
## stretched downwind. A mote lands at its own place in the cloud at release
## (within `r0` of the middle), plus a spread (within `sigma`), plus the drift
## the air has given the whole cloud by the time it lands. So the footprint
## runs from the cloud's drift so far, carried on by the present wind for the
## least and the most fall time left, at radius r0 + sigma; every mote lands
## inside the footprint as it stands when that mote lands. Only a change of
## wind moves it; in steady air the release's footprint holds.
##
## Motes that land at least SEED_GAP from the cloud's other seeds are its
## seeds; the rest is dust that glints and is gone. Where a seed lands on ground
## that could take it (`takes`) a sprout pops up and later sinks as the forest
## takes over. `settled` hands the editor a cloud whose last mote is down.
##
## Several clouds may be in the air at once, up to CLOUDS; each settles as its
## own undo step (the editor writes it when it settles).
##
## Lives under the terrain node, so its coordinates are the plate's.

const Wind = preload("res://scripts/pollen_wind.gd")

## A cloud's last mote is down: {"id", "seeds" (plate x, z), "points" (every
## landing), "lost" (motes that fell off the land), "radius", "motes", and for
## probes "promised" (the footprint's ends at release), "drift" (m the air
## carried it), "worst" (the farthest landing in shares of the radius from
## the footprint as it stood then), "outside" (landings outside it) and
## "outside_promised" (landings outside the release's footprint)}.
signal settled(cloud: Dictionary)

## Metres from the ground to the cloud's middle.
const HEIGHT := 2.2
## Seconds of holding, at strength 1, from a puff to a full cloud.
const HOLD_SECONDS := 1.4
## Motes in a puff and a full cloud at REFERENCE_RADIUS and strength 1.
const MOTES := Vector2(120,260)
## The cloud's radius (m) and the spread (m) its motes may drift apart by as
## they fall, puff to full, at REFERENCE_RADIUS.
const CLOUD := Vector2(0.6,1.3)
const SPREAD := Vector2(1.8,2.8)
## Brush radius (m) those are for; a brush's radius scales them within SIZE.
const REFERENCE_RADIUS := 3.6
const SIZE := Vector2(0.6,1.6)
## Seconds a mote takes to come down, the lightest the longest.
const FALL := Vector2(3.2,5.2)
## Metres a mote wanders as it falls (the curl of the air), dying out as it lands.
const WANDER := 0.35
## The held cloud's follow spring (1/s²) and damping (1/s): soft, so it floats
## after the pointer.
const FOLLOW := 30.0
const FOLLOW_DAMP := 9.0
## Metres of the held cloud's bob and billow, and their hertz.
const BOB := Vector2(0.08,0.45)
const BILLOW := Vector2(0.12,0.3)
## Metres apart a cloud's seeds land at least (Emergence TREE_GAP); closer
## motes are dust.
const SEED_GAP := 1.1
## Seconds a landed mote glints on the ground; the sprout's pop, life and
## height (m).
const GLINT := 0.8
const SPROUT_POP := 0.35
const SPROUT_SECONDS := 9.0
const SPROUT_SIZE := 0.3
## Clouds in the air at once; another's release settles the oldest at once.
const CLOUDS := 4
const MOTES_MAX := 1024
const SPROUTS_MAX := 160
## Soft haze puffs drawn per cloud, and their brightness.
const HAZE := 8
const HAZE_GLOW := 0.16
## Pollen colours by the family of the stand's trees (Emergence
## `seed_family`): pine gold, broadleaf cream, birch pale, desert dust.
const LOOKS := {"conifer":"eed477","broadleaf":"f2e8bf","birch":"f4f0da","arid":"ead7a6"}
const FAMILY := {"tree":"conifer","redwood":"conifer","juniper":"conifer","broadleaf":"broadleaf","layered_tree":"broadleaf",
	"willow":"broadleaf","birch":"birch","joshua":"arid","cactus":"arid"}

## The editor's ground: plate x, z -> height, NAN off the land. Whether a
## seed landing there could take (a sprout shows). The scene, for the wind.
var ground_at: Callable = func(_p: Vector2) -> float: return 0.0
var takes: Callable = func(_p: Vector2) -> bool: return true
var scene: Node
## Microseconds the last frame's step took (for probes).
var last_usec := 0
var age := 0.0
## The cloud in hand, or {}; clouds in the air.
var held := {}
var clouds: Array[Dictionary] = []
var _hover: Variant = null
var _hover_scale := 1.0
var _serial := 0
var _sprouts: Array[Dictionary] = []
var _glints: Array[Dictionary] = []
var _mote_node: MultiMeshInstance3D
var _sprout_node: MultiMeshInstance3D
var _haze_node: MultiMeshInstance3D
var _prints: Array[MeshInstance3D] = []
static var _meshes := {}

func _ready() -> void:
	var material := ShaderMaterial.new()
	material.shader = preload("res://shaders/pollen_mote.gdshader")
	_mote_node = _instances("Motes",_mesh("mote"),MOTES_MAX,material)
	_sprout_node = _instances("Sprouts",_mesh("sprout"),SPROUTS_MAX,material)
	var haze := ShaderMaterial.new()
	haze.shader = preload("res://shaders/pollen_haze.gdshader")
	haze.render_priority = 1
	var quad := QuadMesh.new()
	quad.size = Vector2(2,2)
	_haze_node = _instances("Haze",quad,HAZE*(CLOUDS+1),haze)
	for i in range(CLOUDS+1):
		var print_material := ShaderMaterial.new()
		print_material.shader = preload("res://shaders/pollen_footprint.gdshader")
		print_material.render_priority = -1
		var node := MeshInstance3D.new()
		node.name = "Footprint%d" % i
		node.mesh = BoxMesh.new()
		node.material_override = print_material
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		node.top_level = true
		node.visible = false
		add_child(node)
		_prints.append(node)

func _instances(title: String, mesh: Mesh, count: int, material: Material) -> MultiMeshInstance3D:
	var instances := MultiMesh.new()
	instances.transform_format = MultiMesh.TRANSFORM_3D
	instances.use_colors = true
	instances.instance_count = count
	instances.visible_instance_count = 0
	instances.mesh = mesh
	var node := MultiMeshInstance3D.new()
	node.name = title
	node.multimesh = instances
	node.material_override = material
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.top_level = true
	node.visible = false
	add_child(node)
	return node

## Aiming: the footprint a click would make, under `point` (plate, on the
## ground), or none for null. `brush_radius` sizes it.
func hover(point: Variant, brush_radius := REFERENCE_RADIUS) -> void:
	_hover = point
	_hover_scale = clampf(brush_radius/REFERENCE_RADIUS,SIZE.x,SIZE.y)

## Start gathering a cloud over `point` (plate, on the ground). `tree_kind` is
## the stand's tree there (Emergence `seed_family`), "" for the default look.
func gather(point: Vector3, brush_radius: float, strength: float, tree_kind: String, salt: int) -> void:
	if not held.is_empty(): release()
	_serial += 1
	var rng := RandomNumberGenerator.new()
	rng.seed = salt
	var scale := clampf(brush_radius/REFERENCE_RADIUS,SIZE.x,SIZE.y)
	held = {"id":_serial,"state":"held","centre":point+Vector3.UP*HEIGHT,"velocity":Vector3.ZERO,"target":point,"fill":0.0,"age":0.0,
		"scale":scale,"strength":clampf(strength,0.25,3.0),"rng":rng,"motes":[],"colour":Color(LOOKS[FAMILY.get(tree_kind,"broadleaf")]),
		"seeds":PackedVector2Array(),"points":PackedVector2Array(),"lost":0,"down":0}
	_join(held,_mote_count(held))

## Follow the pointer's ground point (plate), or hold still over null.
func hold(point: Variant) -> void:
	if not held.is_empty() and point != null: held.target = point

## Let the held cloud go: the wind now decides where each mote comes down.
func release() -> void:
	if held.is_empty(): return
	var cloud := held
	held = {}
	if clouds.size() >= CLOUDS: _settle(clouds[0])
	var shape := _shape(cloud,Wind.at(scene,get_parent() as Node3D,_flat(cloud.centre)))
	cloud.merge(shape,true)
	cloud.state = "flying"
	cloud.origin = _flat(cloud.centre)
	cloud.drift = Vector2.ZERO
	cloud.flown = 0.0
	# The footprint as promised at release, for probes.
	cloud.promised = [shape.a,shape.b]
	cloud.worst = 0.0
	cloud.outside = 0
	cloud.outside_promised = 0
	var rng: RandomNumberGenerator = cloud.rng
	var centre: Vector2 = cloud.origin
	for mote: Dictionary in cloud.motes:
		# Its own place in the cloud (within r0) and a spread (within sigma);
		# the air adds the rest as it falls.
		var offset := (_flat(mote.p)-centre).limit_length(float(cloud.r0))
		mote.base = centre+offset+Vector2.RIGHT.rotated(rng.randf()*TAU)*float(cloud.sigma)*sqrt(rng.randf())
		mote.from = mote.p
		mote.fall = rng.randf_range(FALL.x,FALL.y)
		mote.floor = float(cloud.target.y)
		mote.aimed = false
		mote.curl = Vector2.RIGHT.rotated(rng.randf()*TAU)
	clouds.append(cloud)

## True while a cloud is held or any is in the air.
func active() -> bool:
	return not held.is_empty() or not clouds.is_empty()

func motes_in_air() -> int:
	var count := 0
	for cloud: Dictionary in clouds: count += cloud.motes.size()-int(cloud.down)
	return count

static func _to_segment(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b-a
	var t := clampf((p-a).dot(ab)/maxf(ab.length_squared(),1e-6),0.0,1.0)
	return p.distance_to(a+ab*t)

## Land every cloud in the air now, oldest first, where it was promised: a
## new stroke of another brush, an undo or a world change.
func settle_now() -> void:
	release()
	while not clouds.is_empty(): _settle(clouds[0])

## Drop everything, settling nothing: the ground it was promised to is gone.
func withdraw() -> void:
	held = {}
	clouds.clear()
	_sprouts.clear()
	_glints.clear()
	_hide()

## The footprint of `cloud` in `wind`: {"wind", "r0", "sigma", "a", "b",
## "radius"} (plate).
func _shape(cloud: Dictionary, wind: Vector2) -> Dictionary:
	var fill: float = cloud.fill
	var scale: float = cloud.scale
	var r0 := lerpf(CLOUD.x,CLOUD.y,fill)*scale
	var sigma := lerpf(SPREAD.x,SPREAD.y,fill)*scale
	var centre := _flat(cloud.centre) if cloud.state == "held" else _flat(cloud.target)
	return {"wind":wind,"r0":r0,"sigma":sigma,"a":centre+wind*FALL.x,"b":centre+wind*FALL.y,"radius":r0+sigma}

## A flying cloud's footprint now: its drift so far, carried on by `wind` for
## the least and the most fall time left.
func _flying_shape(cloud: Dictionary) -> Array:
	var wind: Vector2 = cloud.wind
	var here: Vector2 = Vector2(cloud.origin)+Vector2(cloud.drift)
	var t: float = cloud.flown
	return [here+wind*maxf(FALL.x-t,0.0),here+wind*maxf(FALL.y-t,0.0)]

func _mote_count(cloud: Dictionary) -> int:
	return clampi(roundi(lerpf(MOTES.x,MOTES.y,float(cloud.fill))*sqrt(float(cloud.strength))*pow(float(cloud.scale),2.0)),20,MOTES_MAX/CLOUDS)

## `count` more motes join the cloud, fading in at their places in it.
func _join(cloud: Dictionary, count: int) -> void:
	var rng: RandomNumberGenerator = cloud.rng
	for i in range(count):
		var up := rng.randf_range(-1.0,1.0)
		var around := rng.randf()*TAU
		var slot := Vector3(cos(around)*sqrt(1.0-up*up),up*0.55,sin(around)*sqrt(1.0-up*up))*pow(rng.randf(),0.4)
		cloud.motes.append({"slot":slot,"p":Vector3(cloud.centre)+slot*0.2,"born":float(cloud.age),"phase":rng.randf()*TAU,
			"rate":rng.randf_range(0.3,0.9)*(1.0 if rng.randf() < 0.5 else -1.0),"size":rng.randf_range(0.7,1.3),"landed":false})

func _process(delta: float) -> void:
	delta = minf(delta,0.05)
	var began := Time.get_ticks_usec()
	age += delta
	if not held.is_empty(): _step_held(delta)
	for cloud: Dictionary in clouds.duplicate(): _step_flying(cloud,delta)
	_step_ground(delta)
	_draw()
	_paint_prints()
	last_usec = Time.get_ticks_usec()-began

func _step_held(delta: float) -> void:
	var cloud := held
	cloud.age = float(cloud.age)+delta
	cloud.fill = minf(1.0,float(cloud.fill)+delta*float(cloud.strength)/HOLD_SECONDS)
	var want := _mote_count(cloud)
	if cloud.motes.size() < want: _join(cloud,want-cloud.motes.size())
	var goal: Vector3 = Vector3(cloud.target)+Vector3.UP*(HEIGHT+sin(age*TAU*BOB.y)*BOB.x)
	var velocity: Vector3 = cloud.velocity
	velocity += ((goal-Vector3(cloud.centre))*FOLLOW-velocity*FOLLOW_DAMP)*delta
	cloud.velocity = velocity
	cloud.centre = Vector3(cloud.centre)+velocity*delta
	var r0 := lerpf(CLOUD.x,CLOUD.y,float(cloud.fill))*float(cloud.scale)
	for mote: Dictionary in cloud.motes:
		# Each mote billows round its place, and trails the cloud a little.
		var turn := float(mote.rate)*float(cloud.age)
		var slot: Vector3 = Vector3(mote.slot).rotated(Vector3.UP,turn)
		var billow := Vector3(sin(age*TAU*BILLOW.y+float(mote.phase)),cos(age*TAU*BILLOW.y*1.3+float(mote.phase)),sin(age*TAU*BILLOW.y*0.7+float(mote.phase)*2.0))*BILLOW.x
		var place: Vector3 = Vector3(cloud.centre)+slot*r0+billow
		mote.p = Vector3(mote.p).lerp(place,1.0-exp(-6.0*delta))

func _step_flying(cloud: Dictionary, delta: float) -> void:
	cloud.age = float(cloud.age)+delta
	# The air where the cloud is now carries every mote still aloft alike.
	var before: Vector2 = cloud.drift
	var was: float = cloud.flown
	var wind := Wind.at(scene,get_parent() as Node3D,Vector2(cloud.origin)+before)
	cloud.wind = wind
	cloud.flown = was+delta
	cloud.drift = before+wind*delta
	for mote: Dictionary in cloud.motes:
		if mote.landed: continue
		if float(mote.fall) <= float(cloud.flown):
			# Down part way through this frame: the drift up to that moment.
			_land(cloud,mote,Vector2(mote.base)+before+wind*(float(mote.fall)-was))
			continue
		_place_falling(cloud,mote)
	if int(cloud.down) >= cloud.motes.size(): _settle(cloud)

## A mote's way down: it sinks at a steady rate after a soft start, drifts
## apart from the others early, rides the cloud's drift, and wanders on the
## curl of the air, the wander dying out as it lands. Near the ground it looks
## ahead to where it will land, so it comes down onto the ground there.
func _place_falling(cloud: Dictionary, mote: Dictionary) -> void:
	var u := clampf(float(cloud.flown)/float(mote.fall),0.0,1.0)
	var from: Vector3 = mote.from
	var start := _flat(from)
	var base: Vector2 = mote.base
	var flat := start+(base-start)*(1.0-pow(1.0-u,2.0))+Vector2(cloud.drift)
	flat += Vector2(mote.curl).rotated(u*4.0+float(mote.phase))*WANDER*sin(u*PI)
	if not mote.aimed and u > 0.6:
		mote.aimed = true
		var ahead: float = ground_at.call(base+Vector2(cloud.drift)+Vector2(cloud.wind)*(float(mote.fall)-float(cloud.flown)))
		if not is_nan(ahead): mote.floor = ahead
	var sink := u*u*(3.0-2.0*u)*0.35+u*0.65
	var y := lerpf(from.y,float(mote.floor),sink)+sin(u*PI*3.0+float(mote.phase))*0.05*(1.0-u)
	mote.p = Vector3(flat.x,y,flat.y)

func _land(cloud: Dictionary, mote: Dictionary, point: Vector2) -> void:
	mote.landed = true
	cloud.down = int(cloud.down)+1
	# Against the footprint as it stands now, and as it was promised at release.
	var ends := _flying_shape(cloud)
	var share := _to_segment(point,ends[0],ends[1])/float(cloud.radius)
	cloud.worst = maxf(float(cloud.worst),share)
	if share > 1.0001: cloud.outside = int(cloud.outside)+1
	if _to_segment(point,cloud.promised[0],cloud.promised[1]) > float(cloud.radius)*1.0001: cloud.outside_promised = int(cloud.outside_promised)+1
	var h: float = ground_at.call(point)
	mote.lost = is_nan(h)
	var to := Vector3(point.x,float(mote.floor) if mote.lost else h,point.y)
	mote.p = to
	if mote.lost:
		cloud.lost = int(cloud.lost)+1
		return
	cloud.points.append(point)
	_glints.append({"p":to,"t":0.0,"size":float(mote.size),"colour":cloud.colour})
	var seeds: PackedVector2Array = cloud.seeds
	for q in seeds:
		if q.distance_squared_to(point) < SEED_GAP*SEED_GAP: return
	seeds.append(point)
	cloud.seeds = seeds
	if takes.call(point):
		_sprouts.append({"p":to,"t":0.0,"yaw":randf()*TAU,"lean":Vector2.RIGHT.rotated(randf()*TAU)})
		if _sprouts.size() > SPROUTS_MAX: _sprouts = _sprouts.slice(_sprouts.size()-SPROUTS_MAX)

## Land what is left of `cloud` now, on the drift so far and the present
## wind, and hand it on.
func _settle(cloud: Dictionary) -> void:
	for mote: Dictionary in cloud.motes:
		if not mote.landed: _land(cloud,mote,Vector2(mote.base)+Vector2(cloud.drift)+Vector2(cloud.wind)*maxf(float(mote.fall)-float(cloud.flown),0.0))
	clouds.erase(cloud)
	settled.emit({"id":cloud.id,"seeds":cloud.seeds,"points":cloud.points,"lost":cloud.lost,"radius":cloud.radius,"motes":cloud.motes.size(),
		"promised":cloud.promised,"drift":cloud.drift,"worst":cloud.worst,"outside":cloud.outside,"outside_promised":cloud.outside_promised})

func _step_ground(delta: float) -> void:
	var kept: Array[Dictionary] = []
	for glint: Dictionary in _glints:
		glint.t = float(glint.t)+delta
		if float(glint.t) < GLINT: kept.append(glint)
	_glints = kept.slice(maxi(0,kept.size()-MOTES_MAX/2))
	var grown: Array[Dictionary] = []
	for s: Dictionary in _sprouts:
		s.t = float(s.t)+delta
		if float(s.t) < SPROUT_SECONDS: grown.append(s)
	_sprouts = grown

func _flat(p: Vector3) -> Vector2:
	return Vector2(p.x,p.z)

func _draw() -> void:
	var plate: Transform3D = (get_parent() as Node3D).global_transform
	var motes := _mote_node.multimesh
	var haze := _haze_node.multimesh
	var n := 0
	var h := 0
	var all: Array[Dictionary] = clouds.duplicate()
	if not held.is_empty(): all.append(held)
	for cloud: Dictionary in all:
		var colour: Color = cloud.colour
		var flying: bool = cloud.state == "flying"
		var groups := []
		for g in range(HAZE): groups.append([Vector3.ZERO,0])
		for i in range(cloud.motes.size()):
			var mote: Dictionary = cloud.motes[i]
			if mote.landed or n >= MOTES_MAX: continue
			# Fluff glints as it turns; it fades in as it joins.
			var twinkle := 0.75+0.25*sin(age*5.0+float(mote.phase)*3.0)
			var grow := smoothstep(0.0,0.4,float(cloud.age)-float(mote.born)) if not flying else 1.0
			var size := 0.045*float(mote.size)*twinkle*maxf(grow,0.01)
			motes.set_instance_transform(n,Transform3D(Basis(Vector3.UP,float(mote.phase)+age).scaled(Vector3.ONE*size),mote.p))
			motes.set_instance_color(n,Color(colour.r,colour.g,colour.b,0.9))
			n += 1
			var group: Array = groups[i%HAZE]
			group[0] += Vector3(mote.p)
			group[1] += 1
		# The haze: soft light over the cloud, thinning as it spreads and lands.
		var left := 1.0-float(cloud.down)/maxf(cloud.motes.size(),1.0) if flying else smoothstep(0.0,0.3,float(cloud.age))
		var spread := 1.0+(float(cloud.age)*0.25 if flying else 0.0)
		var r0 := lerpf(CLOUD.x,CLOUD.y,float(cloud.fill))*float(cloud.scale)
		for group: Array in groups:
			if int(group[1]) == 0 or h >= haze.instance_count: continue
			var at: Vector3 = group[0]/float(group[1])
			haze.set_instance_transform(h,Transform3D(Basis.from_scale(Vector3.ONE*r0*0.9*spread),at))
			haze.set_instance_color(h,Color(colour.r,colour.g,colour.b,HAZE_GLOW*left/spread))
			h += 1
	for glint: Dictionary in _glints:
		if n >= MOTES_MAX: break
		var t: float = glint.t
		var size := 0.04*float(glint.size)*(1.0-t/GLINT)*(0.7+0.3*sin(t*18.0))
		motes.set_instance_transform(n,Transform3D(Basis.from_scale(Vector3.ONE*maxf(size,0.001)),Vector3(glint.p)+Vector3.UP*0.02))
		var colour: Color = glint.colour
		motes.set_instance_color(n,Color(colour.r,colour.g,colour.b,0.9))
		n += 1
	motes.visible_instance_count = n
	_mote_node.global_transform = plate
	_mote_node.visible = n > 0
	haze.visible_instance_count = h
	_haze_node.global_transform = plate
	_haze_node.visible = h > 0
	var sprouts := _sprout_node.multimesh
	var count := mini(_sprouts.size(),SPROUTS_MAX)
	sprouts.visible_instance_count = count
	_sprout_node.global_transform = plate
	_sprout_node.visible = count > 0
	for i in range(count):
		var s: Dictionary = _sprouts[i]
		var t: float = s.t
		# It pops up past its size, sways back and settles, and sinks away
		# as the forest's own saplings take over.
		var pop := clampf(t/SPROUT_POP,0.0,1.0)-1.0
		var up := (1.0+pop*pop*(2.70158*pop+1.70158))*(1.0-smoothstep(SPROUT_SECONDS-1.2,SPROUT_SECONDS,t))
		var lean: Vector2 = s.lean
		var sway := sin(t*7.0)*0.3*exp(-t*2.2)+sin(age*1.3+float(s.yaw))*0.04
		var basis := Basis(Vector3(lean.x,0,lean.y),sway)*Basis(Vector3.UP,float(s.yaw))
		sprouts.set_instance_transform(i,Transform3D(basis.scaled(Vector3.ONE*SPROUT_SIZE*maxf(up,0.001)),s.p))
		sprouts.set_instance_color(i,Color(1,1,1,0))

## The footprints: the aim (a click's under the pointer, or the held cloud's)
## and each released cloud's until it has settled.
func _paint_prints() -> void:
	var shapes: Array[Dictionary] = []
	var parent := get_parent() as Node3D
	if not held.is_empty():
		var shape := _shape(held,Wind.at(scene,parent,_flat(held.centre)))
		shape.strength = smoothstep(0.0,0.15,float(held.age))
		shape.soft = 1.0
		shapes.append(shape)
	elif _hover != null:
		var probe := {"fill":0.0,"scale":_hover_scale,"state":"hover","target":_hover,"centre":_hover}
		var shape := _shape(probe,Wind.at(scene,parent,_flat(_hover)))
		shape.strength = 0.55
		shape.soft = 1.0
		shapes.append(shape)
	for cloud: Dictionary in clouds:
		var share := float(cloud.down)/maxf(cloud.motes.size(),1.0)
		var ends := _flying_shape(cloud)
		shapes.append({"a":ends[0],"b":ends[1],"radius":cloud.radius,"strength":1.0-smoothstep(0.7,1.0,share),"soft":0.0})
	var scale := parent.global_basis.get_scale().x
	for i in range(_prints.size()):
		var node := _prints[i]
		if i >= shapes.size() or float(shapes[i].strength) <= 0.001:
			node.visible = false
			continue
		var shape: Dictionary = shapes[i]
		var a: Vector2 = shape.a
		var b: Vector2 = shape.b
		var r: float = shape.radius
		var ha: float = ground_at.call(a)
		var hb: float = ground_at.call(b)
		var hm: float = ground_at.call((a+b)*0.5)
		var grounds := [ha,hb,hm].filter(func(v: float) -> bool: return not is_nan(v))
		if grounds.is_empty():
			node.visible = false
			continue
		var low: float = grounds.min()
		var high: float = grounds.max()
		var middle := (a+b)*0.5
		var span := Vector2(absf(b.x-a.x),absf(b.y-a.y))*0.5+Vector2.ONE*(r+0.6)
		var at := parent.to_global(Vector3(middle.x,(low+high)*0.5,middle.y))
		node.global_transform = Transform3D(Basis.from_scale(Vector3(span.x*2.0*scale,(high-low+8.0)*scale,span.y*2.0*scale)),at)
		node.visible = true
		var material := node.material_override as ShaderMaterial
		material.set_shader_parameter("seg_a",parent.to_global(Vector3(a.x,ha if not is_nan(ha) else low,a.y)))
		material.set_shader_parameter("seg_b",parent.to_global(Vector3(b.x,hb if not is_nan(hb) else low,b.y)))
		material.set_shader_parameter("radius",r*scale)
		material.set_shader_parameter("strength",float(shape.strength))
		material.set_shader_parameter("soft",float(shape.soft))
		material.set_shader_parameter("ceiling",parent.to_global(Vector3(0.0,high+HEIGHT*0.45,0.0)).y)
		material.set_shader_parameter("age",age)

func _hide() -> void:
	if _mote_node == null: return
	_mote_node.visible = false
	_sprout_node.visible = false
	_haze_node.visible = false
	for node in _prints: node.visible = false

# --- Meshes -------------------------------------------------------------------

## The faceted meshes, built once: a mote of fluff (1 m radius) and a
## two-leafed sprout (1 m tall). Vertex colour is a shade of the instance
## colour; its alpha is how much of the instance's glow the face takes.
static func _mesh(which: String) -> Mesh:
	if _meshes.has(which): return _meshes[which]
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	if which == "sprout": _build_sprout(tool)
	else: _build_mote(tool)
	tool.generate_normals()
	var mesh := tool.commit()
	_meshes[which] = mesh
	return mesh

static func _face(tool: SurfaceTool, colour: Color, points: Array) -> void:
	# Each face its own vertices, so generate_normals gives flat facets.
	for p: Vector3 in points:
		tool.set_color(colour)
		tool.add_vertex(p)

static func _build_sprout(tool: SurfaceTool) -> void:
	var stem := Color(0.55,0.62,0.34,0.0)
	var leaf := Color(0.48,0.72,0.3,0.0)
	var under := Color(0.4,0.6,0.26,0.0)
	# A three-sided stem, a little bent.
	var low := [Vector3(0.04,0,0),Vector3(-0.02,0,0.035),Vector3(-0.02,0,-0.035)]
	var high := [Vector3(0.05,0.62,0.0),Vector3(0.0,0.62,0.025),Vector3(0.0,0.62,-0.025)]
	for i in range(3):
		var j := (i+1)%3
		_face(tool,stem,[low[i],high[i],high[j]])
		_face(tool,stem,[low[i],high[j],low[j]])
	# Two seed leaves, opened up and out, creased along their middles.
	for side in [1.0,-1.0]:
		var root := Vector3(0.02,0.6,0.0)
		var tip := Vector3(0.02,0.86,0.42*side)
		var edge_a := Vector3(0.16,0.74,0.2*side)
		var edge_b := Vector3(-0.12,0.74,0.2*side)
		var crease := (root+tip)*0.5+Vector3(0,0.035,0)
		_face(tool,leaf,[root,crease,edge_a])
		_face(tool,leaf,[crease,tip,edge_a])
		_face(tool,under,[root,edge_b,crease])
		_face(tool,under,[crease,edge_b,tip])

static func _build_mote(tool: SurfaceTool) -> void:
	var dust := Color(1,1,1,1)
	var points := [Vector3(0,1,0),Vector3(1,0,0),Vector3(0,0,1),Vector3(-1,0,0),Vector3(0,0,-1),Vector3(0,-1,0)]
	for i in range(4):
		var a: Vector3 = points[1+i]
		var b: Vector3 = points[1+(i+1)%4]
		_face(tool,dust,[points[0],b,a])
		_face(tool,dust,[points[5],a,b])
