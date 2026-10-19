extends Node3D
## Lightning seen from the plane (a prototype; scripts/plane_weather.gd makes
## it, studies/sky_weather_field.gd steps it). In a storm (`storm` past
## FROM) it strikes round the eye every EVERY s or so, mostly where the
## camera looks (IN_VIEW of them), mostly far, now and then near:
##   bolt     from the storm's base (BASE m up, which the slate dome stands
##            for) down into the cloud sea, branching as it falls; the sea
##            glows round its foot.
##   across   cloud to cloud along the base, its branches hanging.
##   inside   a flash inside a cloud (a drifting one near the eye, else the
##            cloud sea), lighting it from within; no channel seen.
## Each strike is a run of strokes (STROKES): the first lights the whole
## tree, the restrikes only the main channel, each a sharp pop that dies
## off in STROKE_DECAY; one may hang on (a continuing current). While it
## lights, the dome brightens toward it and all round (zs_storm_flash,
## shaders/reference_globals.gdshaderinc), the cloud volume glows round it
## (its `lightning`: this node's `flash`, `flash_position`, `volume_gain`),
## the storm's grey lifts off the cloud a little, and a near one lights the
## plane and the land (a light from its side). Thunder (the kit's, studies/
## thunder_audio.gd) follows by its distance over SOUND_SPEED.
## `strike()` strikes now (F12 in the sandbox). Flags, for stills:
##   --strike-at=<frames>   one strike that many frames in, and none on its own
##   --strike-kind=bolt|across|inside   --strike-range=<m>
##   --strike-bearing=<deg> off the view's middle (+ right)
##   --strike-hold=<s>      the strike frozen that far into its flash

## The storm (0 to 1) it starts at, and the mean wait between strikes (s)
## there and in a full storm; how often one comes hard on another's heels.
const FROM := 0.4
const EVERY := Vector2(16.0,4.0)
const BURST := 0.3
## The kinds' shares: bolts, cloud to cloud, the rest inside a cloud.
const BOLT_SHARE := 0.55
const ACROSS_SHARE := 0.2
## How far off (m): far, middling, near, and the shares of the first two
## (the rest near).
const FAR := Vector2(900.0,2600.0)
const MID := Vector2(320.0,900.0)
const NEAR := Vector2(110.0,320.0)
const FAR_SHARE := 0.55
const MID_SHARE := 0.33
## The share struck where the camera looks (within VIEW_SPREAD of the
## view's half width either side).
const IN_VIEW := 0.85
const VIEW_SPREAD := 0.9
## The storm's base over the field's turf (m, a range), and the cloud sea's
## heaps' tops (SkyTower.SEA) where a bolt ends.
const BASE := Vector2(170.0,260.0)
const SEA_TOP := -105.0
## The channel: half width (m) of the main stroke, its branches' and their
## branches'; their brightness; how far it wanders (share of its length).
const WIDTH := Vector3(0.55,0.3,0.16)
const BRIGHT := Vector3(1.0,0.5,0.28)
const WANDER := 0.22
const BRANCHES := Vector2i(7,13)
## The strokes: how many (a range), the gap between (s), the restrikes'
## strength, each one's fall-off (per s), and a continuing current's.
const STROKES := Vector2i(2,5)
const STROKE_GAP := Vector2(0.04,0.13)
const RESTRIKE := Vector2(0.45,0.9)
const STROKE_DECAY := 22.0
const HANG_DECAY := 6.0
const HANG_CHANCE := 0.35
## The ribbon's look (shaders/plane_lightning.gdshader).
const HOT := 9.0
const MIN_PX := 1.4
## The sky's pop: how strong at REACH m (falling as REACH over the distance,
## between POP_RANGE), and the cloud's grey lifted by GREY_LIFT of it.
const POP := 0.55
const REACH := 600.0
const POP_RANGE := Vector2(0.18,2.2)
const GREY_LIFT := 0.12
## The cloud volume's glow round a flash (scripts/cloud_volume.gd), a bolt's
## foot this deep into the sea, an inside flash this deep in its cloud.
const VOLUME_GAIN := 480.0
const FOOT_DEEP := 12.0
const INSIDE_DEEP := 18.0
## A near one lights the scene from its side, within LIGHT_REACH m.
const LIGHT := 1.5
const LIGHT_REACH := 700.0
## The thunder: pace (m/s), and the distance its clip treats as near
## (studies/thunder_audio.gd: 6 to 34 "plate" metres, so scaled).
const SOUND_SPEED := 240.0
const THUNDER_SCALE := 0.11

