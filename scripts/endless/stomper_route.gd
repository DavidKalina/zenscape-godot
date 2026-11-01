extends RefCounted
## The stomper's walk (stomper.gd): a closed loop round the spawn over ground it
## can stand on. A cost grid of the real land, then the cheapest ring round the
## spawn over it: one radius on each bearing, each near the last, so it can't
## double back. Smoothed to a line the body can turn along. Built once at setup,
## from the field alone, so the same seed walks the same loop.
##   walked(field, start)   the loop
##   at(s) / way(s)         the point and the unit direction `s` m along it
##   nearest(p)             the `s` closest to `p`

## The grid: a cell (m), cells across it.
const CELL := 80.0
const CELLS := 75
## How far apart (cells) the ground is compared for its rise, and the rise (m)
## past which a cell gets dear, then close to shut.
const REACH := 1
const EASY := 28.0
const HARD := 75.0
const HARD_COST := 300.0
## Cells kept off water, and how far over it the ground must stand (m).
const SHORE := 2
const DRY := 6.0
## The ring: bearings round the spawn, the radii open on each (m), how many radii
## it may move a bearing, what a metre of radius costs on each stretch, and what
## a stretch costs on or by the water (a price, so a ring still closes).
const BEARINGS := 28
const RADIUS_NEAR := 800.0
const RADIUS_STEP := 125.0
const RADII := 18
const RADIUS_MOVE := 3
const RADIUS_PRICE := 0.004
const WET_COST := 100000.0
## Points read along a stretch of the ring.
const STRETCH_READS := 6
## The line: its points' spacing (m), smoothing passes.
const SPACING := 40.0
const PASSES := 60

var points := PackedVector2Array()
var length := 0.0

static func walked(field: RefCounted, start: Vector2) -> RefCounted:
	var route: RefCounted = (load("res://scripts/endless/stomper_route.gd") as GDScript).new()
	route._build(field,start)
	return route

func at(s: float) -> Vector2:
	var i := fposmod(s,length)/SPACING
	var a := int(i)%points.size()
	return points[a].lerp(points[(a+1)%points.size()],i-floorf(i))

func way(s: float) -> Vector2:
	return (at(s+60.0)-at(s-60.0)).normalized()

func nearest(p: Vector2) -> float:
	var best := INF
	var out := 0.0
	for i in range(points.size()):
		var d := points[i].distance_squared_to(p)
		if d < best:
			best = d
			out = float(i)*SPACING
	return out

func _build(field: RefCounted, start: Vector2) -> void:
	var cost := _cost(field,start)
	var ring := _ring(cost)
	var raw := PackedVector2Array()
	for b in range(BEARINGS):
		raw.append(start+_spot(b,ring[b]))
	_line(raw)

func _origin(start: Vector2) -> Vector2:
	return start-Vector2.ONE*CELL*float(CELLS)*0.5

## Each cell's price: 1 on easy ground, rising with how much the ground varies
## round it; INF on and by the water.
func _cost(field: RefCounted, start: Vector2) -> PackedFloat32Array:
	var o := _origin(start)
	var high := PackedFloat32Array()
	var wet := PackedByteArray()
	high.resize(CELLS*CELLS)
	wet.resize(CELLS*CELLS)
	var sea := float(field.SEA_Y)+DRY
	for j in range(CELLS):
		for i in range(CELLS):
			var x := o.x+float(i)*CELL
			var z := o.y+float(j)*CELL
			var h := float(field.height(x,z))
			var river := float(field.river_y(x,z))
			high[j*CELLS+i] = h
			wet[j*CELLS+i] = 1 if h < sea or (not is_nan(river) and h < river+DRY) else 0
	var cost := PackedFloat32Array()
	cost.resize(CELLS*CELLS)
	for j in range(CELLS):
		for i in range(CELLS):
			var rise := 0.0
			var near_water := false
			for dj in range(-maxi(REACH,SHORE),maxi(REACH,SHORE)+1):
				for di in range(-maxi(REACH,SHORE),maxi(REACH,SHORE)+1):
					var c := clampi(j+dj,0,CELLS-1)*CELLS+clampi(i+di,0,CELLS-1)
					rise = maxf(rise,absf(high[c]-high[j*CELLS+i]))
					if wet[c] == 1: near_water = true
			var k := rise/EASY
			var price := 1.0+k*k*4.0
			if rise > HARD: price += HARD_COST
			cost[j*CELLS+i] = INF if near_water else price
	return cost

