extends "res://scripts/rune_serpent.gd"
## The linger serpent's body (docs/design/roguelike/linger-serpent-round1.md):
## the rune serpent (scripts/rune_serpent.gd: its pebbled basalt, its chain
## of rings on the head's traced path, the neck's S, the look springs, the
## breath and tongue) grown by the node's scale into a colossus, with a ruff
## of stone feathers behind its head (Kukulkan's). It flies no route: its
## head is steered by scripts/roguelike/linger.gd, which hands it a place a
## frame (`go_to`, local), and every ring follows the exact way the head has
## gone, so the coils, the body's waves and its rising all come from where
## the head has been. `rewind` takes the head back along its own way (the
## strike's wind-up and its recoil), the rings sliding back with it.
##
## Not solid (it never touches an isle); its sound is the threat's.

## The feathers of the ruff: how many round the head's back and sides,
## their length (local m, the top's, the sides' share), width at the root,
## how far back from the head's back they root, their sweep out from the
## neck, a second shorter row between them.
const FEATHERS := 6
const FEATHER_LONG := 4.4
const FEATHER_SIDE := 0.75
const FEATHER_WIDE := 2.2
const FEATHER_ROOT := 1.4
const FEATHER_FAN := 0.3
const FEATHER_ARC := 2.3
const FEATHER_ROW2 := 0.7
## The feathers' stone: a shade warmer and paler than the body's (worn
## plates), their tips darker.
const FEATHER_TONE := Color("4f4d4a")
const FEATHER_TIP := Color("3c3d40")
## Its runes cut in and barely lit: the rune serpent's pebbled glow times
## this (menace from weight, not light).
const RUNE_DIM := 0.08
## Its pebbles a little finer than the rune serpent's (it is drawn bigger).
const PEBBLE_K := 0.6

## Driven by the threat each frame: the head stretched along its way (the
## snap; under 1 squashed), the jaw open (radians, not sprung: a bite is
## quicker than any spring here), whether it is fixed on you (the eyes lit).
var stretch := 1.0
var jaw := 0.0
var fixed := false
## Its pace this frame (local m/s): the spine runes' run.
var pace := 0.0

var _oldest := 0
var _ruff: MeshInstance3D

func _init() -> void:
	name = "LingerSerpent"

## Built (the rune serpent's body, not solid) and its ruff; laid on the
## aqueduct's way until `lay` puts it where it belongs.
func build(study: Node3D) -> void:
	solid = false
	pebbled = true
	rng_seed = 4411
	setup(study)
	_material.set_shader_parameter("pebble_size",PEBBLE_SIZE*GRAIN*PEBBLE_K)
	_build_ruff()

## Stepped by the threat, not by itself.
func _process(_delta: float) -> void:
	pass

func _physics_process(_delta: float) -> void:
	pass

# --- The way ----------------------------------------------------------------

## The whole body laid along `points` (local, tail first, the head last).
func lay(points: PackedVector3Array) -> void:
	_laid = -1
	_oldest = 0
	travelled = 0.0
	_live_p = points[0]
	_live_b = points[0]
	_live_r = 0.0
	_lay(0)
	for i in range(1,points.size()): go_to(points[i])
	_head_fwd = (points[points.size()-1]-points[points.size()-2]).normalized()
	_pose(0.0)

## The head on to `p` (local), its rings laid behind it; how far it went.
func go_to(p: Vector3, roll := 0.0) -> float:
	var d := p.distance_to(_live_p)
	if d < 1e-5: return 0.0
	var from := travelled
	var from_p := _live_p
	var from_r := _live_r
	travelled += d
	_live_p = p
	_live_b = p
	_live_r = roll
	while float(_laid+1)*STEP <= travelled:
		var k := _laid+1
		var f := (k*STEP-from)/d
		var slot := k%TRAIL
		_tp[slot] = from_p.lerp(p,f)
		_tb[slot] = _tp[slot]
		_tr[slot] = lerpf(from_r,roll,f)
		_laid = k
	_oldest = maxi(_oldest,_laid-TRAIL+1)
	return d

