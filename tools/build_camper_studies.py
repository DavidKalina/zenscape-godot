"""Initial editable camper silhouettes. Run with Blender --background --python.
Refuses to replace authored output. All coordinates in meters; forward is -Y.
"""
import bpy, math, json
from pathlib import Path
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'art/blender/campers'; OUT.mkdir(parents=True,exist_ok=True)
TARGET=OUT/'zenscape-campers-v01.blend'
if TARGET.exists(): raise RuntimeError('Preserve authored output; use a new version for regeneration.')
bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
def mat(name,h):
    c=[int(h[i:i+2],16)/255 for i in (0,2,4)]
    c=[v/12.92 if v<=.04045 else ((v+.055)/1.055)**2.4 for v in c]
    m=bpy.data.materials.new(name);m.diffuse_color=(*c,1);m.use_nodes=True
    p=m.node_tree.nodes.get('Principled BSDF');p.inputs['Base Color'].default_value=(*c,1);p.inputs['Roughness'].default_value=.88
    return m
M={n:mat(n,h) for n,h in dict(canvas='B18A49',canvas_light='C5A367',canvas_dark='8C693C',trim='514538',dark='292F2D',skin='C28F69',skin2='976A4E',hair='49362C',teal='526F69',rust='A75F42',pants='4F5550',boots='494035',sock='B8AD8F',metal='768079',glass='374E50',cream='DBCA9F').items()}
col=None

def finish(o,name,m):
    o.name=name;o.data.materials.append(M[m])
    for c in list(o.users_collection): c.objects.unlink(o)
    col.objects.link(o)
    return o

def box(name,p,s,m,bevel=.025):
    bpy.ops.mesh.primitive_cube_add(size=1,location=p);o=bpy.context.object;o.scale=s
    bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    if bevel:
        mod=o.modifiers.new('Broad clipped corners','BEVEL');mod.width=bevel;mod.segments=1
        bpy.context.view_layer.objects.active=o;bpy.ops.object.modifier_apply(modifier=mod.name)
    return finish(o,name,m)

def mesh(name,vs,fs,m):
    d=bpy.data.meshes.new(name);d.from_pydata(vs,[],fs);d.update();o=bpy.data.objects.new(name,d);col.objects.link(o);d.materials.append(M[m]);return o

def rod(name,a,b,r,m,vertices=6,r2=None):
    d=Vector(b)-Vector(a)
    bpy.ops.mesh.primitive_cone_add(vertices=vertices,radius1=r,radius2=r if r2 is None else r2,depth=d.length,location=(Vector(a)+Vector(b))/2)
    o=bpy.context.object;o.rotation_euler=d.to_track_quat('Z','Y').to_euler();return finish(o,name,m)

def collection(name):
    global col
    col=bpy.data.collections.new(name);bpy.context.scene.collection.children.link(col);return col

