extends RefCounted
## The ruin kit's colossus hall (scripts/ruin_kit.gd, the same stone, wear
## and growth): a dim hypostyle hall, after the shrine halls of
## Shadow of the Colossus, cut in the kit's facets. Massive drum columns far
## thicker than the abbey's clustered piers, on deep moulded bases, their
## drums carved in bands (a ring of roundels, a band of pointed niche
## panels with a boss in each) under a flared capital and a square abacus;
## deep architrave beams in two fasciae under a crown moulding, a row of
## roundels along them; heavy flat roof slabs laid over the beams, cracked,
## the light coming in through the cracks and the gaps. The carving is
## raised and sunk facets, never fine detail.
##
## Scale: columns BAY apart, their faces 5.7 m clear (THREAD and more), the
## beams' soffits COLUMN_H up: a plane flies through the hall under the
## roof. The back wall's slit (KNIFE) is narrower than the plane's span and
## taller than it: only a plane on a knife edge (scripts/sky_plane.gd's
## knife-edge lean) slips through it. Weathered, a bay's corner column has
## snapped and the roof over that corner come down: a fallen slab leans up
## onto the sagging beams, a way up onto the roof.
##   ./run-ruin-kit.command  (F3 frames the hall)

const RuinKit = preload("res://scripts/ruin_kit.gd")
const Build = RuinKit.Build
const PlaneFigure = preload("res://scripts/plane_figure.gd")

const PIECES := RuinKit.HALL_PIECES

# --- Scale -------------------------------------------------------------------

## Column middle to column middle (m), along X and Z alike.
const BAY := 8.0
## A column: its drums' apothem (16 sides; 2.1 m across, near three times
## the clustered pier's), and its height from the floor to the abacus's top
## (the beams' soffit).
const COLUMN_R := 1.05
const COLUMN_H := 7.0
## The base: the plinth's height (a step, under STEP_UP) and half width;
## the whole moulded base's height (plinth, two tori round a scotia, a
## fillet).
const PLINTH := Vector2(0.42,1.45)
const BASE_H := 1.09
## The capital: its height (necking, the flared echinus, the abacus) and
## the abacus's half width (TOP_ROOM and far more).
const CAPITAL_H := 0.98
const ABACUS := 1.5
## The carved bands' heights: the niche band and the roundel band.
const NICHE_BAND := 1.25
const ROUNDEL_BAND := 0.7
## A beam: its depth and half width (its top is walked: TOP_ROOM and more).
const BEAM := Vector2(1.0,0.78)
## The roof slabs' thickness; the roof's top.
const SLAB := 0.5
const ROOF_TOP := COLUMN_H+1.0+SLAB
## The paving: its slabs' thickness (stepped onto) and rough size.
const PAVING := Vector2(0.18,1.6)
## The back wall: its thickness. The slit through it, the knife-edge gap:
## clear width (about the plane's height on its wingtip, its fuselage and
## wheels, ~1 m, and under its span SPAN 1.4: a level plane cannot pass),
## the sill's height and the clear height to the head's springing (the
## span on edge, 1.4, and a margin over and under it).
const WALL_THICK := 1.0
const KNIFE := Vector3(1.15,1.0,3.3)
## The assembled hall's walls: the end wall's gate (clear width, sill,
## height to the springing, the arc's radius as a share of the width), its
## middle's place along Z (the plane's corridor through the hall), and the
## front wall's lancet.
const GATE := Vector4(4.4,0.0,3.4,0.8)
const GATE_AT := -0.5
const LANCET := Vector4(1.8,1.4,2.8,1.0)
## The ruined corner: the snapped column's height; the beams that rested on
## it drop to it (their tops a walkable slope, 22 degrees), and a fallen
## slab leans from a heap at its foot up onto them: RAMP its slope.
const SNAP := 3.4
const RAMP := deg_to_rad(33.0)

# --- The pieces -----------------------------------------------------------------

static func piece(id: String, seed_value: int, weathered := 0.0) -> Node3D:
	match id:
		"hall_column": return column(seed_value,weathered)
		"hall_beam": return beam(seed_value,weathered)
		"hall_slab": return slabs(seed_value,weathered)
		"hall_bay": return bay(seed_value,weathered)
	return null

