#!/usr/bin/env python3
"""A top-down picture of a box of the land with every named site marked.

python tools/site_map.py [--box x0,z0,x1,z1] [--step M] [--out FILE.png] [--px N]
                         [--kinds arch,hall,...] [--from-json FILE] [-- scene args]

Runs tools/harness/site_dump.gd headless (the plans themselves, no chunks
built), then draws shaded land, the sea, and each arch, hall, tunnel, split,
sea stack, pond, Peak part, door and find with its name. Every site's numbers
are in the JSON beside the picture (FILE.json), to look one up by name. x runs
right, z down, as seen from above with -z (the start's heading) up. Needs PIL
and numpy.
"""
import argparse, json, math, os, subprocess, sys
from PIL import Image, ImageDraw, ImageFont
import numpy as np

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
STYLE = {  # kind: (colour, shape)
    "start": ((255, 255, 255), "star"), "door": ((255, 90, 200), "star"), "find": ((255, 225, 60), "star"),
    "arch": ((255, 140, 40), "tri"), "hall": ((230, 60, 60), "box"), "tunnel": ((180, 80, 255), "box"),
    "split": ((60, 220, 220), "box"), "stacks": ((90, 200, 255), "dot"), "pond": ((70, 130, 255), "dot"),
    "peak": ((255, 255, 255), "dot"), "valley": ((210, 210, 170), "dot"), "boulders": ((210, 210, 170), "dot"),
}
ORDER = ["start", "door", "find", "peak", "tunnel", "split", "hall", "stacks", "valley", "boulders", "arch", "pond"]
DROP = ("endless/", "rock/")


def shade(data):
    nx, nz, sea, step = data["nx"], data["nz"], data["sea"], data["step"]
    h = np.array(data["heights"], dtype=np.float32).reshape(nz, nx)
    gz, gx = np.gradient(h, step)
    n = np.dstack((-gx, -gz, np.ones_like(h)))
    n /= np.linalg.norm(n, axis=2, keepdims=True)
    lit = np.clip((n @ np.array([-0.5, -0.6, 0.62])) * 0.9 + 0.2, 0.15, 1.1)
    t = np.clip((h - sea) / 300.0, 0, 1)[..., None]
    rgb = (np.array([104, 128, 80.0]) * (1 - t) + np.array([190, 180, 165.0]) * t) * lit[..., None]
    deep = np.clip((sea - h) / 40.0, 0, 1)[..., None]
    water = np.array([62, 110, 150.0]) * (1 - deep) + np.array([24, 52, 88.0]) * deep
    rgb = np.where((h <= sea)[..., None], water, rgb)
    return np.clip(rgb, 0, 255).astype(np.uint8)


