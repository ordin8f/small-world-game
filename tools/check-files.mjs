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
  'src/audio.mjs'
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

console.log('Static player files and boot references look consistent.');
