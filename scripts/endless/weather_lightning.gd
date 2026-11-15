extends Node3D
## A storm's lightning (docs/design/endless-flight/spec-weather.md, lane
## lightning): mostly a flicker inside far cloud, now and then a thin far bolt
## to the ground, thunder late by the distance. Restrained: flashes many
## seconds apart, never nearer than FLOOR m, nothing struck, no white-out.
## Made by studies/endless_flight.gd with the Weather (none with
## --weather=off); stepped each frame after the look (it reads the hour).
##
## When: only while Weather.severity() is past ON (a storm; a shower's is
## SHOWER_SEVERITY 0.5, so never), the gaps drawn at random round EVERY
## (shorter the deeper the storm), so the rhythm is irregular. Where: FLOOR
## to REACH m from the eye, over the heaviest rain cells (Weather.cell_at),
## leaning to the camera's side of the sky. A flash is two to four quick
## pulses (PULSES, PULSE_GAP); BOLT_SHARE of them a bolt (BOLT_MIN m or more
## off) drawn as ribbons (shaders/weather_bolt.gdshader, the old storm
## front's channel and branches).
##
## What it writes each frame:
##   zs_lightning   (x, z, seconds since the flash began, its light now: the
##                  pulses times the flash's strength; 0 between flashes).
##                  The endless clouds' composite lights the cloud round it
##                  (shaders/weather_lightning.gdshaderinc).
##   zs_storm_flash (x, y, z, w): the dome brightens toward it, faintly all
##                  round (reference_globals.gdshaderinc zs_storm_flash_sky).
##   a DirectionalLight3D "Flash" from the flash over the land: soft by day,
##                  more of the land's light at night, never a white-out.
## Thunder (assets/audio/thunder-1..3.mp3, FlightSound "thunder") comes
## distance / SOUND_SPEED late: quieter, lower and rolling longer the farther.
##
## Its RNG is its own (the flight's seed); the plane reads nothing from it.
##
## Flags (stills and checks):
##   --lightning-at=F       one flash F frames in (the natural ones go on)
##   --lightning-kind=cloud|bolt   (cloud)
##   --lightning-range=M    (3000)  --lightning-bearing=DEG off the view (0)
##   --lightning-hold=S     the forced flash frozen S s into it
##   --lightning-log        a line per flash

const LaunchArgs = preload("res://scripts/launch_args.gd")
const Field = preload("res://scripts/endless/land_field.gd")

const SOUND_SPEED := 343.0
## Severity past which flashes come (0..1), and full rate at 1.
const ON := 0.7
## The mean gap between flashes (s) at full storm and at ON; each GAP_MIN
## plus an exponential, so the rhythm never beats.
const EVERY := Vector2(18.0,40.0)
const GAP_MIN := 5.0
## Where (m from the eye): the nearest any flash comes, the farthest; a bolt
## at least BOLT_MIN. Placed where Weather.cell_at is at least CELL_MIN if
## any of TRIES spots is; VIEW_SHARE of them within VIEW_HALF (rad) of the
## camera's way.
const FLOOR := 1500.0
const REACH := 9000.0
const BOLT_MIN := 2000.0
const BOLT_SHARE := 0.22
const CELL_MIN := 0.5
const TRIES := 24
const VIEW_SHARE := 0.6
const VIEW_HALF := 1.2
## The cloud (world y): an in-cloud flash between CLOUD_Y.x and .y; a bolt's
## root at least BASE_OVER over its foot and CLOUD_Y.x.
const CLOUD_Y := Vector2(550.0,1000.0)
const BASE_OVER := 480.0
## The pulses: how many, the gap before each next (s), each one's share of
## the first and its fall-off (per s); the flash's strength.
const PULSES := Vector2i(2,4)
const PULSE_GAP := Vector2(0.06,0.24)
const PULSE_AMP := Vector2(0.4,0.95)
const PULSE_DECAY := 14.0
const STRENGTH := Vector2(0.55,1.0)
const LAST := 0.6
## The sky's lift: SKY x the light, x (SKY_NEAR / distance) within SKY_RANGE.
const SKY := 0.22
const SKY_NEAR := 2500.0
const SKY_RANGE := Vector2(0.3,1.0)
## The land's light (DirectionalLight energy at the light 1) by day and at
## night, x (LAND_NEAR / distance) within LAND_RANGE; a cloud flash's share.
const LAND := Vector2(0.08,0.35)
const LAND_NEAR := 3000.0
const LAND_RANGE := Vector2(0.35,1.0)
const LAND_CLOUD := 0.5
## The bolt's channel: half widths (m) of the main stroke, branches, twigs;
## their brightness; how far it wanders (share of its span); how many branches.
const WIDTH := Vector3(0.7,0.35,0.18)
const BRIGHT := Vector3(1.0,0.45,0.25)
const WANDER := 0.2
const BRANCHES := Vector2i(3,7)
## Thunder: the loudest (a flash at FLOOR), how it falls with the distance
## (x (FLOOR/d)^THUNDER_FALL), the least; a cloud flash's share; the pitch near
## and far; far off a second take rolls on ROLL s later at ROLL_GAIN of it.
const THUNDER := 0.55
const THUNDER_FALL := 0.8
const THUNDER_LEAST := 0.05
const THUNDER_CLOUD := 0.7
const PITCH := Vector2(0.9,0.68)
const ROLL := Vector2(0.5,1.6)
const ROLL_GAIN := 0.55
const ROLL_FROM := 3000.0

