extends "res://tools/harness/drive.gd"
## tools/site_map.py's half in Godot: opens the main scene headless and writes
## every named site in a box, with the land's heights, as JSON (--out=FILE).
##   --box=x0,z0,x1,z1  --step=M  --out=FILE
## Sites are the plans' own, the same the land builds from: nothing is built
## or streamed for them. Finds come from the live table (`study.finds`), and
## tracked layout handles (coast/..., doors/...) from `study.finds.handles()`
## when they exist.

const ArchPlan = preload("res://scripts/endless/arch_plan.gd")
const LandArches = preload("res://scripts/endless/land_arches.gd")
const RockPlan = preload("res://scripts/endless/rocks/rock_plan.gd")
const HALL_CELL := 1024.0
const SPLIT_CELL := 1536.0

var f: RefCounted
var box: PackedFloat64Array
var sites: Array = []

func add(kind: String, sname: String, x: float, z: float, extra: Dictionary = {}) -> void:
	if x < box[0] or x > box[2] or z < box[1] or z > box[3]: return
	var s := {"kind":kind,"name":sname,"x":snappedf(x,0.1),"z":snappedf(z,0.1),"y":snappedf(float(f.height(x,z)),0.1)}
	s.merge(extra,true)
	sites.append(s)

func drive() -> void:
	await open("studies/endless_flight.tscn")
	f = study.field
	box = str(arg("box","-1500,-1500,1500,1500")).split_floats(",")
	var step := arg_float("step",24.0)
	var nx := int((box[2]-box[0])/step)+1
	var nz := int((box[3]-box[1])/step)+1
	var hs := PackedFloat32Array()
	hs.resize(nx*nz)
	for j in nz:
		for i in nx:
			hs[i+j*nx] = float(f.height(box[0]+i*step,box[1]+j*step))
	_plans()
	_landforms()
	_peak()
	if study.doors != null:
		for w: Dictionary in study.doors.walls:
			var xf: Transform3D = w.coded
			add("door",str(w.name),xf.origin.x,xf.origin.z)
	var st: Vector2 = study._start
	add("start","start",st.x,st.y)
	if study.get("finds") != null:
		for e: Dictionary in study.finds.entries():
			var p: Vector3 = e.at
			add("find",str(e.id),p.x,p.z,{"sub":str(e.kind),"y":p.y,"area":str(e.area)})
	var out := str(arg("out","scratch/site_map.json"))
	var fa := FileAccess.open(out,FileAccess.WRITE)
	check(fa != null,"opened "+out)
	fa.store_string(JSON.stringify({"seed":int(f.seed),"box":Array(box),"step":step,"nx":nx,"nz":nz,"sea":f.SEA_Y,"heights":Array(hs),"sites":sites}))
	fa.close()
	result("sites",sites.size())

func _plans() -> void:
	var ar: Dictionary = LandArches.flags()
	var rocks: Dictionary = RockPlan.flags()
	var a := ArchPlan.cell_of(box[0],box[1])
	var b := ArchPlan.cell_of(box[2],box[3])
	for cz in range(a.y,b.y+1):
		for cx in range(a.x,b.x+1):
			for spec: Dictionary in ArchPlan.plan(f,cx,cz,float(ar.density),float(ar.rock),float(ar.ruin)):
				var p: Vector3 = spec.pos
				add("arch",str(spec.name),p.x,p.z,{"sub":str(spec.kind),"y":snappedf(p.y,0.1),"yaw":snappedf(float(spec.get("yaw",0.0)),0.01)})
	var c := RockPlan.cell_of(box[0],box[1])
	var d := RockPlan.cell_of(box[2],box[3])
	for cz in range(c.y,d.y+1):
		for cx in range(c.x,d.x+1):
			for spec: Dictionary in RockPlan.plan(f,cx,cz,rocks):
				var p: Vector3 = spec.pos
				add(str(spec.kind),str(spec.name),p.x,p.z,{"y":snappedf(p.y,0.1),"reach":snappedf(float(spec.get("reach",0.0)),0.1)})

func _landforms() -> void:
	var x0 := box[0]
	var z0 := box[1]
	var x1 := box[2]
	var z1 := box[3]
	for s: PackedFloat32Array in f.halls_in(x0,z0,x1,z1):
		add("hall","endless/hall/%d_%d" % [floori(s[0]/HALL_CELL),floori(s[1]/HALL_CELL)],s[0],s[1],{"way":[s[2],s[3]],"half_len":s[4],"half_w":s[5],"floor":s[6]})
	for s: Variant in f.tunnels_in(x0,z0,x1,z1):
		var path := []
		var pts: PackedVector2Array = s.pts
		for i in range(0,pts.size(),maxi(pts.size()/24,1)): path.append([pts[i].x,pts[i].y])
		add("tunnel",str(s.name),s.origin.x,s.origin.y,{"mouth_b":[s.mouth_b.x,s.mouth_b.y],"path":path,"floor":s.floor_y})
	for s: PackedFloat32Array in f.splits_in(x0,z0,x1,z1):
		add("split","endless/split/%d_%d" % [floori(s[0]/SPLIT_CELL),floori(s[1]/SPLIT_CELL)],s[0],s[1],{"way":[s[2],s[3]],"half_len":s[4],"half_w":s[5]})
	for s: PackedFloat32Array in f.ponds_in(x0,z0,x1,z1):
		add("pond","pond/%d_%d" % [roundi(s[0]),roundi(s[1])],s[0],s[1],{"radius":s[2],"level":s[3]})

func _peak() -> void:
	var pk: RefCounted = f.peak() if f.has_method("peak") else null
	if pk == null: return
	var top: Vector3 = pk.summit()
	add("peak","peak/summit",top.x,top.z,{"y":top.y})
	var t: Dictionary = pk.tarn()
	add("peak","peak/tarn",t.centre.x,t.centre.z,{"y":t.level,"radius":t.wet})
	add("peak","peak/plateau",t.plateau.x,t.plateau.y)
	var strip: Array = t.strip
	add("peak","peak/strip/0",strip[0].x,strip[0].z,{"y":strip[0].y})
	add("peak","peak/strip/1",strip[1].x,strip[1].z,{"y":strip[1].y})
	var i := 0
	for v: Vector3 in pk.tower_bases():
		add("peak","peak/tower/%d" % i,v.x,v.z,{"y":v.y})
		i += 1
