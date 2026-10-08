extends RefCounted
## The ruin kit's colossus hall (scripts/ruin_kit.gd, the same stone, wear,
## growth and glyph glow): a dim hypostyle hall, after the shrine halls of
## Shadow of the Colossus, cut in the kit's facets. Massive drum columns far
## thicker than the abbey's clustered piers, on deep moulded bases, their
## drums carved in bands (a ring of roundels, a band of pointed niche
## panels with a boss in each) under a flared capital and a square abacus;
## deep architrave beams in two fasciae under a crown moulding, a row of
## roundels along them; heavy flat roof slabs laid over the beams, cracked,
## the light coming in through the cracks and the gaps; a great carved
## medallion in the floor with a glyph at its heart; and the fallen mask of
## a colossus, a carved stone face-plate half sunk in the ground, its eye
## sockets holding the glyph light. The carving is raised and sunk facets,
## never fine detail.
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
## The floor medallion: its radius, its rings' outer radii, its stones'
## top (a little under the paving's), the glyph's size.
const MEDALLION := 2.7
const MEDALLION_RINGS := [0.75,1.45,1.75,2.45,2.7]
const MEDALLION_TOP := 0.16
const MEDALLION_GLYPH := 1.0
## The mask: width, height and the face-plate's thickness (m); how far it
## leans back (radians), how deep its chin is sunk (m); the brow ledge's
## reach out of the face (STAND and more), the eye sockets' half size.
const MASK := Vector3(4.4,6.0,0.9)
const MASK_LEAN := deg_to_rad(50.0)
const MASK_SINK := 0.9
const BROW := 0.65
const MASK_GLYPH := 0.62

# --- The pieces -----------------------------------------------------------------

static func piece(id: String, seed_value: int, weathered := 0.0) -> Node3D:
	match id:
		"hall_column": return column(seed_value,weathered)
		"hall_beam": return beam(seed_value,weathered)
		"hall_slab": return slabs(seed_value,weathered)
		"hall_bay": return bay(seed_value,weathered)
		"hall_medallion": return medallion(seed_value,weathered)
		"hall_mask": return mask(seed_value,weathered)
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
## middle beam, the slab roof over all, a paved floor round the medallion
## (`with_medallion`), and the back wall between the back columns, through
## it the knife-edge slit (`slit`). Weathered, the roof is gapped (the
## light comes down in shafts), the back wall's head torn down, the paving
## broken and grassed; `corner`: the front right column snapped and the
## roof over its corner come down, a slab leaning up onto the beams.
static func bay(seed_value: int, weathered := 0.0, columns := 15, slit := true, with_medallion := true, corner := true) -> Node3D:
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
		var extra := [1,1] if with_medallion else [b.rng.randi_range(0,1),b.rng.randi_range(0,1)]
		if not extra in gone: gone.append(extra)
	if weathered > 0.7 and b.rng.randf() < weathered:
		var more := [0,b.rng.randi_range(0,1)]
		if not more in gone: gone.append(more)
	var x0 := -h-(BEAM.y if left else 0.0)
	var x1 := h+(BEAM.y if right else 0.0)
	_roof(b,x0,x1,-h-BEAM.y,h+BEAM.y,soffit+BEAM.x,{"strips":3,"rows":2,"gone":gone,"tipped":false})
	if slit or (columns & 3) == 3 or (columns & 3) == 2: _back_wall(b,-h,slit)
	_paving(b,with_medallion,columns)
	if ruined: _collapse(b)
	for i in range(int(weathered*6.0)):
		b.hang(Vector3(b.rng.randf_range(-h,h),0.0,b.rng.randf_range(-h,h)),b.rng.randf_range(0.8,2.6)*weathered,true)
	RuinKit._rubble(b,h+1.5,int(round(weathered*b.rng.randf_range(4.0,8.0))))
	var root := b.finish()
	if with_medallion:
		var disc := medallion(seed_value+1,weathered)
		disc.name = "Medallion"
		root.add_child(disc)
	if slit: root.set_meta("slit",Vector3(0.0,KNIFE.y+KNIFE.z*0.5,-h))
	root.set_meta("snapped",ruined)
	return root