## The flash now (the brightest strike's), where it is, and the cloud
## volume's gain: read by scripts/cloud_volume.gd as the scene's `_lightning`.
var flash := 0.0
var flash_position := Vector3.ZERO
## Where the sky lights from (a bolt's channel; else the flash).
var sky_position := Vector3.ZERO
var volume_gain := VOLUME_GAIN
var strike_count := 0
var storm := 0.0
var _scene: Node3D
var _rng := RandomNumberGenerator.new()
var _wait := 6.0
var _clock := 0.0
## Strikes under way: {mesh, material, t, strokes [[at, k, decay]], at,
## distance, kind}.
var _strikes: Array[Dictionary] = []
var _thunders: Array[Vector3] = []
var _light: DirectionalLight3D
var _shader := preload("res://shaders/plane_lightning.gdshader")
var _pop := 0.0
var _popped := false
## The flags.
var _strike_at := -1
var _kind := ""
var _range := -1.0
var _bearing := NAN
var _hold := -1.0
var _frames := 0

func setup(scene: Node3D) -> void:
	name = "PlaneLightning"
	_scene = scene
	_rng.randomize()
	for arg in preload("res://scripts/launch_args.gd").user_args():
		if arg.begins_with("--strike-at="): _strike_at = int(arg.get_slice("=",1))
		elif arg.begins_with("--strike-kind="): _kind = arg.get_slice("=",1)
		elif arg.begins_with("--strike-range="): _range = float(arg.get_slice("=",1))
		elif arg.begins_with("--strike-bearing="): _bearing = deg_to_rad(float(arg.get_slice("=",1)))
		elif arg.begins_with("--strike-hold="): _hold = float(arg.get_slice("=",1))
		elif arg.begins_with("--strike-seed="): _rng.seed = int(arg.get_slice("=",1))
	_light = DirectionalLight3D.new()
	_light.name = "LightningLight"
	_light.light_color = Color(0.78,0.85,1.0)
	_light.shadow_enabled = false
	_light.light_energy = 0.0
	_light.visible = false
	_light.sky_mode = DirectionalLight3D.SKY_MODE_LIGHT_ONLY
	add_child(_light)
	# The kit's own lightning (studies/lightning.gd, through scripts/
	# kit_isle/kit_weather.gd) strikes nowhere here; this one stands in for
	# it, for the cloud volume too.
	var weather: Node = scene.get("weather")
	if weather != null and weather.get("lightning") != null:
		weather.lightning.aim = func(_eye: Vector3) -> void: pass
	scene.set("_lightning",self)
	_wait = _rng.randf_range(2.0,6.0)

func _eye() -> Camera3D:
	return _scene.get("camera")

func step(delta: float, storm_now: float) -> void:
	storm = storm_now
	_clock += delta
	_frames += 1
	if _strike_at >= 0:
		if _frames == _strike_at: strike(_kind,_range,_bearing)
	elif storm >= FROM:
		_wait -= delta
		if _wait <= 0.0:
			strike()
			var mean := lerpf(EVERY.x,EVERY.y,smoothstep(FROM,1.0,storm))
			_wait = maxf(-log(1.0-_rng.randf()*0.98)*mean,0.6)
			if _rng.randf() < BURST: _wait = _rng.randf_range(0.5,1.6)
	for i in range(_thunders.size()-1,-1,-1):
		if _thunders[i].x <= _clock:
			var thunder: Node = _scene.weather.get("thunder") if _scene.get("weather") != null else null
			if thunder != null: thunder.play_thunder(_thunders[i].y*THUNDER_SCALE,_thunders[i].z)
			_thunders.remove_at(i)
	_update(delta)

