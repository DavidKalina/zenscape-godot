extends Node
## The line's light-shaft director (scripts/hall_shafts.gd, docs/scenic/
## hall-shafts.md): one a line. It keeps the plane's last few places as the
## wake the dust shader swirls by, and tests the camera and the plane against
## every beam of the pieces standing (the same slant as the shader's) to
## flare the view warm for a moment as it passes through the light. `tick`
## every frame with the plane's world place (or null).

const Shafts = preload("res://scripts/hall_shafts.gd")
const FLARE_SHADER = preload("res://shaders/hall_shaft_flare.gdshader")
const ROOF_Y = Shafts.ROOF_Y
const FLOOR_Y = Shafts.FLOOR_Y
const MAX_LEN = Shafts.MAX_LEN
const TRAIL = Shafts.TRAIL
const TRAIL_STEP = Shafts.TRAIL_STEP
const TRAIL_LIFE = Shafts.TRAIL_LIFE

## How far (m) from a beam's top edge its flare reaches in, and the
## rates the flare comes on and falls away (per s).
const EDGE := 1.0
const ATTACK := 7.0
const RELEASE := 1.5
## How fast the view settles into the light (per s).
const ADAPT := 1.1
## The flare's strength at a full beam and a full sun.
const FLARE := 0.34

var flare_scale := 1.0
## 0..1: how far into a beam the view is, smoothed.
var inside := 0.0
var _raw := 0.0
var _adapt := 0.0
var _clock := 0.0
var _trail: Array = []
var _since := 0.0
var _last := Vector3.INF
var _layer: CanvasLayer = null
var _rect: ColorRect = null
var _flare: ShaderMaterial = null
## For tests and the HUD: the plane's and the camera's own depth in a beam.
var plane_in := 0.0
var camera_in := 0.0

func _init() -> void:
	name = "HallShafts"
	flare_scale = Shafts._flag("--hall-shafts-flare=",1.0)

func _ready() -> void:
	if flare_scale <= 0.0: return
	_layer = CanvasLayer.new()
	_layer.name = "Flare"
	# Under the HUD (layer 0 and up), over the 3D.
	_layer.layer = -1
	add_child(_layer)
	_rect = ColorRect.new()
	_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flare = ShaderMaterial.new()
	_flare.shader = FLARE_SHADER
	_rect.material = _flare
	_rect.visible = false
	_layer.add_child(_rect)

## The celestial rig's published sky (studies/celestial.gd `state`: the
## same values it sets the shader globals to, which can not be read back at
## run time), found on the running scene; {} if it has none.
var _celestial: Variant = null
var _sun: DirectionalLight3D = null

func _sky() -> Dictionary:
	if _celestial == null or not is_instance_valid(_celestial):
		# Up the tree to the isle study, which holds the rig as `_celestial`.
		_celestial = null
		var up := get_parent()
		while up != null and _celestial == null:
			_celestial = up.get("_celestial")
			up = up.get_parent()
	if _celestial != null:
		var state: Variant = _celestial.get("state")
		if state is Dictionary and (state as Dictionary).has("zs_key_direction"): return state
	return {}

## The scene's light, travelling (world, unit; zero if there is none).
func light_way() -> Vector3:
	var sky := _sky()
	if not sky.is_empty():
		var key: Vector3 = sky.zs_key_direction
		return -key.normalized() if key.length() > 0.5 else Vector3.ZERO
	if _sun == null or not is_instance_valid(_sun):
		_sun = null
		for n in get_tree().root.find_children("*","DirectionalLight3D",true,false):
			var l := n as DirectionalLight3D
			if l.shadow_enabled and l.visible: _sun = l
			if _sun != null: break
	return -_sun.global_basis.z.normalized() if _sun != null else Vector3.ZERO

## How strong the light is, 0..1: its colour's energy, the cloud cover
## (the shaders' own sum).
func light_strength() -> float:
	var sky := _sky()
	if sky.is_empty(): return 0.0
	var c: Vector3 = sky.zs_key_irradiance
	var lum := (c.x+c.y+c.z)/3.0
	return clampf(lum/2.4,0.0,1.0)*clampf(float(sky.get("zs_celestial_clear",1.0)),0.0,1.0)

