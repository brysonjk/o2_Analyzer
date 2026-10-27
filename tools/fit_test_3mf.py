#!/usr/bin/env python3
"""Export the fit-test pieces as separate STLs and one 3MF with a named object per piece.

    python3 tools/fit_test_3mf.py        (needs openscad on the PATH and numpy-stl)

Writes stl/fit_test/<piece>.stl, stl/fit_test.3mf and stl/fit_test.stl (all pieces in one mesh).
In Bambu Studio / PrusaSlicer, open the 3MF and untick the pieces you don't want to print.
"""
import os, subprocess, sys, tempfile, zipfile
import numpy as np
from stl import mesh

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SCAD = os.path.join(ROOT, "o2_analyzer.scad")
# keep in sync with fit_pieces / fit_pos in o2_analyzer.scad
PIECES = [("seat", (-4, 0, 0)), ("sensor_seat", (52, 0, 0)), ("flange_ring", (88, 0, 0)),
          ("thread_male", (0, 50, 0)), ("thread_female", (42, 50, 0))]
only = sys.argv[1:]

outdir = os.path.join(ROOT, "stl", "fit_test")
os.makedirs(outdir, exist_ok=True)
meshes = []
for name, pos in PIECES:
    path = os.path.join(outdir, f"{name}.stl")
    if not only or name in only:
        with tempfile.TemporaryDirectory() as td:
            tmp = os.path.join(td, "p.stl")
            subprocess.run(["openscad", "-D", 'PART="fit_piece"', "-D", f'FIT="{name}"', "-o", tmp, SCAD],
                           check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            mesh.Mesh.from_file(tmp).save(path, mode=mesh.stl.Mode.BINARY)
        print("exported", name)
    m = mesh.Mesh.from_file(path)
    m.vectors = m.vectors + np.array(pos, dtype=float)
    meshes.append((name, m))

# one STL with everything (same layout as PART="fit_test")
allm = mesh.Mesh(np.concatenate([m.data for _, m in meshes]))
allm.save(os.path.join(ROOT, "stl", "fit_test.stl"), mode=mesh.stl.Mode.BINARY)

# 3MF: one object per piece, placed with build-item transforms
objs, items = [], []
for i, (name, m) in enumerate(meshes, start=1):
    v = m.vectors.reshape(-1, 3)
    uniq, inv = np.unique(np.round(v, 5), axis=0, return_inverse=True)
    c = (uniq.min(0) + uniq.max(0)) / 2
    c[2] = uniq[:, 2].min()
    uniq = uniq - c
    tri = inv.reshape(-1, 3)
    verts = "".join(f'<vertex x="{x:.5f}" y="{y:.5f}" z="{z:.5f}"/>' for x, y, z in uniq)
    tris = "".join(f'<triangle v1="{a}" v2="{b}" v3="{d}"/>' for a, b, d in tri)
    objs.append(f'<object id="{i}" name="fit_{name}" type="model"><mesh><vertices>{verts}</vertices>'
                f'<triangles>{tris}</triangles></mesh></object>')
    items.append(f'<item objectid="{i}" transform="1 0 0 0 1 0 0 0 1 {c[0]:.4f} {c[1]:.4f} {c[2]:.4f}"/>')
model = ('<?xml version="1.0" encoding="UTF-8"?>'
         '<model unit="millimeter" xml:lang="en-US" xmlns="http://schemas.microsoft.com/3dmanufacturing/core/2015/02">'
         f'<resources>{"".join(objs)}</resources><build>{"".join(items)}</build></model>')
with zipfile.ZipFile(os.path.join(ROOT, "stl", "fit_test.3mf"), "w", zipfile.ZIP_DEFLATED) as z:
    z.writestr("[Content_Types].xml", '<?xml version="1.0" encoding="UTF-8"?>'
               '<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">'
               '<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>'
               '<Default Extension="model" ContentType="application/vnd.ms-package.3dmanufacturing-3dmodel+xml"/></Types>')
    z.writestr("_rels/.rels", '<?xml version="1.0" encoding="UTF-8"?>'
               '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
               '<Relationship Target="/3D/3dmodel.model" Id="rel0" '
               'Type="http://schemas.microsoft.com/3dmanufacturing/2013/01/3dmodel"/></Relationships>')
    z.writestr("3D/3dmodel.model", model)
print("wrote stl/fit_test.3mf and stl/fit_test.stl")
