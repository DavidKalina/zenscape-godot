extends RefCounted
## Terrain-fitted streamGeometry/drawnLine from source water.js.
## Inputs are an authored course and a continuous terrain sampler, never a mesh.
static func half_width(stream: Dictionary) -> float:
	return stream.width*0.5*(1.0+1.8*sqrt(stream.surface/3.0))+0.3
static func distance(a: Dictionary,b: Dictionary) -> float:
	return sqrt((a.x-b.x)*(a.x-b.x)+(a.z-b.z)*(a.z-b.z))
static func drawn_line(points: Array,width: float) -> Array:
	var line:=points.duplicate(true)
	for pass_index in range(12):
		var worst:=0.0
		for i in range(1,line.size()-1):
			var a: Dictionary=line[i-1]
			var b: Dictionary=line[i]
			var c: Dictionary=line[i+1]
			var area: float=absf((b.x-a.x)*(c.z-a.z)-(b.z-a.z)*(c.x-a.x))
			if area<0.000001: continue
			var radius:=distance(a,b)*distance(b,c)*distance(c,a)/(2.0*area)
			if radius>=width*1.5: continue
			worst=maxf(worst,width*1.5-radius)
			b.x+=((a.x+c.x)*0.5-b.x)*0.5
			b.z+=((a.z+c.z)*0.5-b.z)*0.5
		if worst<0.01: break
	var kept: Array=[line[0]]
	for i in range(1,line.size()-1):
		if distance(line[i],kept[-1])>=maxf(0.12,width*0.2): kept.append(line[i])
	if line.size()>1: kept.append(line[-1])
	return kept if kept.size()>2 else line

static func fit(point: Dictionary,ax: float,az: float,side: float,stream: Dictionary,height_at: Callable) -> Array:
	var maximum:=half_width(stream)
	var level: float=point.h-stream.depth+stream.surface
	var d: float=stream.width*0.5*0.9
	while d<maximum:
		var ground: float=height_at.call(point.x+ax*side*d,point.z+az*side*d)
		if ground>=level: return [minf(maximum,d+0.22),0.0]
		if ground<=level-stream.surface*1.2: break
		d+=0.16
	d=minf(d,maximum)
	var ground: float=height_at.call(point.x+ax*side*d,point.z+az*side*d)
	return [d,clampf(level-ground+0.22,0.0,stream.surface*1.2+0.22)]

