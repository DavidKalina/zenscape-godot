extends RefCounted
## The Sundered hall's overgrowth (docs/scenic/sundered-hall.md, "Overgrowth"):
## the ruin kit's wind-blown growth (scripts/ruin_growth.gd,
## shaders/ruin_growth.gdshader) laid on thick over the flown hall, on top of
## what the kit grows at its in-world detail.
##
## Inside a bay (`bay`, through Hall `bay`'s plan "dress"): vine curtains
## from the roof beams, the architraves, the high ties and the edges of
## broken roofs (the plane threads them and parts them; the low ties, the
## knife slits and the breaches are kept clear), ivy down the columns and
## the inner walls, strands spilling off the broken roof's edges into the
## light. Outside: leaf mats on the wall heads with ivy cascading down the
## outer walls, and down the gables' faces. Off a torn bay line: drapes over
## the snapped columns and torn walls.
##
## Under the hall (`podium`, `torn`): ivy down the podium's faces, and long
## vines trailing off the torn ends into the void over the cloud sea. The
## apse (`apse`): its snapped ring draped and the tower cascading from its
## ragged head. Far (`far_bay`, `far_torn`): a cheap hint, a few hanging
## strips and mats in the growth's material (they sway too).
##
## Growth only, never solid: the stone and the hulls are as without it. It
## draws on its own random stream, so the kit's own ivy and moss are as
## before. Probing the stone (where a strand hugs a face, where an underside
## is) goes through `Probe`, a grid over the piece's blocks, as the kit's own
## probe walks every block.

const RuinKit = preload("res://scripts/ruin_kit.gd")
const Hall = preload("res://scripts/ruin_kit_hall.gd")
const RuinGrowth = preload("res://scripts/ruin_growth.gd")

## How much is grown (0 none: the kit's own growth only; 1 as tuned): the
## game's --overgrowth=<x> (--overgrowth=0 to compare), or set before a
## piece is built (the near build reads it on a worker).
static var amount := _from_args()

static func _from_args() -> float:
	for a: String in preload("res://scripts/launch_args.gd").user_args():
		if a.begins_with("--overgrowth="): return maxf(0.0,float(a.trim_prefix("--overgrowth=")))
	return 1.0
## How overgrown each act is (its share of `amount`).
const ACTS := {"gate":0.8,"nave":0.8,"shafts":0.8,"cloister":1.0,"slit":0.8,"apse":0.85}
## The lane the line flies (hall z, m, and up to y over the floor): the low
## ties' curtains and the breaches' keep out of it (the inner columns'
## line to the outer row's, up to 0.6 over the low ties' soffit).
static var LANE := Vector2(Hall.INNER_Z,Hall.ROW_Z)
static var LANE_TOP: float = Hall.TIE_LOW+0.6
## Beam curtains: the spots across the nave (z) tried at each bay line, as
## shares of BEAM_REACH (the outer columns' faces, 0.2 m in: 11.2 m when
## the spots were laid by hand at ROW_Z 12.6, 12.0 at ROW_Z 13.4), the
## odds of one, its strands at most and the asked length (RuinGrowth
## `curtain` hangs 1.8 x that + 0.6 m).
const BEAM_SHARES := [-1.0,-0.696,-0.393,-0.089,0.214,0.5,0.75,1.0]
static var BEAM_REACH: float = Hall.ROW_Z-Hall.COLUMN_R-0.2
static var BEAM_SPOTS: Array = BEAM_SHARES.map(func(k: float) -> float: return k*BEAM_REACH)
## Tie curtains: the spots across the nave (z), evenly out to TIE_REACH (a
## column's width in from the outer columns' faces: the toy hall's 7 m).
static var TIE_REACH: float = Hall.ROW_Z-Hall.COLUMN_R*2.0
static var TIE_SPOTS: Array = [-TIE_REACH,-TIE_REACH*0.5,0.0,TIE_REACH*0.5,TIE_REACH]
const BEAM_ODDS := 0.4
const BEAM_MOST := 7
const BEAM_LENGTH := Vector2(1.4,3.2)
## The longest a hanging curtain may be (m).
const CURTAIN_LONGEST := 7.0
## Ivy down a column: strands a column (a range) and their length.
const COLUMN_STRANDS := Vector2i(0,2)
const COLUMN_LENGTH := Vector2(2.0,5.5)
## Outer cascades: rows a wall a bay, strands a row, spacing, length as a
## share of the wall's height.
const CASCADE_ROWS := Vector2(1.2,2.2)
const CASCADE_STRANDS := Vector2i(4,6)
const CASCADE_SPACING := Vector2(0.24,0.34)
const CASCADE_SHARE := Vector2(0.3,0.6)
## Leaves and their spacing on what is mostly seen from further off (the
## columns, the inner walls): RuinGrowth `strand` coarse; coarser still on
## what is seen from outside (the outer faces, the podium, the torn ends).
const COARSE := 1.4
const COARSE_OUT := 1.75
## Torn ends: strands along the lip (m between clumps), their length.
const TORN_CLUMP := Vector2(1.6,3.0)
const TORN_LENGTH := Vector2(6.0,15.0)
## Far: strips a wall a bay, their width and length range.
const FAR_STRIPS := 3
const FAR_WIDTH := Vector2(0.7,1.5)

