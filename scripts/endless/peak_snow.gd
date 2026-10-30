extends Node
## The Peak's snow answering the plane: the furrow its wash leaves and the
## powder a low pass throws. The surface itself is shaders/peak_snow.gdshaderinc
## (a hook in shaders/endless_ground.gdshader), switched on by `paint`.
## --peak-snow=0 turns all of it off and leaves the Peak's old paint.
##
## The wash is GrassReact's: its push map is world space round the eye, knows
## nothing of grass tiles and nothing of height, so `wash_spot` and
## zs_react_map reach the snow as they are. Its stamps are gone in about 3 s
## and it reaches 192 m, which is why the furrow is a map of its own here:
## a groove lives FILL.y s and shows when you come back round for it.
##
## Both live in the GPU's memory: a stamp or a puff is written once, when
## made, into a ring of FURROW_MOST or POWDER_MOST, and its age does the rest
## in the shaders. Nothing here loops over them, so there is no second path
## for the native kernels. On snow the wash is kept from EndlessMotes (`step`
## returns {}), which on both paths stops the grass blades at `_kick`.

const LaunchArgs = preload("res://scripts/launch_args.gd")
const Field = preload("res://scripts/endless/land_field.gd")
const STAMP = preload("res://shaders/peak_snow_stamp.gdshader")
const POWDER = preload("res://shaders/peak_powder.gdshader")

## The furrow's map: texels a side, metres a side, how far the eye moves
## before it is laid afresh, and how often it is redrawn while anything lives.
const MAP_PX := 768
const MAP_M := 768.0
const MAP_SNAP := 64.0
const MAP_EVERY := 0.1
## A length of furrow every FURROW_STEP m; the most alive; its half width as a
## share of the wash's reach; and when it starts to fill and when it's gone (s).
const FURROW_STEP := 7.0
const FURROW_MOST := 160
const FURROW_WIDTH := 0.62
const FILL := Vector2(4.0,22.0)
## Puffs a second at full wash, how many there can be, their life (s), size
## at first and at last (m), opacity, how hard they're thrown out (m/s), up
## (m/s), the plane's way they keep at first, the drag (1/s), the rise they
## hold (m/s). One in JET_EVERY goes up as a jet, JET_UP m/s.
const POWDER_RATE := 95.0
const POWDER_MOST := 360
const POWDER_LIFE := Vector2(2.4,5.5)
const POWDER_START := Vector2(0.9,2.2)
const POWDER_END := Vector2(5.0,11.0)
const POWDER_OPACITY := Vector2(0.24,0.5)
const POWDER_OUT := Vector2(3.0,10.0)
const POWDER_UP := Vector2(3.0,9.0)
const POWDER_CARRY := 0.55
const POWDER_DRAG := Vector2(1.1,1.9)
const POWDER_RISE := Vector2(0.1,0.7)
const JET_EVERY := 4
const JET_UP := Vector2(12.0,24.0)
## How often the ground under the wash is asked whether it is snow (s).
const COVER_EVERY := 0.08

var peak: RefCounted
var field: RefCounted
var ground: ShaderMaterial
## For the numbers: stamps and puffs made so far, whether the wash is on snow.
var stats := {"furrows": 0, "puffs": 0, "on_snow": false}

var _viewport: SubViewport
var _stamps: MultiMesh
var _drawn: MultiMeshInstance2D
var _stamp_look: ShaderMaterial
var _puffs: MultiMesh
var _puff_node: MultiMeshInstance3D
var _puff_look: ShaderMaterial
var _rng := RandomNumberGenerator.new()
var _time := 0.0
var _stamp_next := 0
var _puff_next := 0
var _map_at := Vector2.INF
var _map_drawn := -INF
var _furrow_until := -INF
var _puff_until := -INF
var _map_live := false
var _last_hit := Vector2.INF
var _last_way := Vector2.ZERO
var _cover_at := -INF
var _on_snow := false
var _cover_spot := Vector2.INF
var _owed := 0.0
var _last_plane := Vector3.INF
var _plane_vel := Vector3.ZERO
var _paint: Dictionary
var _wind := Vector2.ZERO

static func wanted() -> bool:
	return not "--peak-snow=0" in LaunchArgs.user_args()

## The surface on: set with the Peak's paint, before the rocks copy the ground.
static func paint(look: ShaderMaterial, massif: RefCounted) -> void:
	look.set_shader_parameter("psnow_on",1.0)
	look.set_shader_parameter("psnow_wind",Vector2(massif.facing).rotated(0.5))