## The hall the gallery puts together: two bays side by side (BAY apart
## along X), the left round the medallion with the knife-edge slit in its
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
	var left := bay(seed_value,weathered,15,true,true,false)
	left.name = "LeftBay"
	left.position.x = -BAY*0.5
	root.add_child(left)
	var right := bay(seed_value+7,weathered,10,false,false,true)
	right.name = "RightBay"
	right.position.x = BAY*0.5
	root.add_child(right)
	root.set_meta("slit",left.position+(left.get_meta("slit") as Vector3))
	return root

## 10. A floor medallion: a great disc of carved stones in rings, a glyph
## cut in its heart giving the faint glow (`set_night`), eight radial
## stones round it each pitched up to a ridge (radial facets), a raised
## band, a ring of stones stepping up and down by turns, a moulded outer
## rim. Weathered, one side sunk and tilted under a drift of rubble and
## turf, stones gone, grass and moss in the joints.
static func medallion(seed_value: int, weathered := 0.0, glyph := "") -> Node3D:
	var b := Build.new(seed_value,weathered,"Medallion")
	if glyph.is_empty(): glyph = RuinKit.GLYPHS[b.rng.randi()%RuinKit.GLYPHS.size()]
	b.ground = -0.04
	var rings: Array = MEDALLION_RINGS
	var bury_angle := b.rng.randf()*TAU
	var buried := Vector3(cos(bury_angle),0.0,sin(bury_angle))
	var bed := 0.12
	# The ring of each stone: its inner and outer radius, count, top, and
	# whether it rides up to a ridge or steps.
	var specs := [[rings[0]+0.03,rings[1],8,MEDALLION_TOP,"ridge"],[rings[1]+0.03,rings[2],16,MEDALLION_TOP+0.07,"band"],
		[rings[2]+0.03,rings[3],16,MEDALLION_TOP,"step"],[rings[3]+0.03,rings[4],24,MEDALLION_TOP+0.05,"rim"]]
	for spec: Array in specs:
		var r0: float = spec[0]
		var r1: float = spec[1]
		var count: int = spec[2]
		var top: float = spec[3]
		var kind: String = spec[4]
		var turn := b.rng.randf()*0.2
		for k in range(count):
			var a0 := turn+TAU*k/count
			var a1 := turn+TAU*(k+1)/count
			var am := (a0+a1)*0.5
			var dm := Vector3(cos(am),0.0,sin(am))
			# How buried this stone is: 1 on the buried side's edge.
			var under := clampf(dm.dot(buried),0.0,1.0)*smoothstep(0.8,2.6,(r0+r1)*0.5)*weathered
			if under > 0.35 and b.rng.randf() < under*0.8: continue
			if weathered > 0.3 and b.rng.randf() < 0.06*weathered: continue
			var t := top+(0.035 if kind == "step" and k%2 == 0 else 0.0)
			var planes := _sector(b,r0,r1,a0,a1,t-bed,t,0.07 if kind == "ridge" else 0.0)
			if kind == "rim":
				var n := (dm+Vector3.UP*1.2).normalized()
				planes.append(Plane(n,n.dot(dm*r1+Vector3.UP*(t-0.07))))
			if kind == "band":
				for s: float in [-1.0,1.0]:
					var n := (dm*s+Vector3.UP*1.4).normalized()
					var edge: float = r1 if s > 0.0 else r0
					planes.append(Plane(n,n.dot(dm*edge+Vector3.UP*(t-0.035))))
			var sink := under*b.rng.randf_range(0.08,0.2)
			var tilt := Basis(dm.cross(Vector3.UP).normalized(),-under*b.rng.randf_range(0.05,0.15))
			var pose := RuinKit._jiggle(b,Transform3D(tilt,Vector3(0.0,-sink,0.0)),0.25)
			var tone := RuinKit._stone(b,1.06 if kind == "band" or kind == "rim" else 1.0)
			b.solid(planes,pose,tone,true,true,[],-1,0.7)
	# The heart: a sixteen-sided stone, the glyph cut in its top.
	var heart: Array[Plane] = [Plane(Vector3.BACK,0.0),Plane(Vector3.FORWARD,bed+0.1)]
	for k in range(16):
		var a := TAU*k/16.0
		heart.append(Plane(Vector3(cos(a),sin(a),0.0),rings[0]))
	var face := Transform3D(Basis(Vector3.RIGHT,-PI*0.5),Vector3(0.0,MEDALLION_TOP+0.02,0.0))
	var open := b.solid(heart,face,RuinKit._stone(b,0.98),true,true,[],0,0.4)
	var outline := PackedVector2Array()
	for p in open: outline.append(Vector2(p.x,p.y))
	if outline.size() >= 3: RuinKit._carve(b,face,glyph,Vector2.ZERO,0.0,outline,MEDALLION_GLYPH)
	# The bed it is laid in, dark between the joints.
	var bed_planes: Array[Plane] = [Plane(Vector3.DOWN,0.0),Plane(Vector3.UP,MEDALLION_TOP-bed+0.01)]
	for k in range(24):
		var a := TAU*k/24.0
		bed_planes.append(Plane(Vector3(cos(a),0.0,sin(a)),rings[4]+0.02))
	b.solid(bed_planes,Transform3D.IDENTITY,Color(RuinKit.MOSS).lerp(Color("3c362d"),0.6),false,false,[],-1,1.0,false)
	if weathered > 0.2:
		# The drift and turf over its buried side.
		var edge: Vector3 = buried*float(rings[4])
		RuinKit._drift(b,edge+buried*0.2,1.3,3+int(weathered*6.0))
		_turf(b,edge+buried*0.4,buried,1.6+1.2*weathered)
	_feet(b,buried*(rings[4]+0.3),1.4,int(2+weathered*8.0))
	for i in range(int(weathered*6.0)):
		var a := b.rng.randf()*TAU
		b.tuft(Vector3(cos(a),0.0,sin(a))*b.rng.randf_range(rings[1],rings[4]),0.3,3)
	# The halo, low over the glyph at night.
	var halo := MeshInstance3D.new()
	halo.name = "Halo"
	halo.mesh = Build.halo_quad()
	halo.material_override = RuinKit.materials().halo
	halo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	halo.transform = Transform3D(Basis.from_scale(Vector3.ONE*RuinKit.HALO*1.6),Vector3(0.0,MEDALLION_TOP+0.35,0.0))
	b.root.add_child(halo)
	b.root.set_meta("glyph",glyph)
	return b.finish()

