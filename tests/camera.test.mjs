// tests/camera.test.mjs
import test from 'node:test';
import assert from 'node:assert/strict';
import { cameraProfile, inputDirection } from '../src/camera.mjs';

test('camera opens from the home threshold toward the playground reveal', () => {
  const threshold = cameraProfile(6.5); // player start, near home
  const approach = cameraProfile(0);    // mid-courtyard
  const reveal = cameraProfile(-6);     // playground / garden depth
  assert.ok(threshold.distance < approach.distance);
  assert.ok(approach.distance < reveal.distance);
  assert.ok(threshold.fov < reveal.fov);
  assert.ok(threshold.lead < reveal.lead);
});

test('camera zones are stable past their anchor points', () => {
  const deepThreshold = cameraProfile(12); // at the home doorway
  const deepReveal = cameraProfile(-12);   // far garden wall
  assert.ok(Math.abs(deepThreshold.distance - cameraProfile(7).distance) < 0.01);
  assert.ok(Math.abs(deepReveal.distance - cameraProfile(-5).distance) < 0.01);
});

test('W is forward and D is screen-right at neutral camera yaw', () => {
  const forward = inputDirection(0, 1, 0);
  const right = inputDirection(1, 0, 0);
  assert.ok(forward.z < -0.99);
  assert.ok(Math.abs(forward.x) < 0.01);
  assert.ok(right.x > 0.99);
  assert.ok(Math.abs(right.z) < 0.01);
});

test('inputDirection returns zero for no input', () => {
  assert.deepEqual(inputDirection(0, 0, 0), { x: 0, z: 0 });
});
