"""Build the UI direction mockups headlessly (no windows open).

    python3 tools/ui_mockups/build.py [field-journal|lantern|toy-box|lantern-maker ...] [--job ...]

Writes glyph SVGs to docs/ui/glyphs/<direction>/ and PNGs to
docs/ui/mockups/<direction>/: <direction>-create.png and <direction>-mood.png
(1440x900 over real frames from captures/phase3-slices-2-5.mp4) and
<direction>-sheet.png (glyphs and states). Needs ffmpeg and Google Chrome
(run with --headless=new); fonts are fetched once into /tmp and never committed.
"""
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
import common  # noqa: E402
import field_journal  # noqa: E402
import lantern  # noqa: E402
import toy_box  # noqa: E402
import lantern_maker  # noqa: E402

DIRECTIONS = {m.NAME: m for m in (field_journal, lantern, toy_box, lantern_maker)}


def build(mod, bgs, only=None):
    common.write_glyphs(mod.NAME, mod.glyphs())
    out = os.path.join(common.MOCK_ROOT, mod.NAME)
    jobs = getattr(mod, "JOBS", None) or {"create": (mod.create_frame, 1440, 900), "mood": (mod.mood_frame, 1440, 900), "sheet": (mod.sheet, 1440, None)}
    for key, (fn, w, h) in jobs.items():
        if only and key not in only:
            continue
        html = fn(bgs)
        height = h or int(html.split("body{width:1440px;height:")[1].split("px")[0])
        path = common.render(html, os.path.join(out, f"{mod.NAME}-{key}.png"), w, height)
        print(path)


if __name__ == "__main__":
    common.fetch_fonts()
    bgs = common.extract_frames()
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    only = [a[2:] for a in sys.argv[1:] if a.startswith("--")]
    for name in args or DIRECTIONS:
        build(DIRECTIONS[name], bgs, only or None)
