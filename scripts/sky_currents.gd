extends Node3D
## The air between the sky islands (scripts/sky_islands.gd): where the glide
## (scripts/sky_glide.gd) goes fast and where it goes up. The base glide is
## slow and floaty; the speed and the height come from the air.
##
## Jet streams are two rivers of air that loop through every island: a low
## one just outside the islands, and a high one going the other way on the
## inside. In one, the air carries the glide along at JET m/s, holds it
## gently to the stream's core, and turns it to face downstream unless it
## is steering. Steering hard across the stream takes it out.
##
## Thermals are columns of rising air beside each island and out in open
## sky between them. In one, the glide lifts at LIFT m/s.
##
## Both are drawn as soft wisps flowing along them
## (shaders/sky_current.gdshader): long streaks down a jet, short ones
## spiralling up a thermal. The paths go to the shader as a float texture,
## one row per current (`_texture`), and the shader moves each wisp along
## its row.
##
## Everything is laid out from the islands' slots (the plate at the origin,
## then each copy's offset), so the currents move with the world when the
## islands swap (SkyIslands `arrive` shifts this node too).

## Samples along each current's path, in the shader's texture and here.
const SAMPLES := 64
const JET := 26.0
const JET_RADIUS := 9.0
## Metres a second the core pulls the glide in at the stream's edge.
const JET_HOLD := 9.0
## The low loop passes this far out from each island's middle and this high
## over it; the high loop passes on the inside, higher. Between islands each
## loop swells up or dips down by SWELL.
const LOW_OUT := 40.0
const LOW_UP := 18.0
const HIGH_IN := 40.0
const HIGH_UP := 48.0
const SWELL := 26.0
const LIFT := 7.0
const THERMAL_RADIUS := 7.0
const THERMAL_FROM := -70.0
const THERMAL_TO := 55.0
## How the wisps fill each kind: per metre of jet and per thermal.
const JET_WISPS := 0.5
const THERMAL_WISPS := 90

## Each current: {points: PackedVector3Array, closed, speed, radius, kind}.
var currents := []
var _wisps: MultiMeshInstance3D
var _material: ShaderMaterial

## Lays out the currents round `slots` (global positions of the plate and
## every copy, the plate first) and builds their wisps.
func build(slots: Array) -> void:
	name = "SkyCurrents"
	currents.clear()
	var centre := Vector3.ZERO
	for s: Vector3 in slots: centre += s
	centre /= float(slots.size())
	# The loop's order: round the archipelago by angle.
	var order := range(slots.size())
	order.sort_custom(func(a: int, b: int) -> bool:
		var da: Vector3 = slots[a]-centre
		var db: Vector3 = slots[b]-centre
		return atan2(da.z,da.x) < atan2(db.z,db.x))
	var low := []
	var high := []
	for n in range(order.size()):
		var here: Vector3 = slots[order[n]]
		var next: Vector3 = slots[order[(n+1)%order.size()]]
		var out := Vector3(here.x-centre.x,0.0,here.z-centre.z).normalized()
		var next_out := Vector3(next.x-centre.x,0.0,next.z-centre.z).normalized()
		low.append(here+out*LOW_OUT+Vector3.UP*LOW_UP)
		low.append((here+out*LOW_OUT+next+next_out*LOW_OUT)*0.5+Vector3.UP*(LOW_UP+SWELL*(1.0 if n%2 == 0 else -0.6)))
		high.append(here-out*HIGH_IN+Vector3.UP*HIGH_UP)
		high.append((here-out*HIGH_IN+next-next_out*HIGH_IN)*0.5+Vector3.UP*(HIGH_UP+SWELL*(-0.7 if n%2 == 0 else 1.0)))
	high.reverse()
	currents.append(_current(_loop(low),true,JET,JET_RADIUS,"jet"))
	currents.append(_current(_loop(high),true,JET,JET_RADIUS,"jet"))
	# Thermals: off the plate's four sides, two beside each copy, and one
	# out in open sky between each pair of islands round the loop.
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	for i in range(slots.size()):
		var here: Vector3 = slots[i]
		var sides := 4 if i == 0 else 2
		var turn := rng.randf()*TAU
		for k in range(sides):
			var a := turn+TAU*k/sides
			_thermal(here+Vector3(cos(a),0.0,sin(a))*24.0)
	for n in range(order.size()):
		var here: Vector3 = slots[order[n]]
		var next: Vector3 = slots[order[(n+1)%order.size()]]
		var across := (next-here).cross(Vector3.UP).normalized()
		_thermal((here+next)*0.5+across*rng.randf_range(-90.0,90.0))
	_build_wisps()

func _thermal(base: Vector3) -> void:
	var points := PackedVector3Array()
	for i in range(SAMPLES):
		points.append(base+Vector3.UP*lerpf(THERMAL_FROM,THERMAL_TO,float(i)/(SAMPLES-1)))
	currents.append(_current(points,false,LIFT,THERMAL_RADIUS,"thermal"))

func _current(points: PackedVector3Array, closed: bool, speed: float, radius: float, kind: String) -> Dictionary:
	var length := 0.0
	var count := points.size() if closed else points.size()-1
	for i in range(count): length += points[i].distance_to(points[(i+1)%points.size()])
	return {"points":points,"closed":closed,"speed":speed,"radius":radius,"kind":kind,"length":length}

