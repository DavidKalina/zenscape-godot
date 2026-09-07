"""Replace bead-like digits with connected, faceted hands and flatter toes.
The existing finger, hand and foot bones and their animation are retained.
"""
import bpy,bmesh,json,math
from pathlib import Path
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[1];ART=ROOT/'art/blender/bigfoot'
TARGET=ART/'zenscape-bigfoot-hands-feet.blend'
if TARGET.exists():raise RuntimeError('Edit the authored hand/foot study instead of regenerating it.')
bpy.ops.wm.open_mainfile(filepath=str(ART/'zenscape-bigfoot-unkempt.blend'))
scene=bpy.context.scene;rig=bpy.data.objects['Bigfoot_Rig'];work=bpy.data.collections['EDIT - rigged Wanderer']
objects={int(o.name.split('_')[1][1:]):o for o in work.objects if o.type=='MESH'}
ring=[(-.68,1),(.68,1),(1,.65),(1,-.65),(.68,-1),(-.68,-1),(-1,-.65),(-1,.65)]
def rgb(h):
 def c(v):return v/12.92 if v<=.04045 else ((v+.055)/1.055)**2.4
 return Vector([c(int(h[i:i+2],16)/255) for i in (0,2,4)])
base=rgb('44392d');pads=rgb('574737');dark=rgb('30291f')
material=bpy.data.materials['Wanderer - hands and soles']
class Shape:
 def __init__(self):self.vertices=[];self.faces=[]
 def loft(self,stations,axis):
  # stations: along, center-u, center-v, radius-u, radius-v
  start=len(self.vertices)
  for a,u,v,ru,rv in stations:
   for x,y in ring:self.vertices.append((u+x*ru,v+y*rv,a) if axis=='Z' else (u+x*ru,a,v+y*rv))
  for i in range(len(stations)-1):
   for j in range(8):self.faces.append(tuple(start+k for k in [i*8+j,i*8+(j+1)%8,(i+1)*8+(j+1)%8,(i+1)*8+j]))
  self.faces.extend([tuple(start+i for i in reversed(range(8))),tuple(start+(len(stations)-1)*8+i for i in range(8))])
 def apply(self,id,kind):
  obj=objects[id];groups=[g.name for g in obj.vertex_groups];assert len(groups)==1
  old_count=len(obj.data.polygons)
  mesh=bpy.data.meshes.new('Refined_'+obj.name);mesh.from_pydata(self.vertices,[],self.faces);mesh.update()
  bm=bmesh.new();bm.from_mesh(mesh);bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));bm.to_mesh(mesh);bm.free()
  mesh.materials.append(material)
  attr=mesh.color_attributes.new(name='Color',type='FLOAT_COLOR',domain='CORNER')
  for p in mesh.polygons:
   p.use_smooth=False
   for li in p.loop_indices:
    v=mesh.vertices[mesh.loops[li].vertex_index].co
    if kind=='foot':
     t=max(0,min(1,(v.z+.12)/.16));color=dark.lerp(base,t)
     if v.y<-.285:color=color.lerp(pads,.20)
    else:
     color=base.lerp(pads,.30 if v.y<-.015 else .12)
    attr.data[li].color=(*color,1)
  obj.data=mesh;obj.vertex_groups.clear();obj.vertex_groups.new(name=groups[0]).add(list(range(len(mesh.vertices))),1,'REPLACE')
  return dict(object=obj.name,faces_before=old_count,faces_after=len(mesh.polygons),bone=groups[0])
changes=[]
# A palm that meets the wrist, with an integrated angled thumb instead of a ball.
for id,inside in [(30,1),(52,-1)]:
 s=Shape()
 s.loft([(.028,0,0,.073,.043),(-.025,0,0,.102,.052),(-.105,0,-.003,.113,.054),(-.159,0,-.005,.094,.047)],'Z')
 s.loft([(-.040,inside*.075,-.012,.042,.037),(-.087,inside*.124,-.021,.036,.032),(-.135,inside*.139,-.040,.028,.027),(-.166,inside*.123,-.055,.023,.023)],'Z')
 changes.append(s.apply(id,'hand'))
