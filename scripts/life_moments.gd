extends Node3D
## "And it was good": rare moments when a place has become rich
## (docs/scenic/life.md). A heron lands to fish in water that holds fish; deer
## step out of a wood's edge at dawn; a rainbow follows rain over a living
## place; and, rarest, Bigfoot steps out of a mature wood at dusk, looks at
## you and is gone (scripts/life_bigfoot.gd). Each has its conditions, a
## delay after those first hold, a chance per check and a long cooldown, so
## they stay rare.
##
## Owned by LandLife and advanced on its clock; it reads LandLife's survey and
## creatures and never looks at the world by itself.

const Survey = preload("res://scripts/life_survey.gd")
const Models = preload("res://scripts/life_models.gd")
const Bigfoot = preload("res://scripts/life_bigfoot.gd")
const Rigs = preload("res://scripts/life_rigs.gd")
const HeronRig = preload("res://scripts/life_rig_heron.gd")

## Seconds between condition checks.
const CHECK := 2.0
## Heron: fish settled in its water for HERON_DELAY s, then HERON_CHANCE per
## check; it stays HERON_STAY s and returns no sooner than HERON_COOLDOWN.
const HERON_FISH := 2
const HERON_DELAY := 30.0
const HERON_CHANCE := 0.06
const HERON_STAY := Vector2(45.0,90.0)
const HERON_COOLDOWN := 240.0
const HERON_FLIGHT := 7.0
## The Blender heron glides in from this fraction of the flight, and takes a slow
## wading step now and then, HERON_STALK s apart.
const HERON_GLIDE := 0.55
const HERON_STALK := Vector2(12.0,25.0)
## Deer: a forest edge for DEER_DELAY s, at dawn (celestial phase DAWN).
const DEER_TREES := 6
const DEER_DELAY := 25.0
const DEER_CHANCE := 0.25
const DEER_STAY := Vector2(25.0,45.0)
const DEER_COOLDOWN := 300.0
const DEER_SPEED := 0.42
const DAWN := Vector2(0.2,0.36)
const DUSK := Vector2(0.64,0.8)
## Rainbow: rain of at least RAIN_SECONDS that stops over a place at least
## BOW_RICHNESS rich, with the sun up.
const RAIN_WET := 0.25
const RAIN_DRY := 0.06
const RAIN_SECONDS := 8.0
const BOW_RICHNESS := 1.2
const BOW_CHANCE := 0.6
const BOW_RISE := 6.0
const BOW_HOLD := 30.0
const BOW_FALL := 10.0
const BOW_STRENGTH := 0.85
## Bigfoot (docs/scenic/life.md, "Bigfoot: when he comes"): scenery mode only.
## A mature wood: BIGFOOT_TREES trees, richness BIGFOOT_RICHNESS and an edge
## with BIGFOOT_EDGE_TREES trees near, all held for BIGFOOT_SETTLE s of life.
const BIGFOOT_TREES := 18
const BIGFOOT_EDGE_TREES := 7
const BIGFOOT_RICHNESS := 2.0
const BIGFOOT_SETTLE := 600.0
## A quiet world: nothing painted for BIGFOOT_QUIET s.
const BIGFOOT_QUIET := 45.0
## Low light: dawn and dusk count fully, night at BIGFOOT_NIGHT, and full day
## only in mist (fog at least BIGFOOT_MIST). Mist, or the BIGFOOT_AFTER_RAIN s
## after rain, multiply the chance by BIGFOOT_DAMP; a downpour keeps him in.
const BIGFOOT_NIGHT := 0.6
const BIGFOOT_MIST := 0.45
const BIGFOOT_AFTER_RAIN := 180.0
const BIGFOOT_DAMP := 1.75
const BIGFOOT_DOWNPOUR := 0.5
## Chance per CHECK at full weight, then he is about for BIGFOOT_ABOUT s: he
## shows at the first edge the camera can see; if none comes, he was missed.
const BIGFOOT_CHANCE := 0.006
const BIGFOOT_ABOUT := 90.0
const BIGFOOT_COOLDOWN := 1200.0
## --force-bigfoot[=watch|listen|stride]: a sighting as soon as the wood
## allows, and again BIGFOOT_FORCE_GAP s after each one ends (filming).
const BIGFOOT_FORCE_GAP := 12.0