## 11. The fallen mask of a colossus: a great carved stone face-plate,
## long, pointed at the chin, lying back half sunk in the ground and tipped
## a little to one side, its horns broken. A forehead plate with a row of
## studs and a roundel with a glyph cut in it; a heavy brow in a shallow
## vee, its top near level as the mask lies (a ledge to stand on); slanted
## six-sided eye sockets under it, their backs giving the glyph light
## (faint by day, alive at night); a nose ridge; temple plates bevelled
## back; cheek plates pitched into slopes that climb from the ground to
## the sockets; a grill of bars at the mouth; a chin plate. Inanimate: a
## relic. Weathered, cracked across, a cheek plate fallen beside it, mossed
## over.
static func mask(seed_value: int, weathered := 0.0, glyph := "") -> Node3D:
	var b := Build.new(seed_value,weathered,"Mask")
	if glyph.is_empty(): glyph = RuinKit.GLYPHS[b.rng.randi()%RuinKit.GLYPHS.size()]
	b.ground = -0.05
	var lean := Basis(Vector3.RIGHT,-MASK_LEAN-b.rng.randf_range(-0.03,0.05))
	var roll := Basis(Vector3.BACK,b.rng.randf_range(0.08,0.16)*(-1.0 if b.rng.randf() < 0.5 else 1.0))
	var face := Transform3D(roll*lean,Vector3(0.0,-MASK_SINK,-1.2))
	var top := MASK.y
	var crack := Plane()
	var cracked := weathered > 0.35
	if cracked:
		var n := Vector3(1.0,b.rng.randf_range(-0.7,0.7),0.0).normalized()
		crack = Plane(n,n.dot(Vector3(b.rng.randf_range(-0.5,0.5),b.rng.randf_range(1.6,4.6),0.0)))
	# The plate behind it all: long, widest at the cheekbones, a pointed chin.
	var shield := [Vector2(-1.55,top),Vector2(1.55,top),Vector2(2.05,top-0.65),Vector2(2.18,3.1),Vector2(1.35,0.9),Vector2(0.42,0.0),Vector2(-0.42,0.0),Vector2(-1.35,0.9),Vector2(-2.18,3.1),Vector2(-2.05,top-0.65)]
	_split(b,_plate(shield,-MASK.z,0.0,0.0),face,RuinKit._stone(b,0.92),cracked,crack)
	# The forehead plate, its studs, the roundel and the glyph.
	var brow_y := 3.95
	var forehead := [Vector2(-1.42,top-0.14),Vector2(1.42,top-0.14),Vector2(1.9,top-0.7),Vector2(1.98,brow_y+0.2),Vector2(-1.98,brow_y+0.2),Vector2(-1.9,top-0.7)]
	_split(b,_plate(forehead,-0.1,0.22,0.08),face,RuinKit._stone(b,1.0),cracked,crack)
	for k in range(7):
		var x := (k-3.0)*0.42
		_disc(b,face,Vector3(x,top-0.42,0.2),Vector3.BACK,0.09,0.08,6,RuinKit._stone(b,1.08))
	var roundel_at := Vector3(0.0,brow_y+0.95,0.22)
	_ring(b,face,roundel_at,0.48,0.6,0.12)
	var disc: Array[Plane] = [Plane(Vector3.BACK,0.0),Plane(Vector3.FORWARD,0.12)]
	for k in range(12):
		var a := TAU*k/12.0
		disc.append(Plane(Vector3(cos(a),sin(a),0.0),0.48))
	var disc_pose := face*Transform3D(Basis.IDENTITY,roundel_at+Vector3(0.0,0.0,0.07))
	var open := b.solid(disc,disc_pose,RuinKit._stone(b,0.96),true,true,[],0,0.4)
	var round := PackedVector2Array()
	for p in open: round.append(Vector2(p.x,p.y))
	if round.size() >= 3: RuinKit._carve(b,disc_pose,glyph,Vector2.ZERO,0.0,round,MASK_GLYPH)
	# The brow: two heavy stones in a shallow vee, their tops tipped most of
	# the way to level as the mask lies, so the brow is a ledge.
	var level := (lean.inverse()*Vector3.UP).normalized()
	var tip := Vector3.UP.slerp(level,0.62)
	var steepest := 0.0
	for s: float in [-1.0,1.0]:
		var outer := Vector2(s*2.02,brow_y+0.3)
		var inner := Vector2(0.0,brow_y-0.08)
		var along := Vector3(inner.x-outer.x,inner.y-outer.y,0.0).normalized()
		var n := (tip-along*tip.dot(along)).normalized()
		steepest = maxf(steepest,acos(clampf((face.basis*n).normalized().y,-1.0,1.0)))
		var mid := Vector3((outer.x+inner.x)*0.5,(outer.y+inner.y)*0.5,0.0)
		var brow: Array[Plane] = [Plane(Vector3.FORWARD,0.1),Plane(Vector3.BACK,BROW),Plane(Vector3(s,0.0,0.0),2.06),Plane(Vector3(-s,0.0,0.0),0.0)]
		brow.append(Plane(n,n.dot(mid)))
		brow.append(Plane(-n,-n.dot(mid)+0.38))
		var chamfer := (Vector3.BACK-n*0.8).normalized()
		brow.append(Plane(chamfer,chamfer.dot(mid+Vector3.BACK*BROW-n*0.12)))
		var bevel := (Vector3.BACK+Vector3(s,0.0,0.0)).normalized()
		brow.append(Plane(bevel,bevel.dot(Vector3(s*2.06,0.0,BROW-0.25))))
		_split(b,brow,face,RuinKit._stone(b,1.05),cracked,crack)
	# The nose: a ridge from between the brows down to the mouth.
	var nose := _plate([Vector2(-0.36,brow_y),Vector2(0.36,brow_y),Vector2(0.42,1.45),Vector2(-0.42,1.45)],-0.1,0.6,0.0)
	for s: float in [-1.0,1.0]:
		var bevel := Vector3(s,0.0,0.95).normalized()
		nose.append(Plane(bevel,bevel.dot(Vector3(s*0.12,0.0,0.6))))
	var ridge := Vector3(0.0,0.14,1.0).normalized()
	nose.append(Plane(ridge,ridge.dot(Vector3(0.0,1.45,0.6))))
	_split(b,nose,face,RuinKit._stone(b,1.04),cracked,crack)
	var eye_y := 2.95
	for s: float in [-1.0,1.0]:
		# The socket's rim: six points, the outer top drawn up and out (a
		# slant), under the brow; its back the glow.
		var rim := [Vector2(s*0.42,eye_y+0.2),Vector2(s*0.85,eye_y+0.42),Vector2(s*1.62,eye_y+0.5),Vector2(s*1.86,eye_y+0.05),Vector2(s*1.45,eye_y-0.4),Vector2(s*0.62,eye_y-0.36)]
		var pane := PackedVector2Array()
		for p: Vector2 in rim: pane.append(p)
		if s > 0.0: pane.reverse()
		b.flat(pane,0.015,face,Vector3.BACK,Color(0.5,0.5,0.5),true)
		# The plates round it: under the eye, the temple, the corners filled
		# out to the rim.
		var under := _plate([Vector2(s*0.4,eye_y-0.36),Vector2(s*1.5,eye_y-0.4),Vector2(s*1.9,eye_y-0.66),Vector2(s*0.42,eye_y-0.7)],-0.1,0.36,0.08)
		_split(b,under,face,RuinKit._stone(b,1.03),cracked,crack)
		var temple := _plate([Vector2(s*1.86,eye_y+0.05),Vector2(s*1.62,eye_y+0.5),Vector2(s*2.08,eye_y+0.62),Vector2(s*2.16,eye_y-0.2),Vector2(s*1.9,eye_y-0.66),Vector2(s*1.5,eye_y-0.4)],-0.1,0.4,0.0)
		var flare := Vector3(s,0.0,0.9).normalized()
		temple.append(Plane(flare,flare.dot(Vector3(s*1.75,0.0,0.4))))
		_split(b,temple,face,RuinKit._stone(b,0.99),cracked,crack)
		for wedge: Array in [[rim[0],rim[1],Vector2(s*0.4,brow_y-0.1)],[rim[1],rim[2],Vector2(s*0.4,brow_y-0.1)],[rim[5],rim[0],Vector2(s*0.4,eye_y-0.38)]]:
			b.solid(_plate(wedge,-0.1,0.34,0.0),face,RuinKit._stone(b,0.95),false,true,[],-1,0.4)
		var halo := MeshInstance3D.new()
		halo.name = "Halo" if s < 0.0 else "Halo2"
		halo.mesh = Build.halo_quad()
		halo.material_override = RuinKit.materials().halo
		halo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		halo.transform = Transform3D(Basis.from_scale(Vector3.ONE*RuinKit.HALO*1.4),face*Vector3(s*1.12,eye_y,0.4))
		b.root.add_child(halo)
		# The cheek: pitched from thick at its foot to thin under the eye, a
		# slope to climb as the mask lies.
		var cheek := _plate([Vector2(s*0.46,eye_y-0.72),Vector2(s*1.92,eye_y-0.7),Vector2(s*1.36,0.98),Vector2(s*0.5,1.12)],-0.1,0.95,0.08)
		var pitch := Vector3(0.0,0.5,1.0).normalized()
		cheek.append(Plane(pitch,pitch.dot(Vector3(0.0,eye_y-0.72,0.18))))
		if weathered > 0.55 and s > 0.0 and b.rng.randf() < weathered:
			# This one has fallen: lying beside the mask, cracked.
			var lie := Transform3D(Basis(Vector3.UP,b.rng.randf_range(0.4,0.9))*Basis(Vector3.RIGHT,-PI*0.5+0.3),Vector3(2.9,0.45,0.6))
			b.solid(cheek,lie*Transform3D(Basis.IDENTITY,Vector3(-s*1.15,-1.6,-0.2)),RuinKit._stone(b,1.0),true,true,[],-1,1.3)
		else:
			_split(b,cheek,face,RuinKit._stone(b,1.02),cracked,crack)
		# A horn from the upper corner, out and up, broken off.
		var horn_pose := face*Transform3D(Basis(Vector3.BACK,-s*0.75)*Basis(Vector3.RIGHT,-0.25),Vector3(s*1.85,top-0.35,-0.45))
		var length := b.rng.randf_range(1.1,1.7) if s < 0.0 else b.rng.randf_range(0.5,0.9)
		b.solid(RuinKit._prism(5,0.3,0.18,0.0,length,PI*0.1),horn_pose,RuinKit._stone(b,1.02),true,true,RuinKit._break(b,length,0.3,0.35,0.0),-1,1.2)
	# The mouth's grill: bars across under the nose, between the cheeks.
	for k in range(3):
		var y := 0.42+k*0.32
		var bar := _plate([Vector2(-0.48,y+0.11),Vector2(0.48,y+0.11),Vector2(0.48,y-0.11),Vector2(-0.48,y-0.11)],-0.1,0.3,0.05)
		b.solid(bar,face,RuinKit._stone(b,1.04),true,true,[],-1,0.7)
	_split(b,_plate([Vector2(-0.42,0.02),Vector2(0.42,0.02),Vector2(0.58,0.24),Vector2(-0.58,0.24)],-0.1,0.4,0.06),face,RuinKit._stone(b,1.0),false,crack)
	# Round it: a drift where it struck, turf banked over its sunk chin.
	var side := face.basis*Vector3.RIGHT
	RuinKit._drift(b,Vector3(0.0,0.0,0.9)+side*2.2,1.3,3+int(weathered*6.0))
	_turf(b,Vector3(0.0,0.0,0.8),Vector3.BACK,2.6)
	_feet(b,Vector3(0.0,0.0,0.3),2.6,int(4+weathered*8.0))
	RuinKit._rubble(b,3.2,int(round(weathered*b.rng.randf_range(3.0,7.0))))
	b.root.set_meta("glyph",glyph)
	# How steep the brow's ledge lies (radians from level), for the walk.
	b.root.set_meta("brow_slope",steepest)
	return b.finish()

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
## out round the columns' feet and the medallion; weathered, slabs gone to
## grass, heaved and tipped, tufts in the joints.
static func _paving(b: Build, round_middle: bool, columns: int) -> void:
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
			if round_middle and mid.length() < MEDALLION+0.6+PAVING.y*0.4: clear = false
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
	# The other slab, broken on the floor inside the front, half on the
	# medallion's edge where there is one.
	for s: float in [-1.0,1.0]:
		var piece := RuinKit._box(b,Vector3(1.2,SLAB*0.5,0.9),0.03)
		var tilt := Basis(Vector3.UP,b.rng.randf_range(-0.4,0.4))*Basis(Vector3.RIGHT,s*0.2)*Basis(Vector3.BACK,b.rng.randf_range(-0.25,0.25))
		b.solid(piece,Transform3D(tilt,Vector3(h-1.5+s*0.9,0.42,h-0.9+s*0.6)),RuinKit._stone(b,1.0),true,true,RuinKit._break(b,SLAB,1.0,0.5,0.0),-1,1.0)

