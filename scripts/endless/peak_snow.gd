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
##
## The land's lie (`_bake`) is a small map of how flat the land is over a hundred
## metres or so: a bench in a wall is as flat as a plateau where it stands, and
## only the map tells them apart, so the snow's mask lays lenses on the one and
## a whole field on the other. Baked once, on a worker, from the field.

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
## The land's lie, baked once for the zone: texels a side, the half span of the
## slope it reads (texels), the ring its hollows are read against, and how many
## metres of hollow make the full range. The bench in a wall is under the span,
## so it reads as the wall; a plateau or a gorge's floor reads as flat.
const BROAD_PX := 256
const BROAD_SPAN := 2
const BROAD_RING := 3
const BROAD_HOLLOW := 60.0
## The steep limit and the broad lie's share of the slope
## (shaders/peak_snow.gdshaderinc PSNOW_HOLD, PSNOW_BROAD).
const HOLD := 0.63
const BROAD := 0.5
## The band of rubble the ice's edge pushes past it (m, gorge and tongue) and the
## rock floor's edge, by its half-width.
const RUBBLE := Vector2(11.0,80.0)
const ROCK_EDGE := 1.1

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
var _over_line := false
var _cover_spot := Vector2.INF
var _owed := 0.0
var _last_plane := Vector3.INF
var _plane_vel := Vector3.ZERO
var _paint: Dictionary
var _wind := Vector2.ZERO
var _broad_tex: ImageTexture
var _broad_rect := Vector4.ZERO
## The bake's result, and then the image `covers` reads.
var _baked: Image
var _broad: Image
var _bake_task := -1

static func wanted() -> bool:
	return not "--peak-snow=0" in LaunchArgs.user_args()

## The surface on: set with the Peak's paint, before the rocks copy the ground.
static func paint(look: ShaderMaterial, massif: RefCounted) -> void:
	look.set_shader_parameter("psnow_on",1.0)
	look.set_shader_parameter("psnow_wind",Vector2(massif.facing).rotated(0.5))
	# (Flat until `setup`'s bake lands. The rocks copy this material, so the bake
	# fills this same texture, and they get it too.)
	var blank := Image.create_empty(BROAD_PX,BROAD_PX,false,Image.FORMAT_RG8)
	blank.fill(Color(1.0,0.5,0.0))
	look.set_shader_parameter("psnow_broad",ImageTexture.create_from_image(blank))
	var zone: Vector4 = look.get_shader_parameter("peak_zone")
	look.set_shader_parameter("psnow_broad_rect",Vector4(zone.x-zone.z,zone.y-zone.z,zone.z*2.0,0.0))

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
	_broad_tex = look.get_shader_parameter("psnow_broad")
	_broad_rect = look.get_shader_parameter("psnow_broad_rect")
	_bake_task = WorkerThreadPool.add_task(_bake)

func _process(_delta: float) -> void:
	if _baked == null: return
	_broad = _baked
	_baked = null
	_broad_tex.update(_broad)
	WorkerThreadPool.wait_for_task_completion(_bake_task)
	_bake_task = -1
	set_process(false)

func _exit_tree() -> void:
	if _bake_task >= 0: WorkerThreadPool.wait_for_task_completion(_bake_task)

## The land's lie over the zone, on a worker: r how flat it is over BROAD_SPAN
## texels either way (1 flat), g its hollows (over 0.5) and crowns.
func _bake() -> void:
	var n := BROAD_PX
	var step := _broad_rect.z/n
	var hs: PackedFloat32Array = field.grid(_broad_rect.x+step*0.5,_broad_rect.y+step*0.5,step,n,n).heights
	# (A rare NaN in the field's height: take its neighbour's.)
	for k in hs.size():
		if is_nan(hs[k]): hs[k] = hs[k-1] if k > 0 else Field.SEA_Y
	var out := PackedByteArray()
	out.resize(n*n*2)
	for j in n:
		for i in n:
			var gx := (hs[j*n+mini(i+BROAD_SPAN,n-1)]-hs[j*n+maxi(i-BROAD_SPAN,0)])/(2.0*BROAD_SPAN*step)
			var gz := (hs[mini(j+BROAD_SPAN,n-1)*n+i]-hs[maxi(j-BROAD_SPAN,0)*n+i])/(2.0*BROAD_SPAN*step)
			var ring := (hs[j*n+mini(i+BROAD_RING,n-1)]+hs[j*n+maxi(i-BROAD_RING,0)]+hs[mini(j+BROAD_RING,n-1)*n+i]+hs[maxi(j-BROAD_RING,0)*n+i])*0.25
			out[(j*n+i)*2] = int(255.0/sqrt(1.0+gx*gx+gz*gz))
			out[(j*n+i)*2+1] = int(clampf(0.5+(ring-hs[j*n+i])/BROAD_HOLLOW,0.0,1.0)*255.0)
	_baked = Image.create_from_data(n,n,false,Image.FORMAT_RG8,out)

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
			_over_line = _above_line(hit.x,hit.y)
		stats.on_snow = _on_snow
		# (Over the snow line bare rock has no grass to kick either.)
		if _on_snow or _over_line: left = {}
		if _on_snow:
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