var life: Node3D
## Every moment so far: {kind, at, p}.
var history: Array[Dictionary] = []

var _check := 0.0
var _heron: Node3D
var _heron_pose: Node3D
var _heron_neck: Node3D
var _heron_legs: Node3D
var _heron_wings: Array[Node3D] = []
## The Blender heron (life_rig_heron.gd); null with --classic-life.
var _heron_rig: HeronRig
var _heron_state := {}
var _heron_next := 0.0
var _water_since := {}
var _deer: Array[Dictionary] = []
var _deer_state := {}
var _deer_next := 0.0
var _edge_since := -1.0
var _rain := 0.0
var _bow := {}
var bigfoot: Node3D
var _bigfoot_next := 0.0
var _bigfoot_about := -1.0
var _rich_since := -1.0
var _stroke_at := -INF
var _wet_until := -INF
var _force_bigfoot := ""
var _forcing := false
var _force_next := 0.0

func setup(owner: Node3D) -> void:
	life = owner
	name = "LifeMoments"
	var material: Material = life.material
	_heron = Node3D.new()
	_heron.name = "Heron"
	add_child(_heron)
	_heron_pose = Node3D.new()
	_heron.add_child(_heron_pose)
	_heron_pose.add_child(_part(Models.heron_body(material)))
	_heron_legs = Node3D.new()
	_heron_legs.position = Vector3(0,0.72,-0.02)
	_heron_legs.add_child(_part(Models.heron_legs(material)))
	_heron_pose.add_child(_heron_legs)
	_heron_neck = Node3D.new()
	_heron_neck.position = Vector3(0,0.9,0.12)
	_heron_neck.add_child(_part(Models.heron_neck(material)))
	_heron_pose.add_child(_heron_neck)
	for left in [false,true]:
		var wing := Node3D.new()
		wing.position = Vector3(-0.08 if left else 0.08,0.88,0.02)
		wing.add_child(_part(Models.heron_wing(material,left)))
		_heron_pose.add_child(wing)
		_heron_wings.append(wing)
	if HeronRig.enabled():
		_heron_rig = HeronRig.new()
		_heron_rig.setup(material)
		_heron.add_child(_heron_rig)
		_heron_pose.visible = false
	_heron.visible = false
	for coat in [Color(0.58,0.38,0.22),Color(0.66,0.46,0.28)]:
		if Rigs.enabled():
			# The Blender deer: a doe, then her fawn.
			var rig: RefCounted = Rigs.deer(material,not _deer.is_empty())
			add_child(rig.root)
			_deer.append({"root":rig.root,"rig":rig})
			continue
		var root := Node3D.new()
		root.name = "Deer"
		add_child(root)
		root.add_child(_part(Models.deer_body(material,coat)))
		var neck := Node3D.new()
		neck.position = Vector3(0,0.95,0.3)
		neck.add_child(_part(Models.deer_neck(material,coat)))
		root.add_child(neck)
		var legs: Array[Node3D] = []
		for hip in [Vector3(-0.1,0.76,0.26),Vector3(0.1,0.76,0.26),Vector3(-0.1,0.78,-0.3),Vector3(0.1,0.78,-0.3)]:
			var leg := Node3D.new()
			leg.position = hip
			leg.add_child(_part(Models.deer_leg(material,coat,hip.y)))
			root.add_child(leg)
			legs.append(leg)
		root.visible = false
		_deer.append({"root":root,"neck":neck,"legs":legs})
	bigfoot = Bigfoot.new()
	add_child(bigfoot)
	bigfoot.setup(self)
	# Painting keeps him away, and near him sends him off.
	var editor: Node = life.editor
	editor.stroke_started.connect(_stroke)
	editor.stroke_moved.connect(func(center: Vector3, radius: float, mode: String, _amount: float) -> void: _stroke(center,radius,mode))
	editor.stroke_finished.connect(_stroke)
	for arg in OS.get_cmdline_user_args():
		if arg == "--force-bigfoot" or arg.begins_with("--force-bigfoot="):
			_forcing = true
			_force_bigfoot = arg.trim_prefix("--force-bigfoot").trim_prefix("=")

