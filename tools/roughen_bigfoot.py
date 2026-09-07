"""Add sparse faceted fur wisps and caught leaves to the existing material study.
All additions use the existing skin weights/material; no new bones or textures.
"""
import bpy,bmesh,math,random,json,sys
from pathlib import Path
from mathutils import Vector
from mathutils.bvhtree import BVHTree
ROOT=Path(__file__).resolve().parents[1];ART=ROOT/'art/blender/bigfoot'
TARGET=ART/'zenscape-bigfoot-unkempt.blend'
if TARGET.exists() and '--replace-generated' not in sys.argv:raise RuntimeError('Edit the existing unkempt study instead of regenerating over it.')
bpy.ops.wm.open_mainfile(filepath=str(ART/'zenscape-bigfoot-finished.blend'))
scene=bpy.context.scene;work=bpy.data.collections['EDIT - rigged Wanderer'];rig=bpy.data.objects['Bigfoot_Rig']
objects={int(o.name.split('_')[1][1:]):o for o in work.objects if o.type=='MESH'}
rng=random.Random(731)
def rgb(h):
 def f(v):return v/12.92 if v<=.04045 else ((v+.055)/1.055)**2.4
 return Vector([f(int(h[i:i+2],16)/255) for i in (0,2,4)])
# Broad, coherent color variation, restrained enough to leave large facets clean.
fur_ids=[3,10,12,32,34,54,56,60,62]
for id in fur_ids:
 obj=objects[id];colors=obj.data.color_attributes['Color']
 for i,loop in enumerate(obj.data.loops):
  x,y,z=obj.data.vertices[loop.vertex_index].co
  mottling=.075*math.sin(x*16+z*7+id)*math.cos(y*13-z*5)+.032*math.sin(z*31+x*9+y*17)
  old=Vector(colors.data[i].color[:3]);color=old*(1+mottling)
  colors.data[i].color=(*color,1)
original={id:([v.co.copy() for v in obj.data.vertices],len(obj.data.polygons)) for id,obj in objects.items()}
cache={};trees={};added_faces=[];counts={'fur_tufts':0,'leaves':0,'twigs':0}
def mesh_edit(id):
 if id not in cache:
  obj=objects[id];bm=bmesh.new();bm.from_mesh(obj.data)
  color=bm.loops.layers.float_color.get('Color') or bm.loops.layers.color.get('Color')
  if color is None:color=bm.loops.layers.float_color.new('Color')
  deform=bm.verts.layers.deform.verify()
  cache[id]=(bm,color,deform,obj.vertex_groups[0].index)
 return cache[id]
def geometry(id,verts,faces,colour,tip_colour=None):
 bm,layer,deform,group=mesh_edit(id)
 vs=[]
 for p in verts:
  v=bm.verts.new(p);v[deform][group]=1.0;vs.append(v)
 new=[]
 for indices in faces:
  f=bm.faces.new([vs[i] for i in indices]);f.smooth=False;f.material_index=0
  for loop in f.loops:
   c=colour
   if tip_colour is not None:
    t=vs.index(loop.vert)/max(1,len(vs)-1);c=colour.lerp(tip_colour,t*.65)
   # BMesh byte-color layers expose sRGB, unlike Mesh.color_attributes.color.
   # Convert explicitly so newly attached fur matches the sampled linear coat.
   if bm.loops.layers.float_color.get('Color') is None:
    c=Vector([12.92*v if v<=.0031308 else 1.055*v**(1/2.4)-.055 for v in c])
   loop[layer]=(*c,1)
  new.append(f)
 bmesh.ops.recalc_face_normals(bm,faces=new)
 added_faces.extend(new)
