class_name NativeRecipeWater
extends RefCounted
## Source water.js grid flood and contour clipping for continuous terrain recipes.
const Plate = preload("res://scripts/plate.gd")
## The source water-field resolution: about 0.55 m cells (51 on the 28 m plate).
const N := Plate.RECIPE_WATER_CELLS
const W := N+1
const CELL := Plate.SIZE/N
static func surface(data: NativeTerrainData, pond: Dictionary) -> PackedVector3Array:
	return build(data,pond).vertices

static func field(data: NativeTerrainData, pond: Dictionary) -> Dictionary:
	var h := PackedFloat32Array()
	var xy := PackedVector2Array()
	var missing := PackedByteArray()
	var has_void := not data.void_faces.is_empty()
	var edited: bool = data.heights != data._recipe_heights
	# The unsculpted recipe height at each grid node only depends on the recipe,
	# so it is sampled once per recipe and kept in doubles. Adding the sculpt
	# delta to that double reproduces the original expression exactly.
	if data._water_grid_h.size() != W*W:
		data._water_grid_h.resize(W*W)
		for z in range(W):
			for x in range(W):
				data._water_grid_h[z*W+x]=preload("res://scripts/native_recipe_samples.gd").height(data._recipe,-Plate.HALF+x*CELL,-Plate.HALF+z*CELL)
	var base: PackedFloat64Array=data._water_grid_h
	# Away from the standing faces (a recipe world keeps to the old square in
	# the middle of the plate) a node is void wherever it is over the plate,
	# and its height is never read.
	var ground := data.ground_rect().grow(CELL) if has_void else Rect2()
	for z in range(W):
		for x in range(W):
			var px: float=-Plate.HALF+x*CELL
			var pz: float=-Plate.HALF+z*CELL
			var height: float=base[z*W+x]
			var absent := false
			if has_void and not ground.has_point(Vector2(px,pz)):
				absent = data.sample(Vector2(px,pz),data.heights) != null
			else:
				if edited: height+=data._sculpt_delta(Vector2(px,pz))
				absent = has_void and data.is_void(Vector2(px,pz))
			missing.append(1 if absent else 0)
			h.append(NativeTerrainData.MAX_HEIGHT+1.0 if absent else height)
			xy.append(Vector2(px,pz))
	var seed := -1
	var lowest := INF
	var sx := int(floor((float(pond.x)+Plate.HALF)/CELL+0.5))
	var sz := int(floor((float(pond.z)+Plate.HALF)/CELL+0.5))
	for z in range(maxi(0,sz-1),mini(W,sz+2)):
		for x in range(maxi(0,sx-1),mini(W,sx+2)):
			var k:=z*W+x
			if h[k]<lowest:
				lowest=h[k]
				seed=k
	if seed<0 or lowest>=pond.level: return {}
	var wet:=PackedByteArray()
	wet.resize(W*W)
	wet[seed]=1
	var stack: Array[int]=[seed]
	while not stack.is_empty():
		var k: int=stack.pop_back()
		var x:=k%W
		var z:=k/W
		for direction in [Vector2i(1,0),Vector2i(-1,0),Vector2i(0,1),Vector2i(0,-1)]:
			var nx: int=x+direction.x
			var nz: int=z+direction.y
			if nx<0 or nz<0 or nx>=W or nz>=W: continue
			var next:=nz*W+nx
			# A pond reaching an open cliff drains; it cannot flood empty space.
			if missing[next]: return {}
			if wet[next] or h[next]>=pond.level: continue
			if pond.has("basin"):
				var radius := Vector2((float(xy[next].x)-pond.x)/pond.basin[0],(float(xy[next].y)-pond.z)/pond.basin[1])
				if radius.length_squared()>1.0: continue
			wet[next]=1
			stack.append(next)
	var depth_grid:=PackedFloat32Array()
	for k in range(h.size()): depth_grid.append(maxf(0.0,pond.level-h[k]) if wet[k] else 0.0)
	return {"h":h,"xy":xy,"wet":wet,"depth":depth_grid}

