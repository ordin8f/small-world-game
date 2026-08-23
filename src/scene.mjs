// src/scene.mjs
import * as THREE from 'three';
import { palette } from './world.mjs';

function hex([r, g, b]) {
  return (Math.round(r * 255) << 16) | (Math.round(g * 255) << 8) | Math.round(b * 255);
}

function material(color, { emissive = 0, alpha = 1, doubleSided = false } = {}) {
  const mat = new THREE.MeshStandardMaterial({
    color: hex(color),
    roughness: 0.92,
    metalness: 0,
    transparent: alpha < 1,
    opacity: alpha,
    side: doubleSided ? THREE.DoubleSide : THREE.FrontSide,
  });
  if (emissive > 0) {
    mat.emissive = new THREE.Color(hex(color));
    mat.emissiveIntensity = emissive;
  }
  return mat;
}

function addShape(scene, kind, position, scale, color, rotation = [0, 0, 0], extra = {}) {
  let geometry;
  if (kind === 'cube') geometry = new THREE.BoxGeometry(1, 1, 1);
  else if (kind === 'sphere') geometry = new THREE.SphereGeometry(0.5, 20, 16);
  else if (kind === 'cylinder') geometry = new THREE.CylinderGeometry(0.5, 0.5, 1, 16);
  else if (kind === 'cone') geometry = new THREE.ConeGeometry(0.5, 1, 16);
  else throw new Error(`Unknown shape: ${kind}`);

  const mesh = new THREE.Mesh(geometry, material(color, extra));
  mesh.position.set(position[0], position[1], position[2]);
  mesh.scale.set(scale[0], scale[1], scale[2]);
  mesh.rotation.set(rotation[0], rotation[1], rotation[2]);
  mesh.castShadow = true;
  mesh.receiveShadow = true;
  scene.add(mesh);
  return mesh;
}

