"""Editable Blender cave study; standalone art, no runtime/world changes.
Run: blender --background --python tools/build_cave_study.py
Use --replace-generated only to regenerate this script's own study.
"""
import bpy, bmesh, math, random, sys, json
from pathlib import Path
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'art/blender/cave'; OUT.mkdir(parents=True,exist_ok=True)
TARGET=OUT/'zenscape-cave-study.blend'
if TARGET.exists() and '--replace-generated' not in sys.argv:
    raise RuntimeError('Editable study exists; preserve manual work.')
bpy.ops.wm.read_factory_settings(use_empty=True)
rng=random.Random(932)
scene=bpy.context.scene
scene.unit_settings.system='METRIC'

def collection(name):
    c=bpy.data.collections.new(name);scene.collection.children.link(c);return c
rock=collection('EDIT - cave stone and interior')
moss=collection('EDIT - moss on stone')
stage=collection('STUDIO - woodland floor and plants')
ref=collection('REFERENCE - Bigfoot at game scale')
lights=collection('STUDIO - cameras and lighting')
def move(o,col):
    for c in list(o.users_collection): c.objects.unlink(o)
    col.objects.link(o)

def linear(h):
    v=[int(h[i:i+2],16)/255 for i in (0,2,4)]
    return tuple(c/12.92 if c<=.04045 else ((c+.055)/1.055)**2.4 for c in v)
def material(name,color):
    m=bpy.data.materials.new(name);m.diffuse_color=(*linear(color),1);m.use_nodes=True
    p=m.node_tree.nodes.get('Principled BSDF');p.inputs['Base Color'].default_value=m.diffuse_color
    p.inputs['Roughness'].default_value=.93;p.inputs['Specular IOR Level'].default_value=.18
    return m
stones=[material('Stone - '+str(i),c) for i,c in enumerate(['777b70','85897c','686f66','939183','73786c','828477'])]
inner=[material('Recess - '+str(i),c) for i,c in enumerate(['53594f','5d6256','62675c','4b5249'])]
mossp=[material('Moss - '+str(i),c) for i,c in enumerate(['545f35','646f3f','74814c','4a5836'])]
soil=material('Earth - warm woodland','555044');soilside=material('Earth - cut edge','3e3c34')
pathmat=material('Earth - worn threshold','7a7561')
fernmat=material('Fern - subdued green','63744c')

def mesh(name,verts,faces,mats,col,indices=None):
    me=bpy.data.meshes.new(name);me.from_pydata(verts,[],faces);me.update()
    o=bpy.data.objects.new(name,me);col.objects.link(o)
    for m in mats:me.materials.append(m)
    for i,p in enumerate(me.polygons):p.material_index=indices[i] if indices else rng.randrange(len(mats))
    bm=bmesh.new();bm.from_mesh(me);bmesh.ops.recalc_face_normals(bm,faces=bm.faces);bm.to_mesh(me);bm.free()
    return o

def strips(name,rings,mats,col):
    n=len(rings[0]);verts=[v for ring in rings for v in ring];faces=[]
    for row in range(len(rings)-1):
        for i in range(n-1):
            a=row*n+i;b=a+1;c=b+n;d=a+n
            if (row+i)%2:faces.extend([(a,b,d),(b,c,d)])
            else:faces.extend([(a,b,c),(a,c,d)])
    return mesh(name,verts,faces,mats,col)

# Arch profiles use broad unequal facets. Outer shell and inner passage are
# separately editable; no boolean modifiers or opaque fake entrance plane.
n=13
angles=[i*math.pi/(n-1) for i in range(n)]
front=[];middle=[];outer=[]
for i,t in enumerate(angles):
    x=1.85*math.cos(t)+.14*math.sin(t*2)
    z=3.65*math.sin(t)**.72
    y=-3.7+.18*math.sin(t*3+.5)
    if i not in [0,n-1]:z+=rng.uniform(-.15,.14)
    front.append((x,y,z-.07))
    ox=5.15*math.cos(t)+.3*math.sin(t*3)
    oz=5.3*math.sin(t)**.8+.48*math.sin(t*2)
    oy=-2.3+.35*math.cos(t*2)+rng.uniform(-.25,.25)
    outer.append((ox,oy,oz-.23))
    middle.append((x*.57+ox*.43,y*.58+oy*.42-.23,z*.58+oz*.42+rng.uniform(-.17,.17)))
strips('Entrance - weathered brow and shoulders',[front,middle,outer],stones,rock)
outer_rings=[outer]
for j,(y,rx,rz,cx) in enumerate([(-.2,5.35,6.1,-.35),(2.1,4.9,5.35,-.55),(3.7,3.65,3.7,-.2),(4.8,1.8,1.55,.1)]):
    outer_rings.append([(cx+rx*math.cos(t)+rng.uniform(-.23,.23),y+rng.uniform(-.3,.3),rz*math.sin(t)**.9-.22+rng.uniform(-.15,.15)) for t in angles])
