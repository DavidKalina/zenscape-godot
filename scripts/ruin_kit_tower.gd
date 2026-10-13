extends RefCounted
class_name RuinKitTower
## The ruin kit's tower family (scripts/ruin_kit.gd, its Build and its
## stone): the broken shell of a square tower with a chimney inside, the
## fast line up. The turret's winding stair is the safe, slow way up a
## ruin; this is the quick one: in at the door, a jump at a side wall,
## then kick from wall to wall up the shaft to the rim.
##
## The tower shell: four coursed walls round a narrow shaft, a pointed
## door at the foot of its front (+Z), slit windows up its sides, a string
## course round its middle, a coping along its two side walls and snapped
## pinnacles on the corners where the head stands whole. The two side walls
## (east and west, facing each other across the shaft) are the kick walls:
## they always stand to the full height, KICK_GAP apart, and the motor
## (scripts/pilot_motor.gd) kicks between them all the way up. Weathered,
## the front and back walls are torn: breaches up them (a way out
## mid-climb, a sill to stand on, a place to fall out), their heads
## ragged, drifts of fallen stone at the foot. `open_side`: the back wall
## torn away to a low ragged line, the shaft a U open behind.
##
## The kick walls' faces walk and kick on clean, true hulls (as the kit's
## stair treads walk on `_walk_box`), not on their drawn stones: a worn,
## chipped, settled block's face would turn a kick askew or stop it, and a
## ray through a joint would miss the wall. The front and back walls keep
## their stones' own hulls (nothing is kicked off them), with true tops on
## their heads, sills and the threshold.
##
## Every piece, as the kit's: a Node3D, its foot on y 0 round the origin,
## front toward +Z, "Mesh" (stone and growth) and "Body" (hulls). No
## ornament glows. The gallery shows it (family "tower", F4); the tower
## shell study climbs it:
##   ./run-tower-shell.command [--tower-height=16] [--tower-weathered=1] [--tower-open]

const RuinKit = preload("res://scripts/ruin_kit.gd")
const PilotMotor = preload("res://scripts/pilot_motor.gd")
const PhysicsGround = preload("res://scripts/pilot_physics_ground.gd")
const WorldScale = preload("res://scripts/world_scale.gd")
const Build = RuinKit.Build

const PIECES := ["tower_shell"]

# --- The kick: what sets the shaft --------------------------------------------
# A kick off a wall (PilotMotor `_kick_off`) sends him up at sqrt(2 g
# WALL_JUMP) and out at WALL_KICK, the stick not steering for WALL_LOCK, his
# rise on GRAVITY uncut. He feels the far wall when his feet are WALL_PROBE
# from it, and he leaves the near one with his body (PhysicsGround RADIUS,
# by the walker's size) and its SKIN between him and it. So the far wall is
# felt after (gap - WALL_PROBE - RADIUS - SKIN) / WALL_KICK seconds.

## When he reaches the far wall, as a share of WALL_LOCK: inside the lock,
## so the stick never matters on the way across (pushed into the wall left
## behind, held off, or let go, he arrives all the same) and the motor
## takes hold of the wall he arrives at as a kick's (`kicked`); and still
## rising, well before the kick's top, so a press on the touch gains most
## of a kick and a late one still gains.
const ARRIVE := 0.85
## The kick's rise (m/s) and the seconds to the far wall.
static var KICK_RISE: float = sqrt(2.0*PilotMotor.GRAVITY*PilotMotor.WALL_JUMP)
static var KICK_TIME: float = PilotMotor.WALL_LOCK*ARRIVE
## His body's radius and its gap off a wall (by the walker's size).
static var BODY: float = PhysicsGround.RADIUS*WorldScale.wanderer+PhysicsGround.SKIN
## The shaft between the kick walls' faces (m): 1.98 at the defaults. A
## kick reaches the far wall 0.24 s out, rising at 2.3 m/s, 1.3 m up
## (KICK_GAIN); a press held to the kick's top gains WALL_JUMP (1.4).
static var KICK_GAP: float = PilotMotor.WALL_KICK*KICK_TIME+PilotMotor.WALL_PROBE+BODY
## The height a kick has gained when he touches the far wall (m), and his
## rise then (m/s).
static var KICK_GAIN: float = KICK_RISE*KICK_TIME-0.5*PilotMotor.GRAVITY*KICK_TIME*KICK_TIME
static var KICK_ARRIVE_RISE: float = KICK_RISE-PilotMotor.GRAVITY*KICK_TIME