## A strike now: of `kind` (bolt, across, inside; "" draws one), `range` m
## off (<0 draws one) at `bearing` radians off the view's middle (NAN draws
## one).
func strike(kind := "", range_m := -1.0, bearing := NAN) -> void:
	var camera := _eye()
	if camera == null: return
	var eye := camera.global_position
	if kind == "":
		var roll := _rng.randf()
		kind = "bolt" if roll < BOLT_SHARE else ("across" if roll < BOLT_SHARE+ACROSS_SHARE else "inside")
	if range_m < 0.0:
		var roll := _rng.randf()
		var span := FAR if roll < FAR_SHARE else (MID if roll < FAR_SHARE+MID_SHARE else NEAR)
		range_m = _rng.randf_range(span.x,span.y)
	var forward := -camera.global_basis.z
	var view_yaw := atan2(forward.z,forward.x)
	if is_nan(bearing):
		var half := atan(tan(deg_to_rad(camera.fov)*0.5)*_aspect())
		bearing = _rng.randf_range(-half,half)*VIEW_SPREAD if _rng.randf() < IN_VIEW else _rng.randf_range(-PI,PI)
	var yaw := view_yaw+bearing
	var way := Vector3(cos(yaw),0.0,sin(yaw))
	var ground := Vector3(eye.x,0.0,eye.z)+way*range_m
	var top: float = float(_scene.isle_top())+_rng.randf_range(BASE.x,BASE.y)
	var lines: Array = []
	var at := Vector3.ZERO
	# Where the sky lights from: the channel's upper part, or the flash.
	var sky_at := Vector3.INF
	match kind:
		"across":
			var side := way.cross(Vector3.UP)
			var length := _rng.randf_range(0.35,0.9)*clampf(range_m,250.0,1200.0)
			var y := top-_rng.randf_range(40.0,140.0)
			var a := ground+side*length*_rng.randf_range(-0.6,-0.3)+Vector3.UP*y
			var b := ground+side*length*_rng.randf_range(0.3,0.6)+Vector3.UP*(y-_rng.randf_range(-30.0,60.0))+way*_rng.randf_range(-0.2,0.2)*length
			# Its ends in the drifting clouds near them, where there are any.
			a = _in_cloud_near(a,length*0.6)
			b = _in_cloud_near(b,length*0.6)
			lines = _tree(a,b,true)
			at = (a+b)*0.5
			sky_at = at
		"inside":
			at = _inside(eye,ground)
		_:
			var root := ground+Vector3.UP*top
			var foot := ground+Vector3(_rng.randf_range(-0.25,0.25),0.0,_rng.randf_range(-0.25,0.25))*(top-SEA_TOP)
			foot.y = SEA_TOP
			lines = _tree(root,foot,false)
			at = foot-Vector3.UP*FOOT_DEEP
			sky_at = root.lerp(foot,0.3)
	var strokes: Array = [[0.0,1.0,STROKE_DECAY]]
	var count := 1 if kind == "inside" and _rng.randf() < 0.5 else _rng.randi_range(STROKES.x,STROKES.y)
	var t := 0.0
	for s in range(count-1):
		t += _rng.randf_range(STROKE_GAP.x,STROKE_GAP.y)
		var decay := HANG_DECAY if _rng.randf() < HANG_CHANCE/count else STROKE_DECAY
		strokes.append([t,_rng.randf_range(RESTRIKE.x,RESTRIKE.y),decay])
	var distance := eye.distance_to(at if lines.is_empty() else (lines[0].points[0]+lines[0].points[-1])*0.5)
	if sky_at == Vector3.INF: sky_at = at
	var strike := {"sky_at":sky_at,"t":0.0,"strokes":strokes,"at":at,"distance":distance,"kind":kind,
		"end":t+0.9,"gain":1.25 if kind == "inside" else 1.0}
	if not lines.is_empty():
		var instance := MeshInstance3D.new()
		instance.name = "Bolt"
		instance.top_level = true
		instance.mesh = _ribbons(lines)
		instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		instance.extra_cull_margin = 200.0
		var material := ShaderMaterial.new()
		material.shader = _shader
		# Over the cloud volume and the sea (SkySea.RENDER_PRIORITY -2),
		# under the rain's veils.
		material.render_priority = 5
		material.set_shader_parameter("hot",HOT)
		material.set_shader_parameter("min_px",MIN_PX)
		instance.material_override = material
		add_child(instance)
		instance.global_transform = Transform3D.IDENTITY
		strike.mesh = instance
		strike.material = material
	_strikes.append(strike)
	_thunders.append(Vector3(_clock+distance/SOUND_SPEED,distance,clampf(700.0/distance,0.35,1.0)))
	strike_count += 1
	if _strike_at >= 0: print("lightning: %s %.0f m off at %s" % [kind,distance,at.round()])