func _stroke(center: Vector3, _radius: float, _mode: String) -> void:
	if life == null: return
	_stroke_at = life.clock
	bigfoot.stroke(life.to_local(center))

func _part(mesh: Mesh) -> MeshInstance3D:
	var part := MeshInstance3D.new()
	part.mesh = mesh
	part.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	return part

## A new world: everything leaves at once and the clocks start again.
func clear() -> void:
	_heron_state = {}
	_heron.visible = false
	_deer_state = {}
	for deer in _deer: deer.root.visible = false
	bigfoot.hide_now()
	_bigfoot_about = -1.0
	_rich_since = -1.0
	_water_since.clear()
	_edge_since = -1.0
	_end_bow()

func advance(step: float, real_step: float) -> void:
	_check += step
	if _check >= CHECK:
		_check = 0.0
		_consider()
	if not _heron_state.is_empty(): _move_heron(step)
	if not _deer_state.is_empty(): _move_deer(step)
	if bigfoot.showing():
		bigfoot.advance(step,real_step)
		if not bigfoot.showing(): _bigfoot_gone()
	_watch_rain(real_step)
	if not _bow.is_empty(): _move_bow(step)

func _record(kind: String, p: Vector3) -> void:
	history.append({"kind":kind,"at":life.clock,"p":p})
	life.moment.emit(kind,life.to_global(p))

func _roll(chance: float) -> bool:
	return life._rng.randf() < chance

func _phase() -> float:
	return float(life.scene._celestial.phase)

func _in(window: Vector2) -> bool:
	var phase := _phase()
	return phase >= window.x and phase <= window.y

# --- Conditions ---------------------------------------------------------------

func _consider() -> void:
	var survey: RefCounted = life.survey
	if survey == null: return
	var clock: float = life.clock
	# How long each water body has held enough fish. Body ids are per survey,
	# so a body is known by its first cell, which a small edit leaves alone.
	var fish_by_body := {}
	for site: Dictionary in life.present("fish"): fish_by_body[int(site.body)] = int(fish_by_body.get(int(site.body),0))+1
	var seen := {}
	for record: Dictionary in survey.bodies:
		if int(fish_by_body.get(record.id,0)) < HERON_FISH or record.wade.is_empty(): continue
		var key: int = record.cells[0]
		seen[key] = record
		if not _water_since.has(key): _water_since[key] = clock
	for key in _water_since.keys():
		if not seen.has(key): _water_since.erase(key)
	if _heron_state.is_empty() and clock >= _heron_next and _daylight() > 0.25 and _rain_now() < 0.3:
		for key in _water_since:
			if clock-float(_water_since[key]) >= HERON_DELAY and _roll(HERON_CHANCE):
				_heron_arrive(seen[key])
				break
	var edges: Array = survey.forest_edges
	if edges.is_empty(): _edge_since = -1.0
	elif _edge_since < 0.0: _edge_since = clock
	if _deer_state.is_empty() and clock >= _deer_next and survey.tree_count >= DEER_TREES and _edge_since >= 0.0 and clock-_edge_since >= DEER_DELAY and _in(DAWN) and _rain_now() < 0.3 and _roll(DEER_CHANCE):
		_deer_arrive(edges)
	_consider_bigfoot(survey,clock)

## Probes only: start a moment now, skipping its delay, chance and hour but
## not the place it needs. False when the world has no such place.
func force(kind: String) -> bool:
	var survey: RefCounted = life.survey
	if survey == null: return false
	match kind:
		"heron":
			for record: Dictionary in survey.bodies:
				if not record.wade.is_empty() and _heron_state.is_empty():
					_heron_arrive(record)
					return true
		"deer":
			if not survey.forest_edges.is_empty() and _deer_state.is_empty():
				_deer_arrive(survey.forest_edges)
				return true
		"bigfoot","bigfoot_watch","bigfoot_listen","bigfoot_stride":
			if bigfoot.showing(): return false
			var how := kind.trim_prefix("bigfoot").trim_prefix("_")
			# On screen if the camera allows it, anywhere with footing if not.
			if bigfoot.begin(how,survey.forest_edges,BIGFOOT_EDGE_TREES,true) or bigfoot.begin(how,survey.forest_edges,BIGFOOT_EDGE_TREES,false):
				_record("bigfoot",bigfoot.position)
				return true
		"rainbow":
			_bow = {"age":0.0}
			_record("rainbow",Vector3.ZERO)
			return true
	return false

