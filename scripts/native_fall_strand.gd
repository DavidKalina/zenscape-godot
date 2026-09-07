extends RefCounted
## Source buildStrand geometry state, before animation/mesh construction.
const Course=preload("res://scripts/native_fall_course.gd")
static func add(a: Array,b: Array) -> Array: return [a[0]+b[0],a[1]+b[1],a[2]+b[2]]
static func scale(a: Array,s: float) -> Array: return [a[0]*s,a[1]*s,a[2]*s]
static func dot(a: Array,b: Array) -> float: return a[0]*b[0]+a[1]*b[1]+a[2]*b[2]
static func cross(a: Array,b: Array) -> Array: return [a[1]*b[2]-a[2]*b[1],a[2]*b[0]-a[0]*b[2],a[0]*b[1]-a[1]*b[0]]
static func normal(a: Array) -> Array:
	var length:=sqrt(dot(a,a))
	return scale(a,1.0/length) if length>0.0 else a.duplicate()
static func separation(a: Array,b: Array) -> float:
	var difference:=add(a,scale(b,-1.0))
	return sqrt(dot(difference,difference))
static func point(p: Dictionary) -> Array: return [p.x,p.h,p.z]
static func build(height_at: Callable,pool: Dictionary,start_x: float,start_z: float,aim: Dictionary,lip_half: float,depth: float,across: Array,flow: float,force:=false) -> Dictionary:
	var traced:=Course.trace(height_at,pool,start_x,start_z,aim,pool.waterY)
	if not traced.arrived and not force: return {}
	var probe:=Course.resample(traced.pts,10)
	var length:=0.0
	for i in range(1,probe.size()): length+=Course.distance(probe[i],probe[i-1])
	var room0:=Course.room(height_at,start_x,start_z,across[0],across[2],height_at.call(start_x,start_z),depth,3.0)
	var count:=Course.ring_count(length,minf(room0,minf(2.5,maxf(0.08,lip_half))))
	var centers: Array=[]
	for p in Course.resample(traced.pts,count): centers.append(point(p))
	var tangent: Array=[]
	for r in range(count):
		var t:=add(centers[mini(count-1,r+1)],scale(centers[maxi(0,r-1)],-1.0))
		tangent.append(normal(t) if dot(t,t)>0.00000001 else [0.0,-1.0,0.0])
	var axis_a: Array=[]
	var axis_b: Array=[]
	var previous:=across.duplicate()
	for t in tangent:
		var a:=add(previous,scale(t,-dot(previous,t)))
		if dot(a,a)<0.000001: a=previous.duplicate()
		a=normal(a)
		var level:=cross(t,[0.0,1.0,0.0])
		if dot(level,level)>0.000001:
			level=normal(level)
			if dot(level,a)<0.0: level=scale(level,-1.0)
			var blend:=smoothstep(0.995,0.9,absf(t[1]))
			a=add(a,scale(add(level,scale(a,-1.0)),blend))
			a=normal(add(a,scale(t,-dot(a,t))))
		axis_a.append(a)
		axis_b.append(normal(cross(t,a)))
		previous=a
	var steep: Array[float]=[]
	for t in tangent: steep.append(clampf(-t[1],0.0,1.0))
	var tau: Array[float]=[0.0]
	for r in range(1,count): tau.append(tau[-1]+separation(centers[r],centers[r-1])/(1.0+3.0*steep[r]))
	var aeration: Array[float]=[]
	var air:=0.0
	for r in range(count):
		var dt:=tau[r]-tau[r-1] if r>0 else 0.0
		air=minf(1.0,air*pow(0.5,dt)+steep[r]*dt*1.15)
		aeration.append(air)
	var rooms: Array[float]=[]
	for r in range(count):
		var c: Array=centers[r]
		var a: Array=axis_a[r]
		rooms.append(Course.room(height_at,c[0],c[2],a[0],a[2],height_at.call(c[0],c[2]),depth,3.0))
	for pass_index in range(2):
		for r in range(1,count-1): rooms[r]=(rooms[r-1]+2.0*rooms[r]+rooms[r+1])/4.0
	var cap:=maxf(0.08*3.0,minf(lip_half*2.2,length*0.35))
	var w0:=minf(rooms[0],minf(cap,maxf(0.08,lip_half)))
	var widths: Array[float]=[]
	for r in range(count):
		var profile: float=(1.0-0.16*steep[r])*(1.0+0.5*aeration[r])
		var want:=minf(rooms[r],minf(cap*(1.0+0.5*aeration[r]),maxf(0.08,w0*profile)))
		widths.append(want if r==0 else maxf(widths[r-1]*0.94,minf(widths[r-1]*1.18,want)))
	for pass_index in range(2):
		for r in range(1,count-1): widths[r]=(widths[r-1]+widths[r]*2.0+widths[r+1])/4.0
	for r in range(count): widths[r]=minf(widths[r],maxf(0.08,rooms[r]))
	var thickness: Array[float]=[]
	var inlet:=minf(1.6,(count-1)*0.12)
	for r in range(count):
		var thick:=minf(widths[r]*0.55,(0.06+0.45*steep[r])*(0.5+flow*0.4))
		thick*=0.06+0.94*smoothstep(0.0,2.5,float(r))
		var pinch:=0.28+0.72*smoothstep(0.0,inlet,float(r))
		widths[r]*=pinch
		thickness.append(thick*pinch)
	for r in range(count):
		var c: Array=centers[r]
		var gradient:=Course.slope(height_at,c[0],c[2])
		var n:=normal([-gradient[0],1.0,-gradient[1]])
		centers[r]=add(c,scale(n,-(thickness[r]+0.32) if r==0 else thickness[r]*0.9+0.06))
	centers[-1][1]=pool.waterY-0.05
	var ledges: Array[int]=[]
	for r in range(2,count-3):
		if steep[r]>0.5 and steep[r]-steep[r+2]>0.26 and (ledges.is_empty() or r-ledges[-1]>2): ledges.append(r)
	return {"centers":centers,"axA":axis_a,"axB":axis_b,"halfW":widths,"thick":thickness,"steep":steep,"aer":aeration,"tau":tau,"rooms":rooms,"ledges":ledges,"impact":centers[-1].duplicate()}

