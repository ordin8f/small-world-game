import './build-player-bundle.mjs';
import { cp, mkdir, rm } from 'node:fs/promises';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const dist = resolve(root, 'dist');

await rm(dist, { recursive: true, force: true });
await mkdir(resolve(dist, 'src'), { recursive: true });

for (const file of ['index.html', 'styles.css', '.nojekyll']) {
  await cp(resolve(root, file), resolve(dist, file));
}
await cp(resolve(root, 'src/game.bundle.js'), resolve(dist, 'src/game.bundle.js'));
await cp(resolve(root, 'v02'), resolve(dist, 'v02'), { recursive: true });

console.log('Packaged the public Lost Ball playtest and the additive v0.2 character/camera preview in dist/.');
