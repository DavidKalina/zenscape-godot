"""Model-only woodland revision of the current diorama inhabitant.
Run with Blender --background --python tools/restyle_bigfoot.py.
Creates a new editable source and GLB; does not overwrite earlier authored models.
"""
import bpy,bmesh,json,hashlib,struct
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
ART=ROOT/'art/blender/bigfoot'
TARGET=ART/'zenscape-bigfoot-woodland.blend'
EXPORT=ROOT/'assets/models/zenscape-bigfoot-woodland.glb'
if TARGET.exists():raise RuntimeError('Edit the existing woodland source; do not regenerate over it.')
bpy.ops.wm.open_mainfile(filepath=str(ART/'zenscape-bigfoot-routine.blend'))
scene=bpy.context.scene;work=bpy.data.collections['EDIT - rigged Wanderer'];rig=bpy.data.objects['Bigfoot_Rig']
meshes=[o for o in work.objects if o.type=='MESH']
def animation_signature():
 h=hashlib.sha256()
 for bone in rig.data.bones:
  h.update(bone.name.encode())
  for row in bone.matrix_local:h.update(struct.pack('ffff',*row))
 for action in sorted(bpy.data.actions,key=lambda a:a.name):
  h.update(action.name.encode())
  for layer in action.layers:
   for strip in layer.strips:
    for bag in strip.channelbags:
     for curve in bag.fcurves:
      h.update(curve.data_path.encode());h.update(str(curve.array_index).encode())
      for key in curve.keyframe_points:
       h.update(struct.pack('ffffff',*key.co,*key.handle_left,*key.handle_right));h.update(key.interpolation.encode())
 return h.hexdigest()
before=animation_signature();faces_before=sum(len(o.data.polygons) for o in meshes)
for obj in meshes:
 identity=int(obj.name.split('_')[1][1:])
 if identity in [7,8]:continue
 bm=bmesh.new();bm.from_mesh(obj.data)
 bmesh.ops.remove_doubles(bm,verts=list(bm.verts),dist=0.000001)
 remaining=set(bm.verts);components=[]
 while remaining:
  todo=[remaining.pop()];component=set(todo)
  while todo:
   for edge in todo.pop().link_edges:
    for v in edge.verts:
     if v in remaining:remaining.remove(v);component.add(v);todo.append(v)
  components.append(component)
 components.sort(key=lambda c:(-len(c),sum(v.co.z for v in c)/len(c)))
 # Preserve the solid anatomy; express coat with a few large silhouette locks.
 if identity in [3,10,12,32,34,54,56,60,62]:
  keep=3 if identity in [3,10,12,32,34] else 1
  for c in components[keep:]:bmesh.ops.delete(bm,geom=list(c),context='VERTS')
 elif identity==5:
  # Skull and integrated nose carry recognition; tiny crown/chin tufts go.
  for c in components:
   if len(c)<=8:bmesh.ops.delete(bm,geom=list(c),context='VERTS')
 elif identity in [58,64]:
  # Keep the original sole and forefoot; remove separately articulated-looking toes.
  for c in components[1:]:bmesh.ops.delete(bm,geom=list(c),context='VERTS')
 bm.to_mesh(obj.data);bm.free()
 bpy.context.view_layer.objects.active=obj
 modifier=obj.modifiers.new('Woodland broad planes','DECIMATE')
 bpy.ops.object.modifier_move_to_index(modifier=modifier.name,index=0)
 modifier.ratio=.52 if identity==5 else (.68 if identity in [3,10,12,32,34,54,56,60,62] else .85)
 bpy.ops.object.modifier_apply(modifier=modifier.name)
 color=obj.data.color_attributes.get('Color')
 for poly in obj.data.polygons:
  poly.use_smooth=False
  if color:
   indices=list(poly.loop_indices)
   average=[sum(color.data[i].color[k] for i in indices)/len(indices) for k in range(4)]
   for i in indices:color.data[i].color=average
 for v in obj.data.vertices:
  assert abs(sum(g.weight for g in v.groups)-1)<1e-5,(obj.name,v.index,'skin coverage')
assert animation_signature()==before,'Model revision changed bones or animation'
rig.animation_data.action=bpy.data.actions['Idle']
scene.frame_set(1)
bpy.ops.object.select_all(action='DESELECT');rig.select_set(True)
for obj in meshes:obj.select_set(True)
bpy.context.view_layer.objects.active=rig
bpy.ops.export_scene.gltf(filepath=str(EXPORT),export_format='GLB',use_selection=True,
 export_animations=True,export_animation_mode='ACTIONS',export_force_sampling=True,
 export_frame_range=False,export_anim_slide_to_zero=True,export_def_bones=True,export_skins=True)
report={'source':'zenscape-bigfoot-routine.blend','faces_before':faces_before,
 'faces_after':sum(len(o.data.polygons) for o in meshes),'skinned_meshes':len(meshes),
 'source_bones_and_animation_unchanged':True,'animation_signature':before,'complete_skin_weights':True}
(ART/'woodland-validation.json').write_text(json.dumps(report,indent=2)+'\n')
scene.render.filepath=str(ART/'bigfoot-woodland.png')
bpy.ops.wm.save_as_mainfile(filepath=str(TARGET))
scene.render.engine='CYCLES';scene.cycles.samples=24
bpy.ops.render.render(write_still=True)
print('WOODLAND MODEL',json.dumps(report))