# --- A bay -----------------------------------------------------------------------

## Dresses a hall bay (Hall `bay`, plan "dress"): `b` its Build with all its
## stone laid (straight, x 0..BAY along, z across, y up from the floor);
## `plan` its plan, with "growth" (its density, by act).
static func bay(b, plan: Dictionary) -> void:
	var d: float = float(plan.get("growth",1.0))*amount
	if d <= 0.0: return
	var keep_rng: RandomNumberGenerator = b.rng
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([keep_rng.seed,"sundered growth"])
	b.rng = rng
	var keep_lean: bool = b.lean
	var probe := Probe.new(b)
	var soffit := Hall.COLUMN_H+Hall.BEAM.x
	var torn: int = plan.get("torn",0)
	var roof: String = plan.get("roof","whole")
	var breach: Vector2i = plan.get("breach",Vector2i.ZERO)
	# The flown lane under LANE_Y's top and the flyable breaches' corridors
	# (Hall `breach_box`) are kept clear: every strand in the bay, this
	# growth's and the kit's own, stops at them (Build `clear`).
	b.clear.append(AABB(Vector3(-1.0,-2.0,Hall.LANE.x),Vector3(Hall.BAY+2.0,Hall.LANE_Y.y+2.0,Hall.LANE.y-Hall.LANE.x)))
	for k in range(2):
		var kind: String = Hall.BREACHES[breach[k]]
		if kind in ["","door"]: continue
		var s := -1.0 if k == 0 else 1.0
		b.clear.append(Hall.breach_box(kind,s,b.floor_at(Hall.BAY*0.5,s*Hall.WALL_Z)))
	var lines: Array = [0.0]
	if bool(plan.get("last",false)): lines.append(Hall.BAY)
	var slit: bool = plan.get("screen",false)
	for x: float in lines:
		var torn_line := (x == 0.0 and torn & 1 != 0) or (x > 0.0 and torn & 2 != 0)
		var zs: Array = [-Hall.ROW_Z,Hall.ROW_Z]
		if x == 0.0: zs.append_array(plan.get("inner",[]))
		probe.label = "columns"
		for z: float in zs: _column_ivy(probe,Vector3(x,0.0,z),d,torn_line)
		# Curtains along the roof beam across.
		probe.label = "beams"
		if (bool(plan.get("beam",true)) or x > 0.0) and not torn_line:
			for z: float in BEAM_SPOTS:
				if rng.randf() > BEAM_ODDS*d: continue
				# Clear of the knife slit's screen under it.
				if slit and x == 0.0 and z < -Hall.INNER_Z+0.6 and z > -Hall.ROW_Z-0.6: continue
				var at := Vector3(x+rng.randf_range(-0.2,0.2),0.0,z+rng.randf_range(-0.8,0.8))
				RuinGrowth.curtain(probe,at,rng.randf_range(BEAM_LENGTH.x,BEAM_LENGTH.y),Hall.COLUMN_H,BEAM_MOST,CURTAIN_LONGEST,true)
			if (x == 0.0 and bool(plan.get("gable",false))) or (x > 0.0 and bool(plan.get("last_gable",false))):
				probe.label = "gables"
				_gable_drape(probe,x,d)
	# The tie across the nave: a high one curtained over the lane too, a low
	# one only off it (the way under it stays open).
	var tie: String = plan.get("tie","")
	probe.label = "ties"
	if tie != "" and torn & 1 == 0:
		var tie_y := Hall.TIE_LOW if tie == "low" else Hall.TIE_HIGH
		for z: float in TIE_SPOTS:
			if rng.randf() > 0.45*d: continue
			var in_lane := z+0.8 > LANE.x and z-0.8 < LANE.y
			if tie == "low" and in_lane: continue
			var room := tie_y-LANE_TOP if in_lane else tie_y-0.6
			if room < 0.9: continue
			RuinGrowth.curtain(probe,Vector3(rng.randf_range(-0.15,0.15),0.0,z+rng.randf_range(-0.6,0.6)),minf(rng.randf_range(0.5,1.3),(room-0.6)/RuinGrowth.LENGTH_GAIN),tie_y,5,room,true)
	# The architraves along the rows.
	probe.label = "architraves"
	var architraves: Vector2 = plan.get("architraves",Vector2.ONE)
	for k in range(2):
		if architraves[k] < 0.5 or rng.randf() > 0.45*d: continue
		RuinGrowth.curtain(probe,Vector3(rng.randf_range(1.6,Hall.BAY-1.6),0.0,Hall.ROW_Z*(k*2-1)),rng.randf_range(1.0,2.4),Hall.COLUMN_H,5,CURTAIN_LONGEST,true)
	# The broken roof's edges: curtains under them and strands spilling over
	# them into the light.
	if roof == "broken" or (roof == "whole" and not (plan.get("gaps",[]) as Array).is_empty()):
		probe.label = "roof edges"
		_roof_edges(probe,soffit,d)
	# The walls: ivy down their inner faces, mats on their heads and ivy
	# cascading down their outer faces.
	for k in range(2):
		var s := -1.0 if k == 0 else 1.0
		var kind: String = Hall.BREACHES[breach[k]]
		_walls(probe,s,kind,roof,soffit,d*(1.4 if torn != 0 else 1.0))
	b.lean = keep_lean
	b.rng = keep_rng
	b.grow = PackedFloat32Array()