## 6. A colossus column: a deep moulded base, the shaft in drums (a plain
## drum, the band of pointed niche panels, a plain drum, the ring of
## roundels), the capital's necking, echinus and abacus. Weathered, it is
## snapped partway, its upper drums and capital lying round its foot.
static func column(seed_value: int, weathered := 0.0) -> Node3D:
	var b := Build.new(seed_value,weathered,"HallColumn")
	var broken := INF
	if weathered > 0.2: broken = lerpf(COLUMN_H-1.2,2.4,clampf(weathered*b.rng.randf_range(0.75,1.1),0.0,1.0))
	var lost := _column(b,Transform3D.IDENTITY,broken)
	if broken < INF:
		# What fell: the drums over the break, lying parted, the capital
		# tipped on its side past them.
		var x := 1.6
		var yaw := b.rng.randf_range(-0.3,0.3)
		for drum: Array in lost:
			var lie := Basis(Vector3.UP,yaw)*Basis(Vector3.BACK,-PI*0.5)*Basis(Vector3.UP,b.rng.randf()*TAU)
			var at := Basis(Vector3.UP,yaw)*Vector3(x,0.0,1.1)+Vector3(0.0,COLUMN_R*0.96,0.0)
			_drum(b,Transform3D(lie,at),str(drum[0]),float(drum[1]),RuinKit._break(b,float(drum[1]),COLUMN_R,0.2,0.0) if b.rng.randf() < 0.4 else [])
			x += float(drum[1])+b.rng.randf_range(0.1,0.4)
		# Upside down on its abacus, a little askew, as a capital comes to rest.
		_capital(b,Transform3D(Basis(Vector3.UP,b.rng.randf()*TAU)*Basis(Vector3.RIGHT,PI-b.rng.randf_range(0.08,0.2)),Vector3(-2.2,0.92,1.8)))
		RuinKit._drift(b,Vector3(-1.4,0.0,-1.0),1.2,3+int(weathered*4.0))
	_feet(b,Vector3.ZERO,PLINTH.y+0.3,int(2+weathered*6.0))
	RuinKit._rubble(b,2.2,int(round(weathered*b.rng.randf_range(3.0,6.0))))
	return b.finish()

## 7. An architrave beam as the hall lays one from column to column: two
## fasciae under a crown moulding, a row of roundels along its faces, here
## resting on two abacus stones. Weathered, cracked through, its one end
## dropped off its bearing to the ground.
static func beam(seed_value: int, weathered := 0.0) -> Node3D:
	var b := Build.new(seed_value,weathered,"HallBeam")
	var length := BAY*0.85
	var bearing := 0.4
	for s: float in [-1.0,1.0]:
		b.solid(RuinKit._box(b,Vector3(ABACUS*0.7,bearing*0.5,ABACUS*0.7)),RuinKit._settle(b,Vector3(s*(length*0.5-0.9),bearing*0.5,0.0),0.4),RuinKit._stone(b,1.02))
	if weathered > 0.3:
		# Cracked through, the right part dropped off its bearing.
		var at := b.rng.randf_range(-0.6,0.6)
		var cut := Vector3(1.0,0.0,b.rng.randf_range(-0.2,0.2)).normalized()
		_beam(b,Transform3D(Basis.IDENTITY,Vector3(0.0,bearing,0.0)),length,[Plane(cut,at-0.03)])
		var drop := Transform3D(Basis(Vector3.BACK,-atan2(bearing,length*0.5))*Basis(Vector3.UP,b.rng.randf_range(-0.12,0.12)),Vector3(0.12,0.0,b.rng.randf_range(-0.2,0.2)))
		_beam(b,Transform3D(drop.basis,Vector3(0.0,bearing,0.0)+drop.origin),length,[Plane(-cut,-at-0.03)])
		RuinKit._drift(b,Vector3(at,0.0,BEAM.y+0.9),1.0,int(weathered*5.0))
	else:
		_beam(b,Transform3D(Basis.IDENTITY,Vector3(0.0,bearing,0.0)),length)
	_feet(b,Vector3(0.0,0.0,BEAM.y+0.4),length*0.5,int(1+weathered*5.0))
	RuinKit._rubble(b,length*0.5,int(round(weathered*b.rng.randf_range(2.0,5.0))))
	return b.finish()

## 8. Roof slabs: a panel of the heavy slabs laid as the roof has them,
## here on two sleeper beams: cracked even as they lie (one split, one gap
## a hand wide). Weathered, slabs gone, one broken in two and its half
## tipped up against the next, its cracked edge to the sky.
static func slabs(seed_value: int, weathered := 0.0) -> Node3D:
	var b := Build.new(seed_value,weathered,"HallSlabs")
	var sleeper := 0.36
	for s: float in [-1.0,1.0]:
		b.solid(RuinKit._box(b,Vector3(BAY*0.36,sleeper*0.5,0.42)),RuinKit._settle(b,Vector3(0.0,sleeper*0.5,s*1.6),0.4),RuinKit._stone(b,0.92))
	_roof(b,-BAY*0.36,BAY*0.36,-2.4,2.4,sleeper,{"strips":3,"rows":1,"gone":[[0,0]] if weathered > 0.5 else [],"tipped":weathered > 0.4})
	_feet(b,Vector3(0.0,0.0,2.8),BAY*0.3,int(1+weathered*5.0))
	RuinKit._rubble(b,3.4,int(round(weathered*b.rng.randf_range(3.0,6.0))))
	return b.finish()

