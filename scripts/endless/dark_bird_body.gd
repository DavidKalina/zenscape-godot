extends RefCounted
## The grass flocks' dark bird: one thin mesh, 94 triangles, the outline
## being all there is. Span 1, facing -z, wings along x: a small spindle of a
## body, a short wedge of a tail, and long swept wings that come to a point,
## each with a camber along its chord so it takes the light as it turns.
## shaders/grass_birds.gdshaderinc flaps it; UV.x is 1 on the wings.

## The body's rings, beak to vent: Vector4(z, half width, half depth, y).
const BODY := [
	Vector4(-0.19,0.021,0.022,0.006),
	Vector4(-0.145,0.031,0.033,0.008),
	Vector4(-0.07,0.05,0.05,0.0),
	Vector4(0.02,0.044,0.044,0.0),
	Vector4(0.1,0.024,0.024,0.004),
]
const BEAK := Vector3(0.0,0.003,-0.25)
const VENT := Vector3(0.0,0.008,0.15)
const SIDES := 6
## The right wing, root to tip: Vector4(x, leading z, trailing z, camber).
const WING := [
	Vector4(0.03,-0.075,0.085,0.016),
	Vector4(0.14,-0.098,0.092,0.018),
	Vector4(0.25,-0.09,0.078,0.014),
	Vector4(0.37,-0.022,0.07,0.008),
]
const WING_TIP := Vector3(0.5,0.0,0.135)
## The tail's half, root to the two tips (x, z), flat under the vent.
const TAIL := [Vector2(0.018,0.09),Vector2(0.05,0.235),Vector2(0.018,0.215)]

static func mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_body(st)
	_tail(st)
	for side: float in [-1.0,1.0]: _wing(st,side)
	st.generate_normals()
	return st.commit()

static func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, wing: float, group: int) -> void:
	for p: Vector3 in [a,b,c]:
		st.set_uv(Vector2(wing,0.0))
		st.set_smooth_group(group)
		st.add_vertex(p)

static func _ring(k: Vector4, i: int) -> Vector3:
	var a := TAU*i/SIDES
	return Vector3(cos(a)*k.y,sin(a)*k.z+k.w,k.x)

static func _body(st: SurfaceTool) -> void:
	for r in BODY.size()-1:
		for i in SIDES:
			var a := _ring(BODY[r],i)
			var b := _ring(BODY[r],i+1)
			var c := _ring(BODY[r+1],i)
			var d := _ring(BODY[r+1],i+1)
			_tri(st,a,c,b,0.0,0)
			_tri(st,b,c,d,0.0,0)
	for i in SIDES:
		_tri(st,_ring(BODY[0],i),_ring(BODY[0],i+1),BEAK,0.0,0)
		_tri(st,_ring(BODY[-1],i+1),_ring(BODY[-1],i),VENT,0.0,0)

## Its own smooth group: the tail keeps a hard edge against the body.
static func _tail(st: SurfaceTool) -> void:
	var y := 0.012
	for side: float in [-1.0,1.0]:
		var root := Vector3(0.0,y,TAIL[0].y)
		var a := Vector3(TAIL[0].x*side,y,TAIL[0].y)
		var b := Vector3(TAIL[1].x*side,y,TAIL[1].y)
		var c := Vector3(TAIL[2].x*side,y,TAIL[2].y)
		var mid := Vector3(0.0,y,TAIL[2].y-0.012)
		_tri(st,root,a,b,0.0,1)
		_tri(st,root,b,c,0.0,1)
		_tri(st,root,c,mid,0.0,1)

## Three lines along the wing: leading edge, a raised hump a third back,
## trailing edge. Its own smooth group a side.
static func _wing(st: SurfaceTool, side: float) -> void:
	var group := 2 if side < 0.0 else 3
	for s in WING.size()-1:
		var a := _chord(WING[s],side)
		var b := _chord(WING[s+1],side)
		for k in 2:
			_tri(st,a[k],a[k+1],b[k],1.0,group)
			_tri(st,a[k+1],b[k+1],b[k],1.0,group)
	var last := _chord(WING[-1],side)
	var tip := Vector3(WING_TIP.x*side,WING_TIP.y,WING_TIP.z)
	for k in 2: _tri(st,last[k],last[k+1],tip,1.0,group)

static func _chord(k: Vector4, side: float) -> Array:
	var x := k.x*side
	return [Vector3(x,0.0,k.y),Vector3(x,k.w,lerpf(k.y,k.z,0.35)),Vector3(x,-k.w*0.3,k.z)]