## Ivy down a column from under its capital (or its snapped head): a few
## strands hugging the drums round it; a mat on a snapped head.
static func _column_ivy(probe: Probe, foot: Vector3, d: float, snapped: bool) -> void:
	var rng := probe.rng
	var top := Hall.COLUMN_H-Hall.CAPITAL_H-0.15
	if snapped:
		top = probe.top_at(foot.x,foot.z,Hall.COLUMN_H+0.5)
		if top < 0.5: return
		_mat(probe,Vector3(foot.x,top,foot.z),Vector3.UP,rng.randi_range(2,4),Hall.COLUMN_R*0.6)
		top -= 0.12
	var n := int(round(rng.randf_range(COLUMN_STRANDS.x,COLUMN_STRANDS.y+0.49)*d))
	var turn := rng.randf()*TAU
	for i in range(n):
		var a := turn+TAU*i/maxf(n,1)+rng.randf_range(-0.4,0.4)
		var out := Vector3(cos(a),0.0,sin(a))
		var start := foot+out*(Hall.COLUMN_R+0.12)
		start.y = top-rng.randf_range(0.0,1.5)
		if probe._inside(start): continue
		var l := minf(rng.randf_range(COLUMN_LENGTH.x,COLUMN_LENGTH.y),start.y-0.2)
		RuinGrowth.strand(probe,start,l,out,false,COARSE,true)