func setup(land_seed: int, look: ShaderMaterial, massif: RefCounted, land: RefCounted) -> void:
	name = "PeakSnow"
	ground = look
	peak = massif
	field = land
	_paint = massif.paint()
	_rng.seed = land_seed*4231+17
	_viewport = SubViewport.new()
	_viewport.name = "Furrows"
	_viewport.size = Vector2i(MAP_PX,MAP_PX)
	_viewport.use_hdr_2d = true
	_viewport.transparent_bg = true
	_viewport.disable_3d = true
	_viewport.render_target_clear_mode = SubViewport.CLEAR_MODE_ALWAYS
	_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(_viewport)
	_stamps = MultiMesh.new()
	_stamps.transform_format = MultiMesh.TRANSFORM_2D
	_stamps.use_custom_data = true
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	_stamps.mesh = quad
	_stamps.instance_count = FURROW_MOST
	_stamps.visible_instance_count = 0
	_drawn = MultiMeshInstance2D.new()
	_drawn.multimesh = _stamps
	_stamp_look = ShaderMaterial.new()
	_stamp_look.shader = STAMP
	_stamp_look.set_shader_parameter("fill",FILL)
	_drawn.material = _stamp_look
	_viewport.add_child(_drawn)
	ground.set_shader_parameter("psnow_furrow",_viewport.get_texture())
	_puffs = MultiMesh.new()
	_puffs.transform_format = MultiMesh.TRANSFORM_3D
	_puffs.use_colors = true
	_puffs.use_custom_data = true
	var puff := QuadMesh.new()
	puff.size = Vector2.ONE*2.0
	_puffs.mesh = puff
	_puffs.instance_count = POWDER_MOST
	_puffs.visible_instance_count = 0
	_puff_look = ShaderMaterial.new()
	_puff_look.shader = POWDER
	_puff_node = MultiMeshInstance3D.new()
	_puff_node.name = "Powder"
	_puff_node.multimesh = _puffs
	_puff_node.material_override = _puff_look
	_puff_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_puff_node.custom_aabb = AABB(Vector3.ONE*-1.0e5,Vector3.ONE*2.0e5)
	_puff_node.visible = false
	add_child(_puff_node)

## One frame, after GrassReact's. `at` the plane, `wash` its wash_spot (or {}),
## `wind` the day's breeze. The wash to hand on to the grass bits: {} on snow.
func step(delta: float, at: Vector3, wash: Dictionary, wind: Vector2, eye: Vector3) -> Dictionary:
	_time += delta
	if _last_plane != Vector3.INF and delta > 0.0: _plane_vel = (at-_last_plane)/delta
	_last_plane = at
	_wind = wind
	var left := wash
	if wash.is_empty():
		stats.on_snow = false
		_last_hit = Vector2.INF
	else:
		var hit: Vector2 = wash.at
		if _time-_cover_at >= COVER_EVERY or hit.distance_to(_cover_spot) > 8.0:
			_cover_at = _time
			_cover_spot = hit
			_on_snow = covers(hit.x,hit.y)
		stats.on_snow = _on_snow
		if _on_snow:
			left = {}
			_furrow(hit,wash)
			_powder(delta,hit,wash)
		else:
			_last_hit = Vector2.INF
	_map(eye)
	if _time < _puff_until:
		_puff_look.set_shader_parameter("now",_time)
		_puff_look.set_shader_parameter("air",_wind*2.2)
	elif _puff_node.visible:
		_puff_node.visible = false
	return left

# --- Where the snow lies ---------------------------------------------------------------

## Whether snow lies at world xz (x, z), as the ground shader paints it
## without its ragged edges: the Peak's zone over its snow line, not too steep
## for the height, off the valley floor's ice and scree.
func covers(x: float, z: float) -> bool:
	var h: float = field.height(x,z)
	var over := h-Field.SEA_Y
	var line := float(_paint.peak_snow)
	if over < line-10.0: return false
	var zone: Vector4 = _paint.peak_zone
	if Vector2(x,z).distance_to(Vector2(zone.x,zone.y)) > zone.z: return false
	var hx: float = field.height(x+3.0,z)
	var hz: float = field.height(x,z+3.0)
	var ny := 1.0/sqrt(1.0+((hx-h)*(hx-h)+(hz-h)*(hz-h))/9.0)
	var high := smoothstep(line,line+500.0,over)
	if ny < lerpf(0.60,0.44,high): return false
	return not _on_floor(x,z)

## Whether (x, z) lies on the approach valley's ice or scree
## (shaders/endless_ground.gdshader peak_paint, without its rag).
func _on_floor(x: float, z: float) -> bool:
	var frame: Vector4 = _paint.peak_frame
	var rel := Vector2(x-frame.x,z-frame.y)
	var f := Vector2(frame.z,frame.w)
	var a := rel.dot(f)
	var v := rel.dot(Vector2(-f.y,f.x))
	var bend: Vector4 = _paint.peak_bend
	var stretch: Vector4 = _paint.peak_stretch
	var half: Vector4 = _paint.peak_half
	if a < stretch.x or a > stretch.w: return false
	var t := clampf((a-bend.z)/(bend.w-bend.z),0.0,1.0)
	var mid := bend.x*sin(PI*bend.y*t)*smoothstep(0.0,0.25,t)
	var hw := half.x
	if a > stretch.y and a < stretch.z: hw = lerpf(half.x,half.y,smoothstep(0.0,0.3,(a-stretch.y)/(stretch.z-stretch.y)))
	elif a >= stretch.z: hw = lerpf(half.z,half.w,clampf((a-stretch.z)/(stretch.w-stretch.z),0.0,1.0))
	return absf(v-mid)/hw < 1.0

