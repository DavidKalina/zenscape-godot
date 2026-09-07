"""Match the approved bear to Wanderer's faceted, weathered woodland finish."""
import bpy,bmesh,math,random,json,sys
from pathlib import Path
from mathutils import Vector
from mathutils.bvhtree import BVHTree
ROOT=Path(__file__).resolve().parents[1];ART=ROOT/'art/blender/bear';TARGET=ART/'zenscape-bear-woodland.blend'
if TARGET.exists() and '--replace-generated' not in sys.argv:raise RuntimeError('Preserve authored output.')
bpy.ops.wm.open_mainfile(filepath=str(ART/'zenscape-bear-walk.blend'))
scene=bpy.context.scene;work=bpy.data.collections['EDIT - rigged bear'];rig=bpy.data.objects['Bear_Rig']
objects={o.name:o for o in work.objects if o.type=='MESH'}
def rgb(h):
 def f(v):return v/12.92 if v<=.04045 else ((v+.055)/1.055)**2.4
 return Vector([f(int(h[i:i+2],16)/255) for i in (0,2,4)])
base=rgb('61513d');warm=rgb('806b4c');dark=rgb('40362a');muzzle=rgb('62513e');nose=rgb('28241e')
mat=bpy.data.materials.new('Bear - weathered woodland coat');mat.use_nodes=True
bs=mat.node_tree.nodes.get('Principled BSDF');bs.inputs['Roughness'].default_value=.94
bs.inputs['Specular IOR Level'].default_value=.20
vc=mat.node_tree.nodes.new('ShaderNodeVertexColor');vc.layer_name='Color';mat.node_tree.links.new(vc.outputs['Color'],bs.inputs['Base Color'])
rng=random.Random(617)
for name,o in objects.items():
 o.data=o.data.copy()
 o.data.materials.clear();o.data.materials.append(mat)
 attr=o.data.color_attributes.get('Color') or o.data.color_attributes.new(name='Color',type='FLOAT_COLOR',domain='CORNER')
 for poly in o.data.polygons:
  poly.material_index=0;poly.use_smooth=False
  for li in poly.loop_indices:
   p=o.matrix_world@o.data.vertices[o.data.loops[li].vertex_index].co
   c=base.lerp(warm,max(0,min(1,(p.z-.3)/.7))*.70)
   if 'Paw' in name:c=dark.lerp(base,max(0,min(1,p.z/.14))*.7)
   elif 'Leg' in name:c=dark.lerp(base,max(0,min(1,(p.z-.08)/.4)))
   elif 'Muzzle' in name:c=muzzle
   elif 'Eye' in name or 'Nose' in name or 'Inset' in name:c=nose
   c=c*(1+.045*math.sin(p.x*15+p.y*8+p.z*12))
   attr.data[li].color=(*c,1)
# Append shallow folded clumps to rigid body/head meshes, using existing bones.
count=0
for name,num in [('Bear_Body',24),('Bear_SquareHead',10)]:
 o=objects[name];mesh=o.data;bm=bmesh.new();bm.from_mesh(mesh)
 layer=bm.loops.layers.float_color.get('Color');deform=bm.verts.layers.deform.verify();group=o.vertex_groups[0].index
 points=[o.matrix_world@v.co for v in mesh.vertices]
 tree=BVHTree.FromPolygons(points,[tuple(p.vertices) for p in mesh.polygons])
 inv=o.matrix_world.inverted()
 for i in range(num):
  side=-1 if i%2 else 1
  if name=='Bear_Body': y=rng.uniform(-.50,-.12) if i<16 else rng.uniform(.1,.5);z=rng.uniform(.46,.77)
  else:y=rng.uniform(-.86,-.69);z=rng.uniform(.44,.65)
  p,n,idx,d=tree.ray_cast(Vector((side*1.5,y,z)),Vector((-side,0,0)),3)
  if p is None:continue
  length=rng.uniform(.10,.16) if name=='Bear_Body' else rng.uniform(.06,.09)
  width=rng.uniform(.027,.045) if name=='Bear_Body' else rng.uniform(.019,.027)
  down=Vector((0,.25,-1));t=(down-n*down.dot(n)).normalized();across=n.cross(t).normalized()
  root=p-n*.005;mid=p+t*length*.43+n*.010;tip=p+t*length+n*.014+across*rng.uniform(-.012,.012)
  verts=[]
  for c,w in [(root,width),(mid,width*.65)]:verts.extend([c-across*w,c+across*w,c+n*.006])
  verts.append(tip)
  vs=[]
  for pos in verts:
   v=bm.verts.new(inv@pos);v[deform][group]=1;vs.append(v)
  faces=[]
  for indices in [(2,1,0),(0,1,4,3),(1,2,5,4),(2,0,3,5),(3,4,6),(4,5,6),(5,3,6)]:
   f=bm.faces.new([vs[j] for j in indices]);faces.append(f);f.material_index=0
   c=base.lerp(warm,rng.uniform(.25,.65))
   for loop in f.loops:loop[layer]=(*c,1)
  bmesh.ops.recalc_face_normals(bm,faces=faces);count+=1
 bm.to_mesh(mesh);bm.free();mesh.update()
for o in objects.values():
 for v in o.data.vertices:assert abs(sum(g.weight for g in v.groups)-1)<1e-5
scene.frame_set(1);bpy.ops.object.select_all(action='DESELECT')
for o in work.objects:o.select_set(True)
bpy.context.view_layer.objects.active=rig
bpy.ops.export_scene.gltf(filepath=str(ROOT/'assets/models/zenscape-bear-woodland.glb'),export_format='GLB',use_selection=True,export_animations=True,export_animation_mode='ACTIONS',export_force_sampling=True,export_frame_range=False,export_anim_slide_to_zero=True,export_def_bones=True,export_skins=True)
bpy.ops.object.select_all(action='DESELECT');rig.select_set(True)
scene.render.filepath=str(ART/'bear-woodland.png');bpy.ops.wm.save_as_mainfile(filepath=str(TARGET));bpy.ops.render.render(write_still=True)
report=dict(tufts=count,meshes=len(objects),bones=len(rig.data.bones),faces=sum(len(o.data.polygons) for o in objects.values()),complete_skin_weights=True)
(ART/'woodland-validation.json').write_text(json.dumps(report,indent=2)+'\n');print('BEAR_WOODLAND_OK',report)
