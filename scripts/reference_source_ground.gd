extends RefCounted
## Original continuous height equations for the imported seed-7 range.
## This consumes an exported genome/plan; it does not generate new worlds.
var g: Dictionary
var pool: Dictionary
var landmark: Dictionary
var noise_seed := 0.0
func setup() -> void:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/zen_reference/terrain-source.json"))
	g = data.genome
	pool = data.pool
	landmark = data.landmark
	noise_seed = data.noiseSeed
	assert(data.strips == null and g.seed == 7 and g.gen == 21, "Continuous terrain sampler requires the imported seed-7 scene")
func hash_at(x: float, z: float) -> float:
	var s := sin(x * 127.1 + z * 311.7 + noise_seed) * 43758.5453
	return s - floor(s)
func noise_at(x: float, z: float) -> float:
	var xi := floorf(x)
	var zi := floorf(z)
	var u := smoothstep(0.0, 1.0, x - xi)
	var v := smoothstep(0.0, 1.0, z - zi)
	var a := hash_at(xi, zi)
	var b := hash_at(xi + 1, zi)
	var c := hash_at(xi, zi + 1)
	var d := hash_at(xi + 1, zi + 1)
	return a + (b-a)*u + (c-a)*v + (a-b-c+d)*u*v
func fbm(x: float, z: float) -> float:
	var result := 0.0
	var amplitude := 0.5
	var frequency := 1.0
	for i in range(4):
		result += amplitude * noise_at(x * frequency, z * frequency)
		amplitude *= 0.5
		frequency *= 2.1
	return result
func spine_distance(x: float, z: float) -> float:
	var best := INF
	for points: Array in g.spine.lines:
		for i in range(points.size()-1):
			var ax: float = points[i][0]
			var az: float = points[i][1]
			var bx: float = points[i+1][0] - ax
			var bz: float = points[i+1][1] - az
			var t := clampf(((x-ax)*bx+(z-az)*bz)/(bx*bx+bz*bz),0,1)
			best = minf(best, (x-ax-bx*t)**2 + (z-az-bz*t)**2)
	return sqrt(best)
func channel_at(x: float, z: float) -> float:
	var half: float = g.size / 2.0 + 4.0
	var extent := ceilf(half * 2.0 / 1.5) * 1.5 - half
	if x < -half or z < -half or x >= extent or z >= extent:
		return INF
	var best := INF
	for stream: Dictionary in g.streams:
		var width: float = stream.width * 0.5
		var reach := width * 3.7 + 0.3
		for i in range(stream.pts.size()-1):
			var a: Dictionary = stream.pts[i]
			var b: Dictionary = stream.pts[i+1]
			var dx: float = b.x-a.x
			var dz: float = b.z-a.z
			var length_squared := dx*dx+dz*dz
			var t := clampf(((x-a.x)*dx+(z-a.z)*dz)/(length_squared if length_squared != 0 else 0.000001),0,1)
			var distance := sqrt((x-a.x-dx*t)**2+(z-a.z-dz*t)**2)
			if distance > reach:
				continue
			var bed := maxf(stream.floor, a.h-stream.depth+(b.h-a.h)*t)
			var u := maxf(0, distance/width-1)/1.8
			best = minf(best, bed+u*u*3)
	return best
func foundation_at(x: float, z: float, mountain_mask := 0.0) -> float:
	var h: float = g.meadow.base + fbm(x*g.meadow.freq+3,z*g.meadow.freq+3)*g.meadow.amp
	for stamp: Dictionary in g.stamps:
		h += stamp.amp * exp(-((x-stamp.x)**2+(z-stamp.z)**2)/stamp.r2)
	var relief: Dictionary = g.relief
	return h+(maxf(0,x*relief.tiltX+z*relief.tiltZ)+fbm(x*relief.hillFreq-17,z*relief.hillFreq+23)*relief.hillAmp)*(1-mountain_mask*relief.massFade)

func height_at(x: float, z: float) -> float:
	var d := spine_distance(x,z)-(fbm(x*0.45+9,z*0.45+9)-0.5)*2.6
	var side: float = (x-g.spine.cx)*g.spine.perpX+(z-g.spine.cz)*g.spine.perpZ
	var front := smoothstep(-1.2,1.2,side*g.spine.scarpSign)
	var falloff: float = g.spine.falloff*(1-front*(1-g.spine.scarp))
	var crest: Dictionary = g.landform.crest
	var along_ridge: float = (x-g.spine.cx)*crest.dx+(z-g.spine.cz)*crest.dz
	var top := 0.0
	for peak: Dictionary in crest.peaks:
		top = maxf(top,peak.height*pow(clampf(1-absf(along_ridge-peak.at)/peak.width,0,1),0.85))
	var crest_height: float = crest.saddle+(1-crest.saddle)*top
	var m := pow(clampf(1-maxf(0,d)/falloff,0,1),crest.flank)*crest_height
	var h := foundation_at(x,z,m)
	var n := fbm(x*g.wall.freq+7,z*g.wall.freq)
	var wn: float = (1-absf(2*n-1))*g.wall.sharp+n*(1-g.wall.sharp)
	var wall: float = (g.wall.base+g.wall.amp+g.wall.spike)*(0.88+0.12*wn)
	var ax: float = g.chute.px-pool.x
	var az: float = g.chute.pz-pool.z
	var length := sqrt(ax*ax+az*az)
	var ux := ax/length
	var uz := az/length
	var rx: float = x-pool.x
	var rz: float = z-pool.z
	var u := rx*ux+rz*uz
	var v := -rx*uz+rz*ux
	var notch: float = exp(-v*v/g.chute.width)
	var along := smoothstep(length-1.6,length+0.4,u)*(1-smoothstep(length+1.2,length+4.2,u))
	var mass: float = wall*(m*(1-notch)+along*g.chute.keep*notch*crest_height)
	# JS Math.round ties toward positive infinity, unlike round() for negatives.
	var quantized: float = floor(mass/g.terrace.step+0.5)*g.terrace.step
	h += mass+(quantized-mass)*g.terrace.mix
	var channel := channel_at(x,z)
	h = minf(h,channel)
	var angle := atan2(rz,rx)
	var lobes := 1.0
	for lobe: Dictionary in g.pool.lobes:
		lobes += lobe.amp*sin(angle*lobe.k+lobe.ph)
	var ca := cos(angle-g.pool.stretchTheta)
	var radius: float = g.pool.radius*lobes*(1+(g.pool.stretch-1)*ca*ca)
	var scoop := minf(1,exp(-(v*v+u*u*(2.5 if u>0 else 1.0))/(radius*radius*1.13))*1.9)
	h = h*(1-scoop)+pool.floorY*scoop
	h = minf(h,pool.floorY+0.12+smoothstep(0.5,0.85,sqrt(u*u+v*v)/pool.radius)*14)
	var lx: float = x-landmark.x
	var lz: float = z-landmark.z
	var lu: float = lx*landmark.dx+lz*landmark.dz
	var lv: float = -lx*landmark.dz+lz*landmark.dx
	var edge: float = sqrt((lu/landmark.ru)**2+(lv/landmark.rv)**2)
	if edge < 1:
		var shape: Dictionary = landmark.shape
		var bend: float = 0.3*sin(lv*0.7+shape.phase)
		var target: float = landmark.floor-0.45+2.8*smoothstep(shape.span*0.35,shape.span*0.98,absf(lu-bend))+0.10*sin(lv*1.7+lu+shape.phase)
		h += (target-h)*(1-smoothstep(0.72,1,edge))
	return minf(h,channel)