## Where a flash inside a cloud goes: a drifting cloud near the eye, else
## the cloud sea at `ground`.
func _inside(eye: Vector3, ground: Vector3) -> Vector3:
	var host: Node = _scene.cloud_host() if _scene.has_method("cloud_host") else null
	if host != null and _rng.randf() < 0.6:
		var puff: Variant = host.cloud_near(ground+Vector3.UP*eye.y,clampf(eye.distance_to(ground)*0.6,150.0,900.0))
		if puff is Vector3 and (puff as Vector3).distance_to(eye) > 80.0: return puff
	return Vector3(ground.x,SEA_TOP-INSIDE_DEEP,ground.z)

## A drifting cloud's middle within `reach` of `p`, else `p`.
func _in_cloud_near(p: Vector3, reach: float) -> Vector3:
	var host: Node = _scene.cloud_host() if _scene.has_method("cloud_host") else null
	if host == null: return p
	var puff: Variant = host.cloud_near(p,reach)
	return puff if puff is Vector3 and ((puff as Vector3).distance_to(_eye().global_position) > 80.0) else p

## The channels from `a` to `b`: the main one and its branches, each
## {points, width, bright, main}. `across` hangs its branches down as well
## as along.
func _tree(a: Vector3, b: Vector3, across: bool) -> Array:
	var main := _channel(a,b,WANDER,7)
	var lines: Array = [{"points":main,"width":WIDTH.x,"bright":BRIGHT.x,"main":true,"ends":across}]
	var length := a.distance_to(b)
	var count := _rng.randi_range(BRANCHES.x,BRANCHES.y)
	for k in range(count):
		# More near the root, where the leader forked most.
		var u := pow(_rng.randf(),1.6)*0.85
		var i := clampi(int(u*(main.size()-1)),1,main.size()-2)
		var from: Vector3 = main[i]
		var along := (main[mini(i+3,main.size()-1)]-main[maxi(i-3,0)]).normalized()
		var off := _rng.randf_range(0.35,0.9)*(1.0 if _rng.randf() < 0.5 else -1.0)
		var sideways := along.cross(Vector3.UP if absf(along.y) < 0.9 else Vector3.RIGHT).normalized().rotated(along,_rng.randf_range(0.0,TAU))
		var dir := (along+sideways*off*1.4).normalized()
		if across: dir = (dir+Vector3.DOWN*_rng.randf_range(0.3,1.2)).normalized()
		var reach := length*(1.0-u)*_rng.randf_range(0.15,0.5)
		var end := from+dir*reach
		if not across: end.y = maxf(end.y,SEA_TOP+5.0)
		var branch := _channel(from,end,WANDER*1.3,5)
		lines.append({"points":branch,"width":WIDTH.y,"bright":BRIGHT.y*_rng.randf_range(0.6,1.2),"main":false})
		for s in range(_rng.randi_range(0,2)):
			var j := _rng.randi_range(2,branch.size()-3)
			var twig_from: Vector3 = branch[j]
			var twig_dir := (dir+Vector3(_rng.randf_range(-0.6,0.6),_rng.randf_range(-0.5,0.1),_rng.randf_range(-0.6,0.6))).normalized()
			var twig := _channel(twig_from,twig_from+twig_dir*reach*_rng.randf_range(0.2,0.45),WANDER*1.4,4)
			lines.append({"points":twig,"width":WIDTH.z,"bright":BRIGHT.z,"main":false})
	return lines

## A jagged channel from `a` to `b`: the line halved `levels` times, each
## new middle thrown aside by `wander` of its span (less each level, but
## not by much: lightning is ragged at every size).
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
			var push := (n1*_rng.randf_range(-1.0,1.0)+n2*_rng.randf_range(-1.0,1.0))*span*amount
			# Along the way a little too, so the kinks are uneven.
			out.append((p+q)*0.5+push+d*span*_rng.randf_range(-0.12,0.12))
			out.append(q)
		points = out
		amount *= 0.88
	return points

