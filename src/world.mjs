import { clamp } from './logic.mjs';

export const palette = Object.freeze({
  plaster: [0.68, 0.62, 0.52],
  plasterLight: [0.78, 0.71, 0.58],
  ground: [0.36, 0.37, 0.29],
  path: [0.66, 0.57, 0.40],
  wood: [0.34, 0.20, 0.12],
  woodLight: [0.62, 0.38, 0.20],
  foliage: [0.18, 0.34, 0.22],
  foliageLight: [0.34, 0.50, 0.28],
  slide: [0.80, 0.30, 0.16],
  chalk: [0.78, 0.76, 0.62],
  puddle: [0.20, 0.32, 0.37],
  shadow: [0.06, 0.07, 0.065],
  warmLight: [1.0, 0.66, 0.28],
  ball: [0.83, 0.53, 0.18]
});

export const colliders = [
  { x: -10.7, z: -1, halfX: 0.6, halfZ: 15 },
  { x: 10.7, z: -1, halfX: 0.6, halfZ: 15 },
  { x: 0, z: -13.3, halfX: 11.5, halfZ: 0.6 },
  { x: -3.4, z: -5.6, halfX: 1.35, halfZ: 1.35 },
  { x: 3.4, z: -5.6, halfX: 1.35, halfZ: 1.35 },
  { x: 5.4, z: -5.9, halfX: 0.35, halfZ: 2.1 },
  { x: 5.4, z: -1.1, halfX: 0.35, halfZ: 0.7 },
  { x: 8.1, z: -0.8, halfX: 2.35, halfZ: 0.35 },
  { x: 8.3, z: -8.2, halfX: 1.0, halfZ: 1.0 },
  { x: -7.6, z: 1.7, halfX: 0.65, halfZ: 0.65 }
];

export function circleIntersectsBox(x, z, radius, box) {
  const nearestX = clamp(x, box.x - box.halfX, box.x + box.halfX);
  const nearestZ = clamp(z, box.z - box.halfZ, box.z + box.halfZ);
  const dx = x - nearestX;
  const dz = z - nearestZ;
  return dx * dx + dz * dz < radius * radius;
}

export function canMoveTo(x, z, radius = 0.32) {
  if (x < -10 || x > 10 || z < -12.5 || z > 12) return false;
  return !colliders.some((box) => circleIntersectsBox(x, z, radius, box));
}