## Bearing `b`, radius index `r`, as a way from the spawn.
func _spot(b: int, r: int) -> Vector2:
	return Vector2.from_angle(TAU*float(b)/float(BEARINGS))*(RADIUS_NEAR+float(r)*RADIUS_STEP)

## The ring's radius index on each bearing: the cheapest closed ring, by dynamic
## programming from each radius on the first bearing.
func _ring(cost: PackedFloat32Array) -> PackedInt32Array:
	var moves := RADIUS_MOVE*2+1
	var stretch := PackedFloat32Array()
	stretch.resize(BEARINGS*RADII*moves)
	for b in range(BEARINGS):
		for r in range(RADII):
			for m in range(moves):
				var to := r+m-RADIUS_MOVE
				var i := (b*RADII+r)*moves+m
				stretch[i] = _stretch(cost,_spot(b,r),_spot((b+1)%BEARINGS,clampi(to,0,RADII-1))) if to >= 0 and to < RADII else INF
	var best := INF
	var out := PackedInt32Array()
	for first in range(RADII):
		var dist := PackedFloat32Array()
		dist.resize(RADII)
		dist.fill(INF)
		dist[first] = 0.0
		var back := PackedInt32Array()
		back.resize(BEARINGS*RADII)
		for b in range(BEARINGS):
			var next := PackedFloat32Array()
			next.resize(RADII)
			next.fill(INF)
			for r in range(RADII):
				if is_inf(dist[r]): continue
				for m in range(moves):
					var to := r+m-RADIUS_MOVE
					if to < 0 or to >= RADII: continue
					var through := dist[r]+stretch[(b*RADII+r)*moves+m]
					if through < next[to]:
						next[to] = through
						back[b*RADII+to] = r
			dist = next
		if dist[first] < best:
			best = dist[first]
			out.resize(BEARINGS)
			var r := first
			for b in range(BEARINGS-1,-1,-1):
				r = back[b*RADII+r]
				out[b] = r
	return out

## What it costs to walk from `a` to `b` (ways from the spawn).
func _stretch(cost: PackedFloat32Array, a: Vector2, b: Vector2) -> float:
	var sum := 0.0
	for i in range(STRETCH_READS):
		var p := a.lerp(b,(float(i)+0.5)/float(STRETCH_READS))/CELL+Vector2.ONE*float(CELLS)*0.5
		var x := int(round(p.x))
		var y := int(round(p.y))
		if x < 0 or y < 0 or x >= CELLS or y >= CELLS: sum += WET_COST
		else: sum += minf(cost[y*CELLS+x],WET_COST)
	return sum*a.distance_to(b)/CELL/float(STRETCH_READS)+a.distance_to(b)*(a.length()+b.length())*0.5*RADIUS_PRICE/CELL

## The ring's corners as an even closed line, smoothed so the body turns, not jogs.
func _line(raw: PackedVector2Array) -> void:
	points = _even(raw)
	for pass_i in range(PASSES):
		var next := PackedVector2Array()
		next.resize(points.size())
		var n := points.size()
		for i in range(n):
			next[i] = (points[(i+n-1)%n]+points[i]*2.0+points[(i+1)%n])*0.25
		points = next
		if pass_i%10 == 9: points = _even(points)
	points = _even(points)
	length = float(points.size())*SPACING

## A closed line at SPACING.
func _even(raw: PackedVector2Array) -> PackedVector2Array:
	var total := 0.0
	var n := raw.size()
	for i in range(n): total += raw[i].distance_to(raw[(i+1)%n])
	var count := maxi(int(round(total/SPACING)),3)
	var step := total/float(count)
	var out := PackedVector2Array()
	var i := 0
	var into := 0.0
	var run := raw[0].distance_to(raw[1%n])
	for k in range(count):
		var want := float(k)*step
		while want-into > run and i < n-1:
			into += run
			i += 1
			run = raw[i].distance_to(raw[(i+1)%n])
		out.append(raw[i].lerp(raw[(i+1)%n],clampf((want-into)/maxf(run,0.001),0.0,1.0)))
	return out