## `prepared` may carry the waterfall impacts and colour ramp, which read the
## live recipe, so a detached height copy can build the surface off-thread.
static func build(data: NativeTerrainData, pond: Dictionary, prepared := {}) -> Dictionary:
	var grid:=field(data,pond)
	if grid.is_empty(): return {"vertices":PackedVector3Array(),"depths":PackedFloat32Array(),"colors":PackedColorArray(),"fetch_a":PackedColorArray(),"fetch_b":PackedColorArray()}
	var h: PackedFloat32Array=grid.h
	var xy: PackedVector2Array=grid.xy
	var wet: PackedByteArray=grid.wet
	var depth_grid: PackedFloat32Array=grid.depth
	stamp_streams(data.streams,wet.duplicate(),depth_grid,PackedByteArray())
	for z in range(1,N):
		for x in range(1,N):
			var k:=z*W+x
			if wet[k] and wet[k-1] and wet[k+1] and wet[k-W] and wet[k+W]:
				var px: float=-Plate.HALF+x*CELL
				var pz: float=-Plate.HALF+z*CELL
				xy[k]=Vector2(float(xy[k].x)+(_hash(px*4.1,pz*4.1)-0.5)*CELL*0.4,float(xy[k].y)+(_hash(pz*6.3,px*6.3)-0.5)*CELL*0.4)
	var fetch:=fetch_field(wet)
	var fetch_a:=PackedColorArray()
	var fetch_b:=PackedColorArray()
	var result:=PackedVector3Array()
	var depths:=PackedFloat32Array()
	var colors:=PackedColorArray()
	var impacts: Array[Dictionary]=prepared.impacts if prepared.has("impacts") else data.waterfall_impacts()
	var ramp: Array[Color]=prepared.ramp if prepared.has("ramp") else water_ramp(data._recipe.source.g.get("water",{}))
	for z in range(N):
		for x in range(N):
			var ids: Array[int]=[z*W+x,z*W+x+1,(z+1)*W+x+1,(z+1)*W+x]
			var corner_depths: Array[float]=[]
			for k in ids:
				var d: float=pond.level-h[k]
				corner_depths.append(-0.001 if d>0.0 and not wet[k] else d)
			var polygon: Array[Array]=[]
			for a in range(4):
				var b: int=(a+1)%4
				if corner_depths[a]>0.0: polygon.append([float(xy[ids[a]].x),float(xy[ids[a]].y)])
				if (corner_depths[a]>0.0)!=(corner_depths[b]>0.0):
					var t: float=corner_depths[a]/(corner_depths[a]-corner_depths[b])
					polygon.append([float(xy[ids[a]].x)+(float(xy[ids[b]].x)-float(xy[ids[a]].x))*t,float(xy[ids[a]].y)+(float(xy[ids[b]].y)-float(xy[ids[a]].y))*t])
			for i in range(1,polygon.size()-1):
				var cx: float=float(polygon[0][0])/3.0+float(polygon[i][0])/3.0+float(polygon[i+1][0])/3.0
				var cz: float=float(polygon[0][1])/3.0+float(polygon[i][1])/3.0+float(polygon[i+1][1])/3.0
				var depth:=sample_grid(depth_grid,cx,cz)
				var band:=clampi(int(clampf(depth/1.1+(_hash(cx*3.7,cz*3.7)-0.5)*0.28,0.0,1.0)*4.0),0,3)
				var color: Color=ramp[band]
				for impact in impacts:
					if sqrt((cx-impact.x)*(cx-impact.x)+(cz-impact.z)*(cz-impact.z))<impact.radius:
						color=Color("f2f7f8").srgb_to_linear()
						break
				for k in [0,i+1,i]:
					result.append(Vector3(polygon[k][0],pond.level,polygon[k][1]))
					var p: Array=polygon[k]
					fetch_a.append(Color(sample_grid(fetch[0],p[0],p[1]),sample_grid(fetch[1],p[0],p[1]),sample_grid(fetch[2],p[0],p[1]),sample_grid(fetch[3],p[0],p[1])))
					fetch_b.append(Color(sample_grid(fetch[4],p[0],p[1]),sample_grid(fetch[5],p[0],p[1]),sample_grid(fetch[6],p[0],p[1]),sample_grid(fetch[7],p[0],p[1])))
					depths.append(depth)
					colors.append(color)
	return {"vertices":result,"depths":depths,"colors":colors,"fetch_a":fetch_a,"fetch_b":fetch_b}