## 9. A hall bay: four columns BAY apart (`columns`: bit 0 the back left,
## 1 the back right, 2 the front left, 3 the front right; a bay set beside
## another leaves out the two it shares), the architraves on them and a
## middle beam, the slab roof over all, a paved floor, and the back wall between the back columns, through
## it the knife-edge slit (`slit`). Weathered, the roof is gapped (the
## light comes down in shafts), the back wall's head torn down, the paving
## broken and grassed; `corner`: the front right column snapped and the
## roof over its corner come down, a slab leaning up onto the beams.
static func bay(seed_value: int, weathered := 0.0, columns := 15, slit := true, corner := true) -> Node3D:
	var b := Build.new(seed_value,weathered,"HallBay")
	var h := BAY*0.5
	var ruined := corner and weathered > 0.45 and (columns & 8) != 0
	var at := [Vector3(-h,0.0,-h),Vector3(h,0.0,-h),Vector3(-h,0.0,h),Vector3(h,0.0,h)]
	for k in range(4):
		if not columns & (1 << k): continue
		_column(b,Transform3D(Basis.IDENTITY,at[k]),SNAP if ruined and k == 3 else INF)
	var soffit := COLUMN_H
	# The beams: front and back along X, the sides along Z (where the bay has
	# its columns), the middle beam across; ruined, those on the snapped
	# column dropped to it.
	var left := (columns & 5) != 0
	var right := (columns & 10) != 0
	if (columns & 3) != 0: _beam(b,Transform3D(Basis.IDENTITY,Vector3(0.0,soffit,-h)),BAY)
	if (columns & 12) != 0:
		if ruined: _beam(b,_sag(Vector3(-h,soffit,h),Vector3(h,SNAP,h)),BAY)
		else: _beam(b,Transform3D(Basis.IDENTITY,Vector3(0.0,soffit,h)),BAY)
	var turn := Basis(Vector3.UP,PI*0.5)
	if left: _beam(b,Transform3D(turn,Vector3(-h,soffit-0.02,0.0)),BAY)
	if right:
		if ruined: _beam(b,_sag(Vector3(h,soffit-0.02,-h),Vector3(h,SNAP-0.02,h)),BAY)
		else: _beam(b,Transform3D(turn,Vector3(h,soffit-0.02,0.0)),BAY)
	var middle := Transform3D(Basis.IDENTITY,Vector3(0.0,soffit+0.25,0.0))
	if ruined:
		# Its far end went down with the side beam: snapped off, lying in
		# front, rolled.
		var snap := Vector3(1.0,b.rng.randf_range(-0.4,0.4),b.rng.randf_range(-0.3,0.3)).normalized()
		_beam(b,middle,BAY-0.2,[Plane(snap,1.5)],0.75)
		_beam(b,Transform3D(Basis(Vector3.UP,b.rng.randf_range(0.2,0.5))*Basis(Vector3.BACK,0.12)*Basis(Vector3.RIGHT,1.4),Vector3(2.6,0.75,2.5)),2.3,[],0.75)
	else:
		_beam(b,middle,BAY-0.2,[],0.75)
	# The roof: three strips along X by two rows along Z. Whole, cracked;
	# weathered, a slab or two gone; ruined, all but the back of the left
	# two strips down (what rested on the dropped beams).
	var gone: Array = []
	if ruined: gone = [[2,0],[2,1],[1,1],[0,1]]
	if weathered > 0.25:
		var extra := [b.rng.randi_range(0,2),b.rng.randi_range(0,1)]
		if not extra in gone: gone.append(extra)
	if weathered > 0.7 and b.rng.randf() < weathered:
		var more := [0,b.rng.randi_range(0,1)]
		if not more in gone: gone.append(more)
	var x0 := -h-(BEAM.y if left else 0.0)
	var x1 := h+(BEAM.y if right else 0.0)
	_roof(b,x0,x1,-h-BEAM.y,h+BEAM.y,soffit+BEAM.x,{"strips":3,"rows":2,"gone":gone,"tipped":false})
	if slit or (columns & 3) == 3 or (columns & 3) == 2: _back_wall(b,-h,slit)
	_paving(b,columns)
	if ruined: _collapse(b)
	for i in range(int(weathered*6.0)):
		b.hang(Vector3(b.rng.randf_range(-h,h),0.0,b.rng.randf_range(-h,h)),b.rng.randf_range(0.8,2.6)*weathered,true)
	RuinKit._rubble(b,h+1.5,int(round(weathered*b.rng.randf_range(4.0,8.0))))
	var root := b.finish()
	if slit: root.set_meta("slit",Vector3(0.0,KNIFE.y+KNIFE.z*0.5,-h))
	root.set_meta("snapped",ruined)
	return root

