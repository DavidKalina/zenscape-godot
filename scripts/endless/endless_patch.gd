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

## ep_fade and ep_patch near the eye (no fade).
static func fade(x: float, z: float, scale: float) -> float:
	return noise(x/scale,z/scale)-0.5

static func patch(x: float, z: float, scale: float) -> float:
	return smoothstep(0.43,0.57,noise(x/scale,z/scale))-0.5

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
	var clump := patch(x+57.0,z+19.0,34.0)*0.7+patch(x+3.0,z+77.0,8.0)*0.5
	var sunny := clampf((broad*1.3+wide*1.5+mid*0.9+clump*0.9)*PATCH_STRENGTH,-1.0,1.0)
	var g := GREEN.lerp(SUNLIT if sunny > 0.0 else DEEP*0.82,absf(sunny))
	g = g.lerp(MEADOW*(1.0+mid*0.5),meadow*0.75)
	var warm := clampf(broad*2.4+vast*1.8,-1.0,1.0)*PATCH_STRENGTH
	g *= Vector3.ONE.lerp(Vector3(1.32,1.05,0.62) if warm > 0.0 else Vector3(0.80,0.97,1.16),absf(warm)*0.5)
	if hue != Vector3.ZERO: g = g.lerp(hue/maxf(_luma(hue),0.01)*_luma(g),VERTEX_HUE*0.6)
	var dry_far := smoothstep(0.05,0.32,broad+wide*0.6+0.1)
	var dry := clampf(DRY_NEAR*0.6+dry_far*0.55,0.0,1.0)*(1.0-meadow*0.6)
	g = g.lerp(DRY,dry*0.4)
	var alpine := smoothstep(42.0,78.0,over+broad*30.0)
	g = g.lerp(TUNDRA*(1.0+mid*0.6),alpine*0.8)
	var thin := smoothstep(THIN_UP,ROCK_UP,up)
	g = g.lerp(OLIVE,thin*0.7)
	return g

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
