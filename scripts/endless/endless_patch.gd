extends RefCounted
## The endless ground's patches in GDScript (shaders/endless_patch.gdshaderinc,
## the same integer-hashed value noise, and the grass colour of shaders/
## endless_ground.gdshader from its scales of 8 m up), so the grass carpet's
## tufts (scripts/endless/endless_grass.gd) take the painted ground's
## patches, its meadows' lusher turf, its dry ground and its tundra: `tint`
## is the painted grass there over its plain colour, which the tufts'
## instance colour carries. Keep it in step with the shader's grass.

const M := 0xffffffff

## The shader's greens (linear), as endless_ground.gdshader has them.
const GREEN := Vector3(0.1296,0.3563,0.1597)
const SUNLIT := Vector3(0.2012,0.4365,0.1964)
const DEEP := Vector3(0.1004,0.2565,0.1318)
const DRY := Vector3(0.2350,0.3800,0.1250)
const MEADOW := Vector3(0.2050,0.4500,0.1300)
const TUNDRA := Vector3(0.2050,0.2300,0.1300)
const OLIVE := Vector3(0.2300,0.2600,0.1200)
## Its uniforms' defaults: patch_strength, thin_up, rock_up, vertex_hue.
const PATCH_STRENGTH := 1.0
const THIN_UP := 0.93
const ROCK_UP := 0.80
const VERTEX_HUE := 0.2
## The fine dry patches' mean (the tufts draw their own).
const DRY_NEAR := 0.18

## a*b mod 2^32, in halves so no product passes 2^63.
static func _mul(a: int, b: int) -> int:
	return (a*(b & 0xffff)+(((a*(b >> 16)) & 0xffff) << 16)) & M

static func _hash(x: int, z: int) -> int:
	var h := _mul(x & M,1597334677) ^ _mul(z & M,3812015801)
	h ^= h >> 16
	h = _mul(h,2246822519)
	h ^= h >> 13
	h = _mul(h,3266489917)
	h ^= h >> 16
	return h

static func _lattice(x: int, z: int) -> float:
	return float(_hash(x,z) >> 8)/16777215.0

static func noise(px: float, pz: float) -> float:
	var ix := floori(px)
	var iz := floori(pz)
	var fx := px-ix
	var fz := pz-iz
	fx = fx*fx*(3.0-2.0*fx)
	fz = fz*fz*(3.0-2.0*fz)
	var a := lerpf(_lattice(ix,iz),_lattice(ix+1,iz),fx)
	var b := lerpf(_lattice(ix,iz+1),_lattice(ix+1,iz+1),fx)
	return lerpf(a,b,fz)

## A river bank's width of sand and stones past the water at a point (m),
## as the ground shader paints it (endless_ground `bank_w`, `river_bank`
## 3.5), so the grass stops where the stones start.
static func river_bank(x: float, z: float) -> float:
	var n := noise(x/70.0+11.0,z/70.0+11.0)*0.75+noise(x/17.0+5.0,z/17.0+5.0)*0.25
	return 3.5*lerpf(0.2,1.6,smoothstep(0.32,0.68,n))

## ep_fade and ep_patch near the eye (no fade).
static func fade(x: float, z: float, scale: float) -> float:
	return noise(x/scale,z/scale)-0.5

static func patch(x: float, z: float, scale: float) -> float:
	return smoothstep(0.43,0.57,noise(x/scale,z/scale))-0.5

## patch with its edge's softness `w0` (the ground's `ep_patch_edge`, near
## the eye where its pixel widening is nil).
static func patch_edge(x: float, z: float, scale: float, w0: float) -> float:
	return smoothstep(0.5-w0,0.5+w0,noise(x/scale,z/scale))-0.5