## The hall the gallery puts together: two bays side by side (BAY apart
## along X), the left with the knife-edge slit in its
## back wall, the right its corner fallen; the left bay walled in, so it is
## dim and the light comes in as beams: an end wall at -X with a pointed
## gate through it (the plane's way in, THREAD wide and more, out through
## the fallen bay), a front wall with a tall lancet. The bays and the walls
## are its children.
static func hall(seed_value: int, weathered := 0.8) -> Node3D:
	var root := Node3D.new()
	root.name = "Hall"
	var walls := Build.new(seed_value+13,weathered,"HallWalls")
	var span := BAY*0.5-COLUMN_R+0.1
	_wall(walls,Transform3D(Basis(Vector3.UP,PI*0.5),Vector3(-BAY,0.0,GATE_AT)),span+0.5,GATE,4.4)
	_wall(walls,Transform3D(Basis.IDENTITY,Vector3(-BAY*0.5,0.0,BAY*0.5)),span,LANCET,4.6)
	for i in range(int(weathered*5.0)):
		walls.tuft(Vector3(-BAY+walls.rng.randf_range(0.6,1.4),0.0,walls.rng.randf_range(-3.0,3.0)),0.4,5)
	root.add_child(walls.finish())
	var left := bay(seed_value,weathered,15,true,false)
	left.name = "LeftBay"
	left.position.x = -BAY*0.5
	root.add_child(left)
	var right := bay(seed_value+7,weathered,10,false,true)
	right.name = "RightBay"
	right.position.x = BAY*0.5
	root.add_child(right)
	root.set_meta("slit",left.position+(left.get_meta("slit") as Vector3))
	return root

# --- Parts ----------------------------------------------------------------------

## A column at `pose` (its foot), `broken` the height it snaps at (INF,
## whole); gives back the drums above the break [kind, height] (what fell).
static func _column(b: Build, pose: Transform3D, broken := INF) -> Array:
	_base(b,pose)
	var shaft_top := COLUMN_H-CAPITAL_H
	var plain := shaft_top-BASE_H-NICHE_BAND-ROUNDEL_BAND
	var drums := [["plain",plain*0.6],["niche",NICHE_BAND],["plain",plain*0.4],["roundel",ROUNDEL_BAND]]
	var y := BASE_H
	var fell: Array = []
	for d: Array in drums:
		var h: float = d[1]
		if y >= broken:
			fell.append(d)
			y += h
			continue
		var extra: Array[Plane] = []
		if y+h > broken: extra = RuinKit._break(b,h,COLUMN_R,clampf((y+h-broken)/h,0.3,0.8),0.0)
		var slip := Vector3(b.rng.randf_range(-1,1),0.0,b.rng.randf_range(-1,1))*(0.004+0.02*b.weathered)
		_drum(b,pose*Transform3D(Basis(Vector3.UP,b.rng.randf_range(-0.04,0.04)),Vector3(0.0,y,0.0)+slip),str(d[0]),h,extra)
		y += h
	if broken >= COLUMN_H: _capital(b,pose*RuinKit._jiggle(b,Transform3D(Basis.IDENTITY,Vector3(0.0,shaft_top,0.0)),0.5))
	return fell

## The moulded base at `pose`: a square plinth (a step) with its top
## chamfered, a torus, a scotia, a smaller torus, a fillet.
static func _base(b: Build, pose: Transform3D) -> void:
	var plinth := RuinKit._box(b,Vector3(PLINTH.y,PLINTH.x*0.5,PLINTH.y))
	for s: float in [-1.0,1.0]:
		for axis: Vector3 in [Vector3.RIGHT,Vector3.BACK]:
			var n := (axis*s+Vector3.UP*1.2).normalized()
			plinth.append(Plane(n,n.dot(axis*s*(PLINTH.y-0.12)+Vector3.UP*PLINTH.x*0.5)))
	b.solid(plinth,pose*RuinKit._settle(b,Vector3(0.0,PLINTH.x*0.5,0.0),0.3),RuinKit._stone(b,0.9))
	var y := PLINTH.x
	# [bottom radius, top radius, height]: the mouldings.
	var mouldings := [[1.3,1.38,0.13],[1.38,1.27,0.13],[1.12,1.12,0.14],[1.15,1.22,0.1],[1.22,1.13,0.1],[1.1,1.1,0.07]]
	for k in range(mouldings.size()):
		var m: Array = mouldings[k]
		var tone := RuinKit._stone(b,1.04 if k in [1,4] else 0.97)
		b.solid(RuinKit._prism(16,float(m[0]),float(m[1]),0.0,float(m[2])),pose*Transform3D(Basis.IDENTITY,Vector3(0.0,y,0.0)),tone,k in [0,2,5],true,[],-1,0.6)
		y += float(m[2])