static func fetch_field(wet: PackedByteArray) -> Array[PackedFloat32Array]:
	var fields: Array[PackedFloat32Array]=[]
	for direction in [Vector2i(1,0),Vector2i(1,1),Vector2i(0,1),Vector2i(-1,1),Vector2i(-1,0),Vector2i(-1,-1),Vector2i(0,-1),Vector2i(1,-1)]:
		var values:=PackedFloat32Array()
		values.resize(W*W)
		var step: float=CELL*sqrt(float(direction.x*direction.x+direction.y*direction.y))
		for z in range(W-1 if direction.y>0 else 0,-1 if direction.y>0 else W,-1 if direction.y>0 else 1):
			for x in range(W-1 if direction.x>0 else 0,-1 if direction.x>0 else W,-1 if direction.x>0 else 1):
				var k:=z*W+x
				if not wet[k]: continue
				var nx: int=x+direction.x
				var nz: int=z+direction.y
				if nx>=0 and nz>=0 and nx<W and nz<W and wet[nz*W+nx]:
					values[k]=minf(9.0,values[nz*W+nx]+step)
		fields.append(values)
	return fields

static func sample_grid(values: PackedFloat32Array,x: float,z: float) -> float:
	var fi:=clampf((x+Plate.HALF)/CELL,0.0,N)
	var fj:=clampf((z+Plate.HALF)/CELL,0.0,N)
	var i:=mini(N-1,int(floor(fi)))
	var j:=mini(N-1,int(floor(fj)))
	var u:=fi-i
	var v:=fj-j
	var k:=j*W+i
	return values[k]*(1-u)*(1-v)+values[k+1]*u*(1-v)+values[k+W]*(1-u)*v+values[k+W+1]*u*v

static func _hash(x: float,z: float) -> float:
	return fposmod(sin(x*127.1+z*311.7)*43758.5453,1.0)

## Union of authored ponds. Dry bodies contribute nothing after terrain edits.
static func shoreline(data: NativeTerrainData) -> Dictionary:
	if data._recipe == null or (data.ponds.is_empty() and data.streams.is_empty()): return {}
	var wet:=PackedByteArray()
	wet.resize(W*W)
	var depth:=PackedFloat32Array()
	depth.resize(W*W)
	for pond in data.ponds:
		var grid:=field(data,pond)
		if grid.is_empty(): continue
		for k in range(W*W):
			wet[k]=maxi(wet[k],grid.wet[k])
			depth[k]=maxf(depth[k],grid.depth[k])
	var nearest:=wet.duplicate()
	stamp_streams(data.streams,wet,depth,nearest)
	if wet.count(1)==0: return {}
	return {"shore":signed_distance(wet,nearest),"depth":depth,"kind":nearest}

