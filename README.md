# Shandon's Body Atlas

A high-fidelity proof-of-concept **layered 3D human body atlas**: a real
anatomical human model whose systems — skin, muscles, skeleton, organs,
circulation, nerves — can be toggled and faded as layers, orbited and zoomed
in 3D, with tap-to-identify on every individual structure (~3,200 named
anatomical structures).

Built with Flutter (one codebase for web + app), rendered by a small embedded
three.js viewer, with anatomy processed from the open-source
[Z-Anatomy](https://www.z-anatomy.com/) dataset through Blender.

## Run the demo

```bash
flutter run -d chrome --release
```

Layer switches and opacity sliders live in the right panel — ghost the skin
to ~35% over the organs and skeleton for the classic atlas view, then tap any
structure to identify it.

## Architecture

- `assets/viewer/viewer.html` — self-contained three.js scene (vendored
  three.js 0.185, no CDN): meshopt-compressed GLB loading, PBR + IBL
  lighting, orbit controls, raycast picking, per-layer visibility/opacity.
  Layers with hundreds of structures render as a single `BatchedMesh` draw
  call while every structure stays individually pickable.
- `lib/` — Flutter shell: layer panel, info card, attribution. Talks to the
  viewer over one JSON postMessage protocol
  (`lib/src/viewer/controller.dart`); web embeds an iframe
  (`viewer_web.dart`), mobile/desktop can reuse the identical HTML in a
  WebView later (`viewer_stub.dart`).
- `assets/models/` — one optimized GLB per anatomical layer + `atlas.json`
  (the manifest both sides read: layer specs, defaults, structure
  descriptions, attribution).

## Asset pipeline (reproducible)

1. Download `Z-Anatomy.zip` (Blender application template) from
   https://github.com/Z-Anatomy/Models-of-human-anatomy and unzip.
2. Export the six layer GLBs (converts vessel/nerve curves to meshes, strips
   label text and landmark overlays, flattens the node-group shaders the glTF
   exporter cannot handle, bakes tissue colors):

   ```bash
   blender --background Startup.blend --python tool/blender_export.py -- /tmp/atlas-staging --thumbnails
   ```

3. Optimize into the app (weld + selective simplify + meshopt; drops the
   one-sided fascia sheets; never join/flatten — every structure must stay a
   named node for picking):

   ```bash
   cd tool && npm install && node optimize_models.mjs /tmp/atlas-staging ../assets/models
   ```

## Tests

```bash
flutter test   # protocol contract, name-prettifier properties, panel behavior
```

## Licensing & attribution

Model data derives from **Z-Anatomy — The libre 3D atlas of anatomy**
(CC-BY-SA 4.0), itself derived from **BodyParts3D**, © The Database Center
for Life Science (CC-BY 4.0 per the current DBCLS archive; historically
CC-BY-SA 2.1 JP). The exported GLBs in `assets/models/` therefore remain
**CC-BY-SA 4.0** and the app displays attribution in the panel footer.

Known caveats before any commercial redistribution:

- Z-Anatomy credits an inner-ear model (University of Dundee, CC-BY-NC-SA)
  — the recognizable detailed inner-ear meshes are excluded from export
  (`NC_RE` in `tool/blender_export.py`), and a kidney model (Lissie Cowley,
  CC-BY-NC) — the displayed `Kidney L/R` meshes appear to be
  BodyParts3D-derived, but provenance is not machine-verifiable; swap in
  kidneys from BodyParts3D or the CC-BY HuBMAP Human Reference Atlas if
  certainty is required.
- Code in this repository is original; Z-Anatomy's GPL Blender add-ons are
  not used or bundled.
