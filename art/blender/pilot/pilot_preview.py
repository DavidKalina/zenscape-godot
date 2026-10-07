"""Stills of the pilot's clips for checking by eye (tests/test_pilot_figure.gd
measures the planted boots in the game).

    /opt/homebrew/bin/blender -b art/blender/pilot/pilot.blend --python art/blender/pilot/pilot_preview.py -- [OUT_DIR] [CLIP ...]

Writes OUT_DIR/<clip>_<view>_<frame>.png (default /tmp/pilot_preview): about
ten stills through each of walk, run and skid, the idle once a second
through its length, the ledge's clips against a block standing for the lip, and the model up close in its rest pose
(model_<view>_000.png, to compare builds by). CLIP names limit it to those clips (`model` for
the close-ups). Tile them with ffmpeg.
"""
import sys
from pathlib import Path

import bpy
from mathutils import Vector

args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
OUT = Path(args[0] if args else "/tmp/pilot_preview")
ONLY = set(args[1:])
OUT.mkdir(parents=True, exist_ok=True)
scene = bpy.context.scene
rig = bpy.data.objects["PilotRig"]
for track in rig.animation_data.nla_tracks:
    track.mute = True

scene.render.engine = "BLENDER_WORKBENCH"
scene.display.shading.light = "STUDIO"
scene.display.shading.color_type = "MATERIAL"
scene.display.shading.show_shadows = True
scene.render.film_transparent = False
scene.world = bpy.data.worlds.new("w") if scene.world is None else scene.world
scene.world.color = (0.55, 0.62, 0.7)

bpy.ops.mesh.primitive_plane_add(size=6)
ground = bpy.context.object
ground.data.materials.append(bpy.data.materials.new("ground"))
ground.data.materials[0].diffuse_color = (0.35, 0.42, 0.3, 1)

cam_data = bpy.data.cameras.new("cam")
cam_data.type = "ORTHO"
cam = bpy.data.objects.new("cam", cam_data)
scene.collection.objects.link(cam)
scene.camera = cam
# Where each view stands, what it looks at, and how much it takes in (m).
VIEWS = {
    "side": (Vector((3.0, 0.0, 0.55)), Vector((0, 0, 0.55)), 1.35),
    "front": (Vector((0.0, 3.0, 0.55)), Vector((0, 0, 0.55)), 1.35),
    "three": (Vector((2.2, 2.0, 1.3)), Vector((0, 0, 0.55)), 1.35),
    "back": (Vector((-1.6, -2.6, 1.0)), Vector((0, 0, 0.55)), 1.35),
    "closethree": (Vector((1.9, 2.3, 1.2)), Vector((0, 0, 0.57)), 1.25),
    "closefront": (Vector((0.0, 3.0, 0.57)), Vector((0, 0, 0.57)), 1.25),
    "closeside": (Vector((3.0, 0.0, 0.57)), Vector((0, 0, 0.57)), 1.25),
}

def aim(view):
    at, look, scale = VIEWS[view]
    cam.location = at
    cam.rotation_euler = (look - at).to_track_quat("-Z", "Y").to_euler()
    cam_data.ortho_scale = scale

def render(clip, frames, views, name=None, size=(360, 480)):
    """Stills of `clip` (None: the rest pose)."""
    if clip is not None and clip not in bpy.data.actions:
        print("PREVIEW no clip", clip)
        return
    scene.render.resolution_x, scene.render.resolution_y = size
    rig.animation_data.action = bpy.data.actions[clip] if clip else None
    for pb in rig.pose.bones:
        pb.location = (0, 0, 0)
        pb.rotation_quaternion = (1, 0, 0, 0)
    for f in frames:
        scene.frame_set(f)
        for v in views:
            aim(v)
            scene.render.filepath = str(OUT / f"{name or clip}_{v}_{f:03d}.png")
            bpy.ops.render.render(write_still=True)

def last(clip):
    return int(bpy.data.actions[clip].frame_range[1]) if clip in bpy.data.actions else 0

def wanted(clip):
    return not ONLY or clip in ONLY

if wanted("model"):
    render(None, [0], ["closethree", "closefront", "closeside", "back"], name="model", size=(720, 960))
if wanted("walk"):
    render("walk", range(0, last("walk"), 3), ["side", "three"])
if wanted("run"):
    render("run", range(0, last("run"), 2), ["side", "three", "front"])
if wanted("skid"):
    render("skid", range(0, last("skid"), 3), ["side", "three", "front", "back"])
# The ledge clips against a block standing for the lip: its edge HANG_OUT
# ahead of the feet, its top HANG_DROP over them; no ground under the hang.
LEDGE = ("hang", "shimmy_left", "shimmy_right", "climb")
if any(wanted(c) for c in LEDGE) and "HANG_DROP" in rig:
    drop, out = rig["HANG_DROP"], rig["HANG_OUT"]
    bpy.ops.mesh.primitive_cube_add(size=1)
    block = bpy.context.object
    block.scale = (1.6, 1.0, 1.4)
    block.location = (0, out + 0.5, drop - 0.7)
    block.data.materials.append(bpy.data.materials.new("rock"))
    block.data.materials[0].diffuse_color = (0.45, 0.42, 0.38, 1)
    ground.hide_render = True
    for v, (at, look, scale) in list(VIEWS.items()):
        VIEWS["ledge" + v] = (at + Vector((0, 0, 0.4)), look + Vector((0, 0, 0.4)), scale + 0.3)
    VIEWS["ledgeback"] = (Vector((0.6, -2.6, 1.3)), Vector((0, 0.1, 0.75)), 1.6)
    VIEWS["ledgebackthree"] = (Vector((-1.9, -2.0, 1.7)), Vector((0, 0.1, 0.8)), 1.7)
    VIEWS["climbside"] = (Vector((3.0, 0.3, 1.0)), Vector((0, 0.3, 1.0)), 2.1)
    VIEWS["climbthree"] = (Vector((-2.2, -1.6, 2.0)), Vector((0, 0.3, 1.0)), 2.1)
    if wanted("hang"):
        render("hang", range(0, last("hang"), 60), ["ledgeside", "ledgeback", "ledgebackthree"])
    for c in ("shimmy_left", "shimmy_right"):
        if wanted(c):
            render(c, range(0, last(c), 5), ["ledgeback", "ledgebackthree"])
    if wanted("climb"):
        render("climb", range(0, last("climb") + 1, 4), ["climbside", "climbthree"])
    block.hide_render = True
    ground.hide_render = False
if wanted("idle"):
    render("idle", range(0, last("idle"), 60), ["three", "front"])
