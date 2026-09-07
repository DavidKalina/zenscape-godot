"""A heavier brow, broad nose and broken cheek/crown fur for Wanderer."""
import bpy,bmesh,math,random,json,sys
from pathlib import Path
from mathutils import Vector
from mathutils.bvhtree import BVHTree
ROOT=Path(__file__).resolve().parents[1];ART=ROOT/'art/blender/bigfoot'
TARGET=ART/'zenscape-bigfoot-classic.blend'
if TARGET.exists() and '--replace-generated' not in sys.argv:raise RuntimeError('Preserve the authored head study; do not regenerate over edits.')
bpy.ops.wm.open_mainfile(filepath=str(ART/'zenscape-bigfoot-hands-feet.blend'))
scene=bpy.context.scene;work=bpy.data.collections['EDIT - rigged Wanderer'];rig=bpy.data.objects['Bigfoot_Rig']
objects={int(o.name.split('_')[1][1:]):o for o in work.objects if o.type=='MESH'}
# Reuse the tested weighted faceted tuft builder without running the coat pass.
source=(ROOT/'tools/roughen_bigfoot.py').read_text()
rng=random.Random(921)
exec(source[source.index('def rgb('):source.index('# Broad, coherent')])
exec(source[source.index('cache={};'):source.index('# Irregular shoulder')])
head=objects[5]
for v in head.data.vertices:
 x,y,z=v.co
 # Squarer lower jaw, broader nasal wings, less spherical crown.
 if z<.10:v.co.x*=1+.13*max(0,1-abs(z)/.16)
 if y<-.255 and .11<z<.205:v.co.x*=1.23
 if z>.285:
  t=min(1,(z-.285)/.158)
  v.co.z+=.037*t*t
  v.co.y+=.018*t
 # Project the supraorbital ridge; preserve the recessed eye line.
 if y<-.14 and .235<z<.28:
  v.co.y-=.030
  v.co.z-=.004*(1-min(1,abs(x)/.2))
head.data.update()
# Layered sideburns and cheek/beard locks narrow the bare facial oval.
for side in [0,math.pi]:
 for i in range(12):
  angle=side+rng.uniform(-.67,.64)
  z=rng.uniform(.015,.35)
  tuft(5,z,angle,rng.uniform(.075,.135),rng.uniform(.017,.029),True)
# A broken hairline, swept crown and short chin fringe, no uniform furry helmet.
for z,a in [(.34,-.85),(.36,-1.25),(.355,-1.85),(.33,-2.25),(.425,.2),(.43,1.1),(.42,2.4),(.40,2.9),(.035,-.85),(.015,-2.2),(-.04,-1.35),(-.04,-1.9)]:
 tuft(5,z,a,rng.uniform(.055,.10),rng.uniform(.013,.024),True)
for id,(bm,layer,deform,group) in cache.items():
 bm.to_mesh(objects[id].data);bm.free();objects[id].data.update()
for o in objects.values():
 for v in o.data.vertices:assert abs(sum(g.weight for g in v.groups)-1)<1e-5
scene.frame_set(1);bpy.ops.object.select_all(action='DESELECT')
for o in work.objects:o.select_set(True)
bpy.context.view_layer.objects.active=rig
bpy.ops.export_scene.gltf(filepath=str(ROOT/'assets/models/zenscape-bigfoot-classic.glb'),export_format='GLB',use_selection=True,export_animations=True,export_animation_mode='ACTIONS',export_force_sampling=True,export_frame_range=False,export_anim_slide_to_zero=True,export_def_bones=True,export_skins=True)
report=dict(added_head_tufts=counts['fur_tufts'],mesh_objects=len(objects),faces=sum(len(o.data.polygons) for o in objects.values()),complete_skin_weights=True,rig_bones=len(rig.data.bones))
(ART/'classic-head-validation.json').write_text(json.dumps(report,indent=2)+'\n')
bpy.ops.object.select_all(action='DESELECT');rig.select_set(True)
scene.render.filepath=str(ART/'bigfoot-classic.png');bpy.ops.wm.save_as_mainfile(filepath=str(TARGET));bpy.ops.render.render(write_still=True)
cam=scene.camera;cam.location=(1.7,-4,2.85);cam.rotation_euler=(Vector((-.025,-.22,2.40))-cam.location).to_track_quat('-Z','Y').to_euler();cam.data.ortho_scale=1.18
scene.render.resolution_x=900;scene.render.resolution_y=900;scene.render.filepath=str(ART/'bigfoot-classic-face.png');bpy.ops.render.render(write_still=True)
print('CLASSIC_HEAD_VALIDATED',json.dumps(report))
