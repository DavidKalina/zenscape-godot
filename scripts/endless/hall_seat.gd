extends RefCounted
## What seats the ruin door (hall_doors.gd) in its land: a podium of stepped
## stone courses under both belfries and the hall, down into the ground, with
## broken edges, fallen blocks and outworks in the grass; the trees kept off
## it and off the way in; and the far end of the mouth, a shader that looks
## down a torchlit hall where a quad stands.
##
## All of it stands in the door's frame (origin the mouth's floor, z inward,
## x across). The land is left as it is: the podium takes up what the ground
## does under it, so land_hash stays the field's own.

const RuinKit_ = preload("res://scripts/ruin_kit.gd")
const Gothic = preload("res://scripts/ruin_kit_gothic.gd")

## Where the wilderness mouth stands on seed 1 (XZ), and the spot it faces:
## the true start, on the title's meadow.
const WILD_AT := Vector2(-1960.0,3440.0)
const FACES := Vector2(164.8,-32.4)
## The stone's top, the mouth's floor: half width (m), how far before the
## mouth it starts; how far past the ruin's back it ends.
const HALF_X := 58.0
const FRONT := -16.0
const BACK := 8.0
## A course's rise and the step out to the next one (m), how deep a block runs
## in, and the most courses (the ground stops them sooner).
const COURSE := 1.7
const STEP := 2.6
const DEEP := 3.4
const MOST := 14
## The ground under the outermost stone is this far over the course's foot.
const SINK := 1.0
## Clear of trees round the stone, and down the way in (m; half sizes).
const CLEAR_X := 92.0
const CLEAR_Z := 130.0
const WAY_X := 46.0
const WAY_LONG := 270.0
## Fallen blocks, and outworks (stubs of old walling in the grass).
const FALLEN := 46
const OUTWORKS := 7

## The wilderness mouth's XZ.
static func wild_at() -> Vector2:
	return WILD_AT

## The way in from the mouth (XZ).
static func wild_in() -> Vector2:
	return (wild_at()-FACES).normalized()

## TreePlan's keep-outs, [centre XZ, cos, sin, half across, half along]: the
## stone with its margin, and the way in.
static func tree_keepouts(x0: float, z0: float, x1: float, z1: float) -> Array:
	var way := wild_in()
	var yaw := atan2(way.x,way.y)
	var out: Array = []
	var c := cos(yaw)
	var s := sin(yaw)
	for spot: Array in [[wild_at()+way*60.0,CLEAR_X,CLEAR_Z],[wild_at()-way*90.0,WAY_X,WAY_LONG]]:
		var p: Vector2 = spot[0]
		if p.x < x0-500.0 or p.x > x1+500.0 or p.y < z0-500.0 or p.y > z1+500.0: continue
		out.append([p,c,s,float(spot[1]),float(spot[2])])
	return out

## The stone's top under (x, z) in the frame (0 on the podium, down the steps
## past it), -INF off it. `back`: the z its rear edge stands at; `steps`: its
## courses.
static func top(x: float, z: float, back: float, steps: int) -> float:
	var d := maxf(maxf(absf(x)-HALF_X,FRONT-z),z-back)
	if d <= 0.0: return 0.0
	var k := ceili(d/STEP)
	return -INF if k > steps else -k*COURSE

## How many courses it takes for the stone to go into the ground all round:
## `ground`: Callable(x, z) -> y in the frame.
static func courses(ground: Callable, back: float) -> int:
	var k := 1
	while k < MOST:
		var r := k*STEP
		var low := INF
		for t: float in [0.0,0.2,0.4,0.6,0.8,1.0]:
			var x := lerpf(-HALF_X-r,HALF_X+r,t)
			var z := lerpf(FRONT-r,back+r,t)
			low = minf(low,minf(float(ground.call(x,FRONT-r)),float(ground.call(x,back+r))))
			low = minf(low,minf(float(ground.call(-HALF_X-r,z)),float(ground.call(HALF_X+r,z))))
		if -k*COURSE-SINK < low: return k
		k += 1
	return MOST

