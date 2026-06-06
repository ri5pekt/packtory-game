# Analyze Kenney body colormap: which atlas colors = clothes vs skin.
# Run in Blender with ONE character selected (body-mesh), or picks row-1 female-a.
# Writes report + palette PNG to tools/blender-mcp/debug/

import bpy
import colorsys
import os
from collections import Counter, defaultdict

OUT_DIR = r"C:\Users\denis\Desktop\godot-projects\packtory-game\tools\blender-mcp\debug"


def quantize(r, g, b, step=0.04):
    return (
        round(r / step) * step,
        round(g / step) * step,
        round(b / step) * step,
    )


def hsv_label(r, g, b):
    h, s, v = colorsys.rgb_to_hsv(r, g, b)
    return h, s, v


def classify(r, g, b):
    h, s, v = hsv_label(r, g, b)
    if v > 0.92 and s < 0.12:
        return "neutral"  # white shoes, highlights
    if v < 0.12:
        return "neutral"
    if 0.03 <= h <= 0.14 and s < 0.55 and 0.30 <= v <= 0.92:
        return "skin"  # tan / brown skin on body hands
    if s < 0.10 and v < 0.85:
        return "neutral"  # grey
    return "garment"  # shirt, pants, shoes (colored)


def get_image_from_mesh(obj):
    if not obj.data.materials:
        return None, None
    mat = obj.data.materials[0]
    if not mat or not mat.node_tree:
        return mat, None
    for node in mat.node_tree.nodes:
        if node.type == "TEX_IMAGE" and node.image:
            return mat, node.image
    return mat, None


def sample_uv_colors(obj, img):
    mesh = obj.data
    if not mesh.uv_layers.active:
        return Counter()
    uv_layer = mesh.uv_layers.active.data
    w, h = img.size
    px = img.pixels
    counts = Counter()
    for poly in mesh.polygons:
        for loop_idx in poly.loop_indices:
            uv = uv_layer[loop_idx].uv
            x = int(uv.x * w) % w
            y = int(uv.y * h) % h
            i = (y * w + x) * 4
            r, g, b, a = px[i], px[i + 1], px[i + 2], px[i + 3]
            if a < 0.5:
                continue
            key = quantize(r, g, b)
            counts[key] += 1
    return counts


def image_palette(img):
    counts = Counter()
    w, h = img.size
    px = img.pixels
    for y in range(h):
        for x in range(w):
            i = (y * w + x) * 4
            r, g, b, a = px[i], px[i + 1], px[i + 2], px[i + 3]
            if a < 0.5:
                continue
            counts[quantize(r, g, b)] += 1
    return counts


def find_test_body():
    obj = bpy.context.active_object
    if obj and obj.type == "MESH" and "body" in obj.name.lower():
        return obj
    arm = bpy.data.objects.get("character-female-a")
    if arm:
        for c in arm.children:
            if c.type == "MESH" and "body" in c.name.lower():
                return c
    return None


def save_palette_png(img, path):
    import array

    w, h = img.size
    out = bpy.data.images.new("_palette_debug", width=w * 8, height=h, alpha=False)
    px = list(img.pixels)
    palette = sorted(image_palette(img).items(), key=lambda x: -x[1])
    out_px = [0.0] * (w * 8 * h * 4)
    for y in range(h):
        for x in range(w):
            i = (y * w + x) * 4
            r, g, b = px[i], px[i + 1], px[i + 2]
            kind = classify(r, g, b)
            marker = 1.0 if kind == "garment" else 0.3 if kind == "skin" else 0.15
            for dx in range(w * 8):
                oi = (y * w * 8 + dx) * 4
                if dx < w:
                    out_px[oi : oi + 3] = [r, g, b]
                elif dx < w * 2:
                    c = marker
                    out_px[oi : oi + 3] = [c, c, c]
                elif dx < w * 3:
                    if kind == "garment":
                        out_px[oi : oi + 3] = [1, 0, 0]
                    elif kind == "skin":
                        out_px[oi : oi + 3] = [0, 1, 0]
                    else:
                        out_px[oi : oi + 3] = [0.5, 0.5, 0.5]
                out_px[oi + 3] = 1.0
    out.pixels = out_px
    out.filepath_raw = path
    out.file_format = "PNG"
    out.save()
    bpy.data.images.remove(out)


def main():
    os.makedirs(OUT_DIR, exist_ok=True)
    body = find_test_body()
    if not body:
        raise RuntimeError("Select a body-mesh or open character-female-a")

    mat, img = get_image_from_mesh(body)
    if not img:
        raise RuntimeError("No image on body material")

    tex_palette = image_palette(img)
    uv_usage = sample_uv_colors(body, img)

    lines = []
    lines.append("Body mesh: %s" % body.name)
    lines.append("Image: %s (%dx%d)" % (img.name, img.size[0], img.size[1]))
    lines.append("")
    lines.append("Atlas colors (pixel count | UV face samples | class | RGB | HSV):")
    lines.append("-" * 72)

    all_keys = set(tex_palette.keys()) | set(uv_usage.keys())
    for key in sorted(all_keys, key=lambda k: (-tex_palette.get(k, 0), -uv_usage.get(k, 0))):
        r, g, b = key
        kind = classify(r, g, b)
        h, s, v = hsv_label(r, g, b)
        lines.append(
            "%3d px | %5d uv | %-8s | (%.2f,%.2f,%.2f) | h=%.2f s=%.2f v=%.2f"
            % (tex_palette.get(key, 0), uv_usage.get(key, 0), kind, r, g, b, h, s, v)
        )

    report_path = os.path.join(OUT_DIR, "colormap_analysis.txt")
    png_path = os.path.join(OUT_DIR, "colormap_palette_debug.png")
    with open(report_path, "w", encoding="utf-8") as f:
        f.write("\n".join(lines))

    save_palette_png(img, png_path)

    print("\n".join(lines))
    print("\nWrote:", report_path)
    print("Wrote:", png_path)
    print("Legend PNG: original | brightness | RED=garment GREEN=skin GREY=neutral")


main()