## The eddies' ribbons that may kick grass bits: those not skimming snow.
func off_snow(ribbons: Array) -> Array:
	var line := float(_paint.peak_snow)-10.0+Field.SEA_Y
	var out := []
	for rb: Dictionary in ribbons:
		if float(rb.ground) < line or not covers(float(rb.pos.x),float(rb.pos.z)): out.append(rb)
	return out

# --- Where the snow lies ---------------------------------------------------------------

## Whether snow lies at world xz (x, z), as the ground shader paints it
## without its ragged edges or a wall's patches: the Peak's zone over its snow
## line, not too steep for the land's lie, off the gorges' floors.
func covers(x: float, z: float) -> bool:
	if not _above_line(x,z): return false
	var h: float = field.height(x,z)
	var hx: float = field.height(x+3.0,z)
	var hz: float = field.height(x,z+3.0)
	var ny := 1.0/sqrt(1.0+((hx-h)*(hx-h)+(hz-h)*(hz-h))/9.0)
	if lerpf(ny,_lie(x,z),BROAD) < HOLD: return false
	return not _on_floor(x,z)

## Whether (x, z) lies in the Peak's zone over its snow line.
func _above_line(x: float, z: float) -> bool:
	if float(field.height(x,z))-Field.SEA_Y < float(_paint.peak_snow)-10.0: return false
	var zone: Vector4 = _paint.peak_zone
	return Vector2(x,z).distance_to(Vector2(zone.x,zone.y)) <= zone.z

## The land's broad flatness at (x, z).
func _lie(x: float, z: float) -> float:
	if _broad == null: return 1.0
	var c := Vector2i(int((x-_broad_rect.x)/_broad_rect.z*BROAD_PX),int((z-_broad_rect.y)/_broad_rect.z*BROAD_PX))
	return _broad.get_pixelv(c.clamp(Vector2i.ZERO,Vector2i.ONE*(BROAD_PX-1))).r

## Whether (x, z) lies on the ice, the rubble round it or the rock gorge's floor
## (shaders/peak_ice.gdshaderinc peak_ice_frame and peak_ice_margin,
## peak_paint's rock line; without their rag).
func _on_floor(x: float, z: float) -> bool:
	var q := Vector2(x,z)
	return _on_ice(q) or _on_rock(q)

func _on_ice(q: Vector2) -> bool:
	if not _paint.has("peak_ice_line"): return false
	var box: Vector4 = _paint.peak_ice_box
	if q.x < box.x or q.y < box.y or q.x > box.z or q.y > box.w: return false
	var line: PackedVector4Array = _paint.peak_ice_line
	var more: PackedVector2Array = _paint.peak_ice_more
	var best := INF
	var at := 0
	var at_h := 0.0
	for i in int(_paint.peak_ice_count)-1:
		var a := Vector2(line[i].x,line[i].y)
		var e := Vector2(line[i+1].x,line[i+1].y)-a
		var h := clampf((q-a).dot(e)/maxf(e.length_squared(),0.001),0.0,1.0)
		var dd := q.distance_squared_to(a+e*h)
		if dd < best:
			best = dd
			at = i
			at_h = h
	var half := lerpf(line[at].z,line[at+1].z,at_h)
	var m := more[at].lerp(more[at+1],at_h)
	var tongue := smoothstep(0.16,0.24,m.y)
	var past := (sqrt(best)/half+(1.0-m.x)*1.3-1.0)*half
	return past < lerpf(RUBBLE.x,RUBBLE.y,tongue)

func _on_rock(q: Vector2) -> bool:
	if int(_paint.get("peak_rock_count",0)) < 2: return false
	var box: Vector4 = _paint.peak_rock_box
	if q.x < box.x or q.y < box.y or q.x > box.z or q.y > box.w: return false
	var line: PackedVector3Array = _paint.peak_rock_line
	for i in int(_paint.peak_rock_count)-1:
		var a := Vector2(line[i].x,line[i].y)
		var e := Vector2(line[i+1].x,line[i+1].y)-a
		var h := clampf((q-a).dot(e)/maxf(e.length_squared(),0.001),0.0,1.0)
		if q.distance_to(a+e*h) < lerpf(line[i].z,line[i+1].z,h)*ROCK_EDGE: return true
	return false

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
