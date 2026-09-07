class_name NativeTerrainPalette
extends RefCounted
## Source seed-7 palette in linear RGB, including cover offsets and face shimmer.
var noise := preload("res://scripts/reference_source_ground.gd").new()
var grass: Array[Color] = []
var rock: Array[Color] = []
var snow := Color("f4f7fa").srgb_to_linear()
var sand: Color
var gravel: Color
var snowline := 0.0
var rock_slope := 0.0
func _init() -> void:
	noise.setup()
	var palette: Dictionary = noise.g.palette
	var cover: Dictionary = noise.g.cover
	var hue: float = palette.hue
	var p: float = cover.parch
	var c: float = cover.chill
	var w: float = cover.sodden
	for hex in ["5d9e53","7fb069","4a8548"]:
		grass.append(shift_hsl(Color(hex).srgb_to_linear(),hue-0.075*p+0.06*c+0.03*w,-0.38*p-0.3*c+0.05*w,0.1*p+0.06*c-0.08*w))
	for hex in ["8d8577","6f6a5f"]:
		rock.append(shift_hsl(Color(hex).srgb_to_linear(),hue*0.3,0.0,palette.rockLift+0.05*c))
	gravel = shift_hsl(Color("a8a08c").srgb_to_linear(),hue*0.3,-0.05,0.0)
	sand = shift_hsl(Color("c9b57e").srgb_to_linear(),hue*0.5-0.01*p,-0.05*p,0.05*p)
	snowline = palette.snowline
	rock_slope = palette.rockSlope
func patch(point: Vector2) -> float:
	return noise.fbm(point.x*0.4,point.y*0.4)
func grass_at(point: Vector2) -> Color:
	return grass_at_coordinates(point.x,point.y)
func grass_at_coordinates(x: float, z: float) -> Color:
	var n: float = noise.fbm(x*0.4,z*0.4)
	return shimmer_coordinates(grass[1 if n > 0.55 else 2 if n < 0.42 else 0],x,z)
func rock_at(point: Vector2) -> Color:
	return rock_at_coordinates(point.x,point.y)
func rock_at_coordinates(x: float, z: float) -> Color:
	return shimmer_coordinates(rock[0 if noise.fbm(x*0.4,z*0.4) > 0.5 else 1],x,z)
func shimmer(color: Color, point: Vector2) -> Color:
	return shimmer_coordinates(color,point.x,point.y)
func shimmer_coordinates(color: Color, x: float, z: float) -> Color:
	var v := (noise.hash_at(x*7.3,z*7.3)-0.5)*0.07
	return Color(color.r+v,color.g+v,color.b+v)
static func shift_hsl(color: Color, dh: float, ds: float, dl: float) -> Color:
	# THREE.Color.offsetHSL operates on its linear RGB storage.
	var high := maxf(color.r,maxf(color.g,color.b))
	var low := minf(color.r,minf(color.g,color.b))
	var light := (high+low)*0.5
	var hue := 0.0
	var saturation := 0.0
	var delta := high-low
	if delta > 0.0:
		saturation = delta/(high+low) if light <= 0.5 else delta/(2.0-high-low)
		if high == color.r:
			hue = (color.g-color.b)/delta+(6.0 if color.g < color.b else 0.0)
		elif high == color.g:
			hue = (color.b-color.r)/delta+2.0
		else:
			hue = (color.r-color.g)/delta+4.0
		hue /= 6.0
	hue = fposmod(hue+dh,1.0)
	saturation = clampf(saturation+ds,0.0,1.0)
	light = clampf(light+dl,0.0,1.0)
	var q := light*(1.0+saturation) if light <= 0.5 else light+saturation-light*saturation
	var p := 2.0*light-q
	return Color(_channel(p,q,hue+1.0/3.0),_channel(p,q,hue),_channel(p,q,hue-1.0/3.0))
static func _channel(p: float, q: float, value: float) -> float:
	var t := fposmod(value,1.0)
	if t < 1.0/6.0: return p+(q-p)*6.0*t
	if t < 0.5: return q
	if t < 2.0/3.0: return p+(q-p)*6.0*(2.0/3.0-t)
	return p