## A sector of a ring of stones: `r0` to `r1`, angles `a0` to `a1`, from
## `y0` to `y1`, a hair of joint either side; `ridge` its top pitched up to
## a ridge along its middle radius.
static func _sector(b: Build, r0: float, r1: float, a0: float, a1: float, y0: float, y1: float, ridge := 0.0) -> Array[Plane]:
	var am := (a0+a1)*0.5
	var dm := Vector3(cos(am),0.0,sin(am))
	var t := Vector3(-sin(am),0.0,cos(am))
	var out: Array[Plane] = [Plane(Vector3.DOWN,-y0),Plane(Vector3(sin(a0),0.0,-cos(a0)),-0.006),Plane(Vector3(-sin(a1),0.0,cos(a1)),-0.006),Plane(-dm,-r0),Plane(dm,r1)]
	if ridge > 0.0:
		var hw := r1*sin((a1-a0)*0.5)
		for s: float in [-1.0,1.0]:
			var n := (Vector3.UP*hw+t*s*ridge).normalized()
			out.append(Plane(n,n.dot(Vector3.UP*(y1+ridge))))
		out.append(Plane(Vector3.UP,y1+ridge))
	else:
		out.append(Plane(Vector3.UP,y1))
	return out

## A carved plate: `outline`'s slab from `back` to `front`, its front
## arrises bevelled `bevel` deep.
static func _plate(outline: Array, back: float, front: float, bevel: float) -> Array[Plane]:
	var out := _outline_planes(outline,back,front)
	if bevel <= 0.0: return out
	var centre := Vector2.ZERO
	for p: Vector2 in outline: centre += p
	centre /= outline.size()
	for i in range(outline.size()):
		var a: Vector2 = outline[i]
		var c: Vector2 = outline[(i+1)%outline.size()]
		var n2 := Vector2(c.y-a.y,a.x-c.x).normalized()
		if n2.dot(a-centre) < 0.0: n2 = -n2
		var n := Vector3(n2.x,n2.y,1.0).normalized()
		out.append(Plane(n,n.dot(Vector3(a.x,a.y,front))-bevel*0.7))
	return out

