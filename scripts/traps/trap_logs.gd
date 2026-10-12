extends "res://scripts/traps/trap.gd"
## Rolling Logs (the user's idea, docs/design/roguelike/traps-round3-roll-flip.md;
## built to the contract in scripts/traps/trap.gd): a chain of stone drums
## across a gap, each spinning about its long axis. A log's top moves, and
## what stands on it is carried with the surface (`motor.carry`, as
## foot_pieces.gd and the seesaw carry): standing still he is walked off the
## log's back (or its side) and into the gap; running against it he makes
## headway; hopping log to log he barely feels it. Drums alternate their
## spin (`alternate`) so one helps and the next fights, and the spin gains
## pace the longer he is on them (`speedup`, capped by `max_boost`).
##
## `axis`: "cross" (default) logs lie across the route, the top moving along
## it, so he is carried back (or forward); "along" logs lie along the route,
## side by side across it, the top moving sideways, so he drifts off the side.
##
## The tell: dark stripes on the drum so the spin reads (they go orange as
## the spin gains pace), a low `rumble` (tell_sound) while he is on one.
## The logs spin from the start, so the first one is seen turning from the
## entry. Cost 2 over a layer, 3 over the void.
##
## Sizes come from the pilot: `radius` a share of his walk, the surface
## `spin` (m/s) a share of his walk, `gap` a share of a running small hop's
## reach (REACH_SHARE). Knobs: `count`, `radius`, `width` (across, "cross"),
## `span` (length of a log, "along"), `gap`, `axis`, `spin`, `alternate`,
## `speedup` (per s on them), `max_boost`, `rumble_gap` (s).
const STONE := Color(0.42,0.41,0.4)
const STRIPE := Color(0.2,0.19,0.19)
const THICK := 0.3
## The collision top's share of the drum's diameter (a flat top the feet ride).
const TOP_SHARE := 0.85
const REACH_SHARE := 0.3

## One record per log: body, spin pivot, top-middle (local), carry direction
## (local, a unit horizontal), spin sign, angle, collision extents.
var logs: Array[Dictionary] = []
## Seconds spent riding the logs: the spin's speed-up clock.
var clock := 0.0
var _rumble_t := 0.0
var stripe_mat: StandardMaterial3D

func _init() -> void:
	super()
	trap_name = "logs"
	cost = 2
	under = "layer"
	verbs = PackedStringArray(["run","jump"])

## The reach of a running small hop (m).
static func hop_reach(p: PilotMotor) -> float:
	return p.run*2.0*sqrt(2.0*p.jumps[0]/p.gravity)

func defaults() -> Dictionary:
	var p := pilot()
	return {
		"count":6,"radius":p.walk*0.3,"width":p.run*0.5,"span":p.walk*3.0,
		"gap":hop_reach(p)*REACH_SHARE,"axis":"cross","spin":p.walk*0.7,"alternate":true,
		"speedup":0.08,"max_boost":1.8,"rumble_gap":0.5,
	}

func _along() -> bool:
	return str(knob("axis")) == "along"

## A log's flat top, along the route ("cross") or across it ("along").
func foot() -> float:
	return float(knob("radius"))*2.0*TOP_SHARE

func pitch() -> float:
	return foot()+float(knob("gap"))

func length() -> float:
	if _along(): return float(knob("span"))
	return float(knob("count"))*pitch()-float(knob("gap"))

func footprint() -> Rect2:
	var w := float(knob("count"))*pitch() if _along() else float(knob("width"))
	return Rect2(-w*0.5,-length(),w,length())

