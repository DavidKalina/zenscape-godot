extends RefCounted
## Source waterfall.js course tracing and descent-weighted ring placement.
## Double-valued point dictionaries avoid early Vector3 rounding on long traces.
static func pool_radius(pool: Dictionary,angle: float) -> float:
	var m:=1.0
	for lobe in pool.lobes: m+=lobe.amp*sin(angle*lobe.k+lobe.ph)
	var ca:=cos(angle-pool.stretchTheta)
	return pool.radius*m*(1.0+(pool.stretch-1.0)*ca*ca)
static func slope(height_at: Callable,x: float,z: float) -> Array[float]:
	return [(height_at.call(x+0.22,z)-height_at.call(x-0.22,z))/0.44,(height_at.call(x,z+0.22)-height_at.call(x,z-0.22))/0.44]
static func trace(height_at: Callable,pool: Dictionary,start_x: float,start_z: float,target: Dictionary,stop_y: float) -> Dictionary:
	var points: Array=[]
	var x:=start_x
	var z:=start_z
	var mx:=0.0
	var mz:=0.0
	for i in range(200):
		var h: float=height_at.call(x,z)
		points.append({"x":x,"z":z,"h":h})
		if h<=stop_y: break
		var tx: float=target.x-x
		var tz: float=target.z-z
		var gap:=sqrt(tx*tx+tz*tz)
		if gap<0.3: break
		var gradient:=slope(height_at,x,z)
		var sx: float=-gradient[0]
		var sz: float=-gradient[1]
		var grade:=sqrt(sx*sx+sz*sz)
		if grade>0.001:
			sx/=grade
			sz/=grade
		else:
			sx=tx/gap
			sz=tz/gap
		var flat:=smoothstep(0.5,0.12,grade)
		var pull:=maxf(0.26+0.62*smoothstep(3.2,0.7,gap),0.9*flat)
		mx=mx*0.55+(sx*(1.0-pull)+tx/gap*pull)*0.45
		mz=mz*0.55+(sz*(1.0-pull)+tz/gap*pull)*0.45
		var length:=sqrt(mx*mx+mz*mz)
		if length==0.0: length=1.0
		x+=mx/length*0.3
		z+=mz/length*0.3
	var last: Dictionary=points[-1]
	var dx: float=pool.x-last.x
	var dz: float=pool.z-last.z
	var length:=sqrt(dx*dx+dz*dz)
	if length==0.0: length=1.0
	var radius:=pool_radius(pool,atan2(dz,dx))
	var arrived:=length<=radius
	var reach:=minf(length*0.55,radius*0.4)
	for k in range(1,4):
		points.append({"x":last.x+dx/length*reach*(float(k)/3.0),"z":last.z+dz/length*reach*(float(k)/3.0),"h":pool.waterY-0.05})
	return {"pts":points,"arrived":arrived}
static func room(height_at: Callable,x: float,z: float,ax: float,az: float,bed: float,depth: float,limit: float) -> float:
	var total:=0.0
	for side in [1.0,-1.0]:
		var distance:=0.15
		while distance<limit:
			var height: float=height_at.call(x+ax*side*distance,z+az*side*distance)
			if height>bed+depth or height<bed-depth: break
			distance+=0.15
		total+=distance
	return total/2.0
static func ring_count(length: float,width: float) -> int:
	var segment:=minf(0.85,maxf(0.35,width*1.3))
	return clampi(floori(length/segment+0.5)+1,6,26)
static func distance(a: Dictionary,b: Dictionary) -> float:
	return sqrt((a.x-b.x)*(a.x-b.x)+(a.h-b.h)*(a.h-b.h)+(a.z-b.z)*(a.z-b.z))
static func resample(points: Array,count: int) -> Array:
	var cumulative: Array[float]=[0.0]
	for i in range(1,points.size()):
		cumulative.append(cumulative[-1]+(1.0-0.85)*distance(points[i],points[i-1])+0.85*maxf(0.0,points[i-1].h-points[i].h))
	var total:=cumulative[-1] if cumulative[-1]!=0.0 else 1.0
	var result: Array=[]
	var j:=0
	for i in range(count):
		var target:=float(i)/(count-1)*total
		while j<cumulative.size()-2 and cumulative[j+1]<target: j+=1
		var segment:=cumulative[j+1]-cumulative[j]
		if segment==0.0: segment=1.0
		var t: float=(target-cumulative[j])/segment
		var a: Dictionary=points[j]
		var b: Dictionary=points[j+1]
		result.append({"x":a.x+(b.x-a.x)*t,"z":a.z+(b.z-a.z)*t,"h":a.h+(b.h-a.h)*t})
	return result