strips('Mass - low asymmetric hillside rock',outer_rings,stones,rock)
last=outer_rings[-1]
mesh('Mass - buried back',last+[(0,5.35,-.35)],[(i,i+1,n) for i in range(n-1)],stones,rock)
# The passage bends right and narrows behind the entrance. Daylight dies away
# through depth and occlusion, while a real floor and back wall remain.
inside=[front]
for y,rx,rz,cx in [(-2.8,1.92,3.8,.08),(-1.1,1.85,3.75,.48),(.65,1.68,3.35,1.0),(2.15,1.5,3.05,1.35)]:
    inside.append([(cx+rx*math.cos(t),y+.10*math.sin(t*3),rz*math.sin(t)**.72-.07) for t in angles])
strips('Interior - curved sheltered passage',inside,inner,rock)
last=inside[-1]
mesh('Interior - closed chamber end',last+[(1.35,2.2,-.07)],[(i,i+1,n) for i in range(n-1)],inner,rock)
floorverts=[]
for r in inside:floorverts.extend([r[0],r[-1]])
mesh('Interior - continuous earthen floor',floorverts,[(i,i+1,i+3,i+2) for i in range(0,len(floorverts)-2,2)],[soil],rock)

def boulder(name,location,scale,col=rock,mats=stones,subdiv=1):
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=subdiv,radius=1,location=location)
    o=bpy.context.object;o.name=name;move(o,col)
    for v in o.data.vertices:v.co*=rng.uniform(.90,1.12)
    o.scale=scale;o.rotation_euler=(rng.uniform(-.12,.12),rng.uniform(-.18,.18),rng.uniform(-.4,.4))
    for m in mats:o.data.materials.append(m)
    for p in o.data.polygons:p.material_index=rng.randrange(len(mats))
    return o
boulder('Shoulder - left split slab',(-3.75,-2.55,1.4),(1.7,1.8,2.0),subdiv=1)
boulder('Shoulder - right low outcrop',(3.6,-2.55,.7),(1.8,1.6,1.2))
boulder('Toe - left embedded rock',(-4.6,-3.5,.15),(1.2,1.0,.65))
boulder('Toe - right embedded rock',(4.6,-3.1,.05),(1.2,1.3,.62))
# Moss is sparse geometry attached to upward-facing rock facets.
bpy.context.view_layer.update()
for o in list(rock.objects):
    if o.type!='MESH' or o.name.startswith('Interior'):continue
    for poly in o.data.polygons:
        normal=(o.matrix_world.to_3x3()@poly.normal).normalized()
        center=o.matrix_world@poly.center
        if normal.z<.48 or center.z<.55 or rng.random()>.26:continue
        pts=[o.matrix_world@o.data.vertices[i].co for i in poly.vertices]
        mid=sum(pts,Vector())/len(pts)
        # Small irregular pads on the face, rather than triangle-shaped decals.
        u=(pts[0]-mid).normalized();v=normal.cross(u).normalized()
        radius=min((p-mid).length for p in pts)*.36
        inset=[]
        for k in range(11):
            a=k*math.tau/11;rad=radius*rng.uniform(.7,1.15)
            inset.append(mid+u*math.cos(a)*rad*1.25+v*math.sin(a)*rad+normal*.012)
        mesh('Moss - attached patch',inset,[tuple(range(len(inset)))],mossp,moss)
# A restrained oval earth plinth keeps this visibly a diorama study.
N=64;verts=[]
for z in [-.13,-.65]:
    for i in range(N):
        t=i*2*math.pi/N;verts.append((7.8*math.cos(t),6.8*math.sin(t)+.0,z))
verts.append((0,0,-.13));faces=[];ids=[]
for i in range(N):
    j=(i+1)%N;faces.extend([(2*N,i,j),(i,N+i,N+j,j)]);ids.extend([0,1])
mesh('Display - woodland earth',verts,faces,[soil,soilside],stage,ids)
# Fan-shaped worn approach, with irregular edge and no perfectly straight path.
verts=[(0,-3.4,-.105)]
for i in range(17):
    t=math.pi+i*math.pi/16
    verts.append((math.cos(t)*(2.45+rng.uniform(-.25,.25)), -3.4+math.sin(t)*2.8,-.10+rng.uniform(0,.012)))
mesh('Display - worn approach',verts,[(0,i,i+1) for i in range(1,17)],[pathmat],stage)
for i in range(27):
    x=rng.choice([-1,1])*rng.uniform(2.3,6);y=rng.uniform(-5,3.5)
    s=rng.uniform(.10,.31)
    boulder('Display - loose stone', (x,y,-.05),(s*1.4,s,s*.6),stage)

