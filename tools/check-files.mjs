// tools/check-files.mjs
import { access, readFile } from 'node:fs/promises';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = resolve(dirname(fileURLToPath(import.meta.url)), '..');

const required = [
  'index.html',
  'styles.css',
  'src/game.mjs',
  'src/logic.mjs',
  'src/world.mjs',
  'src/audio.mjs',
  'src/camera.mjs',
  'src/characters.mjs',
  'src/scene.mjs',
  'src/vendor/three/build/three.module.js',
  'src/vendor/three/build/three.core.js',
  'src/vendor/three/examples/jsm/loaders/GLTFLoader.js',
  'src/vendor/three/examples/jsm/utils/BufferGeometryUtils.js',
  'src/assets/kenney/character-male-a.glb',
  'src/assets/kenney/character-female-b.glb',
  'src/assets/kenney/character-male-c.glb',
  'src/assets/kenney/Textures/colormap.png',
  'src/assets/house/house.gltf',
  'src/assets/house/house.bin',
  'src/assets/house/tiny_treats_texture_1.png',
  'src/assets/park/tree_large.gltf',
  'src/assets/park/bush_large.gltf',
  'src/assets/park/bench.gltf',
  'src/assets/park/street_lantern.gltf',
  'src/assets/park/tiny_treats_texture_1.png',
];
for (const file of required) await access(resolve(root, file));

const html = await readFile(resolve(root, 'index.html'), 'utf8');
for (const reference of ['./styles.css', './src/vendor/three/build/three.module.js', 'type="module"', './src/game.mjs']) {
  if (!html.includes(reference)) throw new Error(`index.html is missing ${reference}`);
}

for (const relative of ['src/game.mjs', 'src/camera.mjs', 'src/characters.mjs', 'src/scene.mjs']) {
  const source = await readFile(resolve(root, relative), 'utf8');
  if (source.includes('cdn.jsdelivr.net') || source.includes('jsdelivr') || /https?:\/\//.test(source)) {
    throw new Error(`${relative} must not stream assets from a live CDN.`);
  }
}

const gameSource = await readFile(resolve(root, 'src/game.mjs'), 'utf8');
if (!gameSource.includes('window.__SMALL_WORLD__')) throw new Error('game.mjs is missing the smoke-test hook.');
if (!gameSource.includes('character-male-a.glb')) throw new Error('game.mjs is missing the visible player asset route.');

console.log('Small World file set looks consistent.');