func build() -> void:
	var r := float(knob("radius"))
	var along := _along()
	var n := int(knob("count"))
	stripe_mat = paint(STRIPE)
	for i in range(n):
		var top: Vector3
		var sx: float
		var sz: float
		var axis_len: float
		if along:
			top = Vector3((float(i)-float(n-1)*0.5)*pitch(),0.0,-length()*0.5)
			sx = foot()
			sz = length()
			axis_len = length()
		else:
			top = Vector3(0.0,0.0,-(float(i)*pitch()+foot()*0.5))
			sx = float(knob("width"))
			sz = foot()
			axis_len = sx
		var body := StaticBody3D.new()
		body.position = top
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(sx,THICK,sz)
		shape.shape = box
		shape.position.y = -THICK*0.5
		body.add_child(shape)
		var pivot := Node3D.new()
		pivot.position.y = -r
		body.add_child(pivot)
		var drum := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = r
		cyl.bottom_radius = r
		cyl.height = axis_len
		cyl.radial_segments = 24
		drum.mesh = cyl
		drum.material_override = paint(STONE)
		if along: drum.rotation.x = PI*0.5
		else: drum.rotation.z = PI*0.5
		pivot.add_child(drum)
		# Stripes: four bars along the drum, 90 degrees apart.
		for k in range(4):
			var holder := Node3D.new()
			if along: holder.rotation.z = float(k)*PI*0.5
			else: holder.rotation.x = float(k)*PI*0.5
			var bar := MeshInstance3D.new()
			var bm := BoxMesh.new()
			bm.size = Vector3(0.14,0.04,axis_len*1.01) if along else Vector3(axis_len*1.01,0.04,0.14)
			bar.mesh = bm
			bar.position.y = r
			bar.material_override = stripe_mat
			holder.add_child(bar)
			pivot.add_child(holder)
		add_child(body)
		var sgn := 1.0 if (not bool(knob("alternate")) or i%2 == 0) else -1.0
		logs.append({"body":body,"pivot":pivot,"top":top,"dir":Vector3(1.0,0.0,0.0) if along else Vector3(0.0,0.0,1.0),"sgn":sgn,"angle":0.0,"sx":sx,"sz":sz})

## Surface pace now (m/s).
func pace() -> float:
	return float(knob("spin"))*minf(1.0+float(knob("speedup"))*clock,float(knob("max_boost")))

## Index of the log the feet (world) are on, or -1.
func log_at(feet: Vector3) -> int:
	var local := to_local(feet)
	for i in range(logs.size()):
		var l: Dictionary = logs[i]
		var top: Vector3 = l.top
		if absf(local.x-top.x) <= float(l.sx)*0.5 and absf(local.z-top.z) <= float(l.sz)*0.5 and absf(local.y-top.y) < 0.25: return i
	return -1

## The pace (world m/s, signed) the surface of log `i` carries what stands on it.
func surface_velocity(i: int) -> Vector3:
	var l: Dictionary = logs[i]
	return global_transform.basis*(l.dir as Vector3)*(float(l.sgn)*pace())

func before(delta: float) -> void:
	if delta <= 0.0: return
	var r := float(knob("radius"))
	var along := _along()
	var spin := pace()/r*delta
	for l: Dictionary in logs:
		l.angle += spin*float(l.sgn)
		(l.pivot as Node3D).rotation = Vector3(0.0,0.0,-float(l.angle)) if along else Vector3(float(l.angle),0.0,0.0)
	var share := clampf((pace()/float(knob("spin"))-1.0)/maxf(float(knob("max_boost"))-1.0,0.01),0.0,1.0)
	tell_sight(share)
	if motor == null or motor.rider != null or motor.swimming or not (motor.grounded or motor.on_ledge()): return
	var i := log_at(motor.feet)
	if i < 0: return
	clock += delta
	motor.carry(Transform3D(Basis.IDENTITY,surface_velocity(i)*delta),0.0)
	_rumble_t -= delta
	if _rumble_t <= 0.0:
		_rumble_t = float(knob("rumble_gap"))
		tell_sound(&"rumble",to_global(logs[i].top as Vector3))

func tell_sight(amount: float) -> void:
	if stripe_mat != null: stripe_mat.albedo_color = STRIPE.lerp(TELL,amount)

func reset() -> void:
	super()
	clock = 0.0
	_rumble_t = 0.0
	for l: Dictionary in logs:
		l.angle = 0.0
		(l.pivot as Node3D).rotation = Vector3.ZERO