static func landscape(height_at: Callable,pool: Dictionary,genome: Dictionary) -> Array[Dictionary]:
	var chute: Dictionary=genome.chute
	var flow: float=chute.flow
	var specs: Array=chute.get("strands",[])
	var result: Array[Dictionary]=[]
	if flow<=0.01 or specs.is_empty(): return result
	var dx: float=chute.px-pool.x
	var dz: float=chute.pz-pool.z
	var length:=sqrt(dx*dx+dz*dz)
	if length<0.000001: return result
	var basin: Dictionary=genome.get("basin",{}) if genome.get("basin") is Dictionary else {}
	var rim:=Course.pool_radius(pool,atan2(dz,dx))*float(basin.get("outletT",1.0))
	var aim_in:=0.78 if not basin.is_empty() else 0.38
	var aim: Dictionary={"x":pool.x+dx/length*rim*aim_in,"z":pool.z+dz/length*rim*aim_in}
	var across: Array=[-dz/length,0.0,dx/length]
	var depth:=0.3+flow
	var curtain:=Course.room(height_at,chute.px,chute.pz,across[0],across[2],height_at.call(chute.px,chute.pz),depth,3.0)
	var total:=0.0
	for spec in specs: total+=spec.w
	var cumulative:=0.0
	for i in range(specs.size()):
		var spec: Dictionary=specs[i]
		var fraction: float=spec.w/total
		var mid: float=cumulative+fraction/2.0
		cumulative+=fraction
		var share:=minf(1.0,fraction*1.7)
		var lip_half:=maxf(0.16,fraction*curtain*1.45)
		var offset:=0.0 if specs.size()==1 else (mid*2.0-1.0)*curtain*(1.0-share*0.5)
		var sx: float=chute.px+across[0]*offset+dx/length*-spec.start*length*0.5
		var sz: float=chute.pz+across[2]*offset+dz/length*-spec.start*length*0.5
		var strand:=build(height_at,pool,sx,sz,aim,lip_half,depth,across,flow)
		if not strand.is_empty():
			strand.seed=i*13.7
			result.append(strand)
	if result.is_empty():
		var strand:=build(height_at,pool,chute.px,chute.pz,aim,curtain,depth,across,flow,true)
		strand.seed=0.0
		result.append(strand)
	return result