var study: Node3D
var weather: RefCounted
## Every flash: [clock, kind, distance, thunder delay, severity, state name].
var log_lines: Array = []
var flashes := 0
var bolts := 0
## The light now (the brightest flash's), for a driver.
var light := 0.0

var _rng := RandomNumberGenerator.new()
var _t := 0.0
var _frames := 0
var _wait := 0.0
var _flashes: Array[Dictionary] = []
var _thunders: Array = []
var _light: DirectionalLight3D
var _shader := preload("res://shaders/weather_bolt.gdshader")
var _latest := Vector4(0.0,0.0,1e6,0.0)
var _at := -1
var _kind := "cloud"
var _range := 3000.0
var _bearing := 0.0
var _hold := -1.0
var _say := false

func setup(scene: Node3D, w: RefCounted) -> void:
	name = "WeatherLightning"
	study = scene
	weather = w
	_rng.seed = hash([int(scene.get("seed")),"weather-lightning"])
	for arg in LaunchArgs.user_args():
		if arg.begins_with("--lightning-at="): _at = int(arg.get_slice("=",1))
		elif arg.begins_with("--lightning-kind="): _kind = arg.get_slice("=",1)
		elif arg.begins_with("--lightning-range="): _range = float(arg.get_slice("=",1))
		elif arg.begins_with("--lightning-bearing="): _bearing = deg_to_rad(float(arg.get_slice("=",1)))
		elif arg.begins_with("--lightning-hold="): _hold = float(arg.get_slice("=",1))
		elif arg == "--lightning-log": _say = true
	_light = DirectionalLight3D.new()
	_light.name = "Flash"
	_light.light_color = Color(0.86,0.9,1.0)
	_light.shadow_enabled = false
	_light.sky_mode = DirectionalLight3D.SKY_MODE_LIGHT_ONLY
	_light.visible = false
	add_child(_light)
	_wait = _gap()

func _exit_tree() -> void:
	RenderingServer.global_shader_parameter_set("zs_storm_flash",Vector4.ZERO)
	RenderingServer.global_shader_parameter_set("zs_lightning",Vector4(0.0,0.0,1e6,0.0))

## The next gap (s) at the storm now.
func _gap() -> float:
	var deep := clampf((float(weather.severity())-ON)/(1.0-ON),0.0,1.0)
	var mean := lerpf(EVERY.y,EVERY.x,deep)
	# GAP_MIN plus an exponential: no run of equal gaps (a clamp made a 4 s beat).
	return GAP_MIN-log(1.0-_rng.randf()*0.97)*(mean-GAP_MIN)

# --- Each frame -----------------------------------------------------------------------------

func step(delta: float, held := false) -> void:
	var camera: Camera3D = study.camera
	if camera == null: return
	var dt := 0.0 if held else delta
	_t += dt
	_frames += 1
	var eye := camera.global_position
	if _at >= 0 and _frames == _at: _flash(_kind,eye,camera,true)
	if not held and float(weather.severity()) > ON:
		_wait -= dt
		if _wait <= 0.0:
			_flash("bolt" if _rng.randf() < BOLT_SHARE else "cloud",eye,camera,false)
			_wait = _gap()
	for i in range(_thunders.size()-1,-1,-1):
		if float(_thunders[i][0]) <= _t:
			_thunder(_thunders[i])
			_thunders.remove_at(i)
	_update(dt,camera)

# --- Where ------------------------------------------------------------------------------