## The head back `dist` m along its own way (at most what the kept way
## allows behind the tail); how far it went.
func rewind(dist: float) -> float:
	var most := travelled-(float(_oldest)*STEP+LENGTH+STEP*6.0)
	dist = clampf(dist,0.0,maxf(most,0.0))
	if dist <= 0.0: return 0.0
	var to := travelled-dist
	var t := trail_at(to)
	travelled = to
	_laid = mini(_laid,floori(to/STEP))
	_live_p = t[0]
	_live_b = t[1]
	_live_r = float(t[2])
	return dist

## How far back the head may go now (local m).
func rewind_room() -> float:
	return maxf(travelled-(float(_oldest)*STEP+LENGTH+STEP*6.0),0.0)

## The head's live place (local), and its way (the path's last metres).
func live() -> Vector3:
	return _live_p

func way() -> Vector3:
	var back: Vector3 = trail_at(travelled-2.0)[0]
	var w := _live_p-back
	return w.normalized() if w.length() > 1e-4 else _head_fwd

# --- Looking ----------------------------------------------------------------

## The look's goals: turn and tilt off its way (radians), the head's lean
## toward the look and lift (local m).
func look(yaw: float, pitch: float, lean := 0.0, lift := 0.0) -> void:
	_sg[S_YAW] = clampf(yaw,-LOOK_MAX.x,LOOK_MAX.x)
	_sg[S_PITCH] = clampf(pitch,-LOOK_MAX.y,LOOK_MAX.y)
	_sg[S_LEAN] = lean
	_sg[S_LIFT] = lift

## The look let go at once (the snap: the head straight down its way).
func look_snap() -> void:
	for i in [S_YAW,S_PITCH,S_LEAN,S_LIFT]:
		_sx[i] = 0.0
		_sv[i] = 0.0
		_sf[i] = 0.0
		_sg[i] = 0.0

## Its head's way as it looks (local, unit) and its forward way.
func look_dir() -> Vector3:
	return _head_dir

func forward() -> Vector3:
	return _head_fwd

# --- A frame ----------------------------------------------------------------

## One frame: its springs, the body posed on the way, the head stretched,
## the light. `snap`: the head's way taken at once (the strike).
func step(delta: float, snap := false) -> void:
	_time += delta
	_sg[S_SPEED] = 0.0
	_sg[S_WEAVE] = 0.0
	_sg[S_VEER] = 0.0
	_sg[S_BANK] = 0.0
	_springs(delta)
	_sx[S_JAW] = jaw
	_sv[S_JAW] = 0.0
	_sx[S_SPEED] = pace
	mode = "watch" if fixed else "roam"
	_scroll += pace*delta*RUNE_RUN
	_pose(0.0 if snap else delta)
	_stretch_head()
	_light(delta)
	_material.set_shader_parameter("energy",float(_material.get_shader_parameter("energy"))*RUNE_DIM)

func _stretch_head() -> void:
	if _skeleton == null or absf(stretch-1.0) < 0.005: return
	var sq := 1.0/sqrt(maxf(stretch,0.1))
	var sc := Basis.from_scale(Vector3(sq,sq,stretch))
	for b in [STATIONS,STATIONS+2]:
		var xf := _skeleton.get_bone_pose(b)
		xf.basis = xf.basis*sc
		_skeleton.set_bone_pose(b,xf)

# --- The ruff ---------------------------------------------------------------