## The stone as a built kit piece. `keep_off`: Callable(x, z) -> bool, no deck
## slab there (the hall's own floor, the towers); `lane`: half width of the
## way in, kept free of what lies in the grass.
static func build(seed_value: int, weathered: float, back: float, steps: int, ground: Callable, keep_off: Callable, lane: float) -> Node3D:
	var b: RuinKit_.Build = Gothic._build(seed_value,weathered,"HallSeat")
	b.terrain = ground
	var worn := FastNoiseLite.new()
	worn.seed = seed_value
	worn.frequency = 0.035
	for k in range(steps+1):
		_ring(b,k,back,ground,worn)
	_deck(b,back,keep_off)
	_fallen(b,back,steps,ground,lane)
	_outworks(b,back,steps,ground,lane)
	return b.finish()

## Stone a share darker the nearer the ground it is: the earth's stain.
static func _stained(b: RuinKit_.Build, y: float, ground_y: float, tone := 1.0) -> Color:
	var c: Color = RuinKit_._stone(b,tone)
	var near := 1.0-smoothstep(0.0,3.2,y-ground_y)
	return c*lerpf(1.0,0.62,near)

## Course `k`: a ring of blocks round the podium grown k steps, over a core.
static func _ring(b: RuinKit_.Build, k: int, back: float, ground: Callable, worn: FastNoiseLite) -> void:
	var r := k*STEP
	var hx := HALF_X+r
	var z0 := FRONT-r
	var z1 := back+r
	var y1 := -k*COURSE
	var y0 := y1-COURSE-0.3
	# The core under the facing, dark, seen where blocks are gone.
	var in_x := hx-DEEP+0.5
	var in_z := (z1-z0)*0.5-DEEP+0.5
	var core := Vector3(in_x,(y1-y0)*0.5-(0.1 if k == 0 else 0.0),in_z)
	b.solid(RuinKit_._box(b,core,0.0),Transform3D(Basis.IDENTITY,Vector3(0.0,(y0+y1-(0.2 if k == 0 else 0.0))*0.5,(z0+z1)*0.5)),RuinKit_._stone(b,0.5),false,false,[],-1,1.0,false)
	var sides := [
		[Vector3(-hx,0.0,z0),Vector3(1.0,0.0,0.0),2.0*hx],
		[Vector3(hx,0.0,z0),Vector3(0.0,0.0,1.0),z1-z0],
		[Vector3(hx,0.0,z1),Vector3(-1.0,0.0,0.0),2.0*hx],
		[Vector3(-hx,0.0,z1),Vector3(0.0,0.0,-1.0),z1-z0],
	]
	var along := 0.0
	for side: Array in sides:
		var from: Vector3 = side[0]
		var way: Vector3 = side[1]
		var length: float = side[2]
		var inward := Vector3.UP.cross(way).normalized()
		var s := -b.rng.randf_range(0.0,1.8)*float(k%2)
		while s < length-0.05:
			var sa := maxf(s,0.0)
			var sb := minf(s+b.rng.randf_range(2.4,5.4),length)
			if length-sb < 1.2: sb = length
			s = sb
			var mid := (sa+sb)*0.5
			var at := from+way*mid+inward*DEEP*0.5
			var gy := float(ground.call(at.x,at.z))
			var gy2 := minf(float(ground.call((from+way*sa).x,(from+way*sa).z)),float(ground.call((from+way*sb).x,(from+way*sb).z)))
			var buried := y1 < minf(gy,gy2)-0.25
			if buried: continue
			# The edges go first: more of the upper courses, the corners most.
			var corner := 1.0-smoothstep(0.0,11.0,minf(mid,length-mid))
			var gone := worn.get_noise_2d((along+mid)*1.0,k*9.0)+corner*0.3+b.rng.randf_range(-0.12,0.12)
			# (The lowest courses that show stay: the ground holds them.)
			if y1-gy > 0.6 and gone > 0.24: continue
			var drop := 0.0
			if gone > 0.14: drop = b.rng.randf_range(0.2,0.55)
			var half := Vector3((sb-sa)*0.5-0.02,(y1-y0)*0.5,DEEP*0.5)
			var pose := Transform3D(Basis(way,Vector3.UP,way.cross(Vector3.UP)),at+Vector3(0.0,(y0+y1)*0.5-drop,0.0))
			var out := inward*b.rng.randf_range(-0.1,0.16)
			pose.origin -= out
			b.solid(RuinKit_._box(b,half),pose*RuinKit_._settle(b,Vector3.ZERO,0.7),_stained(b,y1,gy,b.rng.randf_range(0.86,1.05)),false,true,[],-1,1.6,false)
		along += length