## Drapes down a gable's two faces from its ragged head.
static func _gable_drape(probe: Probe, x: float, d: float) -> void:
	var rng := probe.rng
	for s: float in [-1.0,1.0]:
		var rows := int(round(rng.randf_range(0.8,2.2)*d))
		for r in range(rows):
			var z0 := rng.randf_range(-Hall.WALL_Z+2.0,Hall.WALL_Z-2.0)
			var count := rng.randi_range(2,4)
			for j in range(count):
				var z := z0+(j-count*0.5)*0.3
				var top := probe.top_at(x,z,Hall.ROOF_TOP+Hall.GABLE_RISE+1.5)
				if top < Hall.ROOF_TOP+0.4: continue
				var out := Vector3(s,0.0,0.0)
				var start := Vector3(x+s*0.4,top-0.05,z)
				if probe._inside(start):
					start.x += s*0.35
					if probe._inside(start): continue
				if j == 0: _mat(probe,Vector3(x,top,z),Vector3.UP,2,0.4)
				RuinGrowth.strand(probe,start,rng.randf_range(1.5,top-Hall.ROOF_TOP+0.5),out,false,COARSE,true)

## The broken roof's edges, found by looking across it: a curtain under
## the slab beside a gap now and then, and strands spilling over its edge
## down into the gap's light.
static func _roof_edges(probe: Probe, soffit: float, d: float) -> void:
	var rng := probe.rng
	var mid_y := soffit+Hall.SLAB*0.5
	for x: float in [Hall.BAY*0.28,Hall.BAY*0.72]:
		var was := probe._inside(Vector3(x,mid_y,-Hall.WALL_Z))
		var z := -Hall.WALL_Z+0.3
		while z <= Hall.WALL_Z:
			var now := probe._inside(Vector3(x,mid_y,z))
			if now != was:
				# An edge: stone on the side `back`, the gap toward `out`.
				var out := Vector3(0.0,0.0,1.0 if was else -1.0)
				var edge := z-0.15
				if rng.randf() < 0.25*d:
					RuinGrowth.curtain(probe,Vector3(x+rng.randf_range(-0.8,0.8),0.0,edge-out.z*0.45),rng.randf_range(0.9,2.4),soffit,5,CURTAIN_LONGEST,true)
				if rng.randf() < 0.4*d:
					var count := rng.randi_range(2,4)
					var x0 := x+rng.randf_range(-1.2,1.2)
					var top := soffit+Hall.SLAB
					_mat(probe,Vector3(x0,top+0.01,edge-out.z*0.3),Vector3.UP,rng.randi_range(2,4),0.6)
					for j in range(count):
						var start := Vector3(x0+(j-count*0.5)*0.28,top-0.04,edge+out.z*0.1)
						for nudge in range(6):
							if not probe._inside(start): break
							start.z += out.z*0.1
						if probe._inside(start): continue
						RuinGrowth.strand(probe,start,rng.randf_range(1.6,4.2),out,false,1.0,true)
				was = now
			z += 0.3