## The ribbons' mesh (shaders/plane_lightning.gdshader's layout).
func _ribbons(lines: Array) -> ArrayMesh:
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
		# Its brightness wanders along it (a channel is never even).
		var beads := FastNoiseLite.new()
		beads.seed = _rng.randi()
		beads.frequency = 0.08
		for i in range(n):
			var tangent := (points[mini(i+1,n-1)]-points[maxi(i-1,0)]).normalized()
			var u := float(i)/float(n-1)
			# A branch thins to its tip; the main stroke a little.
			var w: float = float(line.width)*(lerpf(1.0,0.75,u) if main else lerpf(1.0,0.35,u))
			for side in [-1.0,1.0]:
				verts.append(points[i])
				normals.append(tangent)
				uvs.append(Vector2(side,u))
				uv2s.append(Vector2(w,float(line.bright)*(1.0+0.6*beads.get_noise_1d(float(i)))))
				colours.append(Color(1.0 if main else 0.0,1.0 if line.get("ends",false) else 0.0,0.0,1.0))
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
	return mesh

func _aspect() -> float:
	var size := get_viewport().get_visible_rect().size
	return size.x/maxf(size.y,1.0)

## The strikes' flashes this frame: each one's strokes summed, the ribbons
## lit, the brightest made the flash.
func _update(delta: float) -> void:
	var camera := _eye()
	var pixel := 0.001
	if camera != null:
		pixel = 2.0*tan(deg_to_rad(camera.fov)*0.5)/maxf(get_viewport().get_visible_rect().size.y,1.0)
	flash = 0.0
	_pop = 0.0
	var light_k := 0.0
	var light_at := Vector3.ZERO
	for i in range(_strikes.size()-1,-1,-1):
		var s: Dictionary = _strikes[i]
		if _hold < 0.0: s.t += delta
		else: s.t = _hold
		var t: float = s.t
		var main := 0.0
		var first := 0.0
		for k in range(s.strokes.size()):
			var stroke: Array = s.strokes[k]
			var since: float = t-float(stroke[0])
			if since < 0.0: continue
			# A stroke pops in over a frame and dies off.
			var v: float = float(stroke[1])*exp(-since*float(stroke[2]))
			main = maxf(main,v)
			if k == 0: first = v
		# The channel glows faintly between the strokes while they last.
		if t < float(s.strokes[-1][0]): main = maxf(main,0.12)
		if s.has("material"):
			var m: ShaderMaterial = s.material
			m.set_shader_parameter("flash",main)
			m.set_shader_parameter("branch_flash",first)
			m.set_shader_parameter("pixel",pixel)
			(s.mesh as Node3D).visible = main > 0.004
		var reach := clampf(REACH/maxf(float(s.distance),1.0),POP_RANGE.x,POP_RANGE.y)
		var lit := main*float(s.gain)
		if lit > flash:
			flash = lit
			flash_position = s.at
			sky_position = s.sky_at
		_pop = maxf(_pop,main*reach*float(s.gain))
		if float(s.distance) < LIGHT_REACH and main*reach > light_k:
			light_k = main*reach
			light_at = s.at if not s.has("material") else (s.at as Vector3)+Vector3.UP*120.0
		if _hold < 0.0 and t > float(s.end):
			if s.has("mesh"): (s.mesh as Node).queue_free()
			_strikes.remove_at(i)
	_light.visible = light_k > 0.01 and camera != null
	if _light.visible:
		_light.light_energy = light_k*LIGHT
		var from := light_at-camera.global_position
		if from.length() > 1.0: _light.look_at_from_position(Vector3.ZERO,-from.normalized(),Vector3.UP if absf(from.normalized().y) < 0.95 else Vector3.RIGHT)

## The flash on the sky, after the storm's grade (plane_weather.gd
## `grade`) has set it this frame: the dome's pop (zs_storm_flash) and the
## kit's flash (zs_flash, for the air's glow), the cloud's grey (the
## grade's `graded`) lifted.
func publish(graded: float) -> void:
	RenderingServer.global_shader_parameter_set("zs_storm_flash",Vector4(sky_position.x,sky_position.y,sky_position.z,_pop*POP))
	RenderingServer.global_shader_parameter_set("zs_flash",Vector4(flash_position.x,flash_position.y,flash_position.z,flash))
	if _pop > 0.0 or _popped:
		RenderingServer.global_shader_parameter_set("zs_storm_grade",graded*(1.0-clampf(_pop*GREY_LIFT,0.0,0.8)))
	_popped = _pop > 0.0