## The calmed paint's light/deep share (-1..1) from the scales of 19 m up, as
## endless_ground.gdshader `sunny` (PAINT_BIAS, the crisp clumps, the soft
## thirds): the tufts carry no finer variation, so neighbours agree.
const PAINT_BIAS := -0.10
const PAINT_STEPS := 0.92
static func sunny_of(broad: float, wide: float, mid: float, x: float, z: float) -> float:
	var clump := patch_edge(x+57.0,z+19.0,34.0,0.02)*1.5+patch_edge(x+3.0,z+77.0,8.0,0.04)*0.18
	var s := clampf(PAINT_BIAS+(broad*1.3+wide*1.8+mid*0.36+clump*0.9)*PATCH_STRENGTH,-1.0,1.0)
	var q := s*3.0
	q = (floorf(q)+smoothstep(0.36,0.64,q-floorf(q)))/3.0
	return lerpf(s,q,PAINT_STEPS)

static func _luma(c: Vector3) -> float:
	return c.dot(Vector3(0.2126,0.7152,0.0722))

## The painted grass's colour (linear) at a world point: its scales of 8 m
## up, `meadow` 0..1, `over` m over the sea, `up` the normal's, `hue` the
## land's vertex colour (linear; zero: none).
static func grass(x: float, z: float, meadow: float, over: float, up: float, hue := Vector3.ZERO) -> Vector3:
	var vast := fade(x+311.0,z+97.0,900.0)
	var broad := fade(x+71.0,z+13.0,260.0)
	var wide := fade(x+5.0,z+211.0,70.0)
	var mid := fade(x+133.0,z+41.0,19.0)
	var sunny := sunny_of(broad,wide,mid,x,z)
	var g := GREEN.lerp(SUNLIT if sunny > 0.0 else DEEP*0.82,absf(sunny))
	g = g.lerp(MEADOW*(1.0+mid*0.5),meadow*0.75)
	var warm := clampf(broad*2.4+vast*1.8,-1.0,1.0)*PATCH_STRENGTH
	g *= Vector3.ONE.lerp(Vector3(1.32,1.05,0.62) if warm > 0.0 else Vector3(0.80,0.97,1.16),absf(warm)*0.5)
	g *= region(x,z,over)
	if hue != Vector3.ZERO: g = g.lerp(hue/maxf(_luma(hue),0.01)*_luma(g),VERTEX_HUE*0.6)
	var dry_far := smoothstep(0.05,0.32,broad+wide*0.6+0.1)
	var dry := clampf(DRY_NEAR*0.6+dry_far*0.55,0.0,1.0)*(1.0-meadow*0.6)
	g = g.lerp(DRY,dry*0.4)
	var alpine := smoothstep(42.0,78.0,over+broad*30.0)
	g = g.lerp(TUNDRA*(1.0+mid*0.6),alpine*0.8)
	var thin := smoothstep(THIN_UP,ROCK_UP,up)
	g = g.lerp(OLIVE,thin*0.7)
	return g

## The rock's hash and value noise (shaders/endless_rock.gdshaderinc
## er_hash3's x, er_vnoise), for the rock's ragged edge.
static func _rock_hash(x: int, y: int, z: int) -> float:
	var vx := (_mul(x & M,1664525)+1013904223) & M
	var vy := (_mul(y & M,1664525)+1013904223) & M
	var vz := (_mul(z & M,1664525)+1013904223) & M
	vx = (vx+_mul(vy,vz)) & M
	vy = (vy+_mul(vz,vx)) & M
	vz = (vz+_mul(vx,vy)) & M
	vx ^= vx >> 16
	vy ^= vy >> 16
	vz ^= vz >> 16
	vx = (vx+_mul(vy,vz)) & M
	return float(vx & 65535)/65535.0

static func _rock_noise(p: Vector3, lattice: Dictionary) -> float:
	var i := p.floor()
	var f := p-i
	f = f*f*(Vector3(3.0,3.0,3.0)-2.0*f)
	var q := Vector3i(i)
	var h := PackedFloat32Array()
	h.resize(8)
	for k in 8:
		var at := q+Vector3i(k & 1,(k >> 1) & 1,k >> 2)
		if not lattice.has(at): lattice[at] = _rock_hash(at.x,at.y,at.z)
		h[k] = lattice[at]
	var a := lerpf(lerpf(h[0],h[1],f.x),lerpf(h[2],h[3],f.x),f.y)
	var b := lerpf(lerpf(h[4],h[5],f.x),lerpf(h[6],h[7],f.x),f.y)
	return lerpf(a,b,f.z)

