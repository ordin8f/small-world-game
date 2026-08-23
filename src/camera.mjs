// src/camera.mjs
import { clamp, lerp } from './logic.mjs';

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

const THRESHOLD = { distance: 12.0, height: 3.2, targetHeight: 1.15, fov: 46, lateral: 0.55, lead: 0.5, authoredYaw: -0.045 };
const APPROACH  = { distance: 14.0, height: 3.6, targetHeight: 1.2,  fov: 48, lateral: 0.85, lead: 1.2, authoredYaw: 0.035 };
const REVEAL    = { distance: 16.0, height: 4.0, targetHeight: 1.25, fov: 50, lateral: 1.25, lead: 2.1, authoredYaw: -0.07 };

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