## Kukulkan's ruff: stone feathers fanned back over the neck from the
## head's back and sides, two rows, each a long blade with a raised quill,
## on the head's bone. Weathered as the body is (olmec_stone: vertex tone
## and occlusion, the rest place in UV/UV2 for the grain).
func _build_ruff() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var r := RADIUS*girth*HEAD_GIRTH
	for row in range(2):
		var n := FEATHERS if row == 0 else FEATHERS-1
		for i in range(n):
			var u := (float(i)+(0.0 if row == 0 else 0.5))/float(FEATHERS-1)
			var a := lerpf(-FEATHER_ARC*0.5,FEATHER_ARC*0.5,u)
			# Round the head's back: up over the top, down its sides.
			var out := Vector3(sin(a),cos(a)*0.92+0.05,0.0).normalized()
			var root := out*r*(0.86 if row == 0 else 0.96)+Vector3(0.0,0.0,FEATHER_ROOT-0.25*row)
			var side_share := absf(a)/(FEATHER_ARC*0.5)
			var length := FEATHER_LONG*lerpf(1.0,FEATHER_SIDE,side_share)*(1.0 if row == 0 else FEATHER_ROW2)
			var fan := FEATHER_FAN*(1.0 if row == 0 else 1.25)
			var dir := (Vector3(0.0,0.0,-1.0)*cos(fan)+out*sin(fan)).normalized()
			_feather(st,root,dir,out,length,FEATHER_WIDE*(1.0 if row == 0 else 0.8),i*7+row*31)
	st.generate_normals()
	var mesh := st.commit()
	var mat := ShaderMaterial.new()
	mat.shader = SHADER
	mat.set_shader_parameter("fill",FILL*0.6)
	mat.set_shader_parameter("rim",RIM)
	mat.set_shader_parameter("roughness_value",0.95)
	mat.set_shader_parameter("weather",WEATHER)
	mat.set_shader_parameter("bump_strength",BUMP)
	_ruff = MeshInstance3D.new()
	_ruff.name = "Ruff"
	_ruff.mesh = mesh
	_ruff.material_override = mat
	var at := BoneAttachment3D.new()
	at.name = "RuffBone"
	_skeleton.add_child(at)
	at.bone_name = "head"
	at.add_child(_ruff)

## One feather from `root` along `dir`, its face across `out`: SEGS
## sections, each a flat diamond (edge, quill, edge, under), tapering to a
## blunt tip and curling a little back out.
func _feather(st: SurfaceTool, root: Vector3, dir: Vector3, out: Vector3, length: float, wide: float, salt: int) -> void:
	const SEGS := 6
	var across := dir.cross(out).normalized()
	var face := across.cross(dir).normalized()
	var secs: Array = []
	for s in range(SEGS+1):
		var t := float(s)/SEGS
		var w := wide*(0.6+0.5*sin(PI*minf(t*0.7+0.15,1.0)))*(1.0-0.45*t*t*t)
		var thick := 0.36*(1.0-0.5*t)
		var curl := face*(0.12*length*t*t)
		var c := root+dir*length*t+curl
		var jag := 0.06*sin(float(salt)+t*9.0)
		secs.append([c-across*w*0.5+face*jag,c+face*thick,c+across*w*0.5+face*jag,c-face*thick*0.6,t])
	for s in range(SEGS):
		var a: Array = secs[s]
		var b: Array = secs[s+1]
		for k in range(4):
			var k2 := (k+1)%4
			var occ := 0.75 if k == 3 or k2 == 3 else 1.0
			_fq(st,a[k],a[k2],b[k2],b[k],float(a[4]),float(b[4]),occ)

func _fq(st: SurfaceTool, p0: Vector3, p1: Vector3, p2: Vector3, p3: Vector3, t0: float, t1: float, occ: float) -> void:
	for pair in [[p0,t0],[p1,t0],[p2,t1],[p0,t0],[p2,t1],[p3,t1]]:
		var p: Vector3 = pair[0]
		var tone := FEATHER_TONE.lerp(FEATHER_TIP,smoothstep(0.55,1.0,float(pair[1])))
		st.set_color(Color(tone.r*occ,tone.g*occ,tone.b*occ,occ))
		st.set_uv(Vector2(p.x,p.y))
		st.set_uv2(Vector2(p.z,0.0))
		st.add_vertex(p)
