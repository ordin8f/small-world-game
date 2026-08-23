// src/camera.mjs
import { clamp, lerp, smoothstep } from './logic.mjs';

export function damp(current, target, lambda, dt) {
  return lerp(current, target, 1 - Math.exp(-lambda * dt));
}

export function inputDirection(inputX, inputZ, cameraYaw) {
  const magnitude = Math.hypot(inputX, inputZ);
  if (magnitude < 1e-6) return { x: 0, z: 0 };

  const nx = inputX / magnitude;
  const nz = inputZ / magnitude;
  const forwardX = -Math.sin(cameraYaw);
  const forwardZ = -Math.cos(cameraYaw);
  const rightX = Math.cos(cameraYaw);
  const rightZ = -Math.sin(cameraYaw);

  return {
    x: rightX * nx + forwardX * nz,
    z: rightZ * nx + forwardZ * nz,
  };
}

const THRESHOLD = { distance: 5.4, height: 2.15, targetHeight: 0.95, fov: 50, lateral: 0.4, lead: 0.35, authoredYaw: -0.045 };
const APPROACH  = { distance: 6.6, height: 2.35, targetHeight: 1.0,  fov: 54, lateral: 0.6, lead: 0.9,  authoredYaw: 0.035 };
const REVEAL    = { distance: 7.6, height: 2.55, targetHeight: 1.05, fov: 58, lateral: 0.9, lead: 1.6,  authoredYaw: -0.07 };

function blend(a, b, t) {
  return {
    distance: lerp(a.distance, b.distance, t),
    height: lerp(a.height, b.height, t),
    targetHeight: lerp(a.targetHeight, b.targetHeight, t),
    fov: lerp(a.fov, b.fov, t),
    lateral: lerp(a.lateral, b.lateral, t),
    lead: lerp(a.lead, b.lead, t),
    authoredYaw: lerp(a.authoredYaw, b.authoredYaw, t),
  };
}

function smoothstepBidirectional(edge0, edge1, value) {
  let x;
  if (edge0 < edge1) {
    x = clamp((value - edge0) / (edge1 - edge0));
  } else {
    x = clamp((edge0 - value) / (edge0 - edge1));
  }
  return x * x * (3 - 2 * x);
}

export function cameraProfile(z) {
  const thresholdToApproach = smoothstepBidirectional(7, 3, z);
  const approachToReveal = smoothstepBidirectional(-2, -5, z);
  return blend(blend(THRESHOLD, APPROACH, thresholdToApproach), REVEAL, approachToReveal);
}