## One drum from its foot at `pose`, `h` tall: plain, the roundel band or
## the niche band; `extra` cuts every block of it (a break).
static func _drum(b: Build, pose: Transform3D, kind: String, h: float, extra: Array) -> void:
	var cut: Array[Plane] = []
	for p in extra: cut.append(p)
	var tone := RuinKit._stone(b)
	match kind:
		"plain":
			b.solid(RuinKit._prism(16,COLUMN_R,COLUMN_R,0.0,h),pose,tone,true,true,cut,-1,0.7)
		"roundel":
			# A recessed core between two fillets, a ring of twelve roundels,
			# each a disc with a boss standing out of its middle.
			b.solid(RuinKit._prism(16,COLUMN_R-0.05,COLUMN_R-0.05,0.0,h),pose,tone*0.95,true,true,cut,-1,0.6)
			for y: float in [0.0,h-0.09]:
				b.solid(RuinKit._prism(16,COLUMN_R+0.04,COLUMN_R+0.04,y,y+0.09),pose,tone*1.05,false,true,cut,-1,0.5)
			for k in range(12):
				var a := TAU*(k+0.5)/12.0
				var r := Vector3(cos(a),0.0,sin(a))
				var c := r*(COLUMN_R-0.06)+Vector3.UP*h*0.5
				_disc(b,pose,c,r,0.17,0.13,8,tone*1.06,cut)
				_disc(b,pose,c+r*0.1,r,0.075,0.1,6,tone*1.1,cut)
		"niche":
			# A recessed core; eight strips standing to the drum's face between
			# the niches; over each niche a pointed head (the spandrels filled),
			# a sill fillet under them, a lozenge boss in each.
			var back := COLUMN_R-0.11
			b.solid(RuinKit._prism(16,back,back,0.0,h),pose,tone*0.88,true,true,cut,-1,0.6)
			b.solid(RuinKit._prism(16,COLUMN_R+0.03,COLUMN_R+0.03,0.0,0.1),pose,tone*1.04,false,true,cut,-1,0.5)
			b.solid(RuinKit._prism(16,COLUMN_R+0.03,COLUMN_R+0.03,h-0.1,h),pose,tone*1.04,false,true,cut,-1,0.5)
			var half := COLUMN_R*tan(PI/16.0)
			for k in range(8):
				# The strip, on a face of the sixteen.
				var a := TAU*k/8.0
				var r := Vector3(cos(a),0.0,sin(a))
				var t := Vector3(-sin(a),0.0,cos(a))
				var strip: Array[Plane] = [Plane(r,COLUMN_R),Plane(-r,-(back-0.02)),Plane(t,half*0.62),Plane(-t,half*0.62),Plane(Vector3.DOWN,-0.1),Plane(Vector3.UP,h-0.1)]
				b.solid(strip,pose,tone*1.03,false,true,cut,-1,0.5)
				# The niche between this strip and the next: its head and boss.
				var an := a+TAU/16.0
				var rn := Vector3(cos(an),0.0,sin(an))
				var tn := Vector3(-sin(an),0.0,cos(an))
				var nw := half*1.4
				var spring := h-0.48
				var apex := h-0.14
				for s: float in [-1.0,1.0]:
					var head: Array[Plane] = [Plane(rn,COLUMN_R),Plane(-rn,-(back-0.02)),Plane(Vector3.UP,h-0.1),Plane(-tn*s,0.0),Plane(tn*s,nw+0.004)]
					var up := (tn*s*(apex-spring)+Vector3.UP*nw).normalized()
					head.append(Plane(-up,-up.dot(tn*s*nw+Vector3.UP*spring)))
					b.solid(head,pose,tone*1.02,false,true,cut,-1,0.5)
				var boss_at := rn*back+Vector3.UP*(0.1+(spring-0.1)*0.5)
				var boss: Array[Plane] = []
				for e in range(4):
					var ea := TAU*e/4.0+PI*0.25
					var n := (tn*cos(ea)+Vector3.UP*sin(ea)*0.7).normalized()
					boss.append(Plane(n,n.dot(boss_at)+0.12))
				boss.append(Plane(rn,rn.dot(boss_at)+0.08))
				boss.append(Plane(-rn,-rn.dot(boss_at)+0.02))
				var tip := (rn+Vector3.UP*0.0).normalized()
				for e in range(4):
					var ea := TAU*e/4.0+PI*0.25
					var n := (rn+(tn*cos(ea)+Vector3.UP*sin(ea))*0.9).normalized()
					boss.append(Plane(n,n.dot(boss_at+tip*0.08)+0.04))
				b.solid(boss,pose,tone*1.08,false,true,cut,-1,0.4)

## A disc standing out of a face along `axis` from `centre`: `sides` sided,
## apothem `r`, `depth` proud; `cut` cuts it.
static func _disc(b: Build, pose: Transform3D, centre: Vector3, axis: Vector3, r: float, depth: float, sides: int, tone: Color, cut: Array[Plane] = []) -> void:
	var u := axis.cross(Vector3.UP if absf(axis.y) < 0.9 else Vector3.RIGHT).normalized()
	var v := axis.cross(u).normalized()
	var planes: Array[Plane] = [Plane(axis,axis.dot(centre)+depth),Plane(-axis,-axis.dot(centre))]
	for k in range(sides):
		var a := TAU*(k+0.5)/sides
		var n := u*cos(a)+v*sin(a)
		planes.append(Plane(n,n.dot(centre)+r))
	b.solid(planes,pose,tone,false,true,cut,-1,0.4)