## The planes of a slab whose face is the convex `outline` (x, y), from
## `back` to `front` along Z.
static func _outline_planes(outline: Array, back: float, front: float) -> Array[Plane]:
	var out: Array[Plane] = [Plane(Vector3.BACK,front),Plane(Vector3.FORWARD,-back)]
	var centre := Vector2.ZERO
	for p: Vector2 in outline: centre += p
	centre /= outline.size()
	for i in range(outline.size()):
		var a: Vector2 = outline[i]
		var c: Vector2 = outline[(i+1)%outline.size()]
		var n2 := Vector2(c.y-a.y,a.x-c.x).normalized()
		if n2.dot(a-centre) < 0.0: n2 = -n2
		var n := Vector3(n2.x,n2.y,0.0)
		out.append(Plane(n,n.dot(Vector3(a.x,a.y,0.0))))
	return out

## A slab of the mask at `pose`, whole or (`cracked`) in two along `crack`
## with the far part shifted down and out a little.
static func _split(b: Build, planes: Array[Plane], pose: Transform3D, tone: Color, cracked: bool, crack: Plane) -> void:
	if not cracked:
		b.solid(planes,pose,tone,true,true,[],-1,0.7)
		return
	for s: float in [-1.0,1.0]:
		var cut: Array[Plane] = [Plane(crack.normal*s,crack.d*s-0.025)]
		var shift := Transform3D(Basis.IDENTITY,Vector3(0.0,-0.06,0.05)*float(s > 0.0))
		b.solid(planes,pose*shift,tone,true,true,cut,-1,0.7)