def draw_map(data, out, px, kinds):
    x0, z0, x1, z1 = data["box"]
    scale = px / max(x1 - x0, z1 - z0)
    size = (int((x1 - x0) * scale), int((z1 - z0) * scale))
    img = Image.fromarray(shade(data)).resize(size, Image.BILINEAR)
    d = ImageDraw.Draw(img)
    try:
        font = ImageFont.truetype("arial.ttf", 12)
    except OSError:
        font = ImageFont.load_default()
    to = lambda x, z: ((x - x0) * scale, (z - z0) * scale)
    grid = 1000.0
    v = math.ceil(x0 / grid) * grid
    while v <= x1:
        d.line([to(v, z0), to(v, z1)], fill=(120, 120, 120), width=1)
        d.text((to(v, z0)[0] + 2, 2), "x%d" % v, fill=(235, 235, 235), font=font)
        v += grid
    v = math.ceil(z0 / grid) * grid
    while v <= z1:
        d.line([to(x0, v), to(x1, v)], fill=(120, 120, 120), width=1)
        d.text((2, to(x0, v)[1] + 2), "z%d" % v, fill=(235, 235, 235), font=font)
        v += grid
    taken = []

    def free(box):
        return not any(box[0] < b[2] and box[2] > b[0] and box[1] < b[3] and box[3] > b[1] for b in taken)

    rank = lambda s: ORDER.index(s["kind"]) if s["kind"] in ORDER else 99
    sites = sorted([s for s in data["sites"] if not kinds or s["kind"] in kinds], key=rank)
    for s in sites:  # Marks first, so a label never hides one.
        col, shape = STYLE.get(s["kind"], ((220, 220, 220), "dot"))
        sx, sz = to(s["x"], s["z"])
        if "path" in s:
            d.line([to(*p) for p in s["path"]] + [to(*s["mouth_b"])], fill=col, width=3)
        if "way" in s and "half_len" in s:
            w, hl = s["way"], s["half_len"]
            d.line([to(s["x"] - w[0] * hl, s["z"] - w[1] * hl), to(s["x"] + w[0] * hl, s["z"] + w[1] * hl)], fill=col, width=4)
        if s.get("radius"):
            r = s["radius"] * scale
            d.ellipse([sx - r, sz - r, sx + r, sz + r], outline=col)
        r = 5 if shape == "star" else 4
        edge = (0, 0, 0)
        if shape == "box":
            d.rectangle([sx - r, sz - r, sx + r, sz + r], fill=col, outline=edge)
        elif shape == "tri":
            d.polygon([(sx, sz - r - 1), (sx - r, sz + r), (sx + r, sz + r)], fill=col, outline=edge)
        elif shape == "star":
            d.polygon([(sx, sz - r - 3), (sx + r, sz), (sx, sz + r + 3), (sx - r, sz)], fill=col, outline=edge)
        else:
            d.ellipse([sx - r, sz - r, sx + r, sz + r], fill=col, outline=edge)
        taken.append((sx - r, sz - r, sx + r, sz + r))
    missed = 0
    for s in sites:
        col = STYLE.get(s["kind"], ((220, 220, 220), "dot"))[0]
        label = s["name"]
        for p in DROP:
            label = label.replace(p, "")
        sx, sz = to(s["x"], s["z"])
        w = d.textlength(label, font=font)
        for ox, oy in ((7, -7), (7, 6), (-7 - w, -7), (-7 - w, 6), (-w / 2, -21), (-w / 2, 9), (18, -18), (18, 16), (-w - 18, -18), (-w - 18, 16)):
            box = (sx + ox, sz + oy, sx + ox + w, sz + oy + 13)
            if free(box):
                taken.append(box)
                d.text((box[0], box[1]), label, fill=col, font=font, stroke_width=2, stroke_fill=(0, 0, 0))
                break
        else:
            missed += 1
    y = 22
    for k in ORDER:
        n = sum(1 for s in sites if s["kind"] == k)
        if n:
            d.text((size[0] - 150, y), "%s  %d" % (k, n), fill=STYLE[k][0], font=font, stroke_width=2, stroke_fill=(0, 0, 0))
            y += 16
    img.save(out)
    return missed


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--box", default="-1500,-1500,1500,1500", help="x0,z0,x1,z1 (world m)")
    ap.add_argument("--step", type=float, default=0.0, help="height sample spacing (m); default fits the picture")
    ap.add_argument("--px", type=int, default=2000, help="the picture's long side")
    ap.add_argument("--out", default="scratch/site_map.png")
    ap.add_argument("--kinds", default="", help="only these, comma separated")
    ap.add_argument("--from-json", default="", help="redraw from a saved JSON, no Godot")
    args, rest = ap.parse_known_args()
    if rest[:1] == ["--"]:
        rest = rest[1:]
    jpath = args.from_json or os.path.splitext(args.out)[0] + ".json"
    os.makedirs(os.path.dirname(os.path.abspath(args.out)), exist_ok=True)
    if not args.from_json:
        box = [float(v) for v in args.box.split(",")]
        step = args.step or max(max(box[2] - box[0], box[3] - box[1]) / 700.0, 2.0)
        cmd = [sys.executable, os.path.join(ROOT, "tools", "drive.py"), "tools/harness/site_dump.gd", "--",
               "--box=" + args.box, "--step=%g" % step, "--out=" + os.path.abspath(jpath).replace("\\", "/"), "--timeout=480"]
        if rest:
            cmd += ["--scene-args"] + rest
        r = subprocess.run(cmd, cwd=ROOT)
        if r.returncode != 0:
            sys.exit(r.returncode)
    with open(jpath) as f:
        data = json.load(f)
    missed = draw_map(data, args.out, args.px, [k for k in args.kinds.split(",") if k])
    # One line a site, heights left out: the file to read and to keep.
    with open(os.path.splitext(args.out)[0] + ".sites.json", "w") as f:
        f.write("[\n" + ",\n".join(json.dumps(s, separators=(",", ":")) for s in sorted(data["sites"], key=lambda s: s["name"])) + "\n]\n")
    counts = {}
    for s in data["sites"]:
        counts[s["kind"]] = counts.get(s["kind"], 0) + 1
    print("site_map: %s  %s  (%d unlabelled)" % (args.out, counts, missed))


if __name__ == "__main__":
    main()