## The capital from its foot at `pose`: a necking fillet, the flared
## echinus, a thin ring, the square abacus with its edges chamfered.
static func _capital(b: Build, pose: Transform3D) -> void:
	b.solid(RuinKit._prism(16,COLUMN_R+0.06,COLUMN_R+0.06,0.0,0.1),pose,RuinKit._stone(b,1.04),true,true,[],-1,0.5)
	b.solid(RuinKit._prism(16,COLUMN_R,1.42,0.1,0.6),pose,RuinKit._stone(b,1.0),true,true,[],-1,0.6)
	var abacus := RuinKit._box(b,Vector3(ABACUS,0.19,ABACUS))
	for s: float in [-1.0,1.0]:
		for axis: Vector3 in [Vector3.RIGHT,Vector3.BACK]:
			var n := (axis*s-Vector3.UP*1.0).normalized()
			abacus.append(Plane(n,n.dot(axis*s*(ABACUS-0.1)-Vector3.UP*0.19)))
	b.solid(abacus,pose*RuinKit._settle(b,Vector3(0.0,0.6+0.19,0.0),0.5),RuinKit._stone(b,1.05))

## An architrave at `pose` (its soffit's middle; it runs along X), `length`
## long, `depth` deep: two fasciae and a crown moulding over them, each one
## long stone, a row of roundels along the upper fascia's faces; `cut`
## cuts every stone (a crack).
static func _beam(b: Build, pose: Transform3D, length: float, cut: Array = [], depth := BEAM.x) -> void:
	var extra: Array[Plane] = []
	for p in cut: extra.append(p)
	var half := length*0.5
	var lower := depth*0.5
	var upper := depth*0.35
	var crown := depth-lower-upper
	var w := BEAM.y
	b.solid(RuinKit._box(b,Vector3(half,lower*0.5,w-0.12)),pose*Transform3D(Basis.IDENTITY,Vector3(0.0,lower*0.5,0.0)),RuinKit._stone(b,0.97),true,true,extra,-1,0.7)
	b.solid(RuinKit._box(b,Vector3(half,upper*0.5,w-0.06)),pose*Transform3D(Basis.IDENTITY,Vector3(0.0,lower+upper*0.5,0.0)),RuinKit._stone(b,1.0),true,true,extra,-1,0.7)
	var top := RuinKit._box(b,Vector3(half,crown*0.5,w))
	for s: float in [-1.0,1.0]:
		var n := Vector3(0.0,-1.0,s*1.1).normalized()
		top.append(Plane(n,n.dot(Vector3(0.0,-crown*0.5,s*(w-0.08)))))
	b.solid(top,pose*Transform3D(Basis.IDENTITY,Vector3(0.0,depth-crown*0.5,0.0)),RuinKit._stone(b,1.05),true,true,extra,-1,0.7)
	# The roundels along the upper fascia, both faces.
	var count := int(length/1.1)
	for s: float in [-1.0,1.0]:
		for k in range(count):
			var x := -half+length*(k+0.5)/count
			var ok := true
			for p in extra:
				if p.distance_to(Vector3(x,lower,0.0)) > -0.2: ok = false
			if not ok: continue
			var c := Vector3(x,lower+upper*0.5,s*(w-0.06))
			_disc(b,pose,c,Vector3(0.0,0.0,s),minf(0.13,upper*0.4),0.06,8,RuinKit._stone(b,1.08))

## The pose of a beam laid from soffit `a` to soffit `b2` (a sagging one).
static func _sag(a: Vector3, b2: Vector3) -> Transform3D:
	var along := (b2-a).normalized()
	var side := along.cross(Vector3.UP).normalized()
	var up := side.cross(along).normalized()
	return Transform3D(Basis(along,up,side),(a+b2)*0.5)