# --- The shell ---------------------------------------------------------------

## The shaft's depth front to back (m, between the front and back walls'
## faces): room to walk in at the door, turn and jump at a side wall.
const DEPTH := 2.6
## The walls' thickness: the rim walked along the head (the kit's TOP_ROOM
## and more), a sill stood in a breach.
const WALL := 1.4
## The default height of the kick walls' heads (m).
const HEIGHT := 12.0
## The least height built (a shorter one is no tower).
const LOWEST := 5.0
## The door: clear half width, springing, the pointed head's rise.
const DOOR := Vector3(0.65,2.0,0.6)
## The slit windows: half width, height.
const SLIT := Vector2(0.09,1.0)
## The string course round the middle: its height as a share of the
## tower's, how far it stands out, its depth.
const BAND := Vector3(0.42,0.1,0.16)
## The battered plinth at the outer foot: its height, how far it stands out.
const PLINTH := Vector2(0.55,0.14)
## Breaches: the most (at weathered 1), their height at no wear and at full,
## their half width at no wear and at full; the lowest and highest they
## start (m from the foot, and under the head).
const BREACHES := 4
const BREACH_TALL := Vector2(1.5,2.6)
const BREACH_WIDE := Vector2(0.5,0.85)
const BREACH_FROM := 3.2
const BREACH_UNDER := 2.2
## The open side's torn line (m over the foot).
const OPEN_LINE := Vector2(1.0,4.0)

## The outer half extents (x, z), the plinth and string course left out:
## 2.39 by 2.7 m at the defaults (4.78 by 5.4).
static func half_extents() -> Vector2:
	return Vector2(KICK_GAP*0.5+WALL,DEPTH*0.5+WALL)

## The piece with PIECES id `id`.
static func piece(id: String, seed_value: int, weathered := 0.0) -> Node3D:
	match id:
		"tower_shell": return tower_shell(seed_value,weathered)
	return null

