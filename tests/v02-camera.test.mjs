import test from 'node:test';
import assert from 'node:assert/strict';
import {
  cameraProfile,
  clampPlayerPosition,
  corridorHalfWidth,
  inputDirection,
} from '../v02/camera-model.mjs';

test('camera opens from threshold to playground reveal', () => {
  const home = cameraProfile(6);
  const alley = cameraProfile(0);
  const reveal = cameraProfile(-9);
  assert.ok(home.distance < alley.distance);
  assert.ok(alley.distance < reveal.distance);
  assert.ok(home.fov < reveal.fov);
  assert.ok(home.lead < reveal.lead);
});

test('corridor is intentionally narrow at home and wide at playground', () => {
  assert.ok(corridorHalfWidth(6) < corridorHalfWidth(0));
  assert.ok(corridorHalfWidth(0) < corridorHalfWidth(-8));
});

test('W is forward and D is screen-right at neutral camera yaw', () => {
  const forward = inputDirection(0, 1, 0);
  const right = inputDirection(1, 0, 0);
  assert.ok(forward.z < -0.99);
  assert.ok(Math.abs(forward.x) < 0.01);
  assert.ok(right.x > 0.99);
  assert.ok(Math.abs(right.z) < 0.01);
});

test('player remains within authored corridor bounds', () => {
  assert.deepEqual(clampPlayerPosition(99, 6), { x: 1.55, z: 6 });
  assert.deepEqual(clampPlayerPosition(99, -8), { x: 5.4, z: -8 });
  assert.equal(clampPlayerPosition(0, -99).z, -11.5);
});