## What is on stage now, for probes.
func showing() -> Dictionary:
	return {"heron":str(_heron_state.get("phase","")),"deer":_deer_state.size() > 0,"bigfoot":bigfoot.showing(),"rainbow":not _bow.is_empty()}

func _daylight() -> float:
	return life._daylight()

func _rain_now() -> float:
	return float(life.scene._precipitation.state.x)

func _ground(p: Vector2) -> float:
	var h: Variant = life.data.ground_height(p)
	return float(h) if h != null else 0.0

# --- Heron --------------------------------------------------------------------

func _heron_arrive(record: Dictionary) -> void:
	var cells: PackedInt32Array = record.shallow if not record.shallow.is_empty() else record.wade
	var cell := cells[life._rng.randi_range(0,cells.size()-1)]
	var c := Survey.center(cell)
	var bed: float = life.survey.height[cell]
	var spot := Vector3(c.x,bed,c.y)
	var outward := c.normalized() if c.length() > 0.5 else Vector2.from_angle(life._rng.randf()*TAU)
	outward = outward.rotated(life._rng.randf_range(-0.7,0.7))
	var start := spot+Vector3(outward.x,0,outward.y)*24.0+Vector3.UP*10.0
	var leave := Vector2.from_angle(life._rng.randf()*TAU)
	_heron_state = {"phase":"in","age":0.0,"from":start,"spot":spot,"level":record.level,"stay":life._rng.randf_range(HERON_STAY.x,HERON_STAY.y),"leave":Vector3(leave.x,0,leave.y),"strike":life._rng.randf_range(5.0,9.0),"yaw":atan2(-outward.x,-outward.y)}
	_heron.visible = true
	if _heron_rig:
		_heron_state.stalk = life._rng.randf_range(HERON_STALK.x,HERON_STALK.y)
		_heron_rig.play("Fly",0.0)
	_record("heron",spot)