## A wall's growth (side `s`, its breach `kind`): ivy down its inner face
## (from under the roof, or over its head), a mat on its head and rows
## cascading down its outer face; beside an opening, never across it.
static func _walls(probe: Probe, s: float, kind: String, roof: String, soffit: float, d: float) -> void:
	var rng := probe.rng
	var opening := kind in ["arch","door"]
	var half := Hall.BAY*0.5
	var clear := (Hall.ARCH.x*0.5+0.9) if kind == "arch" else (Hall.DOOR.x*0.5+0.7)
	var pick := func() -> float:
		for attempt in range(6):
			var x := rng.randf_range(1.3,Hall.BAY-1.3)
			if not opening or absf(x-half) > clear: return x
		return -1.0
	var inner_z := s*(Hall.WALL_Z-Hall.WALL_THICK*0.5-0.08)
	var outer_z := s*(Hall.WALL_Z+Hall.WALL_THICK*0.5+0.08)
	# Inner face.
	probe.label = "inner walls"
	for r in range(int(round(rng.randf_range(0.8,1.9)*d))):
		var x: float = pick.call()
		if x < 0.0: continue
		var top := probe.top_at(x,s*Hall.WALL_Z,Hall.ROOF_TOP+2.5)
		if top < 1.2: continue
		var from := minf(top,soffit)-0.12
		for j in range(rng.randi_range(3,4)):
			var start := Vector3(x+(j-1.5)*0.28,from,inner_z)
			if probe._inside(start): continue
			RuinGrowth.strand(probe,start,minf(rng.randf_range(2.0,5.5),from-0.2),Vector3(0.0,0.0,-s),false,COARSE_OUT,true)
	# Outer cascades: rows from the head.
	probe.label = "cascades"
	var rows := int(round(rng.randf_range(CASCADE_ROWS.x,CASCADE_ROWS.y)*d))
	if kind in ["low","collapse"]: rows = mini(rows,1)
	for r in range(rows):
		var x0: float = pick.call()
		if x0 < 0.0: continue
		var count := rng.randi_range(CASCADE_STRANDS.x,CASCADE_STRANDS.y)
		var spacing := rng.randf_range(CASCADE_SPACING.x,CASCADE_SPACING.y)
		var share := rng.randf_range(CASCADE_SHARE.x,CASCADE_SHARE.y)
		var matted := false
		for j in range(count):
			var x := x0+(j-(count-1)*0.5)*spacing
			if opening and absf(x-half) < clear-0.4: continue
			var top := probe.top_at(x,s*Hall.WALL_Z,Hall.ROOF_TOP+2.5)
			if top < 0.8: continue
			if not matted:
				_mat(probe,Vector3(x0,top+0.01,s*(Hall.WALL_Z+Hall.WALL_THICK*0.25)),Vector3.UP,rng.randi_range(3,5),count*spacing*0.5)
				matted = true
			var start := Vector3(x,top-0.06,outer_z)
			if probe._inside(start): continue
			var t := (j+0.5)/count
			var l := top*share*(0.55+0.45*sin(PI*t))*rng.randf_range(0.8,1.1)
			RuinGrowth.strand(probe,start,maxf(l,0.8),Vector3(0.0,0.0,s),false,COARSE_OUT,true)

## A leaf mat: `count` ivy clumps lying round `at` within `reach`, only
## fluttering (the kit's own leaf clumps).
static func _mat(probe: Probe, at: Vector3, face: Vector3, count: int, reach: float) -> void:
	var b = probe.build
	var rng := probe.rng
	b.grow = RuinGrowth.attrs(0.0,0.0,Vector3.ZERO,0.0,0.35,fposmod(at.x*3.17+at.z*5.31,1.0),false,0.6)
	for j in range(count):
		var on := at+Vector3(rng.randf_range(-reach,reach),0.02,rng.randf_range(-reach,reach)*0.5)
		b._leaf(on,face,rng.randf_range(RuinKit.IVY_LEAF.x,RuinKit.IVY_LEAF.y)*1.2,0.0)
	b.grow = PackedFloat32Array()

# --- Under the hall -------------------------------------------------------------