def fern(x,y,size):
    verts=[];faces=[]
    for frond in range(7):
        a=frond*math.tau/7+.2
        for k in range(1,6):
            f=k/6;r=f*size;z=math.sin(f*math.pi*.85)*size*.7
            center=Vector((x+r*math.cos(a),y+r*math.sin(a),z-.08))
            side=Vector((-math.sin(a),math.cos(a),.2))*size*(1-f)*.29
            stem=Vector((math.cos(a),math.sin(a),.4))*size*.16
            for sign in [-1,1]:
                base=len(verts);verts.extend([center-stem*.4,center+side*sign-stem*.25,center+stem])
                faces.append((base,base+1,base+2))
    mesh('Display - fern',verts,faces,[fernmat],stage)
for x,y,s in [(-5,-3.7,.8),(4.6,-3.8,.75),(-5.6,-1.8,1.0),(5.2,.0,.9),(-3.2,-4.3,.5),(3.25,-4.2,.6)]:fern(x,y,s)
# Import the actual approved creature as a scale reference. No asset edits.
before=set(bpy.data.objects)
bpy.ops.import_scene.gltf(filepath=str(ROOT/'assets/models/zenscape-bigfoot-woodland.glb'))
refs=set(bpy.data.objects)-before
for o in list(refs):
    if o.type=='MESH' and not o.data.materials:
        refs.remove(o);bpy.data.objects.remove(o,do_unlink=True)
for o in refs:move(o,ref)
roots=[o for o in refs if o.parent not in refs]
anchor=bpy.data.objects.new('Bigfoot - scale and placement',None);ref.objects.link(anchor)
for o in roots:o.parent=anchor
for o in refs:
    if o.animation_data:o.animation_data_clear()
scene.frame_set(1);bpy.context.view_layer.update()
points=[o.matrix_world@Vector(c) for o in refs if o.type=='MESH' for c in o.bound_box]
zmin=min(p.z for p in points);zmax=max(p.z for p in points)
scale=2.8/(zmax-zmin);anchor.scale=(scale,)*3
anchor.location=(-2.85,-5.05,-zmin*scale-.10);anchor.rotation_euler.z=-.22
# Palette-correct imported vertex colors, as in the existing woodland tools.
for o in refs:
    if o.type!='MESH':continue
    for mat in o.data.materials:
        if not mat or not mat.use_nodes:continue
        bs=mat.node_tree.nodes.get('Principled BSDF')
        if bs:bs.inputs['Roughness'].default_value=.95

def point(o,target):o.rotation_euler=(Vector(target)-o.location).to_track_quat('-Z','Y').to_euler()
def area(name,loc,power,size,color):
    d=bpy.data.lights.new(name,'AREA');d.energy=power;d.shape='DISK';d.size=size;d.color=color
    o=bpy.data.objects.new(name,d);lights.objects.link(o);o.location=loc;point(o,(0,0,1));return o
area('Light - warm overcast key',(-6,-8,13),1900,9,(1,.92,.78))
area('Light - cool sky fill',(6,1,10),1100,8,(.78,.87,1))
world=bpy.data.worlds.new('World - muted studio');scene.world=world;world.use_nodes=True
world.node_tree.nodes['Background'].inputs['Color'].default_value=(*linear('a5aaa1'),1)
world.node_tree.nodes['Background'].inputs['Strength'].default_value=.35
camdata=bpy.data.cameras.new('Camera - cave portrait');cam=bpy.data.objects.new('Camera - cave portrait',camdata);lights.objects.link(cam)
cam.location=(11,-17,10);point(cam,(0,-.1,1.7));camdata.type='ORTHO';camdata.ortho_scale=19.5;scene.camera=cam
scene.render.engine='CYCLES';scene.cycles.samples=48;scene.cycles.use_denoising=True
scene.render.resolution_x=1600;scene.render.resolution_y=1200;scene.render.resolution_percentage=100
scene.view_settings.view_transform='AgX';scene.render.image_settings.file_format='PNG'
scene.render.film_transparent=False
# Useful file-open state: material view looking directly into the cave.
for screen in bpy.data.screens:
    for a in screen.areas:
        if a.type=='VIEW_3D':
            a.spaces.active.region_3d.view_perspective='CAMERA'
            a.spaces.active.shading.type='MATERIAL'
bpy.ops.object.select_all(action='DESELECT')
for o in rock.objects:o.select_set(True)
bpy.context.view_layer.objects.active=bpy.data.objects['Entrance - weathered brow and shoulders']
scene.render.filepath=str(OUT/'cave-study.png')
bpy.ops.wm.save_as_mainfile(filepath=str(TARGET))
bpy.ops.render.render(write_still=True)
cam.location=(2,-16,6.6);point(cam,(0,-1.2,1.95));camdata.ortho_scale=12.9
scene.render.filepath=str(OUT/'cave-entrance.png');bpy.ops.render.render(write_still=True)
print('CAVE_STUDY_COMPLETE',TARGET)