## The camera's way, flat.
func _view(camera: Camera3D) -> Vector2:
	var f := -camera.global_basis.z
	var v := Vector2(f.x,f.z)
	return v.normalized() if v.length() > 0.05 else Vector2(0.0,-1.0)

## A spot `least` to REACH m off over the heaviest rain of TRIES tried.
func _spot(e: Vector2, view: Vector2, least: float) -> Vector2:
	var best := Vector2.INF
	var best_cell := -1.0
	for k in range(TRIES):
		var way := view.rotated(_rng.randf_range(-VIEW_HALF,VIEW_HALF)) if _rng.randf() < VIEW_SHARE else Vector2.from_angle(_rng.randf()*TAU)
		var p := e+way*lerpf(least,REACH,sqrt(_rng.randf()))
		var cell := float(weather.cell_at(p))
		if cell > best_cell:
			best_cell = cell
			best = p
		if cell >= CELL_MIN and k >= 2: return p
	return best

## The ground (or the sea's top) at xz `p`.
func _ground(p: Vector2) -> float:
	var field: RefCounted = study.field
	return maxf(float(field.height(p.x,p.y)),Field.SEA_Y) if field != null else 0.0

# --- A flash ----------------------------------------------------------------------------

func _flash(kind: String, eye: Vector3, camera: Camera3D, forced: bool) -> void:
	var e := Vector2(eye.x,eye.z)
	var view := _view(camera)
	var p: Vector2
	if forced: p = e+view.rotated(_bearing)*maxf(_range,FLOOR if kind == "cloud" else BOLT_MIN)
	else: p = _spot(e,view,BOLT_MIN if kind == "bolt" else FLOOR)
	var ground := _ground(p)
	var at: Vector3
	var mesh: MeshInstance3D = null
	if kind == "bolt":
		var top := maxf(CLOUD_Y.x,ground+BASE_OVER)+_rng.randf_range(0.0,150.0)
		var lean := Vector2(_rng.randf_range(-1.0,1.0),_rng.randf_range(-1.0,1.0))*(top-ground)*0.2
		var root := Vector3(p.x+lean.x,top,p.y+lean.y)
		mesh = _bolt_mesh(_tree(root,Vector3(p.x,ground,p.y)))
		at = root.lerp(Vector3(p.x,ground,p.y),0.15)
		bolts += 1
	else:
		at = Vector3(p.x,maxf(_rng.randf_range(CLOUD_Y.x,CLOUD_Y.y),ground+250.0),p.y)
	var pulses: Array = [[0.0,1.0]]
	var t := 0.0
	for k in range(_rng.randi_range(PULSES.x,PULSES.y)-1):
		t += _rng.randf_range(PULSE_GAP.x,PULSE_GAP.y)
		pulses.append([t,_rng.randf_range(PULSE_AMP.x,PULSE_AMP.y)])
	var d := Vector2(at.x,at.z).distance_to(e)
	var f := {"kind":kind,"at":at,"t":0.0,"pulses":pulses,"end":t+LAST,"distance":d,
		"strength":_rng.randf_range(STRENGTH.x,STRENGTH.y) if not forced else STRENGTH.y,"hold":forced and _hold >= 0.0}
	if mesh != null:
		f.mesh = mesh
		f.material = mesh.material_override
	_flashes.append(f)
	flashes += 1
	var delay := eye.distance_to(at)/SOUND_SPEED
	_thunders.append([_t+delay,eye.distance_to(at),f.strength*(1.0 if kind == "bolt" else THUNDER_CLOUD)])
	var state: String = Weather.NAMES[int(weather.state)]
	log_lines.append([_t,kind,d,delay,float(weather.severity()),state])
	if _say: print("lightning: %s %.0f m off, thunder in %.1f s (t %.1f s, %s, severity %.2f)" % [kind,d,delay,_t,state,float(weather.severity())])