## The podium's growth (its Build `b`, straight path space, `length` m):
## ivy down its long faces from their top, now and then.
static func podium(b, length: float, top_y: float, face_z: float, d: float) -> void:
	d *= amount
	if d <= 0.0: return
	var keep_rng: RandomNumberGenerator = b.rng
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([keep_rng.seed,"sundered podium growth"])
	b.rng = rng
	var probe := Probe.new(b)
	probe.label = "podium"
	for s: float in [-1.0,1.0]:
		var x := rng.randf_range(0.5,3.0)
		while x < length-0.5:
			var count := rng.randi_range(2,4)
			_mat(probe,Vector3(x,top_y+0.01,s*(face_z-0.2)),Vector3.UP,2,0.5)
			for j in range(count):
				var start := Vector3(x+(j-count*0.5)*0.3,top_y-0.06,s*(face_z+0.08))
				for nudge in range(8):
					if not probe._inside(start): break
					start.z += s*0.1
				if probe._inside(start): continue
				RuinGrowth.strand(probe,start,rng.randf_range(2.0,5.0),Vector3(0.0,0.0,s),false,COARSE_OUT,true)
			x += rng.randf_range(12.0,20.0)/maxf(d,0.3)
	b.rng = keep_rng
	b.grow = PackedFloat32Array()

## A torn end's growth (at path x `x`, `out` +1 past it, -1 before it): long
## vines over its lip, hugging the hanging stacks and trailing free under
## them into the void, in clumps along the lip; mats on its edge.
static func torn(b, x: float, out: float, top_y: float, half_z: float, d: float) -> void:
	d *= amount
	if d <= 0.0: return
	var keep_rng: RandomNumberGenerator = b.rng
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([keep_rng.seed,"sundered torn growth",x])
	b.rng = rng
	var probe := Probe.new(b)
	probe.label = "torn"
	var way := Vector3(out,0.0,0.0)
	var z := -half_z+rng.randf_range(0.2,1.2)
	while z < half_z:
		var count := rng.randi_range(2,5)
		var longest := rng.randf_range(TORN_LENGTH.x,TORN_LENGTH.y)
		var matted := false
		for j in range(count):
			var zz := z+(j-count*0.5)*0.32+rng.randf_range(-0.05,0.05)
			# The lip here: the outermost stone a little under the top.
			var lip := -INF
			var t := -2.0
			while t < 2.6:
				if probe._inside(Vector3(x+out*t,top_y-0.4,zz)): lip = t
				t += 0.1
			if lip == -INF: continue
			if not matted:
				_mat(probe,Vector3(x+out*(lip-0.3),top_y+0.02,zz),Vector3.UP,rng.randi_range(2,4),0.5)
				matted = true
			var start := Vector3(x+out*(lip+0.14),top_y-0.08,zz)
			if probe._inside(start): continue
			var l := longest*(0.45+0.55*sin(PI*(j+0.5)/count))*rng.randf_range(0.75,1.1)
			RuinGrowth.strand(probe,start,l,way,false,COARSE_OUT,true)
		z += rng.randf_range(TORN_CLUMP.x,TORN_CLUMP.y)/maxf(d,0.3)
	b.rng = keep_rng
	b.grow = PackedFloat32Array()

## The apse's growth (its Build `b`, its frame set back to identity; `f`
## the frame the apse was built in, the tower's middle and height in it;
## the ring's columns): ivy cascading down the tower's four faces from its
## ragged head, drapes over the snapped ring.
static func apse(b, f: Transform3D, middle: Vector3, half: float, high: float, columns: Array, d: float) -> void:
	d *= amount
	if d <= 0.0: return
	var keep_rng: RandomNumberGenerator = b.rng
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([keep_rng.seed,"sundered apse growth"])
	b.rng = rng
	var probe := Probe.new(b)
	probe.label = "apse"
	for c: Vector3 in columns:
		var foot := f*Vector3(c.x,0.0,c.z)
		var top := probe.top_at(foot.x,foot.z,c.y+1.0)
		if top < 0.5: continue
		_mat(probe,Vector3(foot.x,top,foot.z),Vector3.UP,rng.randi_range(2,3),Hall.COLUMN_R*0.6)
		for i in range(rng.randi_range(1,3)):
			var a := rng.randf()*TAU
			var o := Vector3(cos(a),0.0,sin(a))
			var start := foot+o*(Hall.COLUMN_R+0.12)+Vector3.UP*(top-0.15)
			if probe._inside(start): continue
			RuinGrowth.strand(probe,start,minf(rng.randf_range(2.0,6.0),top-0.3),o,false,COARSE,true)
	for k in range(4):
		var turn := Basis(Vector3.UP,PI*0.5*k)
		var o := (f.basis*(turn*Vector3(0.0,0.0,1.0))).normalized()
		for r in range(int(round(rng.randf_range(2.0,3.6)*d))):
			var u := rng.randf_range(-half+0.6,half-0.6)
			var count := rng.randi_range(3,6)
			for j in range(count):
				var p := f*(middle+turn*Vector3(u+(j-count*0.5)*0.3,0.0,half))
				var top := probe.top_at(p.x,p.z,high+2.0)
				if top < 2.0: continue
				if j == 0: _mat(probe,p+Vector3.UP*(top+0.01),Vector3.UP,3,0.5)
				var start := p+o*(Hall.WALL_THICK*0.5+0.08)+Vector3.UP*(top-0.06)
				if probe._inside(start): continue
				RuinGrowth.strand(probe,start,top*rng.randf_range(0.35,0.85),o,false,COARSE_OUT,true)
	b.rng = keep_rng
	b.grow = PackedFloat32Array()