## A smooth closed loop through `controls`, SAMPLES points round.
static func _loop(controls: Array) -> PackedVector3Array:
	var points := PackedVector3Array()
	var n := controls.size()
	for i in range(SAMPLES):
		var t := float(i)/SAMPLES*n
		var k := int(t)
		var f := t-k
		var p0: Vector3 = controls[(k-1+n)%n]
		var p1: Vector3 = controls[k%n]
		var p2: Vector3 = controls[(k+1)%n]
		var p3: Vector3 = controls[(k+2)%n]
		points.append(0.5*((2.0*p1)+(-p0+p2)*f+(2.0*p0-5.0*p1+4.0*p2-p3)*f*f+(-p0+3.0*p1-3.0*p2+p3)*f*f*f))
	return points

## The air at a global point:
##   wind: the air's velocity there (m/s);
##   hold: the jet's pull back towards its core (m/s), which the glide
##     lets go of while steering;
##   along: the way the jet runs there, as long as how far in it is (0 to 1);
##   jet, thermal: how far into each kind it is (0 to 1).
func air_at(point: Vector3) -> Dictionary:
	var local := point-position
	var wind := Vector3.ZERO
	var along := Vector3.ZERO
	var hold := Vector3.ZERO
	var jet := 0.0
	var thermal := 0.0
	for current: Dictionary in currents:
		var nearest := _nearest(current,local)
		var reach: float = current.radius
		var gap: float = nearest.gap
		if gap > reach*1.3: continue
		var inside := 1.0-smoothstep(reach*0.55,reach*1.3,gap)
		# A thermal fades out over its top.
		if current.kind == "thermal":
			var top: float = current.points[current.points.size()-1].y
			inside *= 1.0-smoothstep(top-15.0,top,local.y)
			wind += Vector3.UP*current.speed*inside
			thermal = maxf(thermal,inside)
			continue
		var way: Vector3 = nearest.way
		wind += way*current.speed*inside
		# Held to the core: a pull in, strongest at the edge.
		var to_core: Vector3 = nearest.at-local
		if to_core.length() > 0.01: hold += to_core.normalized()*JET_HOLD*inside*clampf(gap/reach,0.0,1.0)
		along += way*inside
		jet = maxf(jet,inside)
	return {"wind":wind,"hold":hold,"along":along,"jet":jet,"thermal":thermal}

## The nearest point on a current's path to a local point: {at, gap, way}.
static func _nearest(current: Dictionary, local: Vector3) -> Dictionary:
	var points: PackedVector3Array = current.points
	var count := points.size() if current.closed else points.size()-1
	var best := {"at":points[0],"gap":INF,"way":Vector3.FORWARD}
	for i in range(count):
		var a := points[i]
		var b := points[(i+1)%points.size()]
		var ab := b-a
		var t := clampf((local-a).dot(ab)/maxf(ab.length_squared(),1e-6),0.0,1.0)
		var at := a+ab*t
		var gap := at.distance_to(local)
		if gap < best.gap: best = {"at":at,"gap":gap,"way":ab.normalized()}
	return best

# --- The wisps --------------------------------------------------------------------

## The paths as a float texture: one row per current, SAMPLES points, then
## a texel of (length, speed, radius, swirl) and one of (closed, kind).
func _texture() -> ImageTexture:
	var image := Image.create(SAMPLES+2,currents.size(),false,Image.FORMAT_RGBAF)
	for row in range(currents.size()):
		var current: Dictionary = currents[row]
		var points: PackedVector3Array = current.points
		for i in range(SAMPLES):
			var p := points[i]
			image.set_pixel(i,row,Color(p.x,p.y,p.z,1.0))
		var swirl := 0.0 if current.kind == "jet" else 0.08
		image.set_pixel(SAMPLES,row,Color(current.length,current.speed,current.radius,swirl))
		image.set_pixel(SAMPLES+1,row,Color(1.0 if current.closed else 0.0,0.0 if current.kind == "jet" else 1.0,0.0,0.0))
	return ImageTexture.create_from_image(image)

func _build_wisps() -> void:
	if _wisps != null: _wisps.queue_free()
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var custom := []
	for row in range(currents.size()):
		var current: Dictionary = currents[row]
		var count := int(float(current.length)*JET_WISPS) if current.kind == "jet" else THERMAL_WISPS
		for i in range(count):
			# Row, where along it starts, a seed, a size.
			custom.append(Color((row+0.5)/currents.size(),rng.randf(),rng.randf(),rng.randf()))
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_custom_data = true
	multimesh.mesh = quad
	multimesh.instance_count = custom.size()
	for i in range(custom.size()):
		multimesh.set_instance_transform(i,Transform3D.IDENTITY)
		multimesh.set_instance_custom_data(i,custom[i])
	_material = ShaderMaterial.new()
	_material.shader = preload("res://shaders/sky_current.gdshader")
	_material.set_shader_parameter("paths",_texture())
	_material.set_shader_parameter("samples",SAMPLES)
	_wisps = MultiMeshInstance3D.new()
	_wisps.name = "Wisps"
	_wisps.multimesh = multimesh
	_wisps.material_override = _material
	_wisps.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# The wisps are placed in the shader; never cull them.
	_wisps.custom_aabb = AABB(Vector3.ONE*-1e5,Vector3.ONE*2e5)
	add_child(_wisps)

func wisp_count() -> int:
	return _wisps.multimesh.instance_count if _wisps != null else 0
