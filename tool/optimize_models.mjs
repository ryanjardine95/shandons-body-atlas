/**
 * Optimize per-layer GLBs exported from Blender into web-ready assets.
 *
 * Pipeline per file: dedup -> prune -> weld -> simplify (meshopt) -> meshopt compression.
 * Deliberately NO join/flatten: every anatomical structure must stay an
 * individually named node so tap-to-identify keeps working.
 *
 * Usage: node optimize_models.mjs <staging-dir> <output-dir>
 */
import { NodeIO } from '@gltf-transform/core';
import { ALL_EXTENSIONS } from '@gltf-transform/extensions';
import { dedup, prune, weld, simplifyPrimitive, meshopt } from '@gltf-transform/functions';
import { MeshoptSimplifier, MeshoptEncoder } from 'meshoptimizer';
import { readdirSync, statSync, mkdirSync } from 'node:fs';
import { join, basename } from 'node:path';

// Simplification floor per layer (fraction of triangles kept). The error bound
// is the real quality gate; ratio stops runaway reduction on hero layers.
const RATIOS = {
  skin: 0.3,
  muscles: 0.4,
  skeleton: 0.4,
  organs: 0.45,
  vessels: 0.5,
  nerves: 0.5,
};
const SIMPLIFY_ERROR = 0.001;

const [stagingDir, outDir] = process.argv.slice(2);
if (!stagingDir || !outDir) {
  console.error('usage: node optimize_models.mjs <staging-dir> <output-dir>');
  process.exit(1);
}
mkdirSync(outDir, { recursive: true });

const io = new NodeIO().registerExtensions(ALL_EXTENSIONS).registerDependencies({
  'meshopt.encoder': MeshoptEncoder,
});
await MeshoptEncoder.ready;
await MeshoptSimplifier.ready;

const files = readdirSync(stagingDir).filter((f) => f.endsWith('.glb'));
if (files.length === 0) {
  console.error(`no .glb files in ${stagingDir}`);
  process.exit(1);
}

for (const file of files) {
  const id = basename(file, '.glb');
  const inPath = join(stagingDir, file);
  const outPath = join(outDir, file);
  const inSize = statSync(inPath).size;
  const doc = await io.read(inPath);

  const named = () =>
    doc.getRoot().listNodes().filter((n) => n.getMesh() && n.getName()).length;
  const namedBefore = named();

  // three.js GLTFLoader strips dots from node names, so move Blender's
  // `.l`/`.r` laterality (and dedup counters) to a dot-free convention.
  // Fascia sheets are dropped: Z-Anatomy models them on one body half only,
  // which reads as a broken asymmetric shell over the musculature.
  const EXCLUDE = /fascia/i;
  const renameNodes = (document) => {
    for (const node of document.getRoot().listNodes()) {
      const name = node.getName();
      if (!name) continue;
      if (EXCLUDE.test(name)) {
        node.setMesh(null);
        continue;
      }
      node.setName(
        name
          .trim()
          .replace(/\.\d+$/, '')
          .replace(/\.l$/, ' L')
          .replace(/\.r$/, ' R'),
      );
    }
  };

  // Simplify only meshes with real triangle budgets: collapsing tiny
  // structures (small vessels, lymph nodes, facial regions) to zero triangles
  // makes prune() delete them, losing anatomy.
  const SIMPLIFY_MIN_TRIANGLES = 600;
  const ratio = RATIOS[id] ?? 0.5;
  const selectiveSimplify = (document) => {
    for (const mesh of document.getRoot().listMeshes()) {
      for (const prim of mesh.listPrimitives()) {
        const indices = prim.getIndices();
        const count = indices
          ? indices.getCount()
          : prim.getAttribute('POSITION').getCount();
        if (count / 3 < SIMPLIFY_MIN_TRIANGLES) continue;
        simplifyPrimitive(prim, {
          simplifier: MeshoptSimplifier,
          ratio,
          error: SIMPLIFY_ERROR,
        });
      }
    }
  };

  await doc.transform(
    renameNodes,
    dedup(),
    prune(),
    weld(),
    selectiveSimplify,
    prune(),
    meshopt({ encoder: MeshoptEncoder, level: 'medium' }),
  );

  // meshopt quantization re-parents a mesh onto an anonymous child node when
  // the original node also had children (the dequant scale must not affect
  // them). Give those children back their structure's name so picking works.
  const parentOf = new Map();
  for (const node of doc.getRoot().listNodes()) {
    for (const child of node.listChildren()) parentOf.set(child, node);
  }
  for (const node of doc.getRoot().listNodes()) {
    if (!node.getMesh() || node.getName()) continue;
    let up = parentOf.get(node);
    while (up && !up.getName()) up = parentOf.get(up);
    if (up) node.setName(up.getName());
  }

  const namedAfter = named();
  await io.write(outPath, doc);
  const outSize = statSync(outPath).size;
  console.log(
    `${id}: ${(inSize / 1e6).toFixed(1)}MB -> ${(outSize / 1e6).toFixed(1)}MB, ` +
      `named nodes ${namedBefore} -> ${namedAfter}`,
  );
  if (namedAfter < namedBefore * 0.95) {
    console.error(`WARNING: ${id} lost >5% of named nodes — picking may break`);
    process.exitCode = 2;
  }
}