static func signed_distance(wet: PackedByteArray,nearest:=PackedByteArray()) -> PackedFloat32Array:
	var outside:=PackedFloat32Array()
	var inside:=PackedFloat32Array()
	for value in wet:
		outside.append(0.0 if value else 1000000.0)
		inside.append(1000000.0 if value else 0.0)
	for pass_index in range(2):
		var distances: PackedFloat32Array=outside if pass_index==0 else inside
		var carry:=pass_index==0 and not nearest.is_empty()
		for direction in [1,-1]:
			# The four neighbours already passed, made once per sweep rather than
			# per cell, which was nearly half the sweep's time.
			var offsets: Array[Vector2i]=[Vector2i(-direction,0),Vector2i(0,-direction),Vector2i(-direction,-direction),Vector2i(direction,-direction)]
			var weights:=PackedFloat64Array([1.0,1.0,sqrt(2.0),sqrt(2.0)])
			for z in range(0 if direction==1 else N,W if direction==1 else -1,direction):
				for x in range(0 if direction==1 else N,W if direction==1 else -1,direction):
					var k:=z*W+x
					var best: float=distances[k]
					for o in range(4):
						var nx: int=x+offsets[o].x
						var nz: int=z+offsets[o].y
						if nx<0 or nz<0 or nx>=W or nz>=W: continue
						var candidate: float=distances[nz*W+nx]+weights[o]
						if candidate<best:
							distances[k]=candidate
							best=distances[k]
							if carry: nearest[k]=nearest[nz*W+nx]
	var result:=PackedFloat32Array()
	for k in range(W*W):
		result.append((-minf(inside[k],40.0) if wet[k] else minf(outside[k],40.0))*CELL)
	return result

## Source waterPaint/tintRamp, shallow pond ramp. Material uses this same gene.
static func water_ramp(gene: Dictionary) -> Array[Color]:
	var result: Array[Color]=[]
	var stops: Array[String]=["6fb2c0","4d94aa","376f88","2a5b73"]
	var pairs: Array[Array]=[["tannin","6e5c2c","241708"],["silt","b6dcd8","6fb3b9"],["bloom","9cc274","3f7448"]]
	var sum: float=gene.get("tannin",0.0)+gene.get("silt",0.0)+gene.get("bloom",0.0)
	for i in range(stops.size()):
		var color:=preload("res://scripts/native_terrain_palette.gd").shift_hsl(Color(stops[i]).srgb_to_linear(),gene.get("hue",0.0),0.0,0.0)
		if sum>0.0:
			var mixed:=minf(sum,0.85)
			color*=1.0-mixed
			for pair in pairs:
				var weight: float=gene.get(pair[0],0.0)
				color+=Color(pair[1]).srgb_to_linear().lerp(Color(pair[2]).srgb_to_linear(),float(i)/(stops.size()-1)*0.6)*weight*mixed/sum
		color.a=1.0
		result.append(color)
	return result

## Source buildWaterField stream stamp: shared depth, wet mask and water kind.
static func stamp_streams(streams: Array,wet: PackedByteArray,depth: PackedFloat32Array,kind: PackedByteArray) -> void:
	for stream in streams:
		var radius:=maxf(preload("res://scripts/native_stream_geometry.gd").half_width(stream),CELL*0.75)
		for n in range(stream.pts.size()-1):
			var a: Dictionary=stream.pts[n]
			var b: Dictionary=stream.pts[n+1]
			var steps:=maxi(1,ceili(preload("res://scripts/native_stream_geometry.gd").distance(a,b)/(CELL*0.5)))
			for t in range(steps+1):
				var x: float=a.x+(b.x-a.x)*float(t)/steps
				var z: float=a.z+(b.z-a.z)*float(t)/steps
				for j in range(maxi(0,floori((z-radius+Plate.HALF)/CELL)),mini(N,ceili((z+radius+Plate.HALF)/CELL))+1):
					for i in range(maxi(0,floori((x-radius+Plate.HALF)/CELL)),mini(N,ceili((x+radius+Plate.HALF)/CELL))+1):
						var dx: float=-Plate.HALF+i*CELL-x
						var dz: float=-Plate.HALF+j*CELL-z
						var distance:=sqrt(dx*dx+dz*dz)
						if distance>radius: continue
						var k:=j*W+i
						if not wet[k] and not kind.is_empty(): kind[k]=2
						wet[k]=1
						var q:=distance/radius
						depth[k]=maxf(depth[k],0.06+stream.surface*(1.0-q*q))

static func kind_at(field: Dictionary,x: float,z: float) -> int:
	var i:=floori((x+Plate.HALF)/CELL+0.5)
	var j:=floori((z+Plate.HALF)/CELL+0.5)
	return field.kind[j*W+i] if i>=0 and j>=0 and i<W and j<W else 0
