extends "res://scripts/endless/hall_doors.gd"
## The tutorial's way out (scripts/endless/tutorial/tutorial_land.gd): the
## doors world's ruin hall (hall_doors.gd), its one mouth set down in the
## meadow where the lesson asks (`place`), the other the wilderness ruin by
## the start (HallSeat), on the tutorial world's two sides
## (profiles/tutorial.gd). A cracked wall (cracked_walls.gd, sized to the
## mouth) seals the meadow's mouth: until a surge roll breaks it the mouth is
## stone (hall_doors.gd `ground` with `_open` false).

## The cracked wall's handle (cracked_walls.gd `place`).
const WALL := "cracked/tutorial-mouth"

var wall_handle := WALL

## Built ahead (`warm`, at the lesson's start) so that the hall stands at
## WALL without a long frame: the bays' meshes and the four belfry towers on
## a worker (they hang on no ground; ~2.1 s of GDScript), the wilderness
## ruin's seat here (its ground is fixed). `place` takes them.
var _warm_task := -1
var _warm := {}
## The worker's own outputs (read on the main thread once it is joined).
var _w_parts := {}
var _w_towers := {}
## The meadow mouth's seat, built ahead of `place` (`seat_ready`): its ground
## sampled here GRID m apart over a few frames (GRID_MS a frame), then the
## seat built from that grid on a worker.
const GRID := 2.0
const GRID_X := Vector2(-112.0,102.0)
const GRID_Z := Vector2(-62.0,134.0)
const GRID_MS := 5.0
var _seat_task := -1
var _seat_key := []
var _seat_frame := Transform3D()
var _grid := PackedFloat32Array()
var _grid_rows := 0
var _seat_out: Node3D
var _steps_out := 0

## The hall's measures, from the host.
func _measure(host: Node3D) -> void:
	_host = host
	_world = host.world
	_field = host.field
	_big = WorldScale.opening(TOY_NAVE)/(2.0*Hall.ROW_Z)
	_bay = Hall.BAY*_big
	_room = (Hall.ROW_Z-Hall.ABACUS)*_big
	_roof = ROOF*_big
	_out = _bay*BAYS_OUT
	_foot = (Hall.WALL_Z+FOOT_OVER)*_big

## Starts building what does not hang on where the meadow mouth stands. The
## node stays out of the tree until `place`.
func warm(host: Node3D) -> void:
	if _warm_task != -1 or not _warm.is_empty(): return
	_measure(host)
	# Shared caches made here, not raced on the worker.
	RuinKit_.materials()
	_warm_task = WorkerThreadPool.add_task(_warm_build,false,"tutorial hall pieces")
	var frame := _frame_on(HallSeat.wild_at(),HallSeat.wild_in())
	var back := _out+HallSeat.BACK
	var land := func(x: float, z: float) -> float:
		var w: Vector3 = frame*Vector3(x,0.0,z)
		return float(_field.height(w.x,w.z))-frame.origin.y
	_steps[0] = HallSeat.courses(land,back)
	_warm.seat0 = HallSeat.build(4400,0.75,back,_steps[0],land,_kept,_room)
	_warm.frame0 = frame

## On the worker: plain data and nodes out of the tree.
func _warm_build() -> void:
	_w_parts = super._bays()
	for i in 2:
		for s: int in [-1,1]:
			var tower: Node3D = RuinKit_.piece("belfry_tower",4300+i*3+s,0.55)
			# Its body (2000 shapes) goes unused (_build_ruin drops it): freed
			# here, not carried into the tree.
			for b: Node in tower.find_children("*","StaticBody3D",true,false): b.free()
			_w_towers[4300+i*3+s] = tower

## Whether the warm pieces are built (joined once they are).
func warmed() -> bool:
	if _warm_task == -1: return true
	if not WorkerThreadPool.is_task_completed(_warm_task): return false
	WorkerThreadPool.wait_for_task_completion(_warm_task)
	_warm_task = -1
	_warm.parts = _w_parts
	_warm.towers = _w_towers
	return true

## Whether the meadow mouth's seat for a hall at `at` facing `inward` is
## built: asked each frame until it is (a new place starts it over).
func seat_ready(at: Vector2, inward: Vector2) -> bool:
	var key := [at,inward.normalized()]
	if key != _seat_key:
		_drop_seat()
		_seat_key = key
		_seat_frame = _frame_on(at,inward.normalized())
		_grid = PackedFloat32Array()
		_grid_rows = 0
	if _seat_out != null: return true
	if _seat_task != -1:
		if not WorkerThreadPool.is_task_completed(_seat_task): return false
		WorkerThreadPool.wait_for_task_completion(_seat_task)
		_seat_task = -1
		return true
	var nx := _grid_n(GRID_X)
	var nz := _grid_n(GRID_Z)
	if _grid.is_empty(): _grid.resize(nx*nz)
	var began := Time.get_ticks_usec()
	var f := _seat_frame
	while _grid_rows < nz and (Time.get_ticks_usec()-began)/1000.0 < GRID_MS:
		var z := GRID_Z.x+_grid_rows*GRID
		for i in nx:
			var w: Vector3 = f*Vector3(GRID_X.x+i*GRID,0.0,z)
			_grid[_grid_rows*nx+i] = float(_field.height(w.x,w.z))-f.origin.y
		_grid_rows += 1
	if _grid_rows < nz: return false
	_seat_task = WorkerThreadPool.add_task(_seat_build,false,"tutorial hall seat")
	return false

static func _grid_n(span: Vector2) -> int:
	return int(ceilf((span.y-span.x)/GRID))+1

