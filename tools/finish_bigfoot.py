"""First coat/face material study. Keeps all mesh coordinates, weights and keys.
Run through Blender; refuses to overwrite the authored material study.
"""
import bpy, math, json, hashlib, struct
from pathlib import Path
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[1];ART=ROOT/'art/blender/bigfoot'
TARGET=ART/'zenscape-bigfoot-finished.blend'
if TARGET.exists():raise RuntimeError('Material study exists; edit it in Blender.')
bpy.ops.wm.open_mainfile(filepath=str(ART/'zenscape-bigfoot-walk.blend'))
scene=bpy.context.scene;work=bpy.data.collections['EDIT - rigged Wanderer']
rig=bpy.data.objects['Bigfoot_Rig'];meshes=[o for o in work.objects if o.type=='MESH']
def shape_signature():
 h=hashlib.sha256()
 for o in sorted(meshes,key=lambda o:o.name):
  h.update(o.name.encode())
  for v in o.data.vertices:
   h.update(struct.pack('fff',*v.co))
   for g in v.groups:h.update(struct.pack('if',g.group,g.weight))
  for p in o.data.polygons:
   for i in p.vertices:h.update(struct.pack('i',i))
 for b in rig.data.bones:
  for row in b.matrix_local:h.update(struct.pack('ffff',*row))
 for layer in rig.animation_data.action.layers:
  for strip in layer.strips:
   for bag in strip.channelbags:
    for fc in bag.fcurves:
     h.update(fc.data_path.encode())
     for k in fc.keyframe_points:h.update(struct.pack('ff',*k.co))
 return h.hexdigest()
before=shape_signature()
def linear(hexcode):
 def c(v):return v/12.92 if v<=.04045 else ((v+.055)/1.055)**2.4
 return Vector(tuple(c(int(hexcode[i:i+2],16)/255) for i in (0,2,4)))
def smooth(a,b,x):
 t=max(0,min(1,(x-a)/(b-a)));return t*t*(3-2*t)
def mix(a,b,t):return a.lerp(b,max(0,min(1,t)))
base=linear('564633');warm=linear('80684a');dark=linear('332b23');silver=linear('978975')
face=linear('4b382b');eye_shadow=linear('26231d');nose=linear('27211c')
def material(name,roughness,vertex=True,color=None):
 m=bpy.data.materials.new(name);m.use_nodes=True
 p=m.node_tree.nodes.get('Principled BSDF');p.inputs['Roughness'].default_value=roughness
 p.inputs['Specular IOR Level'].default_value=.28
 if vertex:
  n=m.node_tree.nodes.new('ShaderNodeVertexColor');n.layer_name='Color'
  m.node_tree.links.new(n.outputs['Color'],p.inputs['Base Color'])
 else:p.inputs['Base Color'].default_value=(*color,1)
 return m
