extends "res://tools/harness/drive.gd"
## The native ground layers against their GDScript, bit for bit (results
## compared as var_to_bytes) through the real play loop. Run it through
## tools/ground_parity.py, which runs each check in its own Godot and sums up.
##
## --check=ground: the study's plane_ground (pads -1, 0, random, 16, 17),
##   _blocked, _solid, _sight, floor_at, eye_floor and the field's last_river
##   after each, with the GroundNative broad phase on vs off (every owner
##   asked). Points round a low flight at both ships, three meadow/split
##   spots, three stair flights, the Peak and the ice tube, and near standing
##   arches, the loose arches, rock squares, the towers, the flights and the
##   ice windows. --break drops the arches layer, so it must fail.
## --check=trees: LandTrees tree_in (body/bare at several heights), top_at,
##   inside and ground with ZenScapeTreeSolid vs the GDScript
##   (solid_native false), round a low flight at six spots and round stood
##   trees and bucket edges, with knocks and blocks coming and going.
##   --break drops cells from the native side only, so it must fail.
## Each prints `GROUND_PARITY <check> points N mismatches M`.

const SkyGlide = preload("res://scripts/sky_glide.gd")
const NearMiss = preload("res://scripts/endless/near_miss.gd")
const SPEED := 55.0
const SPOTS: Array[Vector3] = [Vector3(164.8,0,-32.4),Vector3(1651.1,0,-525.3),Vector3(3972.0,0,-2431.7)]
const TREE_SPOTS: Array[Vector3] = [Vector3(-2400,0,1800),Vector3(900,0,3100),Vector3(-3500,0,-2600)]

var points := 0
var bad := 0
var rng := RandomNumberGenerator.new()
var bits := {"none":0,"arches":0,"rocks":0,"stair":0,"ice":0}
var hits := 0
var tops := 0
var knocks := 0

func drive() -> void:
	await open("studies/endless_flight.tscn")
	var which := String(arg("check","ground"))
	if which == "ground": await _ground()
	elif which == "trees": await _trees()
	else: check(false,"--check=ground|trees","got %s" % which)
	finish()

# --- Moving the plane ----------------------------------------------------------

## Holds the plane at `spot` a while (so the land round it stands), then
## flies it 55 m/s at 8 m over the ground for `steps` frames, sampling with
## `sample` every 6th.
func _visit(spot: Vector3, steps: int, sample: Callable) -> void:
	var heading := rng.randf_range(-PI,PI)
	var dir := Vector3(-sin(heading),0,-cos(heading))
	for i in 240:
		_put(spot,heading)
		await frames(1)
	for i in steps:
		_put(spot+dir*SPEED*DT*i,heading)
		await frames(1)
		if i % 6 == 0: sample.call()

func _put(at: Vector3, heading: float) -> void:
	var y := maxf(float(study.field.height(at.x,at.z)),-1.0)+8.0
	study.plane.place(Vector3(at.x,y,at.z),heading,0.0,SPEED)

func _report(which: String, extra: String) -> void:
	note("GROUND_PARITY %s points %d mismatches %d  %s" % [which,points,bad,extra])
	check(points > 0,"%s points sampled" % which)
	check(bad == 0,"%s 0 mismatches" % which,"%d of %d" % [bad,points])

# --- The ground composite's broad phase ---------------------------------------

func _ground() -> void:
	var gn: GroundNative = study.ground_native
	if not check(gn != null and gn.on,"ground native on","no library, a stale one, or --ground-native=0"): return
	rng.seed = 7
	if flag("break"):
		gn.arches = null
		GroundNative.bump()
	var spots: Array[Vector3] = SPOTS.duplicate()
	if study.stair != null:
		var fl: Array = study.stair.flights
		for i in [0,fl.size()/2,fl.size()-1]:
			if i < fl.size(): spots.append((fl[i].xf as Transform3D).origin)
	var pk: Variant = study.field.peak()
	if pk != null: spots.append(Vector3(pk.centre.x,0,pk.centre.y))
	if study.coast != null:
		for sh: Node3D in study.coast.ships: spots.push_front(sh.global_position)
	var tun: Variant = study.ice.tun
	if tun != null:
		for s in [study.ice._s0,(study.ice._s0+study.ice._s1)*0.5,study.ice._s1]:
			var a: Vector2 = tun.at_s(s)
			spots.push_front(Vector3(a.x,0,a.y))
	for spot in spots:
		await _visit(spot,180,_ground_sample)
	_report("ground","mask bits seen %s, squares %d, loose %d" % [bits,int(gn._g.squares()),study.arches.loose.size()])

