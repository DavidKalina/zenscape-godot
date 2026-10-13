extends RefCounted
## Reads a built isle through the physics space (docs/design/roguelike/
## layer-round2.md): where its walked ground is, its rims (where an edge
## can leave it over the drop: scripts/kit_isle/kit_motif.gd `socket`
## "rim"), its clear spots (arenas and perches), and how much of the sky it
## fills (`occupancy`: per cell of a grid, its lowest and highest solid).
## The bake (tools/bake_layer_pieces.gd) runs it once over each motif that
## is not a family yet and over the aqueduct isle, and writes what it found
## to data/layer/pieces.json, so the layer generator (scripts/roguelike/
## layer_plan.gd) places isles without building them. The layer's test
## runs `rim_ok` over the built layer.
##
## Sizes come from the pilot (KitMotif `pilot`): a rim stands STEP_IN of
## his run's quarter second in from its lip (the families' own), its
## run-up is clear walked ground behind it; nothing here is metres copied
## from elsewhere but the probe's own sampling.
const KitMotif = preload("res://scripts/kit_isle/kit_motif.gd")
const PilotMotor = preload("res://scripts/pilot_motor.gd")

## Everything solid (the parked plane's layer left out).
const SOLID := 0xFFFFFFFF & ~(1 << 13)
## A walked sample: ground this level (its normal's y) at least, nothing
## over it for CLEAR_OVER of the pilot's height (his body's top, 1.12 m at
## size 1, times this).
const LEVEL := 0.9
const CLEAR_OVER := 1.9
## The drop past a lip: the ground gone, or this far under the rim at
## least (kit_motif.gd's "1.5 m+ under").
const DROP := 1.5
## The air an edge leaves through: clear from AIR_UNDER under the rim to
## AIR_OVER over it, out to AIR_OUT m past the lip (so a tier's edge over
## the isle's own lower ground is no rim).
const AIR_UNDER := 10.0
const AIR_OVER := 4.0
const AIR_OUT := 8.0
## The most run-up measured (m).
const RUN_MOST := 12.0

## How far in from its lip a rim stands (m): a quarter second of his run,
## as the families' rims (motif_colonnade_spine.gd `step`).
static func step_in() -> float:
	return KitMotif.pilot().run*0.25

## The first thing under (x, z) from `from` down to `to` (world y): the
## ray's hit ({position, normal, rid, collider}) or {}.
static func down(space: PhysicsDirectSpaceState3D, x: float, z: float, from: float, to: float, mask := SOLID) -> Dictionary:
	var ray := PhysicsRayQueryParameters3D.create(Vector3(x,from,z),Vector3(x,to,z),mask)
	return space.intersect_ray(ray)

static func clear(space: PhysicsDirectSpaceState3D, a: Vector3, b: Vector3, mask := SOLID) -> bool:
	return space.intersect_ray(PhysicsRayQueryParameters3D.create(a,b,mask)).is_empty()

## The walked ground at (x, z) seen from `top` (world y): its height, if
## the first thing under is turf (`turf`, rid -> true), level, with room
## over it; else NAN.
static func walked(space: PhysicsDirectSpaceState3D, turf: Dictionary, x: float, z: float, top: float) -> float:
	var hit := down(space,x,z,top,top-400.0)
	if hit.is_empty() or not turf.has(hit.rid): return NAN
	if (hit.normal as Vector3).y < LEVEL: return NAN
	var p: Vector3 = hit.position
	if not clear(space,p+Vector3.UP*0.05,p+Vector3.UP*CLEAR_OVER): return NAN
	return p.y

## The ground under (x, z) near `y` (any solid, from a step over it to DROP
## under it): its height, or NAN for none (a drop).
static func near_ground(space: PhysicsDirectSpaceState3D, x: float, z: float, y: float) -> float:
	var hit := down(space,x,z,y+PilotMotor.STEP_UP+0.05,y-DROP)
	return (hit.position as Vector3).y if not hit.is_empty() else NAN