# --- Far ----------------------------------------------------------------------------

## A far bay's hint (its far Build `b`, the bay's start `x0`, its walls'
## heads `highs` (left, right)): a few hanging strips down each wall's
## outer face and a mat on its head; they sway in the growth's material.
static func far_bay(b, x0: float, highs: Vector2, rng: RandomNumberGenerator) -> void:
	if amount <= 0.0: return
	for k in range(2):
		var s := -1.0 if k == 0 else 1.0
		var high := highs[k]
		if high < 2.5: continue
		var z := s*(Hall.WALL_Z+Hall.WALL_THICK*0.5+0.1)
		for i in range(FAR_STRIPS):
			var x := x0+rng.randf_range(1.0,Hall.BAY-1.0)
			var w := rng.randf_range(FAR_WIDTH.x,FAR_WIDTH.y)
			var l := high*rng.randf_range(0.4,0.85)
			_strip(b,Vector3(x,high,z),Vector3(0.0,0.0,s),w,l,rng)
		# A mat along the head.
		var mx := x0+rng.randf_range(1.5,Hall.BAY-1.5)
		b.grow = RuinGrowth.attrs(0.0,0.0,Vector3.ZERO,0.0,0.3,rng.randf(),false,0.6)
		var hz := s*Hall.WALL_Z
		var mw := Hall.WALL_THICK*0.5+0.12
		b.growth_face(PackedVector3Array([Vector3(mx-1.4,high+0.05,hz-mw),Vector3(mx+1.4,high+0.05,hz-mw),Vector3(mx+1.6,high+0.05,hz+mw),Vector3(mx-1.6,high+0.05,hz+mw)]),Vector3.UP,_green(rng,0.3))
	b.grow = PackedFloat32Array()

## A far torn end's hint: long thin strips trailing off the lip into the void.
static func far_torn(b, x: float, out: float, top_y: float, half_z: float, rng: RandomNumberGenerator) -> void:
	if amount <= 0.0: return
	var z := -half_z+rng.randf_range(0.5,2.0)
	while z < half_z:
		_strip(b,Vector3(x+out*0.3,top_y,z),Vector3(out,0.0,0.0),rng.randf_range(0.25,0.5),rng.randf_range(TORN_LENGTH.x,TORN_LENGTH.y),rng)
		z += rng.randf_range(1.8,3.4)

## One far strip: a tapered hanging ribbon from `top`, `w` wide, `l` long,
## off the face looking `out`; root dark, tip light (the growth's gradient).
static func _strip(b, top: Vector3, out: Vector3, w: float, l: float, rng: RandomNumberGenerator) -> void:
	var side := Vector3(-out.z,0.0,out.x)
	b.grow = RuinGrowth.attrs(top.y,l,out,0.6,0.5,rng.randf())
	var c := _green(rng,0.5)
	var a := top-side*w*0.5
	var e := top+side*w*0.5
	var m0 := top-side*w*0.38+Vector3.DOWN*l*0.55+out*0.05
	var m1 := top+side*w*0.38+Vector3.DOWN*l*0.55+out*0.05
	var tip := top+side*rng.randf_range(-0.2,0.2)*w+Vector3.DOWN*l+out*0.1
	b.growth_face(PackedVector3Array([a,e,m1,m0]),out,c)
	b.growth_face(PackedVector3Array([m0,m1,tip]),out,c)