func _ground_sample() -> void:
	var p: Vector3 = study.plane.position
	var pts: Array[Vector3] = []
	for i in 30: pts.append(p+Vector3(rng.randf_range(-60,60),rng.randf_range(-10,10),rng.randf_range(-60,60)))
	var recs: Array = study.arches.standing()
	for k in mini(25,recs.size()):
		var r: Dictionary = recs[rng.randi_range(0,recs.size()-1)]
		pts.append_array(_round(r.pos,float(r.reach)*1.3,4))
	for r: Dictionary in study.arches.loose: pts.append_array(_round(r.pos,float(r.reach)*1.2,4))
	var keys: Array = study.rocks._grid.keys()
	for k in mini(25,keys.size()):
		var g: Vector2i = keys[rng.randi_range(0,keys.size()-1)]
		pts.append_array(_round(Vector3((g.x+0.5)*32.0,0,(g.y+0.5)*32.0),40.0,4))
	if study.towers != null:
		for s: Dictionary in study.towers._solids:
			pts.append_array(_round(Vector3(s.mid.x,0,s.mid.y),float(s.reach)+20.0,6))
	if study.stair != null:
		for f: Dictionary in study.stair.flights:
			if bool(f.built) and rng.randf() < 0.3: pts.append_array(_round((f.xf as Transform3D).origin,30.0,4))
	var tun: Variant = study.ice.tun
	if tun != null:
		for k in 30:
			var s := rng.randf_range(study.ice._s0-60.0,study.ice._s1+60.0)
			var a: Vector2 = tun.at_s(s)
			var f := float(tun.floor_at(clampf(s,study.ice._s0,study.ice._s1)))
			pts.append(Vector3(a.x+rng.randf_range(-70,70),f+rng.randf_range(-6.0,40.0),a.y+rng.randf_range(-70,70)))
		for w: Dictionary in tun.windows:
			for k in 4:
				var c: Vector2 = w.at
				pts.append(Vector3(c.x+rng.randf_range(-12,12),float(w.floor)+rng.randf_range(-4.0,float(w.crown)-float(w.floor)+30.0),c.y+rng.randf_range(-12,12)))
	var eye: Vector3 = study.camera.global_position
	for q in pts: _ground_cmp(q,eye)

## `n` points within `r` of `c` (XZ), from under its ground to well over it.
func _round(c: Vector3, r: float, n: int) -> Array[Vector3]:
	var out: Array[Vector3] = []
	for i in n:
		var x := c.x+rng.randf_range(-r,r)
		var z := c.z+rng.randf_range(-r,r)
		out.append(Vector3(x,float(study.field.height(x,z))+rng.randf_range(-4.0,45.0),z))
	return out

func _ground_cmp(q: Vector3, eye: Vector3) -> void:
	var gn: GroundNative = study.ground_native
	var far := q+Vector3(rng.randf_range(-30,30),rng.randf_range(-8,8),rng.randf_range(-30,30))
	var pads := [-1.0,0.0,rng.randf_range(0.0,16.0),16.0,17.0]
	var on: Array = []
	var off: Array = []
	for k in 2:
		gn.on = k == 0
		var out: Array = on if k == 0 else off
		for pad: float in pads: out.append(study.plane_ground(q,pad))
		out.append(study._blocked(q))
		out.append(study._solid(q))
		out.append(study._sight(eye,q))
		out.append(study._sight(q,far))
		out.append(study.floor_at(Vector2(q.x,q.z)))
		out.append(study.field.last_river)
		out.append(study.eye_floor(q))
		out.append(study.field.last_river)
		out.append(study.plane_ground(q,-1.0))
		out.append(study.field.last_river)
	gn.on = true
	var m := gn.mask(q,0.0)
	if m == 0: bits.none += 1
	if m & 1: bits.arches += 1
	if m & 2: bits.rocks += 1
	if m & 4: bits.stair += 1
	if m & 8: bits.ice += 1
	points += 1
	if var_to_bytes(on) != var_to_bytes(off):
		bad += 1
		if bad <= 10: note("MISMATCH at %s mask %d: on %s off %s" % [q,m,on,off])