## The most the rock's ragged edge swings the normal's up.
const RAGGED_MOST := 0.13

## The rock's ragged edge at a world point (the ground's `ragged`): the
## paint draws rock where the normal's up plus this is under ROCK_UP.
## `lattice` keeps the hashes for the next call (one per caller).
static func rock_ragged(p: Vector3, lattice := {}) -> float:
	return (_rock_noise(p/7.0,lattice)-0.5)*0.10+(_rock_noise(p/31.0+Vector3(4.0,4.0,4.0),lattice)-0.5)*0.16

## How far the paint has turned to tundra at a world point (0..1; the
## shader's `alpine`), `over` m over the sea.
static func alpine(x: float, z: float, over: float) -> float:
	return alpine_of(over,broad(x,z))

## The same from the broad patch there (`broad`).
static func alpine_of(over: float, broad_patch: float) -> float:
	return smoothstep(42.0,78.0,over+broad_patch*30.0)

## Under this over the sea (m) alpine is 0 whatever the broad patch.
const ALPINE_FROM := 42.0-15.0

## The paint's broad patch (260 m across, -0.5..0.5) at a world point.
static func broad(x: float, z: float) -> float:
	return fade(x+71.0,z+13.0,260.0)

## The plain grass every tint is over: no patches, half meadow, low, level.
static var _plain := Vector3.ZERO
static func plain() -> Vector3:
	if _plain == Vector3.ZERO:
		var g := GREEN.lerp(MEADOW,0.5*0.75)
		g = g.lerp(DRY,clampf(DRY_NEAR*0.6+smoothstep(0.05,0.32,0.1)*0.55,0.0,1.0)*(1.0-0.5*0.6)*0.4)
		_plain = g
	return _plain

## A tuft's tint at a world point: the painted grass there over the plain.
static func tint(x: float, z: float, meadow: float, over: float, up: float, hue := Vector3.ZERO) -> Color:
	var g := grass(x,z,meadow,over,up,hue)
	var p := plain()
	return Color(g.x/p.x,g.y/p.y,g.z/p.z)

# --- Grass colour regions and flower drifts (look round 5) ---------------------
# The shader's ep_region, ep_bloom (shaders/endless_patch.gdshaderinc): keep
# them in step.

## The land seed's offset (m) both read at, set once before any worker runs
## (scripts/endless/endless_grass.gd; the ground's `region_offset`).
static var offset := Vector2.ZERO
## How strongly the regions tint the grass (0: off; the ground's
## `region_amount`), how many flower drifts there are (0: none; its
## `bloom_amount`). Set once before any worker runs.
static var region_amount := 1.0
static var bloom_amount := 1.0

const LUSH := Vector3(0.44,0.78,0.58)
const LIME := Vector3(1.33,1.20,0.30)
const SAGE := Vector3(0.92,0.90,1.65)
const STRAW := Vector3(2.05,1.22,0.48)
const HEATHER := Vector3(1.39,0.74,1.46)

## The land seed's offset for `seed`: a few kilometres, so each seed's
## regions and drifts are its own.
static func seed_offset(land_seed: int) -> Vector2:
	var h := _hash(land_seed,7717)
	return Vector2(float(h & 0xffff)/65535.0,float(h >> 16)/65535.0)*4000.0

static func _lerp3(a: Vector3, b: Vector3, t: float) -> Vector3:
	return a+(b-a)*t

static func _ss(a: float, b: float, x: float) -> float:
	# GLSL's smoothstep, which (unlike Godot's) takes a > b as a falling edge.
	var t := clampf((x-a)/(b-a),0.0,1.0)
	return t*t*(3.0-2.0*t)

