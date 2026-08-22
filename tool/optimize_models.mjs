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
import { dedup, prune, weld, simplify, meshopt } from '@gltf-transform/functions';
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

const io = new NodeIO().registerExtensions(ALL_EXTENSIONS);
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
  const renameNodes = (document) => {
    for (const node of document.getRoot().listNodes()) {
      const name = node.getName();
      if (!name) continue;
      node.setName(
        name
          .trim()
          .replace(/\.\d+$/, '')
          .replace(/\.l$/, ' L')
          .replace(/\.r$/, ' R'),
      );
    }
  };

  await doc.transform(
    renameNodes,
    dedup(),
    prune(),
    weld(),
    simplify({
      simplifier: MeshoptSimplifier,
      ratio: RATIOS[id] ?? 0.5,
      error: SIMPLIFY_ERROR,
    }),
    meshopt({ encoder: MeshoptEncoder, level: 'medium' }),
  );

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