# --- The trees' flight solid ---------------------------------------------------

func _trees() -> void:
	var trees: Node = study.trees
	if not check(trees.solid_native,"native tree solid on","no library, a stale one, or --ground-native=0"): return
	rng.seed = 11
	var spots: Array[Vector3] = SPOTS.duplicate()
	spots.append_array(TREE_SPOTS)
	for spot in spots:
		await _visit(spot,300,_trees_sample)
	_report("trees","tree_in hits %d, tops %d, knocks %d, cells native %d" % [hits,tops,knocks,int(trees._solid_n.count())])

func _trees_sample() -> void:
	var trees: Node = study.trees
	if flag("break") and rng.randf() < 0.3:
		# The control: a block's cells dropped from the native side only.
		var ks: Array = trees._blocks.keys()
		if not ks.is_empty():
			var cells: Dictionary = trees._blocks[ks[rng.randi_range(0,ks.size()-1)]].cells
			for ck: Vector2i in cells: trees._solid_n.drop_cell(ck.x,ck.y)
	var p: Vector3 = study.plane.position
	var pts: Array[Vector3] = []
	for i in 40: pts.append(p+Vector3(rng.randf_range(-80,80),rng.randf_range(-15,25),rng.randf_range(-80,80)))
	var c0 := Vector2i(floori(p.x/128.0),floori(p.z/128.0))
	for dz in range(-1,2):
		for dx in range(-1,2):
			var s: PackedFloat32Array = trees.cell_trees(c0+Vector2i(dx,dz))
			var n := s.size()/8
			for k in mini(12,n):
				var q := rng.randi_range(0,n-1)*8
				var foot := Vector3(s[q],s[q+2],s[q+1])
				var r := maxf(s[q+5],1.0)*1.3
				for j in 5:
					pts.append(foot+Vector3(rng.randf_range(-r,r),rng.randf_range(-2.0,s[q+3]+3.0),rng.randf_range(-r,r)))
				pts.append(Vector3(floorf(foot.x/16.0)*16.0,foot.y+s[q+3]*0.5,foot.z))
	for q in pts: _trees_cmp(q)
	# Now and then knock a tree the plane would meet (both sides see it).
	if rng.randf() < 0.25:
		for q in pts:
			var t: Dictionary = trees.tree_in(q,true,1.0)
			if not t.is_empty():
				trees.knock(t)
				knocks += 1
				break

func _trees_cmp(q: Vector3) -> void:
	var trees: Node = study.trees
	var aboves := [0.0,1.0,SkyGlide.SKIM,-NearMiss.TIP_DEPTH,rng.randf_range(-3.0,3.0)]
	var a := []
	var b := []
	for side in [true,false]:
		trees.solid_native = side
		var out := []
		for ab: float in aboves:
			out.append(trees.tree_in(q,true,ab))
			out.append(trees.tree_in(q,false,ab))
		out.append(trees.top_at(q))
		out.append(trees.inside(q))
		out.append(trees.ground(q,q.y-5.0))
		if side: a = out
		else: b = out
	trees.solid_native = true
	points += 1
	if not (a[0] as Dictionary).is_empty(): hits += 1
	if float(a[10]) > -INF: tops += 1
	if var_to_bytes(a) != var_to_bytes(b):
		bad += 1
		if bad <= 5: note("MISMATCH at %s\n native %s\n gd     %s" % [q,a,b])