def camper(name,stocky):
    c=collection(name);skin='skin2' if stocky else 'skin';shirt='rust' if stocky else 'teal'
    hip=.78 if stocky else .91;neck=1.32 if stocky else 1.49;head=1.52 if stocky else 1.70;w=.50 if stocky else .39
    box('Hips',(0,0,hip),(.36,.27,.23),'pants')
    # Tapered jacket, broad shoulders and fewer facets than the woodland creatures.
    vs=[]
    for z,ww,dd in [(hip-.02,w*.39,.125),(neck-.06,w*.5,.16)]:
        vs.extend([(-ww,-dd,z),(ww,-dd,z),(ww,dd,z),(-ww,dd,z)])
    mesh('Jacket',vs,[(0,3,2,1),(4,5,6,7),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7)],shirt)
    box('Jacket zipper',(0,-.164,(hip+neck)/2),(.018,.012,neck-hip-.10),'trim',0)
    for side in [-1,1]:
        x=side*.12;knee=.43 if stocky else .48
        rod('Trouser thigh', (x,0,hip),(x,-.015,knee),.105,'pants',6,r2=.085)
        rod('Trouser cuff',(x,-.015,knee),(x,.01,.18),.08,'pants',6,r2=.068)
        box('Boot',(x,-.075,.095),(.19,.34,.19),'boots',.035)
        box('Sole',(x,-.085,.026),(.195,.345,.05),'dark',.012)
        shoulder=(side*(w*.5+.015),0,neck-.14);elbow=(side*(w*.5+.07),-.015,neck-.40);wrist=(side*(w*.5+.10),-.07,neck-.61)
        rod('Upper sleeve',elbow,shoulder,.078,shirt,6,r2=.105)
        rod('Forearm',wrist,elbow,.065,skin,6,r2=.075)
        box('Mitten hand',(wrist[0],wrist[1]-.005,wrist[2]-.035),(.12,.12,.16),skin,.025)
        box('Chest pocket',(side*.105,-.163,neck-.25),(.13,.035,.14),shirt,.01)
    rod('Neck',(0,0,neck-.04),(0,0,head-.12),.075,skin)
    box('Head',(0,-.018,head),(.30 if stocky else .26,.265,.32),skin,.055)
    box('Hair back',(0,.085,head+.04),(.29,.115,.26),'hair',.035)
    for side in [-1,1]:
        box('Ear',(side*.145,-.008,head),(.055,.07,.09),skin,.015)
        box('Eye',(side*.061,-.153,head+.027),(.025,.013,.025),'dark',.003)
        brow=box('Brow',(side*.061,-.156,head+.064),(.06,.018,.018),'hair',.005);brow.rotation_euler.y=side*.09
    box('Nose',(0,-.166,head-.005),(.067,.075,.083),skin,.015)
    box('Mouth',(0,-.15,head-.087),(.070,.014,.012),'hair',.002)
    if stocky:
        rod('Knit cap',(0,0,head+.105),(0,0,head+.235),.164,'rust',8,r2=.11)
        rod('Cap cuff',(0,0,head+.10),(0,0,head+.15),.171,'rust',8)
        box('Backpack',(0,.255,neck-.25),(.46,.28,.49),'teal',.06)
        rod('Bedroll',(-.28,.28,neck+.02),(.28,.28,neck+.02),.10,'cream',8)
        for side in [-1,1]:
            rod('Pack strap',(side*.16,-.17,hip+.10),(side*.17,-.17,neck-.08),.025,'trim',4)
            rod('Bedroll tie',(side*.18,.28,neck+.02-.003),(side*.205,.28,neck+.02-.003),.105,'trim',8)
        box('Pack pocket',(0,.416,neck-.32),(.29,.06,.22),'teal')
    else:
        rod('Hat brim',(0,-.025,head+.14),(0,-.025,head+.162),.245,'canvas_dark',8)
        rod('Hat crown',(0,.0,head+.16),(0,.0,head+.30),.147,'canvas',8,r2=.115)
        rod('Hat band',(0,0,head+.165),(0,0,head+.195),.15,'trim',8,r2=.142)
        box('Camera',(0,-.237,neck-.37),(.22,.12,.14),'dark',.018)
        rod('Camera lens',(0,-.29,neck-.37),(0,-.36,neck-.37),.056,'metal',8)
        rod('Lens glass',(0,-.36,neck-.37),(0,-.365,neck-.37),.043,'glass',8)
        for side in [-1,1]: rod('Camera strap',(side*.095,-.21,neck-.35),(side*.13,-.17,neck-.08),.012,'trim',4)
        box('Field satchel',(.27,.025,hip+.04),(.17,.23,.28),'canvas_dark')
    return c

photographer=camper('EDIT - Field photographer',False)
backpacker=camper('EDIT - Trail backpacker',True)
tent=collection('EDIT - Ochre ridge tent')
# Broad fabric strips with a lowered middle ridge; open entrance and closed rear.
for side in [-1,1]:
    vs=[]
    for y,ridge in [(-1.15,1.5),(0,1.41),(1.15,1.5)]:
        vs.extend([(side*1.12,y,.10),(side*.62,y,.84),(0,y,ridge)])
    o=mesh('Rainfly left' if side<0 else 'Rainfly right',vs,[(0,1,4,3),(1,2,5,4),(3,4,7,6),(4,5,8,7)],'canvas')
    o.data.materials.append(M['canvas_light']);o.data.polygons[1].material_index=1;o.data.polygons[3].material_index=1
    mod=o.modifiers.new('Fabric thickness','SOLIDIFY');mod.thickness=.008
    mesh('Entrance folded flap',[(0,-1.151,1.48),(side*1.1,-1.151,.1),(side*.74,-1.20,.12),(side*.24,-1.19,1.06)],[(0,1,2,3)],'canvas_dark')
    rod('Front bound edge',(side*1.12,-1.16,.10),(0,-1.16,1.51),.016,'cream')
    for y in [-1.10,1.10]:
        rod('Guy rope',(side*.65,y,.84),(side*1.57,y*1.23,.05),.009,'cream',4)
        rod('Stake',(side*1.57,y*1.23,.01),(side*1.59,y*1.23,.15),.018,'metal',4)