## A raised ring on a face at `pose`, round `centre` (z its foot), from
## radius `r0` to `r1`, `depth` proud: twelve stones.
static func _ring(b: Build, pose: Transform3D, centre: Vector3, r0: float, r1: float, depth: float) -> void:
	for k in range(12):
		var a0 := TAU*k/12.0
		var a1 := TAU*(k+1)/12.0
		var am := (a0+a1)*0.5
		var dm := Vector3(cos(am),sin(am),0.0)
		var planes: Array[Plane] = [Plane(Vector3.FORWARD,-centre.z),Plane(Vector3.BACK,centre.z+depth)]
		planes.append(Plane(Vector3(sin(a0),-cos(a0),0.0),Vector3(sin(a0),-cos(a0),0.0).dot(centre)-0.005))
		planes.append(Plane(Vector3(-sin(a1),cos(a1),0.0),Vector3(-sin(a1),cos(a1),0.0).dot(centre)-0.005))
		planes.append(Plane(-dm,(-dm).dot(centre+dm*r0)))
		planes.append(Plane(dm,dm.dot(centre+dm*r1)))
		var bevel := (dm+Vector3.BACK).normalized()
		planes.append(Plane(bevel,bevel.dot(centre+dm*r1+Vector3.BACK*depth)-0.04))
		b.solid(planes,pose,RuinKit._stone(b,1.08),false,true,[],-1,0.5)