## Per cell of `rect` (x, z), `cell` m square: its lowest and highest solid
## (world y), sampled at its middle and corners from `y_span` (lo, hi) and
## grown one cell round (thin things between samples): {origin, cell,
## cols, rows, lo, hi} (lo INF where empty).
static func occupancy(space: PhysicsDirectSpaceState3D, rect: Rect2, cell: float, y_span: Vector2) -> Dictionary:
	var cols := int(ceil(rect.size.x/cell))
	var rows := int(ceil(rect.size.y/cell))
	var lo := PackedFloat32Array()
	var hi := PackedFloat32Array()
	lo.resize(cols*rows)
	hi.resize(cols*rows)
	var offs := [Vector2(0.5,0.5),Vector2(0.1,0.1),Vector2(0.9,0.1),Vector2(0.1,0.9),Vector2(0.9,0.9)]
	for r in range(rows):
		for c in range(cols):
			var l := INF
			var h := -INF
			for o: Vector2 in offs:
				var x := rect.position.x+(c+o.x)*cell
				var z := rect.position.y+(r+o.y)*cell
				var top := down(space,x,z,y_span.y,y_span.x)
				if top.is_empty(): continue
				h = maxf(h,(top.position as Vector3).y)
				var ray := PhysicsRayQueryParameters3D.create(Vector3(x,y_span.x,z),Vector3(x,y_span.y,z),SOLID)
				var under := space.intersect_ray(ray)
				l = minf(l,(under.position as Vector3).y if not under.is_empty() else (top.position as Vector3).y)
			lo[r*cols+c] = l
			hi[r*cols+c] = h
	# Grown a cell round.
	var glo := lo.duplicate()
	var ghi := hi.duplicate()
	for r in range(rows):
		for c in range(cols):
			for dr in range(-1,2):
				for dc in range(-1,2):
					var rr := r+dr
					var cc := c+dc
					if rr < 0 or cc < 0 or rr >= rows or cc >= cols: continue
					var k := rr*cols+cc
					if lo[k] == INF: continue
					glo[r*cols+c] = minf(glo[r*cols+c],lo[k])
					ghi[r*cols+c] = maxf(ghi[r*cols+c],hi[k])
	return {"origin":rect.position,"cell":cell,"cols":cols,"rows":rows,"lo":Array(glo),"hi":Array(ghi)}

## The walked grid over `rect` at `cell` m: {origin, cell, cols, rows, y}
## (NAN where not walked), seen from `top`.
static func walked_grid(space: PhysicsDirectSpaceState3D, turf: Dictionary, rect: Rect2, cell: float, top: float) -> Dictionary:
	var cols := int(ceil(rect.size.x/cell))
	var rows := int(ceil(rect.size.y/cell))
	var y := PackedFloat32Array()
	y.resize(cols*rows)
	for r in range(rows):
		for c in range(cols):
			y[r*cols+c] = walked(space,turf,rect.position.x+(c+0.5)*cell,rect.position.y+(r+0.5)*cell,top)
	return {"origin":rect.position,"cell":cell,"cols":cols,"rows":rows,"y":y}

## Each walked sample's clear room (m): how far to the nearest sample not
## walked, or a step off level with its neighbour (a chamfer distance).
static func rooms(grid: Dictionary) -> PackedFloat32Array:
	var cols: int = grid.cols
	var rows: int = grid.rows
	var cell: float = grid.cell
	var y: PackedFloat32Array = grid.y
	var d := PackedFloat32Array()
	d.resize(cols*rows)
	for k in range(cols*rows):
		var open := not is_nan(y[k])
		if open:
			var r := k/cols
			var c := k%cols
			for o: Vector2i in [Vector2i(1,0),Vector2i(-1,0),Vector2i(0,1),Vector2i(0,-1)]:
				var rr := r+o.y
				var cc := c+o.x
				if rr < 0 or cc < 0 or rr >= rows or cc >= cols or is_nan(y[rr*cols+cc]) or absf(y[rr*cols+cc]-y[k]) > 0.35*cell:
					open = false
					break
		d[k] = INF if open else 0.0
	var diag := cell*sqrt(2.0)
	for sweep in range(2):
		var rs := range(rows) if sweep == 0 else range(rows-1,-1,-1)
		var cs := range(cols) if sweep == 0 else range(cols-1,-1,-1)
		var s := 1 if sweep == 0 else -1
		for r: int in rs:
			for c: int in cs:
				var k := r*cols+c
				if d[k] == 0.0: continue
				for o: Vector3 in [Vector3(-s,0,cell),Vector3(0,-s,cell),Vector3(-s,-s,diag),Vector3(s,-s,diag)]:
					var rr := r+int(o.y)
					var cc := c+int(o.x)
					if rr < 0 or cc < 0 or rr >= rows or cc >= cols: continue
					d[k] = minf(d[k],d[rr*cols+cc]+o.z)
	return d

## The rim leaving `p` (its walked ground, world) along `way` (flat,
## unit), or {} if none: its lip STEP_IN-ish ahead (between 0.75 and 1.4
## of it), the air past it clear, and the run-up behind it measured.
static func rim_at(space: PhysicsDirectSpaceState3D, turf: Dictionary, p: Vector3, way: Vector3) -> Dictionary:
	var step := step_in()
	var lip := -1.0
	var t := 0.25
	while t <= step*1.6:
		var q := p+way*t
		var g := near_ground(space,q.x,q.z,p.y)
		if is_nan(g):
			lip = t
			break
		if g > p.y+0.3: return {}
		t += 0.25
	if lip < step*0.75 or lip > step*1.4: return {}
	if not air_clear(space,p,way,lip): return {}
	return {"at":p,"face":way,"lip":lip,"run_up":run_up(space,turf,p,way)}

## Clear air ahead of a rim: nothing from AIR_UNDER under it to AIR_OVER over
## it from just past its lip out AIR_OUT m.
static func air_clear(space: PhysicsDirectSpaceState3D, p: Vector3, way: Vector3, lip: float) -> bool:
	var t := lip+0.5
	while t <= lip+AIR_OUT:
		var q := p+way*t
		if not down(space,q.x,q.z,p.y+AIR_OVER,p.y-AIR_UNDER).is_empty(): return false
		t += 0.75
	for h: float in [0.6,1.6,3.0]:
		if not clear(space,p+way*lip+Vector3.UP*h,p+way*(lip+AIR_OUT)+Vector3.UP*h): return false
	return true

