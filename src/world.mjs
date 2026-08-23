import { clamp, lerp } from './logic.mjs';

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
  { x: 5.4, z: -4.3, halfX: 0.35, halfZ: 3.8 },
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

const staticObjects = [];
const add = (mesh, position, scale, color, rotation = [0,0,0], extra = {}) => {
  staticObjects.push({ mesh, position, scale, color, rotation, ...extra });
};

// Courtyard shell: deliberately tall, sparse, and child-scaled.
add('cube', [0,-0.28,-1], [22,0.5,27], palette.ground);
add('cube', [0,-0.01,3.8], [7.2,0.08,14.5], palette.path);
add('cube', [-10.7,3.8,-1], [1.1,8.2,29], palette.plaster);
add('cube', [10.7,3.8,-1], [1.1,8.2,29], palette.plasterLight);
add('cube', [0,4,-13.3], [23,8.5,1.1], palette.plaster);

// Home threshold.
add('cube', [-3.8,2.2,12.0], [6.7,4.7,0.8], palette.plasterLight);
add('cube', [3.8,2.2,12.0], [6.7,4.7,0.8], palette.plasterLight);
add('cube', [0,4.35,12.0], [1.2,1.2,0.8], palette.plasterLight);
add('cube', [0,1.7,12.15], [2.5,3.5,0.18], palette.warmLight, [0,0,0], { emissive: 0.9 });

// Playground towers, bridge, and slide.
for (const x of [-3.4, 3.4]) {
  add('cube', [x,1.25,-5.6], [2.3,2.4,2.3], palette.woodLight);
  add('cube', [x,2.75,-5.6], [2.7,0.25,2.7], palette.wood);
  add('cone', [x,4.0,-5.6], [2.0,1.8,2.0], palette.woodLight);
  for (const dx of [-0.8,0.8]) {
    for (const dz of [-0.8,0.8]) {
      add('cylinder', [x+dx,0.5,-5.6+dz], [0.16,3.8,0.16], palette.wood);
    }
  }
}
add('cube', [0,2.3,-5.6], [4.8,0.25,1.15], palette.wood);
add('cube', [-3.4,0.95,-2.9], [1.25,0.18,5.2], palette.slide, [-0.54,0,0]);

// Garden wall with one discoverable opening.
add('cube', [5.4,0.55,-5.7], [0.6,1.2,5.0], palette.plasterLight);
add('cube', [5.4,0.55,-1.4], [0.6,1.2,1.9], palette.plasterLight);
add('cube', [8.1,0.55,-0.8], [4.7,1.2,0.6], palette.plasterLight);

// Puddles, stepping stones, and bench.
for (const puddle of [
  [-1.5,0.01,3.2,1.6,0.04,0.9],
  [2.1,0.01,0.8,1.15,0.04,0.75],
  [6.8,0.01,-4.2,1.4,0.04,0.8]
]) {
  add('sphere', [puddle[0],puddle[1],puddle[2]], [puddle[3],puddle[4],puddle[5]], palette.puddle, [0,0,0], { alpha: 0.65 });
}
for (const [x,z,s] of [[6.1,-2.5,0.45],[6.9,-3.2,0.52],[7.7,-3.9,0.48],[8.4,-4.7,0.55]]) {
  add('sphere', [x,0.05,z], [s,0.14,s*0.85], palette.path);
}
add('cube', [-7.4,0.7,-0.8], [3.1,0.25,0.8], palette.woodLight);
add('cube', [-8.5,0.35,-0.8], [0.18,1.2,0.65], palette.wood);
add('cube', [-6.3,0.35,-0.8], [0.18,1.2,0.65], palette.wood);

function addTree(x, z, scale = 1) {
  add('cylinder', [x,1.25*scale,z], [0.42*scale,2.5*scale,0.42*scale], palette.wood);
  add('sphere', [x,3.15*scale,z], [2.4*scale,2.1*scale,2.3*scale], palette.foliage);
  add('sphere', [x-0.8*scale,3.4*scale,z+0.2*scale], [1.5*scale,1.3*scale,1.5*scale], palette.foliageLight);
}
addTree(-7.6,1.7,1.05);
addTree(8.3,-8.2,1.25);
addTree(7.9,6.2,0.9);

for (const [x,z,s] of [[8.2,-6.1,1],[7.0,-7.3,0.8],[9.1,-3.2,0.85],[-8.7,-6.5,0.9],[-8.8,7.5,1.0],[8.8,8.6,0.9]]) {
  add('sphere', [x,0.55*s,z], [1.3*s,1.0*s,1.1*s], palette.foliage);
}
for (const [x,z] of [[6.2,-5.5],[6.7,-6.3],[8.8,-5.6],[9.0,-7.0],[-8.4,4.2],[-9.0,5.0]]) {
  add('cylinder', [x,0.25,z], [0.035,0.5,0.035], palette.foliageLight);
  add('sphere', [x,0.52,z], [0.14,0.1,0.14], [0.85,0.72,0.42], [0,0,0], { emissive: 0.15 });
}