## The tower shell, `height` m to its kick walls' heads (LOWEST at least),
## `open_side`: its back wall torn away. Meta:
##   "shaft"     AABB, the shaft between the walls' inner faces
##   "kick_gap"  the kick walls' faces apart (m), "kick_gain" a kick's gain
##   "rim"       the kick walls' least standing head (m)
##   "lips"      [[from, to], ...]: the kick walls' heads' inner edges, the
##               lips the last kick catches
##   "door"      the door's foot on the front face (x, 0, z), "door_size"
##               (clear width, height to the head's point)
##   "footprint" the outer size (x, z), plinth left out
##   "breaches"  [AABB, ...]: each breach through its wall
static func tower_shell(seed_value: int, weathered := 0.0, height := HEIGHT, open_side := false) -> Node3D:
	var b := Build.new(seed_value,weathered,"TowerShell")
	var h := maxf(height,LOWEST)
	var w := KICK_GAP*0.5
	var dz := DEPTH*0.5
	var d := WALL*0.5
	var outer := half_extents()
	var ox := outer.x
	var oz := outer.y
	var course := 0.42
	# The kick walls (east, west): their local x runs along the world's z,
	# their local +z out of the tower. Built first, so their stones' hulls
	# (the first in the Build) can be taken out for the clean faces.
	var kick_poses: Array[Transform3D] = [Transform3D(Basis(Vector3.UP,PI*0.5),Vector3(w+d,0.0,0.0)),Transform3D(Basis(Vector3.UP,-PI*0.5),Vector3(-(w+d),0.0,0.0))]
	var kick_tops: Array[Callable] = []
	for k in range(2):
		# Whole to the height, always: the climb's walls, their heads the
		# rim and its lips (the front and back walls carry the ruin).
		var top := func(_x: float) -> float: return h
		kick_tops.append(top)
		# Two slits up each, staggered: light in the shaft (drawn only: the
		# clean face is solid across them).
		var s0 := 2.4+0.7*k
		var s1 := h*0.58+0.5*k
		var slits := func(y: float) -> Vector2:
			if (y > s0 and y < s0+SLIT.y) or (y > s1 and y < s1+SLIT.y): return Vector2(0.0,SLIT.x)
			return Vector2(0.0,-1.0)
		RuinKit._courses(b,kick_poses[k],-dz,dz,-0.3,top,d,slits,course,true)
	b.hulls.clear()
	b.hull_anchors.clear()
	# Their clean faces: a true slab a strip at a time, the head following
	# the drawn one (each strip at the lower of its ends).
	var rim := INF
	for k in range(2):
		var x := -dz
		while x < dz-0.01:
			var x1 := minf(x+0.25,dz)
			var top := minf(float(kick_tops[k].call(x)),float(kick_tops[k].call(x1)))
			rim = minf(rim,top)
			RuinKit._walk_hull(b,kick_poses[k],[Plane(Vector3.LEFT,-x),Plane(Vector3.RIGHT,x1),Plane(Vector3.UP,top),Plane(Vector3.DOWN,0.3),Plane(Vector3.BACK,d),Plane(Vector3.FORWARD,d)])
			x = x1
	# The breaches: up the front and back walls by turns (all on the front
	# with the back torn away), each its own height band.
	var count := int(round(weathered*BREACHES))
	var front_holes: Array = []
	var back_holes: Array = []
	var span := (h-BREACH_UNDER)-BREACH_FROM
	for i in range(count):
		var tall := lerpf(BREACH_TALL.x,BREACH_TALL.y,weathered)*b.rng.randf_range(0.85,1.15)
		var slot := span/count
		var y0 := BREACH_FROM+slot*i+b.rng.randf_range(0.0,maxf(0.0,slot-tall))
		y0 = minf(y0,h-BREACH_UNDER-tall*0.5)
		var half := minf(lerpf(BREACH_WIDE.x,BREACH_WIDE.y,weathered)*b.rng.randf_range(0.85,1.15),w+0.1)
		var c := b.rng.randf_range(-0.25,0.25)
		c = clampf(c,-(w+0.15-half),w+0.15-half)
		var breach := [y0,y0+tall,c,half,b.rng.randf()*TAU]
		if open_side or i%2 == 0: front_holes.append(breach)
		else: back_holes.append(breach)
	# The front (+Z) and back walls: across the whole width, their local x the
	# world's x (the back's turned round), +z out.
	var front_pose := Transform3D(Basis.IDENTITY,Vector3(0.0,0.0,dz+d))
	var back_pose := Transform3D(Basis(Vector3.UP,PI),Vector3(0.0,0.0,-(dz+d)))
	var walls := [[front_pose,front_holes,true],[back_pose,back_holes,false]]
	var tops: Array[Callable] = []
	var breaches: Array[AABB] = []
	for wall: Array in walls:
		var pose: Transform3D = wall[0]
		var holes: Array = wall[1]
		var door: bool = wall[2]
		var top := RuinKit._worn_top(b,-ox,ox,h,course)
		if not door and open_side:
			top = RuinKit._ruin_line(b,-ox,ox,OPEN_LINE.x,OPEN_LINE.y*b.rng.randf_range(0.8,1.1),1.0,true)
		elif weathered > 0.25:
			top = RuinKit._ruin_line(b,-ox,ox,h-lerpf(0.6,4.0,weathered),h,weathered)
		tops.append(top)
		var hole := func(y: float) -> Vector2:
			if door and y < DOOR.y: return Vector2(0.0,DOOR.x)
			if door and y < DOOR.y+DOOR.z: return Vector2(0.0,DOOR.x*sqrt(maxf(0.0,1.0-pow((y-DOOR.y)/DOOR.z,2.0))))
			for br: Array in holes:
				var y0: float = br[0]
				var y1: float = br[1]
				if y <= y0 or y >= y1: continue
				var u := (y-y0)/(y1-y0)
				# Torn: a near-flat sill, full through its middle, a ragged
				# point at its head.
				var shape := minf(1.0,0.55+u*4.5) if u < 0.55 else sqrt(maxf(0.0,(1.0-u)/0.45))
				var rag := 1.0+0.12*sin(u*17.0+float(br[4]))
				return Vector2(float(br[2]),float(br[3])*shape*rag)
			return Vector2(0.0,-1.0)
		RuinKit._courses(b,pose,-ox,ox,-0.3,top,d,hole,course,false)
		# The head walked on a true top where it stands whole.
		var x := -ox
		while x < ox-0.01:
			var x1 := minf(x+0.5,ox)
			var head := minf(float(top.call(x)),float(top.call(x1)))
			if head > h-0.45:
				RuinKit._walk_hull(b,pose,[Plane(Vector3.LEFT,-x),Plane(Vector3.RIGHT,x1),Plane(Vector3.UP,head-0.06),Plane(Vector3.DOWN,-(head-0.6)),Plane(Vector3.BACK,d),Plane(Vector3.FORWARD,d)])
			x = x1
		# The sills stood on (a way out), true; the threshold.
		for br: Array in holes:
			var y0: float = br[0]
			var c: float = br[2]
			var half: float = br[3]
			RuinKit._walk_hull(b,pose,[Plane(Vector3.LEFT,-(c-half*0.6)),Plane(Vector3.RIGHT,c+half*0.6),Plane(Vector3.UP,y0),Plane(Vector3.DOWN,-(y0-0.4)),Plane(Vector3.BACK,d),Plane(Vector3.FORWARD,d)])
			var a := pose*Vector3(c-half,y0,-d)
			var z := pose*Vector3(c+half,float(br[1]),d)
			breaches.append(AABB(Vector3(minf(a.x,z.x),y0,minf(a.z,z.z)),Vector3(absf(z.x-a.x),float(br[1])-y0,absf(z.z-a.z))))
		if door: RuinKit._walk_hull(b,pose,[Plane(Vector3.LEFT,DOOR.x),Plane(Vector3.RIGHT,DOOR.x),Plane(Vector3.UP,0.0),Plane(Vector3.DOWN,0.3),Plane(Vector3.BACK,d+0.3),Plane(Vector3.FORWARD,d)])
	# The door's head: a pointed lintel in two slanting halves over the hole.
	if float(tops[0].call(0.0)) > DOOR.y+DOOR.z+0.5:
		for s: float in [-1.0,1.0]:
			var planes: Array[Plane] = [Plane(Vector3.BACK,d+0.04),Plane(Vector3.FORWARD,d+0.04),Plane(Vector3.UP,DOOR.y+DOOR.z+0.25)]
			planes.append(Plane(Vector3.RIGHT*s,DOOR.x+0.35))
			planes.append(Plane(-Vector3.RIGHT*s,0.0))
			# Its underside on the head's point, from the springing up.
			var slant := Vector3.DOWN-Vector3.RIGHT*s*(DOOR.z/DOOR.x)
			planes.append(Plane(slant.normalized(),-(DOOR.y+DOOR.z)/slant.length()))
			b.solid(planes,front_pose,RuinKit._stone(b,1.06),false)
	# The floor of the shaft: flags, drawn; walked on a true slab.
	var fx := -w
	while fx < w-0.05:
		var fx1 := minf(w,fx+b.rng.randf_range(0.55,0.8))
		if w-fx1 < 0.3: fx1 = w
		var fz := -dz
		while fz < dz-0.05:
			var fz1 := minf(dz,fz+b.rng.randf_range(0.5,0.8))
			if dz-fz1 < 0.3: fz1 = dz
			var top := -0.01-b.rng.randf_range(0.0,0.025)*(0.4+weathered)
			b.solid(RuinKit._box(b,Vector3((fx1-fx)*0.5-0.01,0.09,(fz1-fz)*0.5-0.01)),Transform3D(Basis.IDENTITY,Vector3((fx+fx1)*0.5,top-0.09,(fz+fz1)*0.5)),RuinKit._stone(b,0.9),false,true,[],-1,0.5)
			fz = fz1
		fx = fx1
	RuinKit._walk_hull(b,Transform3D.IDENTITY,[Plane(Vector3.LEFT,w+0.05),Plane(Vector3.RIGHT,w+0.05),Plane(Vector3.FORWARD,dz+0.05),Plane(Vector3.BACK,dz+0.05),Plane(Vector3.UP,0.0),Plane(Vector3.DOWN,0.3)])
	# Round the outside: the battered plinth and the string course, drawn
	# only (nothing to snag a wall run or a slide down the faces).
	var band := h*BAND.x
	for k in range(4):
		var turn := k*PI*0.5
		var pose := Transform3D(Basis(Vector3.UP,turn),Vector3.ZERO)
		var out := oz if k%2 == 0 else ox
		var along := ox if k%2 == 0 else oz
		# The face's standing head along it (the front's and back's own
		# lines; the kick walls whole), and what is open in it.
		var head := func(x: float) -> float:
			var p := pose*Vector3(x,0.0,out)
			if p.z >= dz: return float(tops[0].call(p.x))
			if p.z <= -dz: return float(tops[1].call(-p.x))
			# The east kick wall's x runs down the world's z, the west's up it.
			return float(kick_tops[0].call(-p.z)) if p.x > 0.0 else float(kick_tops[1].call(p.z))
		var holes: Array = front_holes if k == 0 else (back_holes if k == 2 else [])
		var open := func(x0: float, x1: float, y0: float, y1: float) -> bool:
			if k == 0 and y0 < DOOR.y+DOOR.z+0.1 and x1 > -DOOR.x-0.1 and x0 < DOOR.x+0.1: return true
			for br: Array in holes:
				var c: float = br[2]
				if y1 > float(br[0])-0.2 and y0 < float(br[1])+0.2 and x1 > c-float(br[3])-0.1 and x0 < c+float(br[3])+0.1: return true
			return false
		var x := -along-PLINTH.y
		while x < along+PLINTH.y-0.05:
			var x1 := minf(along+PLINTH.y,x+b.rng.randf_range(0.9,1.5))
			if along+PLINTH.y-x1 < 0.4: x1 = along+PLINTH.y
			if not open.call(x,x1,0.0,PLINTH.x) and minf(float(head.call(clampf(x,-along,along))),float(head.call(clampf(x1,-along,along)))) > PLINTH.x:
				var planes: Array[Plane] = [Plane(Vector3.LEFT,-x),Plane(Vector3.RIGHT,x1),Plane(Vector3.DOWN,0.3),Plane(Vector3.UP,PLINTH.x),Plane(Vector3.BACK,out+PLINTH.y),Plane(Vector3.FORWARD,-(out-0.2))]
				var m := (Vector3.BACK+Vector3.UP*1.4).normalized()
				planes.append(Plane(m,m.dot(Vector3(0.0,PLINTH.x,out+0.01))))
				b.solid(planes,pose*RuinKit._settle(b,Vector3.ZERO,0.2),RuinKit._stone(b,0.92),false)
			x = x1
		x = -along-BAND.y
		while x < along+BAND.y-0.05:
			var x1 := minf(along+BAND.y,x+b.rng.randf_range(0.8,1.3))
			if along+BAND.y-x1 < 0.35: x1 = along+BAND.y
			if not open.call(x,x1,band,band+BAND.z) and minf(float(head.call(clampf(x,-along,along))),float(head.call(clampf(x1,-along,along)))) > band+0.35:
				var planes: Array[Plane] = [Plane(Vector3.LEFT,-x),Plane(Vector3.RIGHT,x1),Plane(Vector3.DOWN,-band),Plane(Vector3.UP,band+BAND.z),Plane(Vector3.BACK,out+BAND.y),Plane(Vector3.FORWARD,-(out-0.2))]
				var m := (Vector3.BACK+Vector3.UP*1.2).normalized()
				planes.append(Plane(m,m.dot(Vector3(0.0,band+BAND.z,out+0.02))))
				b.solid(planes,pose,RuinKit._stone(b,1.06),false)
			x = x1
	# Snapped pinnacles on the corners where the head stands whole.
	for sx: float in [-1.0,1.0]:
		for sz: float in [-1.0,1.0]:
			var x := sx*(ox-0.35)
			var top: float = float(tops[0].call(x)) if sz > 0.0 else float(tops[1].call(-x))
			if top < h-0.05: continue
			RuinKit._spire(b,Transform3D(Basis.IDENTITY,Vector3(x,top,sz*(oz-0.35))),0.3,2.2,weathered > 0.15 or b.rng.randf() < 0.5)
	# The fallen: drifts either side of the door and under the breaches, the
	# way in left clear.
	for s: float in [-1.0,1.0]:
		RuinKit._drift(b,Vector3(s*(ox+0.3),0.0,oz+0.6),1.0,int(weathered*4.0))
	for br: AABB in breaches:
		var c := br.get_center()
		RuinKit._drift(b,Vector3(signf(c.x+0.01)*ox*0.8,0.0,signf(c.z)*(oz+0.6)),0.8,int(weathered*3.0))
	# (Kept within a metre or so of the walls: the footprint is the slot's.)
	RuinKit._rubble(b,maxf(ox,oz)+0.2,int(round(weathered*b.rng.randf_range(4.0,7.0))))
	var node := b.finish()
	node.set_meta("shaft",AABB(Vector3(-w,0.0,-dz),Vector3(KICK_GAP,h,DEPTH)))
	node.set_meta("kick_gap",KICK_GAP)
	node.set_meta("kick_gain",KICK_GAIN)
	node.set_meta("rim",rim)
	node.set_meta("lips",[[Vector3(w,rim,-dz),Vector3(w,rim,dz)],[Vector3(-w,rim,-dz),Vector3(-w,rim,dz)]])
	node.set_meta("door",Vector3(0.0,0.0,oz))
	node.set_meta("door_size",Vector2(DOOR.x*2.0,DOOR.y+DOOR.z))
	node.set_meta("footprint",outer*2.0)
	node.set_meta("breaches",breaches)
	return node