## Clear walked ground behind `p` along -`way` (m, to RUN_MOST): each half
## metre walked, within a step of the last, nothing between at the chest.
static func run_up(space: PhysicsDirectSpaceState3D, turf: Dictionary, p: Vector3, way: Vector3) -> float:
	var at := p
	var run := 0.0
	while run < RUN_MOST:
		var q := at-way*0.5
		var g := walked(space,turf,q.x,q.z,at.y+PilotMotor.STEP_UP+0.05)
		if is_nan(g) or absf(g-at.y) > 0.3: break
		var next := Vector3(q.x,g,q.z)
		if not clear(space,at+Vector3.UP*0.8,next+Vector3.UP*0.8): break
		at = next
		run += 0.5
	return run

## Whether a rim socket (`s`, world) stands on walked ground with the drop
## and the air ahead of it (the layer's test): "" if so, else why not.
static func rim_ok(space: PhysicsDirectSpaceState3D, s: Dictionary) -> String:
	var at: Vector3 = s.at
	var face: Vector3 = s.face
	var g := near_ground(space,at.x,at.z,at.y)
	if is_nan(g) or absf(g-at.y) > 0.35: return "no ground under it (%.2f)" % g
	var ahead := at+face*(step_in()*1.6)
	if not is_nan(near_ground(space,ahead.x,ahead.z,at.y)): return "ground ahead past its lip"
	return ""

## The rims round the walked `grid`: every walked sample by a drop tried
## in DIRS ways, the best way kept; then picked greedily by run-up, each
## at least `apart` m from the last ones (at most `most`). Each a
## KitMotif socket "rim" named r<k>_<compass>, with its `lip`.
const DIRS := 16
static func rims(space: PhysicsDirectSpaceState3D, turf: Dictionary, grid: Dictionary, apart: float, most: int) -> Array:
	var cols: int = grid.cols
	var rows: int = grid.rows
	var cell: float = grid.cell
	var y: PackedFloat32Array = grid.y
	var origin: Vector2 = grid.origin
	var found: Array = []
	for r in range(rows):
		for c in range(cols):
			var k := r*cols+c
			if is_nan(y[k]): continue
			# By an edge: a sample within two cells not walked.
			var by := false
			for dr in range(-2,3):
				for dc in range(-2,3):
					var rr := r+dr
					var cc := c+dc
					if rr < 0 or cc < 0 or rr >= rows or cc >= cols or is_nan(y[rr*cols+cc]): by = true
			if not by: continue
			var p := Vector3(origin.x+(c+0.5)*cell,y[k],origin.y+(r+0.5)*cell)
			var best := {}
			for i in range(DIRS):
				var a := TAU*i/DIRS
				var rim := rim_at(space,turf,p,Vector3(sin(a),0.0,-cos(a)))
				if rim.is_empty(): continue
				if best.is_empty() or float(rim.run_up) > float(best.run_up): best = rim
			if not best.is_empty(): found.append(best)
	found.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a.run_up) > float(b.run_up))
	var out: Array = []
	for rim: Dictionary in found:
		var ok := true
		for o: Dictionary in out:
			if (o.at as Vector3).distance_to(rim.at) < apart: ok = false
		if not ok: continue
		var face: Vector3 = rim.face
		var s := KitMotif.socket("rim","r%d_%s" % [out.size(),compass(face)],rim.at,face,step_in(),rim.run_up)
		s.lip = rim.lip
		out.append(s)
		if out.size() >= most: break
	return out

## The clear spots of the walked `grid` with `room` m at least, the
## roomiest first, each `apart` m from the others (at most `most`): [where
## (world), room].
static func spots(grid: Dictionary, room: PackedFloat32Array, least: float, apart: float, most: int) -> Array:
	var cols: int = grid.cols
	var cell: float = grid.cell
	var origin: Vector2 = grid.origin
	var y: PackedFloat32Array = grid.y
	var order: Array = []
	for k in range(room.size()):
		if room[k] >= least and room[k] < INF: order.append(k)
	order.sort_custom(func(a: int, b: int) -> bool: return room[a] > room[b])
	var out: Array = []
	for k: int in order:
		var p := Vector3(origin.x+(k%cols+0.5)*cell,y[k],origin.y+(k/cols+0.5)*cell)
		var ok := true
		for o: Array in out:
			if (o[0] as Vector3).distance_to(p) < apart: ok = false
		if not ok: continue
		out.append([p,room[k]])
		if out.size() >= most: break
	return out

static func compass(face: Vector3) -> String:
	var a := fposmod(rad_to_deg(atan2(face.x,-face.z)),360.0)
	return ["n","ne","e","se","s","sw","w","nw"][int(round(a/45.0))%8]