# Retain every existing finger joint. Squared cross-sections and overlapping
# segment ends replace the disconnected sphere appearance.
for start in [15,37]:
 for f in range(4):
  proximal=start+4*f;distal=proximal+2
  old=objects[proximal]
  joint_length=.074-abs(f-1.4)*.012
  end=joint_length*.67+.013
  s=Shape();s.loft([(.012,0,0,.022,.025),(-.020,0,-.003,.023,.026),(-end,0,-.008,.020,.023)],'Z')
  changes.append(s.apply(proximal,'hand'))
  tip_length=.049-abs(f-1.35)*.006
  s=Shape();s.loft([(.010,0,0,.020,.023),(-tip_length*.58,0,-.005,.019,.022),(-tip_length,0,-.010,.015,.017)],'Z')
  changes.append(s.apply(distal,'hand'))
# Long plantigrade soles with an instep and five low toe pads sharing the forefoot.
for id,inside in [(58,1),(64,-1)]:
 s=Shape()
 s.loft([(.142,0,-.084,.078,.036),(.075,0,-.052,.110,.068),(-.025,0,-.021,.12,.099),(-.14,0,-.058,.132,.062),(-.245,0,-.085,.15,.035),(-.285,0,-.087,.147,.033)],'Y')
 for x,width,end in [(.110,.069,-.398),(.046,.058,-.384),(-.010,.052,-.364),(-.060,.047,-.343),(-.105,.041,-.320)]:
  x*=inside;r=width/2
  s.loft([(-.255,x,-.085,r*.9,.035),(-.292,x,-.086,r,.034),(end+.018,x,-.087,r,.033),(end,x,-.088,r*.70,.030)],'Y')
 changes.append(s.apply(id,'foot'))
# Foot geometry must still respect the plane throughout the existing walk.
minimum=0
for frame in range(1,110):
 scene.frame_set(frame);deps=bpy.context.evaluated_depsgraph_get()
 for id in [58,64]:
  obj=objects[id].evaluated_get(deps);mesh=obj.to_mesh()
  minimum=min(minimum,min((obj.matrix_world@v.co).z for v in mesh.vertices));obj.to_mesh_clear()
assert minimum>-.005,('New toes penetrate floor',minimum)
for obj in objects.values():
 for v in obj.data.vertices:assert abs(sum(g.weight for g in v.groups)-1)<1e-5
scene.frame_set(1)
bpy.ops.object.select_all(action='DESELECT')
for o in work.objects:o.select_set(True)
bpy.context.view_layer.objects.active=rig
bpy.ops.export_scene.gltf(filepath=str(ROOT/'assets/models/zenscape-bigfoot-hands-feet.glb'),export_format='GLB',use_selection=True,
 export_animations=True,export_animation_mode='ACTIONS',export_force_sampling=True,export_frame_range=False,
 export_anim_slide_to_zero=True,export_def_bones=True,export_skins=True)
report=dict(changed_parts=changes,minimum_sole_height_m=minimum,skin_weights_complete=True,
 total_faces=sum(len(o.data.polygons) for o in objects.values()),mesh_objects=len(objects),
 rig_bones=len(rig.data.bones),animation='Walk',note='Existing finger controls preserved; thumbs still move with palms; toes move with the foot.')
(ART/'hands-feet-validation.json').write_text(json.dumps(report,indent=2)+'\n')
bpy.ops.object.select_all(action='DESELECT');rig.select_set(True)
scene.render.filepath=str(ART/'bigfoot-hands-feet.png');bpy.ops.wm.save_as_mainfile(filepath=str(TARGET));bpy.ops.render.render(write_still=True)
# Hand and foot close-ups use the same key/fill lighting as the full-body view.
cam=scene.camera;scene.render.resolution_x=900;scene.render.resolution_y=900
for name,focus,size in [('hands',Vector((.43,-.23,.61)),.73),('feet',Vector((0,-.12,.18)),1.0)]:
 cam.location=focus+Vector((1.8,-3,1.4));cam.rotation_euler=(focus-cam.location).to_track_quat('-Z','Y').to_euler();cam.data.ortho_scale=size
 scene.render.filepath=str(ART/f'bigfoot-refined-{name}.png');bpy.ops.render.render(write_still=True)
print('HANDS_FEET_VALIDATED',json.dumps({k:v for k,v in report.items() if k!='changed_parts'}))