## The flashes' light this frame; the bolts lit, the light and globals set.
func _update(dt: float, camera: Camera3D) -> void:
	var size := get_viewport().get_visible_rect().size
	var pixel := 2.0*tan(deg_to_rad(camera.fov)*0.5)/maxf(size.y,1.0)
	var eye := camera.global_position
	var veil := float(weather.rain_here())
	light = 0.0
	var sky := 0.0
	var sky_at := Vector3.ZERO
	var land := 0.0
	var land_from := Vector3.ZERO
	var day: float = study.look.celestial.daylight if study.look != null else 1.0
	for i in range(_flashes.size()-1,-1,-1):
		var f: Dictionary = _flashes[i]
		if f.hold: f.t = _hold
		else: f.t += dt
		var t: float = f.t
		var main := 0.0
		var first := 0.0
		for k in range((f.pulses as Array).size()):
			var since := t-float(f.pulses[k][0])
			if since < 0.0: continue
			# A pulse rises in a few hundredths of a second, then falls.
			var v := float(f.pulses[k][1])*smoothstep(0.0,0.025,since)*exp(-maxf(since-0.025,0.0)*PULSE_DECAY)
			main = maxf(main,v)
			if k == 0: first = v
		var lit := main*float(f.strength)
		var d: float = f.distance
		if f.has("material"):
			var m: ShaderMaterial = f.material
			m.set_shader_parameter("flash",main)
			m.set_shader_parameter("branch_flash",first)
			m.set_shader_parameter("pixel",pixel)
			m.set_shader_parameter("veil",clampf(maxf(veil,float(weather.rain_at(Vector2((f.at as Vector3).x,(f.at as Vector3).z)))),0.0,1.0))
			(f.mesh as Node3D).visible = main > 0.004
		if lit > light:
			light = lit
			var at: Vector3 = f.at
			_latest = Vector4(at.x,at.z,t,lit)
		var s := lit*clampf(SKY_NEAR/maxf(d,1.0),SKY_RANGE.x,SKY_RANGE.y)
		if s > sky:
			sky = s
			sky_at = f.at
		var l := lit*clampf(LAND_NEAR/maxf(d,1.0),LAND_RANGE.x,LAND_RANGE.y)*(1.0 if f.kind == "bolt" else LAND_CLOUD)
		if l > land:
			land = l
			land_from = f.at
		if not f.hold and t > float(f.end):
			if f.has("mesh"): (f.mesh as Node).queue_free()
			_flashes.remove_at(i)
	if light <= 0.0:
		_latest.z += dt
		_latest.w = 0.0
	_light.visible = land > 0.005
	if _light.visible:
		_light.light_energy = land*lerpf(LAND.y,LAND.x,day)
		var way := (eye-land_from).normalized()
		way = (way+Vector3.DOWN*0.6).normalized()
		_light.global_transform = Transform3D(Basis.looking_at(way,Vector3.RIGHT if absf(way.y) > 0.95 else Vector3.UP),Vector3.ZERO)
	RenderingServer.global_shader_parameter_set("zs_storm_flash",Vector4(sky_at.x,sky_at.y,sky_at.z,sky*SKY))
	RenderingServer.global_shader_parameter_set("zs_lightning",_latest)

# --- Thunder ----------------------------------------------------------------------------

## [when, distance, loudness] (or a roll: [when, -1, gain, pitch]): quieter,
## lower and longer the farther.
func _thunder(th: Array) -> void:
	var sound: Node = study.get("sound")
	if sound == null: return
	if th.size() > 3:
		sound.shot("thunder",float(th[2]),float(th[3]))
		return
	var d := float(th[1])
	var far := clampf((d-FLOOR)/(REACH-FLOOR),0.0,1.0)
	var gain := maxf(THUNDER*pow(FLOOR/maxf(d,FLOOR),THUNDER_FALL),THUNDER_LEAST)*float(th[2])
	var pitch := lerpf(PITCH.x,PITCH.y,far)
	sound.shot("thunder",gain,pitch)
	if d > ROLL_FROM: _thunders.append([_t+_rng.randf_range(ROLL.x,ROLL.y),-1.0,gain*ROLL_GAIN,pitch*0.92])

# --- The bolt's channel (from the storm front's storm_lightning.gd) ---------------------