## The podium's paving: big slabs, a few gone or tipped.
static func _deck(b: RuinKit_.Build, back: float, keep_off: Callable) -> void:
	var size := 7.0
	var z := FRONT+DEEP
	while z < back-DEEP-0.5:
		var dz := minf(size*b.rng.randf_range(0.8,1.2),back-DEEP-z)
		var x := -HALF_X+DEEP
		while x < HALF_X-DEEP-0.5:
			var dx := minf(size*b.rng.randf_range(0.8,1.3),HALF_X-DEEP-x)
			var mid := Vector3(x+dx*0.5,-0.18,z+dz*0.5)
			x += dx
			if bool(keep_off.call(mid.x,mid.z)): continue
			if b.rng.randf() < 0.1: continue
			var pose := RuinKit_._settle(b,mid-Vector3(0.0,b.rng.randf_range(0.0,0.14),0.0),1.4)
			b.solid(RuinKit_._box(b,Vector3(dx*0.5-0.05,0.18,dz*0.5-0.05)),pose,RuinKit_._stone(b,0.9),false,true,[],-1,1.2,false)
		z += dz

## A block lying on the ground at (x, z): tipped, part sunk.
static func _lying(b: RuinKit_.Build, x: float, z: float, s: Vector3, ground: Callable) -> void:
	var gy := float(ground.call(x,z))
	var tip := Basis(Vector3.UP,b.rng.randf()*TAU)*Basis(Vector3.RIGHT,b.rng.randf_range(-0.5,0.5))*Basis(Vector3.BACK,b.rng.randf_range(-0.4,0.4))
	var pose := Transform3D(tip,Vector3(x,gy+s.y*b.rng.randf_range(0.1,0.65),z))
	b.solid(RuinKit_._box(b,s),pose,_stained(b,gy+0.5,gy,0.92),false,true,[],-1,2.2,false)

## What has come down: blocks in the grass round the stone, thick at the
## corners and under the towers, none on the way in.
static func _fallen(b: RuinKit_.Build, back: float, steps: int, ground: Callable, lane: float) -> void:
	var reach := steps*STEP
	for i in FALLEN:
		var corner: float = [-1.0,1.0][i%2]
		var on_front := b.rng.randf() < 0.6
		var out := pow(b.rng.randf(),1.6)*30.0+reach+1.0
		var run := pow(b.rng.randf(),1.5)*46.0
		var x := 0.0
		var z := 0.0
		if on_front:
			x = corner*(HALF_X+reach-run)
			z = FRONT-out
		else:
			x = corner*(HALF_X+out)
			z = FRONT-reach+run*2.0
		if absf(x) < lane+5.0 and z < 0.0: x = corner*(lane+5.0+b.rng.randf_range(0.0,12.0))
		var big := b.rng.randf_range(0.9,2.1)
		_lying(b,x,z,Vector3(b.rng.randf_range(1.0,1.9),b.rng.randf_range(0.55,0.9),b.rng.randf_range(0.8,1.3))*big,ground)
		# Its chips about it.
		for c in 2:
			_lying(b,x+b.rng.randf_range(-5.0,5.0),z+b.rng.randf_range(-5.0,5.0),Vector3(0.6,0.4,0.5)*b.rng.randf_range(0.5,1.3),ground)

## Stubs of walling in the grass, a course or two showing, that fade out.
static func _outworks(b: RuinKit_.Build, back: float, steps: int, ground: Callable, lane: float) -> void:
	var reach := steps*STEP
	for i in OUTWORKS:
		var a := TAU*(float(i)+b.rng.randf_range(0.1,0.9))/OUTWORKS
		var at := Vector2(cos(a)*(HALF_X+reach+b.rng.randf_range(14.0,46.0)),(FRONT+back)*0.5+sin(a)*((back-FRONT)*0.5+reach+b.rng.randf_range(14.0,40.0)))
		if absf(at.x) < lane+24.0 and at.y < 0.0: at.x = signf(at.x+0.1)*(lane+24.0)
		var turn := roundf(a/(PI*0.5))*PI*0.5+PI*0.5
		var way := Vector2(cos(turn),sin(turn))
		var count := b.rng.randi_range(5,10)
		for j in count:
			var p := at+way*(j*3.3-count*1.6)
			var gy := float(ground.call(p.x,p.y))
			var high := 1.5*(1.0-absf(float(j)/(count-1.0)*2.0-1.0))+0.3+b.rng.randf_range(0.0,0.5)
			var half := Vector3(1.6,high*0.5+0.5,1.2)
			var pose := Transform3D(Basis(Vector3.UP,-turn),Vector3(p.x,gy+high-half.y,p.y))
			b.solid(RuinKit_._box(b,half),pose*RuinKit_._settle(b,Vector3.ZERO,1.2),_stained(b,gy+0.4,gy,0.95),false,true,[],-1,1.8,false)

