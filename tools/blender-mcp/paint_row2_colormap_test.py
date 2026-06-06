# Run inside Blender: Scripting workspace -> Open this file -> Run Script
# Paints a visible shirt-color test on each row-2 body colormap.

import bpy
from collections import Counter

ROW2_COL = "Packtory Characters Row 2"

TEST_COLORS = [
    (0.95, 0.20, 0.25, 1.0),
    (0.98, 0.55, 0.10, 1.0),
    (0.98, 0.90, 0.15, 1.0),
    (0.25, 0.85, 0.35, 1.0),
    (0.20, 0.75, 0.95, 1.0),
    (0.30, 0.45, 0.95, 1.0),
    (0.65, 0.35, 0.95, 1.0),
    (0.95, 0.35, 0.75, 1.0),
    (0.55, 0.30, 0.18, 1.0),
    (0.15, 0.80, 0.70, 1.0),
    (0.85, 0.85, 0.20, 1.0),
    (0.80, 0.25, 0.55, 1.0),
    (0.40, 0.40, 0.45, 1.0),
]


def quantize(r, g, b, step=0.08):
    return (
        round(r / step) * step,
        round(g / step) * step,
        round(b / step) * step,
    )


def find_shirt_swatch(img):
    px = img.pixels
    counts = Counter()
    for i in range(0, len(px), 4):
        r, g, b, a = px[i], px[i + 1], px[i + 2], px[i + 3]
        if a < 0.5:
            continue
        v = max(r, g, b)
        s = v - min(r, g, b)
        if v < 0.12 or v > 0.98 or s < 0.08:
            continue
        counts[quantize(r, g, b)] += 1
    if not counts:
        return None
    return counts.most_common(1)[0][0]


def paint_swatch(img, src, dst, tolerance=0.12):
    px = list(img.pixels)
    sr, sg, sb = src
    dr, dg, db, da = dst
    changed = 0
    for i in range(0, len(px), 4):
        r, g, b, a = px[i], px[i + 1], px[i + 2], px[i + 3]
        if a < 0.01:
            continue
        if abs(r - sr) + abs(g - sg) + abs(b - sb) <= tolerance:
            px[i], px[i + 1], px[i + 2], px[i + 3] = dr, dg, db, da
            changed += 1
    img.pixels = px
    img.update()
    return changed


def paint_corner_mark(img, color, size=4):
    w, h = img.size
    px = list(img.pixels)
    x0, y0 = w - size - 1, h - size - 1
    for y in range(y0, h):
        for x in range(x0, w):
            i = (y * w + x) * 4
            px[i : i + 4] = color
    img.pixels = px
    img.update()


def main():
    col = bpy.data.collections.get(ROW2_COL)
    if col is None:
        raise RuntimeError("Missing collection: %s" % ROW2_COL)

    armatures = sorted(
        [o for o in col.objects if o.type == "ARMATURE"],
        key=lambda o: o.location.x,
    )

    seen = set()
    for idx, arm in enumerate(armatures):
        char_id = arm.name.replace("_row2", "")
        test_color = TEST_COLORS[idx % len(TEST_COLORS)]
        for child in arm.children:
            if child.type != "MESH" or "body" not in child.name.lower():
                continue
            if not child.data.materials:
                continue
            mat = child.data.materials[0]
            img = None
            if mat and mat.node_tree:
                for node in mat.node_tree.nodes:
                    if node.type == "TEX_IMAGE" and node.image:
                        img = node.image
                        break
            if img is None or img.name in seen:
                continue
            seen.add(img.name)
            swatch = find_shirt_swatch(img)
            painted = paint_swatch(img, swatch, test_color) if swatch else 0
            paint_corner_mark(img, (1.0, 1.0, 1.0, 1.0))
            print("%s: %s painted %d pixels -> %s" % (char_id, img.name, painted, test_color[:3]))

    for area in bpy.context.screen.areas:
        if area.type == "VIEW_3D":
            area.tag_redraw()
    print("Done. Row-2 shirts should show unique colors; white mark in atlas corner.")


main()