def surface(id,z,angle):
 obj=objects[id];radial=Vector((math.cos(angle),math.sin(angle),0))
 # Attach to the undeformed mesh; Object.ray_cast would include the live walk.
 if id not in trees:trees[id]=BVHTree.FromPolygons([v.co for v in obj.data.vertices],[tuple(p.vertices) for p in obj.data.polygons])
 p,n,index,distance=trees[id].ray_cast(radial*.9+Vector((0,0,z)),-radial,1.8)
 if p is None:raise RuntimeError(('Fur anchor missed surface',id,z,angle))
 return p,n,index

def tuft(id,z,angle,length,width,crown=False):
 p,n,index=surface(id,z,angle)
 down=Vector((rng.uniform(-.13,.13),rng.uniform(-.10,.10),-1))
 tangent=down-n*down.dot(n)
 if tangent.length<.1:tangent=Vector((1,0,0))
 tangent.normalize();across=n.cross(tangent).normalized()
 bend=across*rng.uniform(-.3,.3)
 # Broad buried root, a lifted fold, and an off-center torn tip.
 root=p-n*.006
 mid=p+tangent*length*.43+n*(.018 if crown else .009)+bend*length*.2
 tip=p+tangent*length+n*.018+bend*length
 vertices=[]
 for center,w,depth in [(root,width,.006),(mid,width*.64,.004)]:
  vertices.extend([center-across*w,center+across*w,center+n*depth])
 vertices.append(tip)
 faces=[(2,1,0),(0,1,4,3),(1,2,5,4),(2,0,3,5),(3,4,6),(4,5,6),(5,3,6)]
 obj=objects[id];poly=obj.data.polygons[index];attr=obj.data.color_attributes['Color']
 color=sum((Vector(attr.data[i].color[:3]) for i in poly.loop_indices),Vector())/len(poly.loop_indices)
 color*=rng.uniform(.97,1.14)
 geometry(id,vertices,faces,color,rgb('8b785b'))
 counts['fur_tufts']+=1

# Irregular shoulder hems, side locks and forearm wisps; no mirrored rows.
for id,num,zrange in [(3,17,(.22,.98)),(10,8,(-.58,.07)),(32,6,(-.56,.06)),(12,6,(-.48,-.03)),(34,8,(-.45,-.04)),(54,3,(-.43,.03)),(60,2,(-.42,.04)),(56,2,(-.30,-.03)),(62,3,(-.31,-.02))]:
 for i in range(num):
  if id==3:
   angle=rng.choice([0,math.pi,math.pi/2])+rng.uniform(-.25,.25)
  else:
   outside=math.pi if id in [10,12,54,56] else 0
   angle=outside+rng.uniform(-.4,.4)
  z=rng.uniform(.70,1.04) if id==3 and i<10 else rng.uniform(*zrange)
  tuft(id,z,angle,rng.uniform(.085,.17),rng.uniform(.019,.032))
# Short broken temple/crown locks, leaving the eye line and muzzle clear.
for z,angle in [(.35,0),(.39,.55),(.32,math.pi),(.38,2.6),(.34,1.5),(.415,-1.0),(.41,-2.0),(.40,2.2),(-.02,.0),(-.025,math.pi),(-.03,-1.6)]:
 tuft(5,z,angle,rng.uniform(.065,.105),rng.uniform(.010,.017),True)

def leaf(id,z,angle,length,colour):
 p,n,index=surface(id,z,angle)
 down=Vector((rng.uniform(-.7,.7),rng.uniform(-.4,.4),-1));down=(down-n*down.dot(n)).normalized()
 side=n.cross(down).normalized()
 p+=n*.014
 middle=p+down*length*.52+n*.012
 tip=p+down*length+side*length*.10
 w=length*.26
 verts=[p,middle-side*w,middle+n*.007,middle+side*w,tip,middle-n*.003]
 geometry(id,verts,[(0,1,2),(0,2,3),(1,4,2),(2,4,3),(0,5,1),(0,3,5),(1,5,4),(5,3,4)],colour,colour*.8)
 counts['leaves']+=1
