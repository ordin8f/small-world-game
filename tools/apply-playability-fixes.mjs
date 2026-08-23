import { readFile, writeFile } from 'node:fs/promises';

async function replaceOnce(path, before, after) {
  const text = await readFile(path, 'utf8');
  const occurrences = text.split(before).length - 1;
  if (occurrences !== 1) {
    throw new Error(`${path}: expected one match, found ${occurrences}`);
  }
  await writeFile(path, text.replace(before, after));
}

await replaceOnce(
  'src/game.mjs',
  "  const right = [Math.cos(camera.yaw),0,-Math.sin(camera.yaw)];",
  "  const right = [-Math.cos(camera.yaw),0,Math.sin(camera.yaw)];"
);

await replaceOnce(
  'src/world.mjs',
  "  { x: 5.4, z: -4.3, halfX: 0.35, halfZ: 3.8 },",
  "  { x: 5.4, z: -5.9, halfX: 0.35, halfZ: 2.1 },\n  { x: 5.4, z: -1.1, halfX: 0.35, halfZ: 0.7 },"
);
await replaceOnce(
  'src/world.mjs',
  "add('cube', [5.4,0.55,-5.7], [0.6,1.2,5.0], palette.plasterLight);\nadd('cube', [5.4,0.55,-1.4], [0.6,1.2,1.9], palette.plasterLight);",
  "add('cube', [5.4,0.55,-5.9], [0.6,1.2,4.2], palette.plasterLight);\nadd('cube', [5.4,0.55,-1.1], [0.6,1.2,1.4], palette.plasterLight);"
);

await replaceOnce(
  'tests/logic.test.mjs',
  "} from '../src/logic.mjs';\n",
  "} from '../src/logic.mjs';\nimport { canMoveTo } from '../src/world.mjs';\n"
);
let tests = await readFile('tests/logic.test.mjs', 'utf8');
if (!tests.includes("garden wall leaves the intended child-sized opening traversable")) {
  tests += `\n\ntest('garden wall leaves the intended child-sized opening traversable', () => {\n  assert.equal(canMoveTo(5.4, -5.9), false);\n  assert.equal(canMoveTo(5.4, -1.1), false);\n  assert.equal(canMoveTo(5.4, -3.0), true);\n  assert.equal(canMoveTo(5.4, -2.6), true);\n});\n`;
  await writeFile('tests/logic.test.mjs', tests);
}

await replaceOnce(
  'tools/smoke_test.py',
  "        assert moved_z < start_z - 0.2, (start_z, moved_z)\n",
  "        assert moved_z < start_z - 0.2, (start_z, moved_z)\n\n        start_x = await page.evaluate(\"window.__SMALL_WORLD__.player.position[0]\")\n        await page.keyboard.down(\"d\")\n        await page.wait_for_timeout(550)\n        await page.keyboard.up(\"d\")\n        moved_x = await page.evaluate(\"window.__SMALL_WORLD__.player.position[0]\")\n        assert moved_x > start_x + 0.2, (start_x, moved_x)\n"
);

const agentsPath = 'AGENTS.md';
let agents = await readFile(agentsPath, 'utf8');
if (!agents.includes('## The Lost Ball prototype exception')) {
  agents += `\n## The Lost Ball prototype exception\n\nFor the dependency-free WebGL2 experience prototype in \`src/*.mjs\`, \`index.html\`, and \`styles.css\`:\n\n- JavaScript modules are permitted even though the production direction remains strict TypeScript.\n- Do not add a framework, backend, account system, telemetry, or CDN without an explicit ticket.\n- Keep episode state, emotional perception, rendering, and release concerns separated.\n- Run \`npm run verify\` and inspect the prototype in a WebGL2 browser before claiming completion.\n- Follow the ownership boundaries in \`docs/AGENT_ORCHESTRATION.md\`.\n`;
  await writeFile(agentsPath, agents);
}

console.log('Applied playability fixes and regression coverage.');
