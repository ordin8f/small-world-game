export function clamp(value, min, max) {
  return Math.max(min, Math.min(max, value));
}

export function lerp(a, b, t) {
  return a + (b - a) * t;
}

export function smoothstep(edge0, edge1, value) {
  const t = clamp((value - edge0) / (edge1 - edge0), 0, 1);
  return t * t * (3 - 2 * t);
}

export function damp(current, target, lambda, dt) {
  return lerp(current, target, 1 - Math.exp(-lambda * dt));
}

export function corridorHalfWidth(z) {
  if (z > 4.5) return 1.55;
  if (z > -4.5) return 2.35;
  return 5.4;
}

export function cameraProfile(z) {
  const thresholdToAlley = smoothstep(5.7, 2.2, z);
  const alleyToReveal = smoothstep(-2.8, -7.2, z);

  const threshold = {
    distance: 3.15,
    height: 1.38,
    targetHeight: 0.72,
    fov: 42,
    lateral: 0.28,
    lead: 0.20,
    authoredYaw: -0.045,
  };

  const alley = {
    distance: 4.15,
    height: 1.52,
    targetHeight: 0.78,
    fov: 46,
    lateral: 0.48,
    lead: 0.75,
    authoredYaw: 0.035,
  };

  const reveal = {
    distance: 5.05,
    height: 1.66,
    targetHeight: 0.83,
    fov: 49,
    lateral: 0.72,
    lead: 1.45,
    authoredYaw: -0.07,
  };

  const blend = (a, b, t) => ({
    distance: lerp(a.distance, b.distance, t),
    height: lerp(a.height, b.height, t),
    targetHeight: lerp(a.targetHeight, b.targetHeight, t),
    fov: lerp(a.fov, b.fov, t),
    lateral: lerp(a.lateral, b.lateral, t),
    lead: lerp(a.lead, b.lead, t),
    authoredYaw: lerp(a.authoredYaw, b.authoredYaw, t),
  });

  return blend(blend(threshold, alley, thresholdToAlley), reveal, alleyToReveal);
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

export function clampPlayerPosition(x, z) {
  const clampedZ = clamp(z, -11.5, 7.25);
  const halfWidth = corridorHalfWidth(clampedZ);
  return {
    x: clamp(x, -halfWidth, halfWidth),
    z: clampedZ,
  };
}