static func build(stream: Dictionary,height_at: Callable,ramp: Array[Color]) -> Dictionary:
	var points:=drawn_line(stream.pts,half_width(stream))
	var count:=points.size()
	var section: Array[Array]=[[-1.0,0.0],[-0.72,-0.62],[0.0,-0.85],[0.72,-0.62],[1.0,0.0]]
	var runs: Array[float]=[0.0]
	var tangents: Array[Array]=[]
	for i in range(count):
		if i>0: runs.append(runs[-1]+distance(points[i],points[i-1]))
		var a: Dictionary=points[maxi(0,i-1)]
		var b: Dictionary=points[mini(count-1,i+1)]
		var length:=distance(a,b)
		if length==0.0: length=1.0
		tangents.append([(b.x-a.x)/length,(b.z-a.z)/length])
	var total:=runs[-1] if runs[-1]>0.0 else 1.0
	var flow: Array[Array]=[]
	var curve: Array[float]=[]
	for i in range(count):
		var a: Dictionary=points[maxi(0,i-1)]
		var b: Dictionary=points[mini(count-1,i+1)]
		var span:=distance(a,b)
		if span==0.0: span=0.3
		var t0: Array=tangents[maxi(0,i-1)]
		var t1: Array=tangents[mini(count-1,i+1)]
		var cross_value: float=t0[0]*t1[1]-t0[1]*t1[0]
		curve.append(cross_value/span)
		var grade:=clampf((a.h-b.h)/span/0.3,0.0,1.0)
		if stream.get("joined",false) and total-runs[i]<1.6:
			grade=maxf(grade,1.0-smoothstep(0.0,1.6,total-runs[i]))
		for mouth in stream.get("mouths",[]):
			grade=maxf(grade,1.0-smoothstep(0.0,1.6,distance(points[i],mouth)))
		flow.append([grade,clampf(cross_value/0.45,-1.0,1.0)])
	var smoothed: Array[Array]=[]
	for i in range(count):
		var a: Array=flow[maxi(0,i-1)]
		var b: Array=flow[i]
		var c: Array=flow[mini(count-1,i+1)]
		smoothed.append([(a[0]+2.0*b[0]+c[0])/4.0,(a[1]+2.0*b[1]+c[1])/4.0])
	var rings: Array[Array]=[]
	var levels: Array[float]=[]
	for i in range(count):
		var p: Dictionary=points[i]
		var ax: float=-tangents[i][1]
		var az: float=tangents[i][0]
		var left:=fit(p,ax,az,-1.0,stream,height_at)
		var right:=fit(p,ax,az,1.0,stream,height_at)
		if absf(curve[i])>0.001:
			if curve[i]>0.0: right[0]=minf(right[0],0.85/absf(curve[i]))
			else: left[0]=minf(left[0],0.85/absf(curve[i]))
		var sink:=0.0
		var taper:=1.0
		if stream.get("capHead",false) and runs[i]<1.0:
			taper=smoothstep(0.0,1.0,runs[i])
			sink=(1.0-taper)*stream.surface*1.2
		if stream.get("capTail",false) and total-runs[i]<1.0:
			var f:=smoothstep(0.0,1.0,total-runs[i])
			taper=minf(taper,f)
			sink=maxf(sink,(1.0-f)*stream.surface*1.2)
		var y: float=p.h-stream.depth+stream.surface-sink
		levels.append(y)
		var ring: Array=[]
		for lane in section:
			var side: Array=left if lane[0]<0.0 else right
			var drop: float=side[1] if absf(lane[0])>=1.0 else 0.0
			ring.append([p.x+ax*lane[0]*side[0]*taper,y+lane[1]*stream.surface*1.1-drop,p.z+az*lane[0]*side[0]*taper])
		rings.append(ring)
	for i in range(1,count):
		for k in range(5):
			var a: Array=rings[i-1][k]
			var b: Array=rings[i][k]
			if (b[0]-a[0])*tangents[i-1][0]+(b[2]-a[2])*tangents[i-1][1]<0.0:
				b[0]=a[0]
				b[2]=a[2]
	var depths: Array[Array]=[]
	for i in range(count):
		var row: Array=[]
		for p in rings[i]:
			row.append(maxf(0.0,minf(levels[i]-p[1],levels[i]-float(height_at.call(p[0],p[2])))))
		depths.append(row)
	var vertices:=PackedVector3Array()
	var colors:=PackedColorArray()
	var uv:=PackedVector2Array()
	var uv2:=PackedVector2Array()
	var centers:=PackedColorArray()
	var run_data:=PackedColorArray()
	var run_offset: float=stream.get("run",0.0)
	for i in range(count-1):
		var riffle:=smoothstep(0.22,0.85,smoothed[i][0])
		for k in range(4):
			var mid:=absf(k-1.5)/2.0
			var lane:=preload("res://scripts/native_recipe_water.gd")._hash(k*2.3+0.5,floor((run_offset+runs[i])/2.4)*7.7)
			var band:=clampf(0.34-mid*0.26+(lane-0.5)*0.2,0.0,1.0)
			var color:=ramp[mini(ramp.size()-1,int(floor(band*ramp.size())))].lerp(Color("f2f7f8").srgb_to_linear(),riffle*0.34)
			# Reverse source winding for Godot's front-face convention.
			for corner in [[i,k],[i+1,k+1],[i+1,k],[i,k],[i,k+1],[i+1,k+1]]:
				var r: int=corner[0]
				var c: int=corner[1]
				var p: Array=rings[r][c]
				vertices.append(Vector3(p[0],p[1],p[2]))
				colors.append(color)
				uv.append(Vector2(run_offset+runs[r],section[c][0]))
				uv2.append(Vector2(depths[r][c],0.0))
				centers.append(Color(points[r].x,levels[r],points[r].z,runs[r]/total))
				run_data.append(Color(smoothed[r][0],smoothed[r][1],0.0,0.0))
	return {"vertices":vertices,"colors":colors,"uv":uv,"uv2":uv2,"centers":centers,"run":run_data}

static func mesh(geometry: Dictionary) -> ArrayMesh:
	var surface:=SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	surface.set_custom_format(0,SurfaceTool.CUSTOM_RGBA_FLOAT)
	surface.set_custom_format(1,SurfaceTool.CUSTOM_RGBA_FLOAT)
	for i in range(geometry.vertices.size()):
		surface.set_color(geometry.colors[i])
		surface.set_uv(geometry.uv[i])
		surface.set_uv2(geometry.uv2[i])
		surface.set_custom(0,geometry.centers[i])
		surface.set_custom(1,geometry.run[i])
		surface.add_vertex(geometry.vertices[i])
	surface.generate_normals()
	return surface.commit()