export function buildStaticWorld(scene) {
  // Courtyard shell: deliberately tall, sparse, and child-scaled.
  addShape(scene, 'cube', [0, -0.28, -1], [22, 0.5, 27], palette.ground);
  addShape(scene, 'cube', [0, -0.01, 3.8], [7.2, 0.08, 14.5], palette.path);
  addShape(scene, 'cube', [-10.7, 3.8, -1], [1.1, 8.2, 29], palette.plaster);
  addShape(scene, 'cube', [10.7, 3.8, -1], [1.1, 8.2, 29], palette.plasterLight);
  addShape(scene, 'cube', [0, 4, -13.3], [23, 8.5, 1.1], palette.plaster);

  // Home threshold.
  addShape(scene, 'cube', [-3.8, 2.2, 12.0], [6.7, 4.7, 0.8], palette.plasterLight);
  addShape(scene, 'cube', [3.8, 2.2, 12.0], [6.7, 4.7, 0.8], palette.plasterLight);
  addShape(scene, 'cube', [0, 4.35, 12.0], [1.2, 1.2, 0.8], palette.plasterLight);
  addShape(scene, 'cube', [0, 1.7, 12.15], [2.5, 3.5, 0.18], palette.warmLight, [0, 0, 0], { emissive: 0.9 });

  // Playground towers, bridge, and slide.
  for (const x of [-3.4, 3.4]) {
    addShape(scene, 'cube', [x, 1.25, -5.6], [2.3, 2.4, 2.3], palette.woodLight);
    addShape(scene, 'cube', [x, 2.75, -5.6], [2.7, 0.25, 2.7], palette.wood);
    addShape(scene, 'cone', [x, 4.0, -5.6], [2.0, 1.8, 2.0], palette.woodLight);
    for (const dx of [-0.8, 0.8]) {
      for (const dz of [-0.8, 0.8]) {
        addShape(scene, 'cylinder', [x + dx, 0.5, -5.6 + dz], [0.16, 3.8, 0.16], palette.wood);
      }
    }
  }
  addShape(scene, 'cube', [0, 2.3, -5.6], [4.8, 0.25, 1.15], palette.wood);
  addShape(scene, 'cube', [-3.4, 0.95, -2.9], [1.25, 0.18, 5.2], palette.slide, [-0.54, 0, 0]);

  // Garden wall with one discoverable opening.
  addShape(scene, 'cube', [5.4, 0.55, -5.9], [0.6, 1.2, 4.2], palette.plasterLight);
  addShape(scene, 'cube', [5.4, 0.55, -1.1], [0.6, 1.2, 1.4], palette.plasterLight);
  addShape(scene, 'cube', [8.1, 0.55, -0.8], [4.7, 1.2, 0.6], palette.plasterLight);

  // Puddles, stepping stones, and bench.
  for (const puddle of [
    [-1.5, 0.01, 3.2, 1.6, 0.04, 0.9],
    [2.1, 0.01, 0.8, 1.15, 0.04, 0.75],
    [6.8, 0.01, -4.2, 1.4, 0.04, 0.8],
  ]) {
    addShape(scene, 'sphere', [puddle[0], puddle[1], puddle[2]], [puddle[3], puddle[4], puddle[5]], palette.puddle, [0, 0, 0], { alpha: 0.65 });
  }
  for (const [x, z, s] of [[6.1, -2.5, 0.45], [6.9, -3.2, 0.52], [7.7, -3.9, 0.48], [8.4, -4.7, 0.55]]) {
    addShape(scene, 'sphere', [x, 0.05, z], [s, 0.14, s * 0.85], palette.path);
  }
  addShape(scene, 'cube', [-7.4, 0.7, -0.8], [3.1, 0.25, 0.8], palette.woodLight);
  addShape(scene, 'cube', [-8.5, 0.35, -0.8], [0.18, 1.2, 0.65], palette.wood);
  addShape(scene, 'cube', [-6.3, 0.35, -0.8], [0.18, 1.2, 0.65], palette.wood);

  const addTree = (x, z, scale = 1) => {
    addShape(scene, 'cylinder', [x, 1.25 * scale, z], [0.42 * scale, 2.5 * scale, 0.42 * scale], palette.wood);
    addShape(scene, 'sphere', [x, 3.15 * scale, z], [2.4 * scale, 2.1 * scale, 2.3 * scale], palette.foliage);
    addShape(scene, 'sphere', [x - 0.8 * scale, 3.4 * scale, z + 0.2 * scale], [1.5 * scale, 1.3 * scale, 1.5 * scale], palette.foliageLight);
  };
  addTree(-7.6, 1.7, 1.05);
  addTree(8.3, -8.2, 1.25);
  addTree(7.9, 6.2, 0.9);

  for (const [x, z, s] of [[8.2, -6.1, 1], [7.0, -7.3, 0.8], [9.1, -3.2, 0.85], [-8.7, -6.5, 0.9], [-8.8, 7.5, 1.0], [8.8, 8.6, 0.9]]) {
    addShape(scene, 'sphere', [x, 0.55 * s, z], [1.3 * s, 1.0 * s, 1.1 * s], palette.foliage);
  }
  for (const [x, z] of [[6.2, -5.5], [6.7, -6.3], [8.8, -5.6], [9.0, -7.0], [-8.4, 4.2], [-9.0, 5.0]]) {
    addShape(scene, 'cylinder', [x, 0.25, z], [0.035, 0.5, 0.035], palette.foliageLight);
    addShape(scene, 'sphere', [x, 0.52, z], [0.14, 0.1, 0.14], [0.85, 0.72, 0.42], [0, 0, 0], { emissive: 0.15 });
  }

  // Sparse grass blades soften the route without filling the scene with clutter.
  for (let index = 0; index < 34; index += 1) {
    const side = index % 2 === 0 ? -1 : 1;
    const z = -10.5 + (index * 0.67) % 20;
    const x = side * (4.3 + ((index * 1.91) % 4.4));
    const height = 0.32 + (index % 5) * 0.07;
    addShape(scene, 'cone', [x, height * 0.48, z], [0.12, height, 0.12], index % 3 === 0 ? palette.foliageLight : palette.foliage);
  }
}