func _move_heron(step: float) -> void:
	var s := _heron_state
	s.age = float(s.age)+step
	var spot: Vector3 = s.spot
	match s.phase:
		"in":
			var u := minf(float(s.age)/HERON_FLIGHT,1.0)
			var from: Vector3 = s.from
			var bend := spot+(from-spot)*0.35+Vector3.UP*1.5
			var e := 1.0-pow(1.0-u,2.2)
			var p := _bezier(from,bend,spot,e)
			var ahead := _bezier(from,bend,spot,minf(e+0.02,1.0))
			if ahead.distance_to(p) > 0.001: s.yaw = atan2(ahead.x-p.x,ahead.z-p.z)
			_heron.position = p
			var landing := smoothstep(0.78,1.0,u)
			_fly_pose(float(s.age),1.0-landing,lerpf(0.9,2.2,landing))
			if u >= 1.0:
				s.phase = "stand"
				s.age = 0.0
				for wing in _heron_wings: wing.visible = false
				life.ripple(Vector3(spot.x,float(s.level),spot.z),0.7)
		"stand":
			_heron.position = spot
			_heron_pose.rotation.x = 0.0
			_heron_legs.rotation.x = 0.0
			# Now and then the neck strikes at a fish.
			var strike := float(s.age)-float(s.strike)
			var reach := 0.0
			if strike >= 0.0:
				reach = smoothstep(0.0,0.2,strike)*(1.0-smoothstep(0.6,1.2,strike))
				if strike >= 0.25 and not s.get("rang",false):
					s.rang = true
					var beak := spot+Basis(Vector3.UP,float(s.yaw))*Vector3(0,0,HeronRig.STRIKE_REACH if _heron_rig else 0.55)
					life.ripple(Vector3(beak.x,float(s.level),beak.z),0.35)
				if strike > 1.3:
					s.strike = float(s.age)+life._rng.randf_range(7.0,14.0)
					s.rang = false
			_heron_neck.rotation.x = reach*1.05
			_heron_neck.scale = Vector3.ONE
			# The Blender heron finishes a strike or a step before it goes, unless driven off.
			var busy := _heron_rig != null and _heron_rig.clip in ["Strike","Stalk"] and not _heron_rig.done()
			if (float(s.age) >= float(s.stay) and not busy) or _rain_now() > 0.4 or not _water_still_there():
				s.phase = "out"
				s.age = 0.0
				s.from = spot
				for wing in _heron_wings: wing.visible = true
		"out":
			# The Blender heron crouches before it leaves the ground.
			var u := minf(maxf(float(s.age)-(HeronRig.TAKEOFF_LEAD if _heron_rig else 0.0),0.0)/HERON_FLIGHT,1.0)
			var leave: Vector3 = s.leave
			var bend := spot+leave*5.0+Vector3.UP*3.0
			var target := spot+leave*26.0+Vector3.UP*11.0
			var e := pow(u,1.6)
			var p := _bezier(spot,bend,target,e)
			var ahead := _bezier(spot,bend,target,minf(e+0.02,1.0))
			if ahead.distance_to(p) > 0.001:
				var toward := atan2(ahead.x-p.x,ahead.z-p.z)
				# The Blender heron turns into its take-off through the crouch.
				s.yaw = lerp_angle(float(s.yaw),toward,minf(1.0,step*5.0)) if _heron_rig else toward
			_heron.position = p
			_fly_pose(float(s.age),smoothstep(0.0,0.2,u),lerpf(2.0,1.0,u))
			if u >= 1.0:
				_heron_state = {}
				_heron.visible = false
				_heron_next = life.clock+HERON_COOLDOWN
				return
	_heron.rotation.y = float(s.yaw)
	if _heron_rig: _heron_act(step)

## The Blender heron's clip for the moment: flying, gliding and landing on the way in;
## standing, striking in time with the ripple and now and then a wading step while it
## stays; taking off on the way out.
func _heron_act(step: float) -> void:
	var s := _heron_state
	var rig := _heron_rig
	var age := float(s.age)
	match s.phase:
		"in":
			if age >= HERON_FLIGHT-HeronRig.LAND_TOUCH: _heron_clip("Land",0.3)
			elif age >= HERON_FLIGHT*HERON_GLIDE: _heron_clip("Glide",0.6)
		"stand":
			var strike := age-float(s.strike)
			if rig.clip != "Strike" and strike >= 0.25-HeronRig.STRIKE_CONTACT and strike < 0.25:
				rig.play("Strike",0.2)
			elif rig.clip == "Stalk" and rig.done():
				# The clip walked the heron forward; move it there and stand on.
				var spot: Vector3 = s.spot
				var ahead := Basis(Vector3.UP,float(s.yaw))*Vector3(0,0,HeronRig.STALK_DISTANCE)
				var there := Vector2(spot.x+ahead.x,spot.z+ahead.z)
				s.spot = Vector3(there.x,_ground(there),there.y)
				_heron.position = s.spot
				rig.play("Stand",0.0)
			elif rig.clip != "Stand" and rig.done():
				rig.play("Stand",0.3)
			elif rig.clip == "Stand" and rig.time > 3.0 and age >= float(s.stalk) and strike < -5.0:
				s.stalk = age+life._rng.randf_range(HERON_STALK.x,HERON_STALK.y)
				var spot: Vector3 = s.spot
				var ahead := Basis(Vector3.UP,float(s.yaw))*Vector3(0,0,HeronRig.STALK_DISTANCE)
				if life.survey != null and life.survey.wet_at(Vector2(spot.x+ahead.x,spot.z+ahead.z)):
					rig.play("Stalk",0.3)
			if rig.clip == "Stalk":
				# Each foot goes down with a small ring.
				for at in HeronRig.STALK_STEPS:
					if rig.time < at and rig.time+step >= at:
						var foot := (s.spot as Vector3)+Basis(Vector3.UP,float(s.yaw))*Vector3(0,0,HeronRig.STALK_DISTANCE)
						life.ripple(Vector3(foot.x,float(s.level),foot.z),0.3)
		"out":
			if rig.clip == "TakeOff" and rig.done(): rig.play("Fly",0.15)
			elif rig.clip != "TakeOff" and rig.clip != "Fly": rig.play("TakeOff",0.2)
	rig.advance(step)