## The channels from `a` (its root) to `b` (its foot): the main one and its
## branches, each {points, width, bright, main}.
func _tree(a: Vector3, b: Vector3) -> Array:
	var length := a.distance_to(b)
	var main := _channel(a,b,WANDER,7)
	var lines: Array = [{"points":main,"width":WIDTH.x,"bright":BRIGHT.x,"main":true}]
	for k in range(_rng.randi_range(BRANCHES.x,BRANCHES.y)):
		# More near the root, where the leader forked most.
		var u := pow(_rng.randf(),1.5)*0.8
		var i := clampi(int(u*(main.size()-1)),1,main.size()-2)
		var from: Vector3 = main[i]
		var along := (main[mini(i+4,main.size()-1)]-main[maxi(i-4,0)]).normalized()
		var off := _rng.randf_range(0.35,0.9)*(1.0 if _rng.randf() < 0.5 else -1.0)
		var sideways := along.cross(Vector3.UP if absf(along.y) < 0.9 else Vector3.RIGHT).normalized().rotated(along,_rng.randf_range(0.0,TAU))
		var dir := (along+sideways*off*1.4).normalized()
		var reach := length*(1.0-u)*_rng.randf_range(0.12,0.35)
		var end := from+dir*reach
		end.y = maxf(end.y,b.y+20.0)
		var branch := _channel(from,end,WANDER*1.3,5)
		lines.append({"points":branch,"width":WIDTH.y,"bright":BRIGHT.y*_rng.randf_range(0.6,1.2),"main":false})
		if _rng.randf() < 0.5:
			var j := _rng.randi_range(2,branch.size()-3)
			var twig_from: Vector3 = branch[j]
			var twig_dir := (dir+Vector3(_rng.randf_range(-0.6,0.6),_rng.randf_range(-0.5,0.1),_rng.randf_range(-0.6,0.6))).normalized()
			lines.append({"points":_channel(twig_from,twig_from+twig_dir*reach*_rng.randf_range(0.2,0.45),WANDER*1.4,4),"width":WIDTH.z,"bright":BRIGHT.z,"main":false})
	return lines

## A jagged channel from `a` to `b`: the line halved `levels` times, each new
## middle thrown aside by `wander` of its span (a little less each level).
func _channel(a: Vector3, b: Vector3, wander: float, levels: int) -> PackedVector3Array:
	var points := PackedVector3Array([a,b])
	var amount := wander
	for level in range(levels):
		var out := PackedVector3Array([points[0]])
		for i in range(points.size()-1):
			var p := points[i]
			var q := points[i+1]
			var span := p.distance_to(q)
			var d := (q-p)/maxf(span,0.001)
			var n1 := d.cross(Vector3.UP if absf(d.y) < 0.95 else Vector3.RIGHT).normalized()
			var n2 := d.cross(n1)
			out.append((p+q)*0.5+(n1*_rng.randf_range(-1.0,1.0)+n2*_rng.randf_range(-1.0,1.0))*span*amount+d*span*_rng.randf_range(-0.12,0.12))
			out.append(q)
		points = out
		amount *= 0.88
	return points

## The ribbons as a mesh in the world (shaders/weather_bolt.gdshader's layout).
func _bolt_mesh(lines: Array) -> MeshInstance3D:
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var uv2s := PackedVector2Array()
	var colours := PackedColorArray()
	var index := PackedInt32Array()
	for line: Dictionary in lines:
		var points: PackedVector3Array = line.points
		var n := points.size()
		var base := verts.size()
		var main: bool = line.main
		var bead := _rng.randf()*100.0
		for i in range(n):
			var tangent := (points[mini(i+1,n-1)]-points[maxi(i-1,0)]).normalized()
			var u := float(i)/float(n-1)
			var w: float = float(line.width)*(lerpf(1.0,0.75,u) if main else lerpf(1.0,0.35,u))
			# Its brightness beads along it (a channel is never even).
			var beads := 1.0+0.35*sin(bead+float(i)*0.9)*sin(bead*0.37+float(i)*0.23)
			for side in [-1.0,1.0]:
				verts.append(points[i])
				normals.append(tangent)
				uvs.append(Vector2(side,u))
				uv2s.append(Vector2(w,float(line.bright)*beads))
				colours.append(Color(1.0 if main else 0.0,0.0,0.0,1.0))
		for i in range(n-1):
			var k := base+i*2
			index.append_array(PackedInt32Array([k,k+1,k+2,k+1,k+3,k+2]))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_TEX_UV2] = uv2s
	arrays[Mesh.ARRAY_COLOR] = colours
	arrays[Mesh.ARRAY_INDEX] = index
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	var mi := MeshInstance3D.new()
	mi.name = "Bolt"
	mi.top_level = true
	mi.mesh = mesh
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.extra_cull_margin = 600.0
	var m := ShaderMaterial.new()
	m.shader = _shader
	m.render_priority = 5
	mi.material_override = m
	mi.visible = false
	add_child(mi)
	mi.global_transform = Transform3D.IDENTITY
	return mi

## A line for --weather-debug.
func note() -> String:
	return "lightning %d flashes (%d bolts)  ·  light %.2f  ·  next %.0f s" % [flashes,bolts,light,_wait]
