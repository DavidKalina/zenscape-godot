class_name NativeMountainShape
extends RefCounted
## Adapt the original world.js spine/scarp/ridged-noise recipe to a local stamp.
## Noise constants and octave weights match makeNoise; the footprint is bounded
## for editing, unlike the original genome's chunk-spanning mountain range.
var seed := 7.0
var spine := PackedVector2Array()

func _init(variation := 7) -> void:
	seed = float(variation)
	for i in range(7):
		var x := lerpf(-0.76,0.76,float(i)/6.0)
		spine.append(Vector2(x,0.14*sin(x*4.0+seed)+0.07*(lattice_hash(i,4)-0.5)))

func lattice_hash(x: float, z: float) -> float:
	return fposmod(sin(x*127.1+z*311.7+seed)*43758.5453,1.0)

func value_noise(point: Vector2) -> float:
	var cell := point.floor()
	var f := point-cell
	var u := f.x*f.x*(3.0-2.0*f.x)
	var v := f.y*f.y*(3.0-2.0*f.y)
	var a := lattice_hash(cell.x,cell.y)
	var b := lattice_hash(cell.x+1,cell.y)
	var c := lattice_hash(cell.x,cell.y+1)
	var d := lattice_hash(cell.x+1,cell.y+1)
	return a+(b-a)*u+(c-a)*v+(a-b-c+d)*u*v

func fbm(point: Vector2) -> float:
	var sum := 0.0
	var amplitude := 0.5
	var frequency := 1.0
	for i in range(4):
		sum += amplitude*value_noise(point*frequency)
		amplitude *= 0.5
		frequency *= 2.1
	return sum

func ridged(point: Vector2) -> float:
	return 1.0-absf(2.0*fbm(point)-1.0)

func height(point: Vector2) -> float:
	if point.length() >= 1.0:
		return 0.0
	var distance := INF
	for i in range(spine.size()-1):
		var edge := spine[i+1]-spine[i]
		var t := clampf((point-spine[i]).dot(edge)/edge.length_squared(),0.0,1.0)
		distance = minf(distance,point.distance_to(spine[i]+edge*t))
	# Source: spineDist - (fbm(x*.45+9,z*.45+9)-.5)*2.6,
	# with its asymmetric scarp compressing the front-facing flank.
	distance -= (fbm(point*4.5+Vector2.ONE*9.0)-0.5)*0.22
	var front := smoothstep(-0.12,0.12,point.y)
	var falloff := lerpf(0.70,0.48,front)
	var mass := 1.0-smoothstep(falloff*0.12,falloff,distance)
	var profile := 0.75*ridged(point*3.2+Vector2(7,0))+0.25*fbm(point*3.2+Vector2(7,0))
	# Distinct summits and a saddle follow the ridge rather than radial distance.
	var crest := 0.60+0.40*pow(absf(cos(point.x*5.4+0.22*sin(seed))),1.7)
	var crag := 0.10*(2.0*ridged(point*8.0+Vector2(13,0))-1.0)
	return maxf(0.0,mass*(0.88+0.12*profile+crag)*crest*(1.0-smoothstep(0.78,1.0,point.length())))