func _heron_clip(clip: String, blend: float) -> void:
	if _heron_rig.clip != clip: _heron_rig.play(clip,blend)

## Wings beat, legs trail and the neck tucks as far as `flight` (0 standing).
func _fly_pose(age: float, flight: float, beat: float) -> void:
	for wing in _heron_wings: wing.visible = true
	var flap := sin(age*TAU*beat*0.9)*lerpf(0.9,0.55,flight)
	_heron_wings[0].rotation.z = flap
	_heron_wings[1].rotation.z = -flap
	_heron_legs.rotation.x = flight*1.35
	_heron_pose.rotation.x = flight*0.12
	_heron_neck.rotation.x = -flight*0.45
	_heron_neck.scale = Vector3(1,lerpf(1.0,0.75,flight),1)

func _water_still_there() -> bool:
	var spot: Vector3 = _heron_state.spot
	return life.survey != null and life.survey.wet_at(Vector2(spot.x,spot.z))

static func _bezier(a: Vector3, b: Vector3, c: Vector3, t: float) -> Vector3:
	return a.lerp(b,t).lerp(b.lerp(c,t),t)

# --- Deer ---------------------------------------------------------------------

func _deer_arrive(edges: Array) -> void:
	var edge: Dictionary = edges[life._rng.randi_range(0,edges.size()-1)]
	var p: Vector2 = edge.p
	var into: Vector2 = edge.into
	var herd := 2 if life._rng.randf() < 0.5 else 1
	var members := []
	for i in range(herd):
		var side := into.orthogonal()*(0.8 if i == 1 else 0.0)-into*(0.5 if i == 1 else 0.0)
		var graze := p+side
		var cover := graze+into*2.6
		members.append({"from":cover,"to":graze,"p":cover,"phase":"in","age":0.0,"scale":0.62 if i == 1 else 1.0,"stay":life._rng.randf_range(DEER_STAY.x,DEER_STAY.y),"head":0.0,"next":life._rng.randf_range(3.0,8.0),"down":true,"walk":0.0,"yaw":atan2(-into.x,-into.y)})
	_deer_state = {"members":members,"into":into}
	_record("deer",Vector3(p.x,_ground(p),p.y))

func _move_deer(step: float) -> void:
	var into: Vector2 = _deer_state.into
	var gone := 0
	for i in range(_deer_state.members.size()):
		var m: Dictionary = _deer_state.members[i]
		var deer: Dictionary = _deer[i]
		m.age = float(m.age)+step
		var moving := false
		var size := 1.0
		match m.phase:
			"in","out":
				var target: Vector2 = m.to
				var p: Vector2 = m.p
				var distance := p.distance_to(target)
				if distance > 0.02:
					var d := minf(DEER_SPEED*step*(1.0 if m.scale >= 1.0 else 1.15),distance)
					m.p = p+(target-p)/distance*d
					m.yaw = lerp_angle(float(m.yaw),atan2(target.x-p.x,target.y-p.y),minf(1.0,step*4.0))
					moving = true
				elif m.phase == "in":
					m.phase = "graze"
					m.age = 0.0
				else:
					m.phase = "gone"
				# They step out of the trees and melt back into them.
				if m.phase == "in": size = smoothstep(0.0,0.8,float(m.age))
				if m.phase == "out": size = smoothstep(0.0,1.2,distance)
				if m.phase == "gone": size = 0.0
			"graze":
				# Head down to graze, up now and then to look about.
				if float(m.age) >= float(m.next):
					m.down = not m.down
					m.next = float(m.age)+(life._rng.randf_range(5.0,11.0) if m.down else life._rng.randf_range(2.0,4.0))
				if float(m.age) >= float(m.stay) or not _in(Vector2(DAWN.x,DAWN.y+0.08)) or _rain_now() > 0.4:
					m.phase = "out"
					m.age = 0.0
					m.from = m.p
					m.to = (m.p as Vector2)+into*4.2
			"gone":
				gone += 1
				size = 0.0
		m.head = move_toward(float(m.head),1.0 if (m.phase == "graze" and m.down) else 0.0,step*1.4)
		m.walk = float(m.walk)+(step*DEER_SPEED*9.0 if moving else 0.0)
		var root: Node3D = deer.root
		root.visible = size > 0.001
		if not root.visible: continue
		var here: Vector2 = m.p
		var bob := absf(sin(float(m.walk)))*0.025 if moving and not deer.has("rig") else 0.0
		root.position = Vector3(here.x,_ground(here)+bob*float(m.scale),here.y)
		root.rotation.y = float(m.yaw)
		root.scale = Vector3.ONE*float(m.scale)*maxf(size,0.001)
		if deer.has("rig"):
			_play_deer(deer.rig,m,moving,step)
			continue
		(deer.neck as Node3D).rotation.x = smoothstep(0.0,1.0,float(m.head))*1.05
		(deer.neck as Node3D).rotation.y = sin(float(m.age)*0.7+i)*0.25*(1.0-float(m.head))
		var legs: Array = deer.legs
		for k in range(4):
			var swing := sin(float(m.walk)+(PI if k in [1,2] else 0.0))*0.42 if moving else 0.0
			(legs[k] as Node3D).rotation.x = swing
	if gone == _deer_state.members.size():
		_deer_state = {}
		for deer in _deer: deer.root.visible = false
		_deer_next = life.clock+DEER_COOLDOWN