## The roof slabs over `x0`..`x1`, `z0`..`z1`, their soffits at `y`:
## `plan.strips` along X by `plan.rows` along Z, those in `plan.gone`
## ([strip, row]) left out; each cracked (split in two along a slanting
## line) at odds, one gap a hand wide even as built; `plan.tipped`: one
## slab broken and its half tipped up against its neighbour.
static func _roof(b: Build, x0: float, x1: float, z0: float, z1: float, y: float, plan: Dictionary) -> void:
	var strips: int = plan.strips
	var rows: int = plan.rows
	var gone: Array = plan.gone
	var wide := b.rng.randi_range(0,strips-2)
	for i in range(strips):
		for j in range(rows):
			if [i,j] in gone: continue
			var xa := x0+(x1-x0)*i/strips+0.012
			var xb := x0+(x1-x0)*(i+1)/strips-0.012
			if i == wide: xb -= 0.1
			if i == wide+1: xa += 0.1
			var za := z0+(z1-z0)*j/rows+0.012
			var zb := z0+(z1-z0)*(j+1)/rows-0.012
			var half := Vector3((xb-xa)*0.5,SLAB*0.5,(zb-za)*0.5)
			var at := Vector3((xa+xb)*0.5,y+SLAB*0.5,(za+zb)*0.5)
			var tip := bool(plan.tipped) and i == strips-1 and j == 0
			if b.rng.randf() < 0.35+0.45*b.weathered or tip:
				# Cracked across, the two parts settled a little apart.
				var n := Vector3(b.rng.randf_range(-0.5,0.5),0.0,1.0).normalized() if b.rng.randf() < 0.5 else Vector3(1.0,0.0,b.rng.randf_range(-0.5,0.5)).normalized()
				var off := b.rng.randf_range(-0.3,0.3)*minf(half.x,half.z)
				for s: float in [-1.0,1.0]:
					var planes := RuinKit._box(b,half,0.03)
					planes.append(Plane(n*s,s*off-0.02-0.03*b.weathered))
					var pose := RuinKit._jiggle(b,Transform3D(Basis.IDENTITY,at+Vector3(0.0,-0.02*b.weathered*float(s > 0.0),0.0)),0.6)
					if tip and s > 0.0:
						# Its half tipped up against the next slab over.
						pose = Transform3D(Basis(Vector3.BACK,0.5),at+Vector3(-0.3,0.55,0.0))
					b.solid(planes,pose,RuinKit._stone(b,1.0),true,true,[],-1,0.8)
			else:
				b.solid(RuinKit._box(b,half,0.03),RuinKit._jiggle(b,Transform3D(Basis.IDENTITY,at),0.5),RuinKit._stone(b,1.0),true,true,[],-1,0.8)

## The back wall between the back columns, under the back beam, at `z`,
## `slit` the knife-edge slit through its middle.
static func _back_wall(b: Build, z: float, slit: bool) -> void:
	var opening := Vector4(KNIFE.x,KNIFE.y,KNIFE.z,0.9) if slit else Vector4.ZERO
	_wall(b,Transform3D(Basis.IDENTITY,Vector3(0.0,0.0,z)),BAY*0.5-COLUMN_R+0.1,opening,2.6)

## A wall at `pose` (along its X, `span` either side of its middle) from
## the floor up under a beam: coursed, its head torn down weathered (never
## under `low`, nor near the opening under its head), and through its
## middle a pointed `opening` (clear width, sill, height to the springing,
## the arc's radius as a share of the width; zero width, none) with a
## moulded ring over it and a sill stone.
static func _wall(b: Build, pose: Transform3D, span: float, opening: Vector4, low: float) -> void:
	var high := COLUMN_H-0.02
	var open := opening.x > 0.0
	var w := opening.x*0.5
	var radius := opening.x*opening.w
	var spring := opening.y+opening.z
	var head := spring+RuinKit._rise(w,radius)+0.35
	var top: Callable = func(_x: float) -> float: return high
	if b.weathered > 0.2:
		var ragged := RuinKit._ruin_line(b,-span,span,lerpf(high,low,b.weathered),high,b.weathered)
		top = func(x: float) -> float: return minf(high,maxf(float(ragged.call(x)),head+0.7 if open and absf(x) < w+1.0 else low))
	var hole := Callable()
	if open:
		hole = func(y: float) -> Vector2:
			if y < opening.y: return Vector2(0.0,-1.0)
			if y < spring: return Vector2(0.0,w)
			return Vector2(0.0,RuinKit._arc_half(w,radius,0.32,y-spring))
	RuinKit._plinth_course(b,pose,span,WALL_THICK*0.5)
	# Laid in heavier courses than the abbey's, and held truer under the
	# beams' weight: its stones settle less than the rest of the hall.
	var keep := b.weathered
	b.weathered *= 0.4
	RuinKit._courses(b,pose,-span,span,RuinKit.PLINTH_COURSE.x,top,WALL_THICK*0.5,hole,0.62)
	b.weathered = keep
	if open:
		# The head: a pointed ring, chamfered; the sill, a long stone.
		var stones := maxi(4,int(radius*1.4))
		RuinKit._ring_order(b,pose,0.0,spring,w,radius,0.0,0.32,WALL_THICK*0.5+0.02,stones,99,1.0,RuinKit._stone(b,1.06),0,Callable(),true)
		if opening.y > 0.3:
			b.solid(RuinKit._box(b,Vector3(w+0.3,0.08,WALL_THICK*0.5+0.05)),pose*RuinKit._settle(b,Vector3(0.0,opening.y-0.08,0.0),0.3),RuinKit._stone(b,1.06))