## The region's hue at a world point (a multiplier over the grass).
static func region(x: float, z: float, over: float) -> Vector3:
	var amount := region_amount
	if amount <= 0.0: return Vector3.ONE
	var q := Vector2(x,z)+offset
	var r := Vector2(q.x*0.8-q.y*0.6,q.x*0.6+q.y*0.8)
	var a := noise(r.x/380.0+3.7,r.y/380.0+1.3)*0.8+noise(r.x/130.0-4.1,r.y/130.0+2.2)*0.2
	var b := noise(q.y/300.0-2.1,q.x/300.0+8.4)*0.8+noise(q.x/110.0+6.3,q.y/110.0-1.7)*0.2
	var c := noise(r.y/220.0+5.5,r.x/220.0-3.3)
	var m := _lerp3(Vector3.ONE,LUSH,_ss(0.42,0.30,a)*amount)
	m *= _lerp3(Vector3.ONE,LIME,_ss(0.58,0.70,a)*amount)
	m *= _lerp3(Vector3.ONE,SAGE,_ss(0.42,0.30,b)*amount)
	m *= _lerp3(Vector3.ONE,STRAW,_ss(0.60,0.72,b)*amount)
	m *= _lerp3(Vector3.ONE,HEATHER,_ss(0.55,0.68,c)*_ss(16.0,34.0,over)*amount)
	return m

## The drifts' kinds by ep_bloom's index: [the flower kind (scripts/
## meadow_types.gd FLOWER_KEYS), its colour variant, the wash (linear)].
const KINDS := [
	["buttercup",0.0,Vector3(0.815,0.509,0.018)],
	["oxeye_daisy",0.0,Vector3(0.900,0.880,0.780)],
	["poppy",0.0,Vector3(0.687,0.064,0.025)],
	["lupine",0.1,Vector3(0.255,0.140,0.527)],
	["cosmos",0.1,Vector3(0.730,0.188,0.392)],
	["cosmos",0.4,Vector3(0.480,0.060,0.250)],
	["dandelion",0.0,Vector3(0.800,0.480,0.012)],
]
const KIND_SLOTS := [0,0,0,1,1,6,6,2,2,3,3,3,4,5,0,4]

static func _layer(q: Vector2, cell: float, chance: float, rad: Vector2, salt: int, best: Vector2) -> Vector2:
	var cx := floori(q.x/cell-0.5)
	var cz := floori(q.y/cell-0.5)
	for j in range(0,2):
		for i in range(0,2):
			var c := Vector2i(cx+i,cz+j)
			var h := _hash(c.x+salt,c.y+salt*3)
			if float(h & 255)/255.0 >= chance: continue
			var centre := (Vector2(c)+Vector2(0.2,0.2)+0.6*Vector2(float((h >> 8) & 255),float((h >> 16) & 255))/255.0)*cell
			var radius := cell*lerpf(rad.x,rad.y,float((h >> 24) & 15)/15.0)
			var w := 1.0-_ss(0.35,1.0,q.distance_to(centre)/radius)
			if w > best.x: best = Vector2(w,float(KIND_SLOTS[(h >> 28) & 15]))
	return best

## The flower drifts at a world point: x their weight (0..1), y the kind
## (KINDS' index).
static func bloom(x: float, z: float) -> Vector2:
	var best := Vector2.ZERO
	var amount := bloom_amount
	if amount <= 0.0: return best
	var q := Vector2(x,z)+offset
	q += (Vector2(noise(q.x/41.0+4.2,q.y/41.0-2.6),noise(q.x/41.0-3.3,q.y/41.0+7.9))-Vector2(0.5,0.5))*30.0
	best = _layer(q,46.0,0.44*amount,Vector2(0.28,0.5),7151,best)
	best = _layer(q,15.0,0.16*amount,Vector2(0.2,0.38),9241,best)
	best.x *= lerpf(0.45,1.0,_ss(0.3,0.68,noise(q.x/6.5+2.9,q.y/6.5-8.1)))
	return best