## The rigged deer plays what the member is doing: a walk synced to its ground
## speed, head down to graze (through HeadDown), and head up (through HeadUp)
## to an alert look on the first lift of a visit, then a look back or a quiet
## stand in turn.
func _play_deer(rig: RefCounted, m: Dictionary, moving: bool, step: float) -> void:
	var want := "Walk" if moving else ("Graze" if m.phase == "graze" and m.down else "Idle")
	var was: String = m.get("clip","")
	if want != was:
		m.clip = want
		match want:
			"Walk":
				rig.play("Walk",0.6 if was == "Graze" else 0.3)
			"Graze":
				rig.play("HeadDown",0.35 if was == "Walk" else Rigs.BLEND)
				rig.then("Graze")
			"Idle":
				if was != "Graze":
					rig.play("Idle",0.4)
				else:
					var ups := int(m.get("ups",0))
					m.ups = ups+1
					var next := "Alert" if ups == 0 else ("Look" if ups%2 == 0 else "Idle")
					rig.play("HeadUp")
					rig.then(next)
					if next != "Idle": rig.then("Idle")
					# Keep the head up long enough for the alert to play out.
					if next == "Alert": m.next = maxf(float(m.get("next",0.0)),float(m.get("age",0.0))+rig.length("HeadUp")+rig.length("Alert"))
	rig.speed = DEER_SPEED*(1.0 if float(m.scale) >= 1.0 else 1.15)/(Rigs.DEER_WALK_SPEED*float(m.scale)) if moving else 1.0
	rig.advance(step)

# --- Rainbow --------------------------------------------------------------------

func _watch_rain(real_step: float) -> void:
	var rain := _rain_now()
	if rain > RAIN_WET:
		_rain += real_step
		_wet_until = life.clock+BIGFOOT_AFTER_RAIN
	elif rain < RAIN_DRY:
		if _rain >= RAIN_SECONDS and _bow.is_empty() and life.survey != null and life.survey.richness() >= BOW_RICHNESS and _daylight() > 0.35 and _roll(BOW_CHANCE):
			_bow = {"age":0.0}
			_record("rainbow",Vector3.ZERO)
		_rain = 0.0

func _move_bow(step: float) -> void:
	_bow.age = float(_bow.age)+step
	var age: float = _bow.age
	var strength := smoothstep(0.0,BOW_RISE,age)*(1.0-smoothstep(BOW_RISE+BOW_HOLD,BOW_RISE+BOW_HOLD+BOW_FALL,age))*BOW_STRENGTH
	var celestial: RefCounted = life.scene._celestial
	if "moment_bow" in celestial: celestial.moment_bow = strength
	if age >= BOW_RISE+BOW_HOLD+BOW_FALL: _end_bow()

