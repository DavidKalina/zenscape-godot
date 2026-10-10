extends SceneTree
## A plan of a flight station for laying out moments (scripts/flight_pack_moments.gd),
## headless, no window: a cut through the stone at the natural line's own
## height, seen from above (north up). Stone at the line's height is dark,
## stone within ABOVE m over it blue (a roof, a tie, a lintel), within
## BELOW m under it brown (a floor, a sill). The line is drawn white with a
## tick every second of flight (red every fifth); free moments gold, the
## starter magenta, challenge ones orange-red.
##   godot --headless --path . -s tools/flight_moments_plan.gd -- --station moments_bend [--px 0.4] [--out /tmp/plan]
## Writes <out>_<station>.png.

const Course = preload("res://scripts/flight_course.gd")
const Metrics = preload("res://scripts/flight_metrics.gd")

const ABOVE := 3.0
const BELOW := 3.0
const MARGIN := 14.0
const CELL := 8.0

func _initialize() -> void:
	main.call_deferred()

func main() -> void:
	var args := OS.get_cmdline_user_args()
	var ids := PackedStringArray()
	var px := 0.4
	var out := "/tmp/plan"
	for i in range(args.size()):
		if args[i] == "--station" and i+1 < args.size(): ids = args[i+1].split(",")
		if args[i] == "--px" and i+1 < args.size(): px = float(args[i+1])
		if args[i] == "--out" and i+1 < args.size(): out = args[i+1]
	for id in ids: plan(Course.station(id),px,"%s_%s.png" % [out,id])
	quit(0)

static func plan(s: Dictionary, px: float, path: String) -> void:
	var entry := Course.entry(s)
	var line := Metrics.line(entry.position,entry.heading,Course.tokens(s))
	var all := Course.solids(s)
	var low := Vector2(INF,INF)
	var high := Vector2(-INF,-INF)
	for q: Dictionary in line:
		var p: Vector3 = q.p
		low = Vector2(minf(low.x,p.x),minf(low.y,p.z))
		high = Vector2(maxf(high.x,p.x),maxf(high.y,p.z))
	for m: Dictionary in Course.moments(s):
		low = Vector2(minf(low.x,m.at.x),minf(low.y,m.at.z))
		high = Vector2(maxf(high.x,m.at.x),maxf(high.y,m.at.z))
	low -= Vector2(MARGIN,MARGIN)
	high += Vector2(MARGIN,MARGIN)
	var w := ceili((high.x-low.x)/px)
	var h := ceili((high.y-low.y)/px)
	# Solids bucketed by plan cell, and line samples too (for the height).
	var cells := {}
	for solid: Dictionary in all:
		var m: Vector3 = solid.middle
		var r: float = (solid.size as Vector3).length()*0.5 if solid.kind == "box" else float(solid.radius)
		for cx in range(floori((m.x-r-low.x)/CELL),floori((m.x+r-low.x)/CELL)+1):
			for cz in range(floori((m.z-r-low.y)/CELL),floori((m.z+r-low.y)/CELL)+1):
				var key := Vector2i(cx,cz)
				if not cells.has(key): cells[key] = []
				cells[key].append(solid)
	var img := Image.create(w,h,false,Image.FORMAT_RGB8)
	img.fill(Color(0.93,0.93,0.9))
	var heights := {}
	for q: Dictionary in line:
		var key := Vector2i(floori(((q.p as Vector3).x-low.x)/CELL),floori(((q.p as Vector3).z-low.y)/CELL))
		if not heights.has(key): heights[key] = []
		heights[key].append(q.p)
	for y in range(h):
		for x in range(w):
			var at := Vector2(low.x+(x+0.5)*px,low.y+(y+0.5)*px)
			var cell := Vector2i(floori((at.x-low.x)/CELL),floori((at.y-low.y)/CELL))
			var near := INF
			var ly := 0.0
			for dx in range(-2,3):
				for dz in range(-2,3):
					for p: Vector3 in heights.get(cell+Vector2i(dx,dz),[]):
						var d := Vector2(p.x,p.z).distance_squared_to(at)
						if d < near:
							near = d
							ly = p.y
			if near > MARGIN*MARGIN: continue
			var mine: Array = cells.get(cell,[])
			if mine.is_empty(): continue
			var colour := Color.TRANSPARENT
			for pair: Array in [[0.0,Color(0.2,0.2,0.22)],[ABOVE,Color(0.55,0.68,0.9)],[-BELOW,Color(0.75,0.62,0.45)]]:
				var p := Vector3(at.x,ly+float(pair[0]),at.y)
				var hit := false
				for solid: Dictionary in mine:
					if Course.distance(solid,p) < 0.0:
						hit = true
						break
				if hit:
					colour = pair[1]
					break
			if colour.a > 0.0: img.set_pixel(x,y,colour)
	var to_px := func(p: Vector3) -> Vector2i: return Vector2i(floori((p.x-low.x)/px),floori((p.z-low.y)/px))
	var arc := 0.0
	var tick := 0.0
	for i in range(line.size()):
		var p: Vector3 = line[i].p
		if i > 0: arc += p.distance_to(line[i-1].p)
		_dot(img,to_px.call(p),1,Color.WHITE)
		if arc >= tick:
			var second := roundi(tick/Metrics.CRUISE)
			_dot(img,to_px.call(p),3 if second%5 == 0 else 2,Color(0.9,0.1,0.1) if second%5 == 0 else Color(0.1,0.1,0.1))
			tick += Metrics.CRUISE
	var colours := {"free":Color(1.0,0.75,0.1),"starter":Color(0.95,0.2,0.85),"challenge":Color(1.0,0.35,0.15)}
	for m: Dictionary in Course.moments(s):
		var r := maxi(2,roundi(float(m.reach)/px))
		_ring(img,to_px.call(m.at),r,colours.get(m.role,Color.BLACK))
		_dot(img,to_px.call(m.at),2,colours.get(m.role,Color.BLACK))
	img.save_png(path)
	print("plan %s: %dx%d px at %.2f m, x %.0f..%.0f z %.0f..%.0f (local x %.0f, z %.0f at the top left)" % [path,w,h,px,low.x,high.x,low.y,high.y,low.x-Course.origin(s).x,low.y-Course.origin(s).z])

static func _dot(img: Image, c: Vector2i, r: int, colour: Color) -> void:
	for dx in range(-r,r+1):
		for dy in range(-r,r+1):
			var q := c+Vector2i(dx,dy)
			if q.x >= 0 and q.y >= 0 and q.x < img.get_width() and q.y < img.get_height(): img.set_pixel(q.x,q.y,colour)

static func _ring(img: Image, c: Vector2i, r: int, colour: Color) -> void:
	for k in range(64):
		var a := TAU*k/64.0
		var q := c+Vector2i(roundi(cos(a)*r),roundi(sin(a)*r))
		if q.x >= 0 and q.y >= 0 and q.x < img.get_width() and q.y < img.get_height(): img.set_pixel(q.x,q.y,colour)
