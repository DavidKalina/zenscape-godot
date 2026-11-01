"""The stomper's body (docs/design/endless-flight/spec-stomper.md): the archived
headless body cut down to one skinned mesh of about TARGET triangles and the
clips it plays, exported to assets/models/stomper_body.glb.

    python3 tools/blender.py run --blend art/blender/headless_body/headless_body.blend \
        art/blender/headless_body/reduce_stomper.py

    python3 art/blender/headless_body/bake_clips.py --clips=stomp --glb=assets/models/stomper_body.glb

The second line adds `stomp`, which the .blend predates; run it alone after
changing the clip. The .blend is read, never saved. Both surfaces are kept: the stone and the cut
stump top, so a head can still seat on it.
"""
import bpy

TARGET = 24000
KEEP = ("idle", "windup", "land")
GLB = "assets/models/stomper_body.glb"

body = bpy.data.objects["Body"]
rig = bpy.data.objects["HeadlessBodyRig"]

before = sum(len(p.vertices) - 2 for p in body.data.polygons)
bpy.context.view_layer.objects.active = body
body.select_set(True)
mod = body.modifiers.new("Reduce", "DECIMATE")
mod.decimate_type = "COLLAPSE"
mod.ratio = TARGET / before
mod.use_collapse_triangulate = True
bpy.ops.object.modifier_move_to_index(modifier="Reduce", index=0)
bpy.ops.object.modifier_apply(modifier="Reduce")
bpy.ops.object.mode_set(mode="OBJECT")
after = sum(len(p.vertices) - 2 for p in body.data.polygons)
print("REDUCED", before, "to", after, "verts", len(body.data.vertices))

for a in list(bpy.data.actions):
    if a.name not in KEEP:
        bpy.data.actions.remove(a)
print("CLIPS", sorted(a.name for a in bpy.data.actions))
if rig.animation_data is not None:
    rig.animation_data.action = None
for slot in rig.pose.bones:
    slot.location = (0, 0, 0)
    slot.rotation_quaternion = (1, 0, 0, 0)
    slot.rotation_euler = (0, 0, 0)
    slot.scale = (1, 1, 1)
for o in bpy.data.objects:
    o.select_set(o in (body, rig))
kw = dict(filepath=GLB, export_format="GLB", use_selection=True, export_animations=True,
    export_animation_mode="ACTIONS", export_skins=True, export_apply=False, export_yup=True,
    export_force_sampling=True, export_def_bones=False, export_frame_step=1, export_optimize_animation_size=True)
try:
    bpy.ops.export_scene.gltf(**kw, export_vertex_color="ACTIVE")
except TypeError:
    bpy.ops.export_scene.gltf(**kw, export_colors=True)
print("STOMPER_EXPORTED", GLB)