# --- The furrow ------------------------------------------------------------------------

func _furrow(hit: Vector2, wash: Dictionary) -> void:
	if _last_hit == Vector2.INF:
		_last_hit = hit
		_last_way = Vector2(wash.back)*-1.0
		return
	var gone := hit.distance_to(_last_hit)
	if gone < FURROW_STEP: return
	if gone > FURROW_STEP*4.0:
		_last_hit = hit
		return
	var way := (hit-_last_hit)/gone
	var half_wide := float(wash.reach)*FURROW_WIDTH
	var strength := clampf(float(wash.k)*1.7,0.0,1.0)
	var i := _stamp_next
	_stamp_next = (_stamp_next+1) % FURROW_MOST
	# Its middle where the wash was last; the window reaches both neighbours.
	var side := half_wide*1.8
	var per_m := MAP_PX/MAP_M
	var long := gone*2.0
	var xf := Transform2D(way*long*per_m,Vector2(-way.y,way.x)*side*2.0*per_m,_last_hit*per_m)
	_stamps.set_instance_transform_2d(i,xf)
	_stamps.set_instance_custom_data(i,Color(_time,strength,half_wide/side,0.0))
	_stamps.visible_instance_count = maxi(_stamps.visible_instance_count,i+1)
	_last_hit = hit
	_last_way = way
	_furrow_until = _time+FILL.y+0.5
	stats.furrows = int(stats.furrows)+1

## Keeps the map laid round the eye and drawn while there is anything in it.
func _map(eye: Vector3) -> void:
	var live := _time < _furrow_until
	if not live:
		if _map_live:
			_map_live = false
			ground.set_shader_parameter("psnow_furrow_rect",Vector4.ZERO)
		return
	var c := Vector2(snappedf(eye.x,MAP_SNAP),snappedf(eye.z,MAP_SNAP))
	var moved := c != _map_at
	if moved:
		_map_at = c
		var low := c-Vector2.ONE*MAP_M*0.5
		_drawn.position = -low*MAP_PX/MAP_M
		ground.set_shader_parameter("psnow_furrow_rect",Vector4(low.x,low.y,MAP_M,1.0))
	if not _map_live:
		_map_live = true
		ground.set_shader_parameter("psnow_furrow_rect",Vector4(c.x-MAP_M*0.5,c.y-MAP_M*0.5,MAP_M,1.0))
	if moved or _time-_map_drawn >= MAP_EVERY:
		_map_drawn = _time
		_stamp_look.set_shader_parameter("now",_time)
		_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE

# --- The powder ------------------------------------------------------------------------

func _powder(delta: float, hit: Vector2, wash: Dictionary) -> void:
	var k := float(wash.k)
	_owed += POWDER_RATE*k*delta
	if _owed < 1.0: return
	var g: float = field.height(hit.x,hit.y)
	var reach := float(wash.reach)
	var back: Vector2 = wash.back
	var carry := _plane_vel*POWDER_CARRY
	var strength := sqrt(k)
	while _owed >= 1.0:
		_owed -= 1.0
		var out := Vector2.from_angle(_rng.randf()*TAU)
		var at := hit+out*sqrt(_rng.randf())*reach*0.8
		var fling := out*_rng.randf_range(POWDER_OUT.x,POWDER_OUT.y)*k+back*_rng.randf_range(1.0,6.0)
		var jet := _puff_next % JET_EVERY == 0
		var up := _rng.randf_range(JET_UP.x,JET_UP.y) if jet else _rng.randf_range(POWDER_UP.x,POWDER_UP.y)
		var keep := _rng.randf_range(0.5,1.2)
		var throw := Vector3(fling.x+carry.x*keep,up*strength,fling.y+carry.z*keep)
		var born_y := g+_rng.randf_range(0.2,1.0)
		var life := _rng.randf_range(POWDER_LIFE.x,POWDER_LIFE.y)
		var i := _puff_next
		_puff_next = (_puff_next+1) % POWDER_MOST
		var xf := Transform3D(Basis(throw,Vector3(g,_rng.randf(),0.0),Vector3.ZERO),Vector3(at.x,born_y,at.y))
		_puffs.set_instance_transform(i,xf)
		var big := 0.6+0.8*k
		_puffs.set_instance_color(i,Color(_time,life,_rng.randf_range(POWDER_START.x,POWDER_START.y),_rng.randf_range(POWDER_END.x,POWDER_END.y)*big))
		_puffs.set_instance_custom_data(i,Color(_rng.randf_range(POWDER_OPACITY.x,POWDER_OPACITY.y)*strength,_rng.randf_range(POWDER_DRAG.x,POWDER_DRAG.y),_rng.randf_range(POWDER_RISE.x,POWDER_RISE.y),0.0))
		_puffs.visible_instance_count = maxi(_puffs.visible_instance_count,i+1)
		stats.puffs = int(stats.puffs)+1
		_puff_until = maxf(_puff_until,_time+life)
	_puff_node.visible = true