# A handful of muted, weathered leaves caught against existing fur.
for id,z,a,size,c in [(3,.88,-.78,.11,'657046'),(3,.53,2.65,.09,'8b6b39'),(3,.69,1.15,.12,'4d5738'),(10,-.15,-1.05,.085,'7c713c'),(34,-.20,-.9,.075,'596044'),(32,-.03,1.0,.09,'9b7d43')]:
 leaf(id,z,a,size,rgb(c))
# One tiny forked twig on the shoulder, anchored under a leaf.
def stick(id,a,b,r,color):
 direction=(b-a).normalized();u=direction.cross(Vector((0,0,1)))
 if u.length<.1:u=direction.cross(Vector((1,0,0)))
 u.normalize();v=direction.cross(u);verts=[]
 for p in [a,b]:
  verts.extend([p+(u*math.cos(k*math.tau/3)+v*math.sin(k*math.tau/3))*r for k in range(3)])
 geometry(id,verts,[(2,1,0),(3,4,5),(0,1,4,3),(1,2,5,4),(2,0,3,5)],color)
 counts['twigs']+=1
p,n,_=surface(3,.90,-.7);p+=n*.02
stick(3,p+Vector((-.035,0,-.035)),p+Vector((.04,0,.055)),.003,rgb('695039'))
stick(3,p+Vector((.012,0,.018)),p+Vector((.045,-.005,.022)),.002,rgb('695039'))
for id,(bm,layer,deform,group) in cache.items():
 obj=objects[id];bm.to_mesh(obj.data);bm.free();obj.data.update()
 # Added geometry is appended; all original coordinates remain exactly intact.
 before,_=original[id]
 assert all((obj.data.vertices[i].co-p).length<1e-7 for i,p in enumerate(before))
 for v in obj.data.vertices:assert abs(sum(g.weight for g in v.groups)-1)<1e-5
scene.frame_set(1)
bpy.ops.object.select_all(action='DESELECT')
for o in work.objects:o.select_set(True)
bpy.context.view_layer.objects.active=rig
bpy.ops.export_scene.gltf(filepath=str(ROOT/'assets/models/zenscape-bigfoot-unkempt.glb'),export_format='GLB',use_selection=True,
 export_animations=True,export_animation_mode='ACTIONS',export_force_sampling=True,
 export_frame_range=False,export_anim_slide_to_zero=True,export_def_bones=True,export_skins=True)
faces_before=sum(n for _,n in original.values());faces_after=sum(len(o.data.polygons) for o in objects.values())
report={**counts,'faces_before':faces_before,'faces_after':faces_after,'added_faces':faces_after-faces_before,
 'original_vertex_positions_preserved':True,'skin_weights_complete':True,'mesh_objects':len(objects),
 'added_bones':0,'added_textures':0,'note':'Faceted clumps, sparse leaf litter and subtle vertex-color mottling. Details follow existing bones, without independent wind motion.'}
(ART/'unkempt-validation.json').write_text(json.dumps(report,indent=2)+'\n')
rig['material_study']='Unkempt coat: tapered fur wisps, six caught leaves, one forked twig and restrained mottling.'
bpy.ops.object.select_all(action='DESELECT');rig.select_set(True)
scene.render.filepath=str(ART/'bigfoot-unkempt.png');bpy.ops.wm.save_as_mainfile(filepath=str(TARGET));bpy.ops.render.render(write_still=True)
cam=scene.camera;cam.location=(1.7,-4,2.85);cam.rotation_euler=(Vector((-.025,-.22,2.40))-cam.location).to_track_quat('-Z','Y').to_euler();cam.data.ortho_scale=1.18
scene.render.resolution_x=900;scene.render.resolution_y=900;scene.render.filepath=str(ART/'bigfoot-unkempt-face.png');bpy.ops.render.render(write_still=True)
print('UNKEMPT_STUDY_VALIDATED',json.dumps(report))