func _end_bow() -> void:
	_bow = {}
	if life == null: return
	var celestial: RefCounted = life.scene._celestial
	if "moment_bow" in celestial: celestial.moment_bow = 0.0

# --- Bigfoot -------------------------------------------------------------------

## Why he may or may not come now, for probes and the doc: each condition and
## the chance per check it gives.
func bigfoot_conditions() -> Dictionary:
	var survey: RefCounted = life.survey
	var clock: float = life.clock
	var hidden: bool = bool(life.scene.get("scenery_mode")) and not bool(life.scene.get("resident_enabled"))
	var trees: int = survey.tree_count if survey != null else 0
	var richness: float = survey.richness() if survey != null else 0.0
	var edges := 0
	if survey != null:
		for edge: Dictionary in survey.forest_edges:
			if int(edge.trees) >= BIGFOOT_EDGE_TREES: edges += 1
	var rich := survey != null and trees >= BIGFOOT_TREES and richness >= BIGFOOT_RICHNESS and edges > 0
	var settled := rich and _rich_since >= 0.0 and clock-_rich_since >= BIGFOOT_SETTLE
	var quiet: bool = not life.editor._painting and clock-_stroke_at >= BIGFOOT_QUIET
	var light := _bigfoot_light()
	var weather := _bigfoot_weather()
	return {"hidden":hidden,"trees":trees,"richness":snappedf(richness,0.01),"edges":edges,"rich":rich,
		"rich_for":snappedf(clock-_rich_since,0.1) if _rich_since >= 0.0 else -1.0,"settled":settled,"quiet":quiet,
		"phase":snappedf(_phase(),0.001),"light":light,"weather":weather,"cooldown":snappedf(maxf(0.0,_bigfoot_next-clock),0.1),
		"about":_bigfoot_about >= clock,"chance":BIGFOOT_CHANCE*light*weather if hidden and settled and quiet and clock >= _bigfoot_next else 0.0}

## Light he walks in: dawn and dusk 1, night BIGFOOT_NIGHT, day only in mist.
func _bigfoot_light() -> float:
	if _in(DAWN) or _in(DUSK): return 1.0
	var phase := _phase()
	if phase < DAWN.x or phase > DUSK.y: return BIGFOOT_NIGHT
	return 1.0 if _fog() >= BIGFOOT_MIST else 0.0

func _bigfoot_weather() -> float:
	if _rain_now() > BIGFOOT_DOWNPOUR: return 0.0
	return BIGFOOT_DAMP if _fog() >= BIGFOOT_MIST or life.clock < _wet_until else 1.0

func _fog() -> float:
	var atmosphere: Variant = life.scene.get("_atmosphere")
	return float(atmosphere.fog_amount) if atmosphere != null else 0.0

func _consider_bigfoot(survey: RefCounted, clock: float) -> void:
	# Poll the model's threaded load here, never on a sighting's frame.
	if not bigfoot.ready_to_show(): return
	var state := bigfoot_conditions()
	if state.rich:
		if _rich_since < 0.0: _rich_since = clock
	else:
		_rich_since = -1.0
	if bigfoot.showing() or not state.hidden: return
	if _forcing:
		if clock >= _force_next: force("bigfoot_"+_force_bigfoot if _force_bigfoot != "" else "bigfoot")
		return
	if _bigfoot_about >= clock:
		# About: he shows at the first edge the camera can see, while it holds.
		if state.quiet and float(state.light)*float(state.weather) > 0.0 and bigfoot.begin("",survey.forest_edges,BIGFOOT_EDGE_TREES,true):
			_bigfoot_about = -1.0
			_record("bigfoot",bigfoot.position)
		return
	if float(state.chance) > 0.0 and _roll(float(state.chance)):
		_bigfoot_about = clock+BIGFOOT_ABOUT
		_consider_bigfoot(survey,clock)

func _bigfoot_gone() -> void:
	_bigfoot_next = life.clock+BIGFOOT_COOLDOWN
	_force_next = life.clock+BIGFOOT_FORCE_GAP