export function createChalkCircle(scene) {
  const group = new THREE.Group();
  const marks = [];
  for (let i = 0; i < 18; i += 1) {
    const angle = (i / 18) * Math.PI * 2;
    const mesh = new THREE.Mesh(
      new THREE.SphereGeometry(0.5, 10, 8),
      new THREE.MeshStandardMaterial({ color: hex(palette.chalk), roughness: 0.95 }),
    );
    mesh.position.set(Math.cos(angle) * 2.25, 0.035, -3.65 + Math.sin(angle) * 2.25);
    mesh.rotation.set(0, -angle, 0);
    mesh.receiveShadow = true;
    group.add(mesh);
    marks.push(mesh);
  }
  scene.add(group);

  return {
    update(pulse, active) {
      const color = active ? [0.95, 0.86, 0.62] : palette.chalk;
      const colorHex = hex(color);
      for (const mesh of marks) {
        mesh.scale.set(0.24 + pulse * 0.04, 0.035, 0.12);
        mesh.material.color.setHex(colorHex);
        const emissive = active ? 0.2 + pulse * 0.15 : 0;
        mesh.material.emissive = emissive > 0 ? new THREE.Color(colorHex) : new THREE.Color(0x000000);
        mesh.material.emissiveIntensity = emissive;
      }
    },
  };
}

export function createFireflies(scene) {
  const MAX = 12;
  const meshes = [];
  const mat = new THREE.MeshStandardMaterial({ color: 0xffc247, emissive: 0xffc247, emissiveIntensity: 1.8 });
  for (let i = 0; i < MAX; i += 1) {
    const mesh = new THREE.Mesh(new THREE.SphereGeometry(0.045, 8, 8), mat.clone());
    mesh.visible = false;
    scene.add(mesh);
    meshes.push(mesh);
  }

  return {
    update(time, intensity, ballPosition) {
      const count = Math.floor(3 + intensity * 9);
      for (let i = 0; i < MAX; i += 1) {
        const mesh = meshes[i];
        if (i >= count) { mesh.visible = false; continue; }
        mesh.visible = true;
        const angle = time * 0.7 + i * 2.17;
        const radius = 0.65 + (i % 4) * 0.22;
        mesh.position.set(
          ballPosition[0] + Math.cos(angle) * radius,
          ballPosition[1] + 0.45 + Math.sin(angle * 1.7 + i) * 0.35,
          ballPosition[2] + Math.sin(angle) * radius,
        );
        mesh.material.opacity = 0.55 + intensity * 0.4;
        mesh.material.transparent = true;
      }
    },
  };
}

export function createBall(scene) {
  const ball = new THREE.Mesh(
    new THREE.SphereGeometry(0.42, 20, 16),
    new THREE.MeshStandardMaterial({ color: hex(palette.ball), roughness: 0.6 }),
  );
  ball.castShadow = true;
  scene.add(ball);

  const shadow = new THREE.Mesh(
    new THREE.SphereGeometry(0.43, 12, 8),
    new THREE.MeshStandardMaterial({ color: 0x483828, transparent: true, opacity: 0.45 }),
  );
  shadow.scale.set(1, 0.19, 1);
  shadow.rotation.set(0.4, 0.25, 0);
  scene.add(shadow);

  return {
    setPosition(position) {
      ball.position.set(position[0], position[1], position[2]);
      shadow.position.set(position[0] + 0.03, position[1] + 0.01, position[2]);
    },
    setVisible(visible) {
      ball.visible = visible;
      shadow.visible = visible;
    },
    setEmissive(amount) {
      if (amount > 0) {
        ball.material.emissive = new THREE.Color(hex(palette.ball));
        ball.material.emissiveIntensity = amount;
      } else {
        ball.material.emissiveIntensity = 0;
      }
    },
  };
}

export function createHomeGlow(scene) {
  const plane = new THREE.Mesh(
    new THREE.PlaneGeometry(2.0, 3.0),
    new THREE.MeshStandardMaterial({
      color: hex(palette.warmLight),
      transparent: true,
      opacity: 0.28,
      emissive: new THREE.Color(hex(palette.warmLight)),
      emissiveIntensity: 0.25,
      side: THREE.DoubleSide,
    }),
  );
  plane.position.set(0, 1.7, 11.82);
  scene.add(plane);

  return {
    update(intensity) {
      plane.material.opacity = 0.28 + 0.28 * intensity;
      plane.material.emissiveIntensity = 0.25 + intensity * 0.75;
    },
  };
}