## The paving round the bay's middle: big worn slabs in rough rows, left
## out round the columns' feet; weathered, slabs gone to
## grass, heaved and tipped, tufts in the joints.
static func _paving(b: Build, columns: int) -> void:
	var h := BAY*0.5+0.4
	var feet: Array[Vector2] = []
	var corners := [Vector2(-1,-1),Vector2(1,-1),Vector2(-1,1),Vector2(1,1)]
	for k in range(4):
		feet.append((corners[k] as Vector2)*BAY*0.5)
	var z := -h+WALL_THICK*0.5
	while z < h-0.1:
		var depth := minf(PAVING.y*b.rng.randf_range(0.7,1.2),h-z)
		if h-(z+depth) < 0.5: depth = h-z
		var x := -h
		while x < h-0.1:
			var x1 := minf(x+PAVING.y*b.rng.randf_range(0.7,1.5),h)
			if h-x1 < 0.5: x1 = h
			var mid := Vector2((x+x1)*0.5,z+depth*0.5)
			var clear := true
			for f in feet:
				if absf(mid.x-f.x) < PLINTH.y+0.5 and absf(mid.y-f.y) < PLINTH.y+0.5: clear = false
			if clear and b.rng.randf() > 0.4*b.weathered:
				var lift := b.rng.randf_range(-0.04,0.0)+b.rng.randf_range(-0.04,0.03)*b.weathered
				var tilt := Basis(Vector3(b.rng.randf_range(-1,1),0.0,b.rng.randf_range(-1,1)).normalized(),b.rng.randf_range(0.004,0.02)+b.rng.randf()*0.06*b.weathered)
				b.solid(RuinKit._box(b,Vector3((x1-x)*0.5-0.03,PAVING.x*0.5,depth*0.5-0.03),0.03),Transform3D(tilt,Vector3(mid.x,PAVING.x*0.5+lift,mid.y)),RuinKit._stone(b,0.98),true,true,[],-1,0.7)
			elif clear and b.weathered > 0.3 and b.rng.randf() < 0.5:
				b.tuft(Vector3(mid.x,0.0,mid.y),0.35,4)
			x = x1
		z += depth
	for f in feet: _feet(b,Vector3(f.x,0.0,f.y),PLINTH.y+0.25,int(1+b.weathered*4.0))

## The ruined corner: the slab that came down with it leaning from a heap
## of the column's fallen drums up onto the dropped side beam (RAMP, a
## walk), the other slab broken on the floor, the capital and drums lying.
static func _collapse(b: Build) -> void:
	var h := BAY*0.5
	var beam_top := SNAP+BEAM.x
	var length := 6.0
	var head := Vector3(h+0.3,beam_top+SLAB*0.5,h-0.7)
	var foot := head+Vector3(cos(RAMP),-sin(RAMP),0.0)*length
	var pose := Transform3D(Basis(Vector3.BACK,RAMP),(head+foot)*0.5)
	b.solid(RuinKit._box(b,Vector3(length*0.5,SLAB*0.5,1.25),0.03),pose,RuinKit._stone(b,1.02),true,true,RuinKit._break(b,SLAB,1.2,0.4,0.0),-1,0.8)
	# The heap under the ramp's foot: the snapped column's drums and its
	# capital, and a drift.
	RuinKit._drift(b,foot+Vector3(0.6,-foot.y,0.0),1.4,8)
	var x := h+2.2
	for k in range(2):
		var lie := Basis(Vector3.UP,0.3+0.4*k)*Basis(Vector3.BACK,-PI*0.5)
		_drum(b,Transform3D(lie,Vector3(x,COLUMN_R*0.97,h+1.6+1.1*k)),"plain" if k == 0 else "roundel",0.8,[])
		x += 0.7
	_capital(b,Transform3D(Basis(Vector3.UP,0.5)*Basis(Vector3.RIGHT,PI-0.14),Vector3(h+1.2,0.92,h+3.4)))
	# The other slab, broken on the floor inside the front.
	for s: float in [-1.0,1.0]:
		var piece := RuinKit._box(b,Vector3(1.2,SLAB*0.5,0.9),0.03)
		var tilt := Basis(Vector3.UP,b.rng.randf_range(-0.4,0.4))*Basis(Vector3.RIGHT,s*0.2)*Basis(Vector3.BACK,b.rng.randf_range(-0.25,0.25))
		b.solid(piece,Transform3D(tilt,Vector3(h-1.5+s*0.9,0.42,h-0.9+s*0.6)),RuinKit._stone(b,1.0),true,true,RuinKit._break(b,SLAB,1.0,0.5,0.0),-1,1.0)

## Grass tufts round a foot at `at`, `reach` out: `count` of them.
static func _feet(b: Build, at: Vector3, reach: float, count: int) -> void:
	for i in range(count):
		var a := b.rng.randf()*TAU
		b.tuft(at+Vector3(cos(a),0.0,sin(a))*reach*b.rng.randf_range(0.85,1.25),0.42,b.rng.randi_range(4,7))
