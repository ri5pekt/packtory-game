#!/usr/bin/env python3
"""Remove baked Kenney hearing-aid geometry from character GLB body meshes."""

from __future__ import annotations

import argparse
import array
import json
import os
import struct
import sys

import numpy as np
import trimesh
from trimesh import graph

# Hearing aids are 16-triangle islands parented near the wrists in bind pose.
_AID_FACE_COUNT = 16
_MIN_ABS_X = 0.06
_MAX_Y = 0.33
_MIN_Y = 0.045
_MAX_ABS_Z = 0.09

CHARACTER_DIR = os.path.join(
    os.path.dirname(__file__),
    "..",
    "blender",
    "assets",
    "kenney_mini-characters",
    "Models",
    "GLB format",
)

_COMPONENT_TYPE_TO_ARRAY = {
    5121: "B",
    5123: "H",
    5125: "I",
}


def _faces_to_remove(geom: trimesh.Trimesh) -> set[int]:
    remove: set[int] = set()
    for comp in graph.connected_components(geom.face_adjacency, min_len=1):
        if len(comp) != _AID_FACE_COUNT:
            continue
        center = geom.triangles_center[comp].mean(axis=0)
        ax = abs(center[0])
        ay = float(center[1])
        az = abs(center[2])
        if ax < _MIN_ABS_X or ay < _MIN_Y or ay > _MAX_Y or az > _MAX_ABS_Z:
            continue
        remove.update(int(i) for i in comp)
    return remove


def _read_glb(path: str) -> tuple[dict, bytearray]:
    with open(path, "rb") as f:
        magic, version, length = struct.unpack("<4sII", f.read(12))
        if magic != b"glTF":
            raise ValueError(f"not glTF: {path}")
        json_len, json_type = struct.unpack("<I4s", f.read(8))
        if json_type != b"JSON":
            raise ValueError(f"expected JSON chunk: {path}")
        gltf = json.loads(f.read(json_len))
        bin_len, bin_type = struct.unpack("<I4s", f.read(8))
        if bin_type != b"BIN\x00":
            raise ValueError(f"expected BIN chunk: {path}")
        bin_data = bytearray(f.read(bin_len))
    return gltf, bin_data


def _write_glb(path: str, gltf: dict, bin_data: bytearray) -> None:
    json_bytes = json.dumps(gltf, separators=(",", ":")).encode("utf-8")
    json_pad = (4 - len(json_bytes) % 4) % 4
    json_bytes += b" " * json_pad
    bin_pad = (4 - len(bin_data) % 4) % 4
    bin_data.extend(b"\x00" * bin_pad)
    total = 12 + 8 + len(json_bytes) + 8 + len(bin_data)
    with open(path, "wb") as f:
        f.write(struct.pack("<4sII", b"glTF", 2, total))
        f.write(struct.pack("<I4s", len(json_bytes), b"JSON"))
        f.write(json_bytes)
        f.write(struct.pack("<I4s", len(bin_data), b"BIN\x00"))
        f.write(bin_data)


def _read_indices(gltf: dict, bin_data: bytearray, accessor_index: int) -> np.ndarray:
    acc = gltf["accessors"][accessor_index]
    bv = gltf["bufferViews"][acc["bufferView"]]
    start = bv.get("byteOffset", 0) + acc.get("byteOffset", 0)
    count = acc["count"]
    comp = _COMPONENT_TYPE_TO_ARRAY[acc["componentType"]]
    typecode = array.array(comp)
    size = typecode.itemsize
    typecode.frombytes(bin_data[start : start + count * size])
    return np.asarray(typecode, dtype=np.uint32)


def _write_indices(
    gltf: dict,
    bin_data: bytearray,
    accessor_index: int,
    indices: np.ndarray,
) -> None:
    acc = gltf["accessors"][accessor_index]
    bv_index = acc["bufferView"]
    bv = gltf["bufferViews"][bv_index]
    comp = acc["componentType"]
    typecode = array.array(_COMPONENT_TYPE_TO_ARRAY[comp])
    for value in indices.astype(np.uint32).tolist():
        typecode.append(int(value))
    start = bv.get("byteOffset", 0) + acc.get("byteOffset", 0)
    new_bytes = typecode.tobytes()
    end = start + bv["byteLength"]
    bin_data[start:end] = new_bytes + b"\x00" * (end - start - len(new_bytes))
    acc["count"] = len(indices)
    bv["byteLength"] = len(new_bytes)
    acc["max"] = [int(indices.max())]
    acc["min"] = [int(indices.min())]


def _strip_body_indices(gltf: dict, bin_data: bytearray, remove_faces: set[int]) -> int:
    body_mesh = next(m for m in gltf["meshes"] if m.get("name") == "body-mesh")
    prim = body_mesh["primitives"][0]
    accessor_index = prim["indices"]
    indices = _read_indices(gltf, bin_data, accessor_index)
    faces = indices.reshape(-1, 3)
    keep_mask = np.array([i not in remove_faces for i in range(len(faces))], dtype=bool)
    new_faces = faces[keep_mask]
    _write_indices(gltf, bin_data, accessor_index, new_faces.reshape(-1))
    return len(faces) - len(new_faces)


def process_glb(path: str, dry_run: bool) -> None:
    scene = trimesh.load(path, force="scene")
    if "body-mesh" not in scene.geometry:
        return
    remove_faces = _faces_to_remove(scene.geometry["body-mesh"])
    if not remove_faces:
        return
    gltf, bin_data = _read_glb(path)
    removed_tris = _strip_body_indices(gltf, bin_data, remove_faces)
    print(
        f"{os.path.basename(path)}: removed {len(remove_faces)} triangles "
        f"({removed_tris} tri(s))"
    )
    if not dry_run:
        _write_glb(path, gltf, bin_data)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--dry-run", action="store_true")
    parser.add_argument("--dir", default=CHARACTER_DIR)
    parser.add_argument(
        "--also-assets",
        action="store_true",
        help="Also process assets/kenney/mini-characters/*.glb",
    )
    args = parser.parse_args()
    dirs = [os.path.abspath(args.dir)]
    if args.also_assets:
        dirs.append(
            os.path.abspath(
                os.path.join(os.path.dirname(__file__), "..", "assets", "kenney", "mini-characters")
            )
        )
    for char_dir in dirs:
        if not os.path.isdir(char_dir):
            continue
        for name in sorted(os.listdir(char_dir)):
            if not name.startswith("character-") or not name.endswith(".glb"):
                continue
            process_glb(os.path.join(char_dir, name), args.dry_run)
    return 0


if __name__ == "__main__":
    sys.exit(main())