## The far end of the mouth, a quad `size` looking out: a hall running on
## behind it, arches in bays of `bay` m, `room` m clear half width, springing at
## `spring`, the crown at `crown`, lit by torches.
static func deep_material(size: Vector2, bay: float, room: float, spring: float, crown: float, torch_y: float) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = _deep_shader()
	m.set_shader_parameter("half_h",size.y*0.5)
	m.set_shader_parameter("bay",bay)
	m.set_shader_parameter("room",room)
	m.set_shader_parameter("spring",spring)
	m.set_shader_parameter("crown",crown)
	m.set_shader_parameter("torch_y",torch_y)
	return m

static var _deep: Shader

static func _deep_shader() -> Shader:
	if _deep != null: return _deep
	_deep = Shader.new()
	_deep.code = """shader_type spatial;
render_mode unshaded, fog_disabled, shadows_disabled;
uniform float half_h = 10.0;
uniform float bay = 10.0;
uniform float room = 10.0;
uniform float spring = 10.0;
uniform float crown = 16.0;
uniform float torch_y = 6.0;
varying vec3 at;
varying vec3 eye;
const vec3 WARM = vec3(1.0, 0.56, 0.24);
const float FADE = 70.0;
void vertex() {
	at = VERTEX;
	eye = (inverse(MODEL_MATRIX) * vec4(CAMERA_POSITION_WORLD, 1.0)).xyz;
}
float open_at(float x, float y) {
	if (y < spring) return room;
	float t = clamp((y - spring) / (crown - spring), 0.0, 1.0);
	return room * (1.0 - t * sqrt(t));
}
void fragment() {
	vec3 d = normalize(at - eye);
	vec3 o = at;
	vec3 sum = vec3(0.0);
	float floor_z = 1e6;
	float y0 = o.y + half_h;
	if (d.y < -0.0005) floor_z = y0 / -d.y * -d.z;
	bool done = false;
	for (int k = 1; k < 10 && !done; k++) {
		float z = float(k) * bay;
		float t = z / -d.z;
		vec3 p = o + d * t;
		float y = p.y + half_h;
		float fade = exp(-z / FADE);
		float side = mod(float(k), 2.0) < 1.0 ? 1.0 : -1.0;
		if (floor_z < z) {
			// The floor, its flagstones, a sheen of the torches down it.
			vec3 f = o + d * (floor_z / -d.z);
			float lines = smoothstep(0.0, 0.25, abs(fract(f.x / 3.1) - 0.5)) * smoothstep(0.0, 0.25, abs(fract(floor_z / 3.7) - 0.5));
			sum += WARM * exp(-floor_z / FADE) * (0.05 + 0.13 * lines);
			done = true;
			break;
		}
		float w = open_at(p.x, y);
		if (abs(p.x) > w || y > crown) {
			// A pier's face or an arch's soffit, brightest by the opening.
			float edge = clamp(1.0 - (abs(p.x) - w) / (room * 0.5), 0.0, 1.0);
			float course = 0.82 + 0.18 * step(0.08, fract(y / 1.4));
			float lit = 0.12 + 0.55 * edge * edge * (p.x * side > 0.0 ? 1.0 : 0.45);
			sum += WARM * fade * lit * course * smoothstep(crown * 1.3, 2.0, y);
			done = true;
			break;
		}
		// The torch on this bay's pier, seen through.
		vec2 q = vec2(p.x - side * room * 0.9, y - torch_y) / vec2(0.8, 1.1);
		float dot_ = exp(-dot(q, q) * 1.6);
		q *= 0.22;
		sum += WARM * (dot_ * 2.4 * sqrt(fade) + exp(-dot(q, q)) * 0.1 * fade);
	}
	ALBEDO = sum * 1.3;
}
"""
	return _deep