// Sparse grass blades soften the route without filling the scene with clutter.
for (let index = 0; index < 34; index += 1) {
  const side = index % 2 === 0 ? -1 : 1;
  const z = -10.5 + (index * 0.67) % 20;
  const x = side * (4.3 + ((index * 1.91) % 4.4));
  const height = 0.32 + (index % 5) * 0.07;
  add('cone', [x,height*0.48,z], [0.12,height,0.12], index % 3 === 0 ? palette.foliageLight : palette.foliage);
}

export function drawStaticWorld(renderer) {
  for (const object of staticObjects) renderer.draw(object);
}

export function drawChalkCircle(renderer, pulse, active) {
  const color = active ? [0.95,0.86,0.62] : palette.chalk;
  for (let i = 0; i < 18; i += 1) {
    const angle = (i / 18) * Math.PI * 2;
    renderer.draw({
      mesh: 'sphere',
      position: [Math.cos(angle)*2.25, 0.035, -3.65+Math.sin(angle)*2.25],
      scale: [0.24+pulse*0.04,0.035,0.12],
      rotation: [0,-angle,0],
      color,
      emissive: active ? 0.2+pulse*0.15 : 0
    });
  }
}

export function drawFireflies(renderer, time, intensity, ballPosition) {
  const count = Math.floor(3 + intensity * 9);
  for (let i = 0; i < count; i += 1) {
    const angle = time*0.7+i*2.17;
    const radius = 0.65+(i%4)*0.22;
    renderer.draw({
      mesh: 'sphere',
      position: [
        ballPosition[0]+Math.cos(angle)*radius,
        ballPosition[1]+0.45+Math.sin(angle*1.7+i)*0.35,
        ballPosition[2]+Math.sin(angle)*radius
      ],
      scale: [0.045,0.045,0.045],
      color: [1,0.76,0.28],
      emissive: 1.8,
      alpha: 0.55+intensity*0.4
    });
  }
}

export function drawChild(renderer, {
  position,
  heading = 0,
  shirt = [0.28,0.42,0.48],
  shorts = [0.19,0.25,0.28],
  skin = [0.68,0.47,0.32],
  hair = [0.12,0.09,0.07],
  walk = 0,
  scale = 1,
  wave = 0
}) {
  renderer.draw({
    mesh: 'sphere',
    position: [position[0],0.025,position[2]],
    scale: [0.72*scale,0.045,0.42*scale],
    color: palette.shadow,
    alpha: 0.22
  });
  const swing = Math.sin(walk)*0.42;
  const baseY = position[1] ?? 0;
  const offset = (localX, localY, localZ) => {
    const c = Math.cos(heading), s = Math.sin(heading);
    return [
      position[0]+localX*c+localZ*s,
      baseY+localY,
      position[2]-localX*s+localZ*c
    ];
  };
  renderer.draw({mesh:'cube',position:offset(0,0.92,0),scale:[0.48*scale,0.65*scale,0.32*scale],rotation:[0,heading,0],color:shirt});
  renderer.draw({mesh:'sphere',position:offset(0,1.48,0),scale:[0.56*scale,0.61*scale,0.54*scale],color:skin});
  renderer.draw({mesh:'sphere',position:offset(0,1.68,-0.02),scale:[0.58*scale,0.34*scale,0.56*scale],color:hair});
  for (const eyeSide of [-1,1]) {
    renderer.draw({
      mesh:'sphere',
      position:offset(eyeSide*0.12,1.51,0.27),
      scale:[0.055*scale,0.07*scale,0.04*scale],
      color:[0.035,0.028,0.024],
      emissive:0.06
    });
  }
  for (const side of [-1,1]) {
    const legAngle = side*swing;
    renderer.draw({mesh:'cube',position:offset(0.14*side,0.38,0),scale:[0.16*scale,0.55*scale,0.18*scale],rotation:[legAngle,heading,0],color:shorts});
    renderer.draw({mesh:'cube',position:offset(0.15*side,0.12,0.05),scale:[0.23*scale,0.14*scale,0.34*scale],rotation:[0,heading,0],color:[0.25,0.19,0.14]});
    const armWave = side === 1 ? wave : 0;
    renderer.draw({mesh:'cube',position:offset(0.33*side,0.92+armWave*0.18,0),scale:[0.13*scale,0.55*scale,0.13*scale],rotation:[side*-swing*0.7,heading,side*armWave*1.3],color:skin});
  }
}

export function drawBall(renderer, position, scale = 1, emissive = 0) {
  renderer.draw({mesh:'sphere',position,scale:[0.42*scale,0.42*scale,0.42*scale],color:palette.ball,emissive});
  renderer.draw({
    mesh:'sphere',
    position:[position[0]+0.03,position[1]+0.01,position[2]],
    scale:[0.43*scale,0.08*scale,0.43*scale],
    rotation:[0.4,0.25,0],
    color:[0.28,0.22,0.16],
    alpha:0.45
  });
}

export function drawHomeGlow(renderer, intensity) {
  renderer.draw({
    mesh:'cube',
    position:[0,1.7,11.82],
    scale:[2.0,3.0,0.08],
    color:palette.warmLight,
    alpha:0.28+0.28*intensity,
    emissive:0.25+intensity*0.75,
    doubleSided:true
  });
}

export function interpolateColor(a, b, t) {
  return [lerp(a[0],b[0],t),lerp(a[1],b[1],t),lerp(a[2],b[2],t)];
}