static func _green(rng: RandomNumberGenerator, shade: float) -> Color:
	var k := clampi(int((shade+rng.randf_range(-0.25,0.25))*RuinGrowth.VINE.size()),0,RuinGrowth.VINE.size()-1)
	var c: Color = (RuinGrowth.VINE[k] as Color).srgb_to_linear()
	c.a = 1.0
	return c

# --- Probing ------------------------------------------------------------------------

## The stone of a Build as RuinGrowth's strands probe it (`_inside`, `_gap`,
## `floor_at`), through a grid over its blocks; growth faces go to the Build.
## RuinGrowth's `strand` and `curtain` take it in place of the Build.
class Probe extends RefCounted:
	const CELL := 1.5
	## Triangles grown by label while `measuring` (a tool's breakdown;
	## `label` set by who grows).
	static var measuring := false
	static var tally := {}
	var label := ""
	var build
	var rng: RandomNumberGenerator
	var grid := {}
	var lean: bool:
		get: return build.lean
	var grow: PackedFloat32Array:
		get: return build.grow
		set(value): build.grow = value

	func _init(b) -> void:
		build = b
		rng = b.rng
		var solids: Array = b.solids
		for i in range(solids.size()):
			var box: AABB = solids[i][0]
			for cx in range(floori(box.position.x/CELL),floori(box.end.x/CELL)+1):
				for cy in range(floori(box.position.y/CELL),floori(box.end.y/CELL)+1):
					for cz in range(floori(box.position.z/CELL),floori(box.end.z/CELL)+1):
						var key := Vector3i(cx,cy,cz)
						if not grid.has(key): grid[key] = PackedInt32Array()
						grid[key].append(i)

	func _inside(p: Vector3) -> bool:
		var key := Vector3i(floori(p.x/CELL),floori(p.y/CELL),floori(p.z/CELL))
		if not grid.has(key): return false
		var solids: Array = build.solids
		for i in grid[key]:
			var s: Array = solids[i]
			if not (s[0] as AABB).has_point(p): continue
			var inside := true
			for plane: Plane in s[1]:
				if plane.distance_to(p) > 0.0:
					inside = false
					break
			if inside: return true
		return false

	func _gap(p: Vector3, dir: Vector3, most: float) -> float:
		var t := 0.0
		while t < most:
			if _inside(p+dir*t): return t
			t += 0.04
		return most

	func floor_at(x: float, z: float) -> float:
		return build.floor_at(x,z)

	func kept_clear(p: Vector3) -> bool:
		return build.kept_clear(p)

	func growth_face(corners: PackedVector3Array, normal: Vector3, colour: Color) -> void:
		build.growth_face(corners,normal,colour)
		if measuring: tally[label] = int(tally.get(label,0))+corners.size()-2

	func card_face(corners: PackedVector3Array, uvs: PackedVector2Array, normal: Vector3, colour: Color, cell: int) -> void:
		build.card_face(corners,uvs,normal,colour,cell)
		if measuring: tally[label] = int(tally.get(label,0))+corners.size()-2

	## The top of the stone over (x, z) looking down from `from` (to 4 cm),
	## or -1 if none above the floor.
	func top_at(x: float, z: float, from: float) -> float:
		var y := from
		var low: float = build.floor_at(x,z)+0.1
		while y > low:
			if _inside(Vector3(x,y,z)):
				var up := y
				while up < from and _inside(Vector3(x,up+0.04,z)): up += 0.04
				return up
			y -= 0.25
		return -1.0