## Turf banked over a sunk edge at `at`, toward `out`, `width` across: a
## low cut wedge of the plate's grass, never solid.
static func _turf(b: Build, at: Vector3, out: Vector3, width: float) -> void:
	var side := out.cross(Vector3.UP).normalized()
	var planes: Array[Plane] = [Plane(Vector3.DOWN,0.04)]
	for s: float in [-1.0,1.0]:
		planes.append(Plane(side*s,width*0.5))
		var n := (side*s*0.5+Vector3.UP).normalized()
		planes.append(Plane(n,n.dot(side*s*width*0.35+Vector3.UP*0.22)))
	var back := (-out+Vector3.UP*0.8).normalized()
	planes.append(Plane(back,back.dot(-out*0.6+Vector3.UP*0.04)))
	var front := (out+Vector3.UP*2.2).normalized()
	planes.append(Plane(front,front.dot(out*0.9+Vector3.UP*0.04)))
	planes.append(Plane(Vector3.UP,0.26))
	var keep := b.frame
	b.frame = Transform3D.IDENTITY
	b.solid(planes,Transform3D(Basis.IDENTITY,at),RuinKit.GRASS[0],false,true,[],-1,0.5,false)
	b.frame = keep

## Grass tufts round a foot at `at`, `reach` out: `count` of them.
static func _feet(b: Build, at: Vector3, reach: float, count: int) -> void:
	for i in range(count):
		var a := b.rng.randf()*TAU
		b.tuft(at+Vector3(cos(a),0.0,sin(a))*reach*b.rng.randf_range(0.85,1.25),0.42,b.rng.randi_range(4,7))
