// tools/package-site.mjs
import { cp, mkdir, rm } from 'node:fs/promises';
import { existsSync } from 'node:fs';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const dist = resolve(root, 'dist');

await rm(dist, { recursive: true, force: true });
await mkdir(dist, { recursive: true });

for (const file of ['index.html', 'styles.css', '.nojekyll']) {
  await cp(resolve(root, file), resolve(dist, file));
}
await cp(resolve(root, 'src'), resolve(dist, 'src'), { recursive: true });

console.log('Packaged Small World: The Lost Ball into dist/.');

// Godot rebuild (godot/lost-ball-port): if a web export already exists,
// publish it alongside the Three.js build at dist/godot/ without touching
// dist/ (the Three.js build stays the site root). Absent locally/in CI jobs
// that haven't built it -- that's fine, this step is additive only.
const godotWeb = resolve(root, 'godot', 'build', 'web');
if (existsSync(godotWeb)) {
  await cp(godotWeb, resolve(dist, 'godot'), { recursive: true });
  console.log('Packaged Godot web export into dist/godot/.');
} else {
  console.log('No godot/build/web found — skipping dist/godot/ (Three.js build at / is unaffected).');
}