fur_mat=material('Wanderer - warm weathered coat',.96)
face_mat=material('Wanderer - exposed face',.72)
hand_mat=material('Wanderer - hands and soles',.86)
eye_mat=material('Wanderer - quiet amber eyes',.38)
coat_ids={3,10,12,32,34,54,56,60,62}
changed=0
for obj in meshes:
 id=int(obj.name.split('_')[1][1:])
 obj.data.materials.clear()
 if id in [7,8]:
  obj.data.materials.append(eye_mat)
  colors=obj.data.color_attributes.get('Color') or obj.data.color_attributes.new(name='Color',type='FLOAT_COLOR',domain='CORNER')
  for li,loop in enumerate(obj.data.loops):
   x,y,z=obj.data.vertices[loop.vertex_index].co
   r=math.sqrt((x/.65)**2+(z/.8)**2)
   front=smooth(.15,.65,-y)
   colour=mix(linear('30291f'),linear('7c572c'),(1-smooth(.65,1.2,r))*front)
   colour=mix(colour,linear('181813'),(1-smooth(.25,.65,r))*front)
   colors.data[li].color=(*colour,1)
   changed+=1
  continue
 obj.data.materials.append(fur_mat if id in coat_ids or id==5 else hand_mat)
 if id==5:obj.data.materials.append(face_mat)
 colors=obj.data.color_attributes.get('Color')
 assert colors is not None
 # Separate fur locks remain separate surfaces; a tiny per-face variation
 # complements broad color regions without adding texture noise or polygons.
 for poly in obj.data.polygons:
  variation=1+.022*math.sin(poly.index*2.399+id*.7)
  for li in poly.loop_indices:
   v=obj.data.vertices[obj.data.loops[li].vertex_index].co;x,y,z=v
   if id==3:
    shoulder=smooth(.30,.85,z)
    colour=mix(base,warm,shoulder*.73)
    colour=mix(colour,dark,(1-smooth(-.12,.30,z))*.38)
    # Faded edges on the existing long fur locks along the sides/back.
    locks=smooth(.265,.37,abs(x))
    tips=(.5+.5*math.sin(z*30+x*7))*.18
    colour=mix(colour,silver,locks*tips)
   elif id in [10,32]:
    t=smooth(-.65,.07,z)
    colour=mix(dark,warm,.22+.56*t)
    colour=mix(colour,silver,smooth(.12,.175,abs(x))*.14)
   elif id in [12,34]:
    colour=mix(dark,base,.23+.40*smooth(-.55,.06,z))
    colour=mix(colour,warm,smooth(.09,.14,abs(x))*.12)
   elif id in [54,60]:colour=mix(dark,base,.35+.55*smooth(-.55,.13,z))
   elif id in [56,62]:colour=mix(dark,base,.13+.30*smooth(-.48,.04,z))
   elif id==5:
    front=smooth(.05,.17,-y)
    skin=front*smooth(-.06,.04,z)*(1-smooth(.25,.33,z))
    colour=mix(base,warm,.27+.22*smooth(.22,.43,z))
    temples=smooth(.12,.20,abs(x))*smooth(.23,.34,z)
    colour=mix(colour,silver,temples*.72)
    colour=mix(colour,face,skin*.94)
    band=smooth(.145,.195,z)*(1-smooth(.222,.256,z))*front
    colour=mix(colour,eye_shadow,band*.88)
    nasal=smooth(.245,.28,-y)*smooth(.115,.14,z)*(1-smooth(.175,.21,z))
    colour=mix(colour,nose,nasal)
    mouth=smooth(.253,.27,-y)*(1-smooth(.008,.024,abs(z-.028)))
    colour=mix(colour,nose,mouth*.8)
   else:
    colour=mix(dark,base,.18)
   colour*=variation
   colors.data[li].color=(*colour,1)
   changed+=1
  if id==5:
   c=poly.center
   poly.material_index=1 if c.y<-.12 and -.035<c.z<.285 else 0
# Existing daylight-invisible eye geometry receives an ordinary opaque amber
# material. No emission, additional eye meshes, lights, textures or geometry.
after=shape_signature();assert before==after,'Shape/rig/animation unexpectedly changed'
scene.frame_set(1)
bpy.ops.object.select_all(action='DESELECT')
for obj in work.objects:obj.select_set(True)
bpy.context.view_layer.objects.active=rig
bpy.ops.export_scene.gltf(filepath=str(ROOT/'assets/models/zenscape-bigfoot-finished.glb'),export_format='GLB',use_selection=True,
 export_animations=True,export_animation_mode='ACTIONS',export_force_sampling=True,
 export_frame_range=False,export_anim_slide_to_zero=True,export_def_bones=True,export_skins=True)
rig['material_study']='Warm shoulder mantle, darker extremities, weathered temples, exposed face and opaque non-emissive amber eyes.'
report=dict(shape_rig_animation_hash_before=before,shape_rig_animation_hash_after=after,
 unchanged_shape_weights_bones_keys=before==after,recolored_corners=changed,
 faces=sum(len(o.data.polygons) for o in meshes),mesh_count=len(meshes),added_textures=0,
 note='Vertex colors and glTF-compatible Principled materials. Studio lighting unchanged.')
(ART/'material-validation.json').write_text(json.dumps(report,indent=2)+'\n')
bpy.ops.object.select_all(action='DESELECT');rig.select_set(True)
scene.render.filepath=str(ART/'bigfoot-finished.png')
bpy.ops.wm.save_as_mainfile(filepath=str(TARGET))
bpy.ops.render.render(write_still=True)
# A separate close-up makes face/eye judgment possible without changing saved framing.
cam=scene.camera
cam.location=(1.7,-4,2.85)
cam.rotation_euler=(Vector((-.025,-.22,2.40))-cam.location).to_track_quat('-Z','Y').to_euler()
cam.data.ortho_scale=1.08
scene.render.resolution_x=900;scene.render.resolution_y=900
scene.render.filepath=str(ART/'bigfoot-finished-face.png')
bpy.ops.render.render(write_still=True)
print('BIGFOOT_MATERIALS_VALIDATED',json.dumps(report))