func tick(delta: float, plane_at: Variant) -> void:
	_clock += delta
	var plane: Vector3 = plane_at if plane_at != null else Vector3.INF
	_wake(delta,plane)
	var way := light_way()
	var strength := light_strength()
	var cam := get_viewport().get_camera_3d() if is_inside_tree() else null
	var cam_in := 0.0
	var pl_in := 0.0
	if way.y < -0.12 and strength > 0.02:
		var nodes := get_tree().get_nodes_in_group(&"hall_shafts")
		if cam != null: cam_in = _depth_in(nodes,way,cam.global_position)
		if plane != Vector3.INF: pl_in = _depth_in(nodes,way,plane)
	camera_in = cam_in
	plane_in = pl_in
	# The plane meets the light before a chase camera does, and the view
	# is what flares: either brings it on, the plane's a little less.
	_raw = maxf(cam_in,pl_in*0.8)*strength*smoothstep(0.12,0.4,-way.y)
	# The eye adapts: the flare is mostly the step up into the light, and
	# fades as the view settles to it; what stays is a faint warmth.
	_adapt = move_toward(_adapt,_raw,ADAPT*delta*maxf(absf(_raw-_adapt),0.2))
	var target := maxf(_raw-_adapt,0.0)*1.6+_raw*0.22
	var rate := ATTACK if target > inside else RELEASE
	inside = move_toward(inside,target,rate*delta*maxf(absf(target-inside),0.25))
	_draw_flare(cam,way)

## How far `world` stands in the light (0 outside every beam, 1 well
## inside): its slant back up to the roof plane lands in an opening.
func _depth_in(nodes: Array, way: Vector3, world: Vector3) -> float:
	var best := 0.0
	for n: Variant in nodes:
		var shafts := n as Shafts.ShaftsNode
		if shafts == null or not shafts.is_inside_tree() or not shafts.is_visible_in_tree(): continue
		var inv := shafts.global_transform.affine_inverse()
		var p := inv*world
		if p.y > ROOF_Y or p.y < FLOOR_Y+0.4: continue
		var dir := inv.basis*way
		if dir.y > -0.05: continue
		# Back up the light to the roof plane.
		var s := (p.y-ROOF_Y)/dir.y
		if s > MAX_LEN: continue
		var top := p-dir*s
		for o: Dictionary in shafts.openings:
			var d := minf(minf(top.x-float(o.x0),float(o.x1)-top.x),minf(top.z-float(o.z0),float(o.z1)-top.z))
			if d <= 0.0: continue
			var w := smoothstep(0.0,EDGE+1.0,d)
			# Faded in under the roof and out toward the floor.
			var along := s/maxf((ROOF_Y-FLOOR_Y)/-dir.y,0.1)
			w *= smoothstep(0.0,0.08,along)*(1.0-smoothstep(0.7,1.0,along))
			best = maxf(best,w)
	return best

## The plane's last places and ways, the dust shader's wake.
func _wake(delta: float, plane: Vector3) -> void:
	_since += delta
	if plane != Vector3.INF:
		if _last != Vector3.INF and _since >= TRAIL_STEP:
			var moved := plane-_last
			if moved.length() > 0.05:
				_trail.push_front([plane,moved.normalized(),_clock,minf(moved.length()/maxf(_since,0.001)/40.0,1.4)])
				_since = 0.0
				_last = plane
		elif _last == Vector3.INF:
			_last = plane
	else:
		_last = Vector3.INF
	while _trail.size() > TRAIL or (not _trail.is_empty() and _clock-float(_trail.back()[2]) > TRAIL_LIFE): _trail.pop_back()
	var at := PackedVector4Array()
	var way := PackedVector4Array()
	for i in range(TRAIL):
		if i < _trail.size():
			var t: Array = _trail[i]
			var p: Vector3 = t[0]
			var w: Vector3 = t[1]
			at.append(Vector4(p.x,p.y,p.z,float(t[2])))
			way.append(Vector4(w.x,w.y,w.z,float(t[3])))
		else:
			at.append(Vector4.ZERO)
			way.append(Vector4.ZERO)
	var m := Shafts.dust_material()
	m.set_shader_parameter("wake_at",at)
	m.set_shader_parameter("wake_way",way)
	m.set_shader_parameter("now",_clock)

func _draw_flare(cam: Camera3D, way: Vector3) -> void:
	if _rect == null: return
	var amount := inside*FLARE*flare_scale
	_rect.visible = amount > 0.003
	if not _rect.visible or cam == null: return
	# Where the sun is on the screen: toward it if it is ahead, else
	# the nearest edge it is behind.
	var sun := -way
	var back := cam.global_basis.z
	var ahead := -back.dot(sun)
	var uv := Vector2(0.5,0.0)
	if ahead > 0.05:
		var p := cam.unproject_position(cam.global_position+sun*100.0)
		var size := get_viewport().get_visible_rect().size
		uv = Vector2(p.x/size.x,p.y/size.y)
	else:
		uv = Vector2(0.5,-0.2)
	_flare.set_shader_parameter("amount",amount)
	_flare.set_shader_parameter("sun_uv",uv)
	_flare.set_shader_parameter("facing",clampf(ahead*1.5+0.35,0.0,1.0))
	var sky := _sky()
	if not sky.is_empty() and (sky.zs_key_irradiance as Vector3).length() > 0.001:
		var c: Vector3 = (sky.zs_key_irradiance as Vector3).normalized()
		_flare.set_shader_parameter("tint",Vector3(c.x*1.15,c.y*0.96,c.z*0.78))