mesh('Rear canvas',[(-1.1,1.14,.1),(1.1,1.14,.1),(0,1.14,1.48)],[(0,1,2)],'canvas_dark')
box('Groundsheet',(0,0,.035),(2.16,2.28,.05),'trim',.015)
rod('Rear pole',(0,1.10,.05),(0,1.10,1.52),.023,'metal')
rod('Front pole',(0,-1.12,.05),(0,-1.12,1.52),.023,'metal')
rod('Ridge seam',(0,-1.17,1.51),(0,1.17,1.51),.018,'cream')
box('Sleeping mat',(0,.24,.085),(.63,1.58,.06),'teal',.03)
box('Pillow',(0,.78,.16),(.49,.30,.12),'cream',.04)
# Export at local origin before arranging the review scene.
report={}
for c,slug in [(photographer,'camper-photographer'),(backpacker,'camper-backpacker'),(tent,'tent-ochre')]:
    bpy.ops.object.select_all(action='DESELECT')
    for o in c.objects:o.select_set(True)
    bpy.context.view_layer.objects.active=list(c.objects)[0]
    bpy.ops.export_scene.gltf(filepath=str(ROOT/'assets/models'/f'zenscape-{slug}-v01.glb'),export_format='GLB',use_selection=True,export_animations=False)
    report[slug]={'mesh_objects':len(c.objects),'faces':sum(len(o.data.polygons) for o in c.objects),'triangles':sum(len(p.vertices)-2 for o in c.objects for p in o.data.polygons)}
for c,offset in [(tent,(-1.20,.55,0)),(photographer,(1.08,-.70,0)),(backpacker,(2.04,.04,0))]:
    for o in c.objects:o.location+=Vector(offset)
collection('STUDIO - excluded from exports')
M['floor']=mat('Studio warm grey','777B70');box('Ground',(0,0,-.065),(200,200,.10),'floor',0)
scene=bpy.context.scene;scene.render.engine='CYCLES';scene.cycles.samples=48
scene.world.color=(.25,.25,.25)
def aim(o,p):o.rotation_euler=(Vector(p)-o.location).to_track_quat('-Z','Y').to_euler()
bpy.ops.object.camera_add(location=(6,-10,6));cam=bpy.context.object;aim(cam,(0,.1,.75));cam.data.type='ORTHO';cam.data.ortho_scale=6.4;scene.camera=cam
for pos,power,size in [((0,-4,7),1600,7),((-4,1,4),1000,5),((4,4,6),1400,4)]:
    bpy.ops.object.light_add(type='AREA',location=pos);o=bpy.context.object;o.data.energy=power;o.data.shape='DISK';o.data.size=size;aim(o,(0,0,.8))
scene.render.resolution_x=1600;scene.render.resolution_y=1100;scene.render.resolution_percentage=100
scene.view_settings.view_transform='AgX';scene.render.filepath=str(OUT/'campers-v01.png')
for screen in bpy.data.screens:
    for area in screen.areas:
        if area.type=='VIEW_3D':
            area.spaces.active.region_3d.view_perspective='CAMERA'
bpy.ops.object.select_all(action='DESELECT')
bpy.ops.wm.save_as_mainfile(filepath=str(TARGET));bpy.ops.render.render(write_still=True)
cam.location=(4,-7,3.6);aim(cam,(1.55,-.25,1));cam.data.ortho_scale=2.9
scene.render.filepath=str(OUT/'campers-detail-v01.png');bpy.ops.render.render(write_still=True)
(OUT/'validation-v01.json').write_text(json.dumps(report,indent=2)+'\n')
print('CAMPER_STUDIES_OK',report)
