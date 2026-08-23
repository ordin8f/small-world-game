import './build-player-bundle.mjs';
import { access, readFile } from 'node:fs/promises';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const required = [
  'index.html',
  'styles.css',
  'src/game.mjs',
  'src/game.bundle.js',
  'src/logic.mjs',
  'src/renderer.mjs',
  'src/world.mjs',
  'src/audio.mjs',
  'v02/index.html',
  'v02/styles.css',
  'v02/main.js',
  'v02/camera-model.mjs',
  'v02/README.md',
  'v02/ASSET_CREDITS.md',
];
for (const file of required) await access(resolve(root,file));

const html = await readFile(resolve(root,'index.html'),'utf8');
for (const reference of ['./styles.css','./src/game.bundle.js']) {
  if (!html.includes(reference)) throw new Error(`index.html is missing ${reference}`);
}
if (html.includes('type="module"')) throw new Error('Player HTML must not depend on module loading.');

const bundle = await readFile(resolve(root,'src/game.bundle.js'),'utf8');
if (!bundle.includes('window.__SMALL_WORLD__')) throw new Error('Player bundle is missing the smoke-test hook.');
if (/^import\s/m.test(bundle)) throw new Error('Player bundle still contains an import statement.');
new Function(bundle);

const v02Html = await readFile(resolve(root,'v02/index.html'),'utf8');
for (const reference of ['./styles.css','./main.js','./vendor/three/build/three.module.js']) {
  if (!v02Html.includes(reference)) throw new Error(`v02/index.html is missing ${reference}`);
}
const v02Main = await readFile(resolve(root,'v02/main.js'),'utf8');
if (!v02Main.includes('window.__SMALL_WORLD_V02__')) throw new Error('v0.2 preview is missing its smoke/debug hook.');
if (!v02Main.includes('character-male-a.glb')) throw new Error('v0.2 preview is missing the visible player asset route.');
if (v02Main.includes('cdn.jsdelivr.net') || v02Main.includes('jsdelivr')) throw new Error('v0.2 preview must not stream assets from a live CDN.');

const vendoredAssets = [
  'v02/vendor/three/build/three.module.js',
  'v02/vendor/three/examples/jsm/loaders/GLTFLoader.js',
  'v02/vendor/three/examples/jsm/utils/BufferGeometryUtils.js',
  'v02/assets/kenney/character-male-a.glb',
  'v02/assets/kenney/character-female-b.glb',
  'v02/assets/kenney/character-male-c.glb',
  'v02/assets/kenney/Textures/colormap.png',
  'v02/assets/house/house.gltf',
  'v02/assets/house/house.bin',
  'v02/assets/house/tiny_treats_texture_1.png',
  'v02/assets/park/tree_large.gltf',
  'v02/assets/park/bush_large.gltf',
  'v02/assets/park/bench.gltf',
  'v02/assets/park/street_lantern.gltf',
  'v02/assets/park/tiny_treats_texture_1.png',
];
for (const file of vendoredAssets) await access(resolve(root, file));

console.log('Static Lost Ball and v0.2 preview files look consistent.');