## The sampled ground at (x, z) in the mouth's frame (bilinear; held at the edge).
func _grid_land(x: float, z: float) -> float:
	var nx := _grid_n(GRID_X)
	var nz := _grid_n(GRID_Z)
	var gx := clampf((x-GRID_X.x)/GRID,0.0,nx-1.001)
	var gz := clampf((z-GRID_Z.x)/GRID,0.0,nz-1.001)
	var ix := int(gx)
	var iz := int(gz)
	var fx := gx-ix
	var fz := gz-iz
	var a := lerpf(_grid[iz*nx+ix],_grid[iz*nx+ix+1],fx)
	var b := lerpf(_grid[(iz+1)*nx+ix],_grid[(iz+1)*nx+ix+1],fx)
	return lerpf(a,b,fz)

## On the worker: the meadow ruin's seat from the grid.
func _seat_build() -> void:
	var back := _out+HallSeat.BACK
	var land := Callable(self,"_grid_land")
	_steps_out = HallSeat.courses(land,back)
	_seat_out = HallSeat.build(4401,0.75,back,_steps_out,land,_kept,_room)

func _drop_seat() -> void:
	if _seat_task != -1:
		WorkerThreadPool.wait_for_task_completion(_seat_task)
		_seat_task = -1
	if _seat_out != null and _seat_out.get_parent() == null: _seat_out.free()
	_seat_out = null

## The warm pieces not used, freed (a hall never placed).
func discard() -> void:
	if _warm_task != -1:
		WorkerThreadPool.wait_for_task_completion(_warm_task)
		_warm_task = -1
		_warm.towers = _w_towers
	for t: Node in (_warm.get("towers",{}) as Dictionary).values(): t.free()
	var seat: Node = _warm.get("seat0")
	if seat != null and seat.get_parent() == null: seat.free()
	_warm.clear()
	_drop_seat()

func _kept(x: float, z: float) -> bool:
	if absf(x) < _foot-1.0 and z > -1.0: return true
	return absf(absf(x)-TOWER_X) < 14.0 and absf(z-TOWER_Z) < 14.0

func _bays() -> Dictionary:
	if _warm.has("parts"): return _warm.parts
	return super()

func _tower(seed_value: int) -> Node3D:
	var towers: Dictionary = _warm.get("towers",{})
	if towers.has(seed_value):
		var t: Node3D = towers[seed_value]
		towers.erase(seed_value)
		return t
	return super(seed_value)

func _seat(i: int, back: float, land: Callable, kept: Callable) -> Node3D:
	if i == 0 and _warm.has("seat0") and _warm.frame0 == _frames[0]:
		var seat: Node3D = _warm.seat0
		_warm.erase("seat0")
		return seat
	if i == 1 and _seat_out != null and _seat_frame == _frames[1]:
		var seat := _seat_out
		_seat_out = null
		_steps[1] = _steps_out
		return seat
	return super(i,back,land,kept)

## The hall, its meadow mouth at `at` (world XZ), its way in `inward` (XZ).
func place(host: Node3D, at: Vector2, inward: Vector2, seed: int) -> void:
	assert(warmed())
	name = "Doors"
	_measure(host)
	_rng.seed = seed*977+31
	_hint_wait = INF
	var coded: Array[Transform3D] = [_frame_on(HallSeat.wild_at(),HallSeat.wild_in()),_frame_on(at,inward.normalized())]
	walls = [
		{"name":"doors/amber-hall","find":"door/amber-hall","coded":coded[0],"white":Color.WHITE},
		{"name":"tutorial/meadow-hall","find":"door/tutorial-hall","coded":coded[1],"white":Color.WHITE},
	]
	for i in 2:
		walls[i].xform = coded[i]
		_frames.append(coded[i])
	_line()
	var far_mouth: Vector3 = _at_s(_len())
	_by = _frames[1].origin-_frames[0]*far_mouth
	var parts := _bays()
	for i in 2: walls[i].node = _build_ruin(i,parts)
	_build_hall(parts)
	_build_overlay()
	_make_lands()
	_seal()
	print("tutorial hall: its mouth at %s facing %s, out at %s, the hall %.0f m, the mouth %.1f m wide, %.1f m high" % [str(at.round()),str(inward.normalized()),str(_xz(0).round()),_len(),_room*2.0,_roof])

## The cracked wall across the meadow mouth: a chamber as wide and high as the
## mouth, standing just outside it, its front facing out.
func _seal() -> void:
	var cw: Node3D = _host.smash.walls
	var long := 10.0
	cw.place(wall_handle,Vector2(_frames[1].origin.x,_frames[1].origin.z),0.0)
	var site: Dictionary = cw.sites[wall_handle]
	var xf := _frames[1]*Transform3D(Basis(Vector3.UP,PI),Vector3(0.0,0.0,-(long+1.0)))
	site.xf = xf
	site.coded = xf
	site.wide = minf(_room*2.0+1.0,30.0)
	site.high = _roof+1.0
	site.long = long
	# A book that broke it in another run: sealed again for this one.
	site.open = false

## The meadow side's stone (the chamber) and the ruin: the mouth opens once the
## wall is broken.
func _open() -> bool:
	return super() and broken()

func broken() -> bool:
	return _host.smash.walls.is_broken(wall_handle)

## Where the mouth's middle stands (world), for a marker.
func mouth() -> Vector3:
	return _frames[1]*Vector3(0.0,_roof*0.5,0.0)

func side_at(p: Vector3) -> int:
	return int(_world.side(p.x,p.z))

## Whether the plane is through to the wilderness side.
func through() -> bool:
	return swaps > 0 and _side == 0
