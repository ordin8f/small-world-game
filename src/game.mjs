// src/game.mjs
import * as THREE from 'three';
import { EpisodeDirector, EpisodeState, EmotionalLens, clamp, lerp, interpolateColor } from './logic.mjs';
import { canMoveTo } from './world.mjs';
import { cameraProfile, damp, inputDirection } from './camera.mjs';
import { loadCharacter, switchAction, animateFallback } from './characters.mjs';
import { buildStaticWorld, createChalkCircle, createFireflies, createBall, createHomeGlow } from './scene.mjs';
import { AudioDirector } from './audio.mjs';

const canvas = document.querySelector('#game-canvas');
const startScreen = document.querySelector('#start-screen');
const startButton = document.querySelector('#start-button');
const unsupported = document.querySelector('#unsupported');
const hud = document.querySelector('#hud');
const objectiveText = document.querySelector('#objective-text');
const prompt = document.querySelector('#prompt');
const promptText = document.querySelector('#prompt-text');
const dialogueCard = document.querySelector('#dialogue-card');
const dialogueSpeaker = document.querySelector('#dialogue-speaker');
const dialogueText = document.querySelector('#dialogue-text');
const debugPanel = document.querySelector('#debug-panel');
const muteButton = document.querySelector('#mute-button');
const motionButton = document.querySelector('#motion-button');
const endScreen = document.querySelector('#end-screen');
const endSummary = document.querySelector('#end-summary');
const restartButton = document.querySelector('#restart-button');
const copyFeedback = document.querySelector('#copy-feedback');
const copyStatus = document.querySelector('#copy-status');

let renderer, scene, threeCamera, sun, hemi;
try {
  renderer = new THREE.WebGLRenderer({ canvas, antialias: true, alpha: true });
  renderer.setPixelRatio(Math.min(window.devicePixelRatio || 1, 1.6));
  renderer.outputColorSpace = THREE.SRGBColorSpace;
  renderer.toneMapping = THREE.ACESFilmicToneMapping;
  renderer.toneMappingExposure = 1.0;
  renderer.shadowMap.enabled = true;
  renderer.shadowMap.type = THREE.PCFSoftShadowMap;

  scene = new THREE.Scene();
  scene.fog = new THREE.Fog(0x4f6070, 10, 27);

  threeCamera = new THREE.PerspectiveCamera(56, canvas.clientWidth / Math.max(1, canvas.clientHeight), 0.08, 120);

  hemi = new THREE.HemisphereLight(0x9fb0c0, 0x4a4030, 1.6);
  scene.add(hemi);

  sun = new THREE.DirectionalLight(0xffd59a, 2.4);
  sun.position.set(5.5, 10, 3.5);
  sun.castShadow = true;
  sun.shadow.mapSize.set(2048, 2048);
  sun.shadow.camera.left = -14;
  sun.shadow.camera.right = 14;
  sun.shadow.camera.top = 14;
  sun.shadow.camera.bottom = -14;
  sun.shadow.camera.near = 0.5;
  sun.shadow.camera.far = 40;
  sun.shadow.bias = -0.0004;
  scene.add(sun);

  buildStaticWorld(scene);
} catch (error) {
  console.error(error);
  unsupported.hidden = false;
  startScreen.hidden = true;
  throw error;
}

const chalkCircle = createChalkCircle(scene);
const fireflies = createFireflies(scene);
const ballObject = createBall(scene);
const homeGlow = createHomeGlow(scene);

const director = new EpisodeDirector();
const lens = new EmotionalLens();
const audio = new AudioDirector();
const keys = new Set();

const player = {
  position: [0, 0, 6.5],
  heading: 0,
  walkCycle: 0,
  moving: false,
  running: false
};
const playerGroup = new THREE.Group();
scene.add(playerGroup);

const NPC_DEFS = [
  { name: 'Mina', url: '', kenney: 'character-female-b.glb', position: [-0.95, 0, -3.8], heading: 0.2, tint: 0xf1eadc },
  { name: 'Arun', url: '', kenney: 'character-male-c.glb', position: [0.35, 0, -4.25], heading: -0.1, tint: 0xead9c2 },
  { name: 'Third', url: '', kenney: 'character-male-a.glb', position: [1.45, 0, -3.55], heading: -0.4, tint: 0xc9d3e0 },
];
const ASSET_BASE = './src/assets/kenney/';
let playerCharacter = null;
let npcCharacters = [];
let fallbackPhase = 0;

async function loadCharacters() {
  playerCharacter = await loadCharacter(`${ASSET_BASE}character-male-a.glb`, { targetHeight: 1.08, tint: 0xf4eee2, isPlayer: true });
  playerGroup.add(playerCharacter.root);

  npcCharacters = await Promise.all(NPC_DEFS.map(async (def) => {
    const character = await loadCharacter(`${ASSET_BASE}${def.kenney}`, { targetHeight: 1.0, tint: def.tint });
    character.root.position.set(def.position[0], def.position[1], def.position[2]);
    character.root.rotation.y = def.heading + Math.PI;
    scene.add(character.root);
    if (character.actions) character.actions.idle.play();
    return { ...character, name: def.name };
  }));
}
const charactersReady = loadCharacters();

const groupPosition = [0, 0, -3.8];
const ballStart = [0.5, 0.45, -3.7];
const ballEnd = [8.6, 0.45, -6.6];
let ballPosition = [...ballStart];
let ballFlight = 0;
let carryingBall = false;
let started = false;
let reducedMotion = window.matchMedia('(prefers-reduced-motion: reduce)').matches;
let lastFrame = performance.now();
let dialogueTimer = 0;
let debugVisible = false;
let dragActive = false;
let previousPointer = [0, 0];
let lookYaw = 0;
let lookPitch = 0;
let activePrompt = null;
let runId = 0;

const dialogues = {
  arrival: ['Other children', 'They are playing the circle game again.'],
  watch: ['Mina', 'It only counts if it stays inside the chalk.'],
  kick: ['Arun', 'Oh—no. It went through the garden gap.'],
  pickup: ['You', 'It is muddier than it looked from far away.'],
  return: ['Mina', 'You found it. You can roll first.'],
  join: ['Arun', 'Stand here. Not too close. Ready?'],
  mother: ['Mom, somewhere above', 'Honey, the light is going. Come home now.'],
  home: ['You', 'Tomorrow, they might already be waiting.']
};

function schedule(callback, delay) {
  const scheduledRun = runId;
  window.setTimeout(() => {
    if (scheduledRun === runId) callback();
  }, delay);
}

function showDialogue([speaker, text], duration = 3.2) {
  dialogueSpeaker.textContent = speaker;
  dialogueText.textContent = text;
  dialogueCard.hidden = false;
  dialogueTimer = duration;
}

function hideDialogue() {
  dialogueCard.hidden = true;
  dialogueTimer = 0;
}

function setObjective() {
  objectiveText.textContent = director.copy().objective;
}

function distance2D(a, b) {
  return Math.hypot(a[0] - b[0], a[2] - b[2]);
}

function nearestInteraction() {
  const state = director.state;
  if (state === EpisodeState.ARRIVE && distance2D(player.position, [0, 0, -1.2]) < 2.3) {
    return { label: 'Watch the children', event: 'observe' };
  }
  if (state === EpisodeState.FIND_BALL && distance2D(player.position, ballEnd) < 1.45) {
    return { label: 'Pick up the ball', event: 'ball_picked_up' };
  }
  if (state === EpisodeState.RETURN_BALL && distance2D(player.position, groupPosition) < 2.1) {
    return { label: 'Give the ball back', event: 'ball_returned' };
  }
  if (state === EpisodeState.INVITED && distance2D(player.position, [0, 0, -3.1]) < 2.2) {
    return { label: 'Join the circle', event: 'joined' };
  }
  if (state === EpisodeState.GO_HOME && distance2D(player.position, [0, 0, 10.8]) < 1.8) {
    return { label: 'Go inside', event: 'entered_home' };
  }
  return null;
}

function mina() { return npcCharacters.find((c) => c.name === 'Mina'); }

function dispatch(eventName) {
  if (!director.dispatch(eventName)) return false;
  setObjective();
  audio.chime(
    eventName === 'ball_kicked'
      ? 'uneasy'
      : eventName === 'ball_returned' || eventName === 'entered_home'
        ? 'warm'
        : 'soft'
  );

  switch (director.state) {
    case EpisodeState.OBSERVED:
      showDialogue(dialogues.watch);
      schedule(() => dispatch('ball_kicked'), 2600);
      break;
    case EpisodeState.BALL_IN_FLIGHT:
      showDialogue(dialogues.kick, 2.6);
      ballFlight = 0;
      break;
    case EpisodeState.FIND_BALL:
      break;
    case EpisodeState.RETURN_BALL:
      carryingBall = true;
      showDialogue(dialogues.pickup);
      break;
    case EpisodeState.INVITED:
      carryingBall = false;
      ballPosition = [0.45, 0.42, -3.9];
      showDialogue(dialogues.return, 3.7);
      { const m = mina(); if (m?.actions?.wave) m.actions.wave.reset().setLoop(THREE.LoopOnce, 1).fadeIn(0.2).play(); }
      break;
    case EpisodeState.GO_HOME:
      showDialogue(dialogues.join, 3.2);
      schedule(() => showDialogue(dialogues.mother, 4.2), 3000);
      break;
    case EpisodeState.COMPLETE:
      showDialogue(dialogues.home, 2.5);
      schedule(showEnding, 1900);
      break;
    default:
      break;
  }
  return true;
}

function interact() {
  if (activePrompt) dispatch(activePrompt.event);
}

function resetGame() {
  runId += 1;
  director.state = EpisodeState.ARRIVE;
  director.start();
  lens.value = { comfort: 0.38, energy: 0.48, curiosity: 0.58 };
  lens.target = { ...lens.value };
  player.position = [0, 0, 6.5];
  player.heading = 0;
  player.walkCycle = 0;
  player.moving = false;
  lookYaw = 0;
  lookPitch = 0;
  ballPosition = [...ballStart];
  ballFlight = 0;
  carryingBall = false;
  endScreen.hidden = true;
  hud.hidden = false;
  copyStatus.textContent = '';
  setObjective();
  showDialogue(dialogues.arrival, 3.5);
  canvas.focus();
}

async function begin() {
  started = true;
  startScreen.hidden = true;
  hud.hidden = false;
  await audio.start();
  await charactersReady;
  director.start();
  setObjective();
  showDialogue(dialogues.arrival, 3.5);
  canvas.focus();
}

startButton.addEventListener('click', begin);
restartButton.addEventListener('click', resetGame);

muteButton.addEventListener('click', () => {
  audio.setMuted(!audio.muted);
  muteButton.textContent = audio.muted ? 'Sound off' : 'Sound on';
  muteButton.setAttribute('aria-pressed', String(audio.muted));
});

motionButton.addEventListener('click', () => {
  reducedMotion = !reducedMotion;
  motionButton.textContent = reducedMotion ? 'Motion reduced' : 'Reduce motion';
  motionButton.setAttribute('aria-pressed', String(reducedMotion));
});

window.addEventListener('keydown', (event) => {
  if (['ArrowUp', 'ArrowDown', 'ArrowLeft', 'ArrowRight', 'Space'].includes(event.code)) {
    event.preventDefault();
  }
  keys.add(event.code);
  if ((event.code === 'KeyE' || event.code === 'Space') && started && endScreen.hidden) interact();
  if (event.code === 'KeyR' && started) resetGame();
  if (event.code === 'F2') {
    event.preventDefault();
    debugVisible = !debugVisible;
    debugPanel.hidden = !debugVisible;
  }
});

window.addEventListener('keyup', (event) => keys.delete(event.code));
window.addEventListener('blur', () => keys.clear());

canvas.addEventListener('pointerdown', (event) => {
  dragActive = true;
  previousPointer = [event.clientX, event.clientY];
  canvas.setPointerCapture?.(event.pointerId);
});
canvas.addEventListener('pointerup', (event) => {
  dragActive = false;
  canvas.releasePointerCapture?.(event.pointerId);
});
canvas.addEventListener('pointercancel', () => { dragActive = false; });
canvas.addEventListener('pointermove', (event) => {
  if (!dragActive || reducedMotion) return;
  const dx = event.clientX - previousPointer[0];
  const dy = event.clientY - previousPointer[1];
  previousPointer = [event.clientX, event.clientY];
  lookYaw = clamp(lookYaw - dx * 0.0045, -0.36, 0.36);
  lookPitch = clamp(lookPitch + dy * 0.0025, -0.12, 0.2);
});

function angleDelta(target, current) {
  return Math.atan2(Math.sin(target - current), Math.cos(target - current));
}

function movePlayer(dt) {
  const x = (keys.has('KeyD') || keys.has('ArrowRight') ? 1 : 0)
    - (keys.has('KeyA') || keys.has('ArrowLeft') ? 1 : 0);
  const z = (keys.has('KeyW') || keys.has('ArrowUp') ? 1 : 0)
    - (keys.has('KeyS') || keys.has('ArrowDown') ? 1 : 0);
  const magnitude = Math.hypot(x, z);
  player.moving = magnitude > 0.01;
  player.running = keys.has('ShiftLeft') || keys.has('ShiftRight');
  if (!player.moving) return;

  const profile = cameraProfile(player.position[2]);
  const yaw = profile.authoredYaw + lookYaw;
  const direction = inputDirection(x, z, yaw);
  const speed = player.running ? 4.1 : 2.65;
  const dx = direction.x * speed * dt;
  const dz = direction.z * speed * dt;

  const nextX = player.position[0] + dx;
  if (canMoveTo(nextX, player.position[2])) player.position[0] = nextX;
  const nextZ = player.position[2] + dz;
  if (canMoveTo(player.position[0], nextZ)) player.position[2] = nextZ;

  const targetHeading = Math.atan2(-direction.x, -direction.z);
  player.heading += angleDelta(targetHeading, player.heading) * Math.min(1, dt * 10);
  player.walkCycle += dt * (player.running ? 10 : 7);
  audio.step(performance.now() / 1000, player.running);
}

function updateBall(dt) {
  if (director.state === EpisodeState.BALL_IN_FLIGHT) {
    ballFlight = clamp(ballFlight + dt / 1.8);
    const arc = Math.sin(ballFlight * Math.PI) * 2.1;
    ballPosition = [
      lerp(ballStart[0], ballEnd[0], ballFlight),
      lerp(ballStart[1], ballEnd[1], ballFlight) + arc,
      lerp(ballStart[2], ballEnd[2], ballFlight)
    ];
    if (ballFlight >= 1) dispatch('ball_landed');
  } else if (carryingBall) {
    const side = [Math.cos(player.heading) * 0.36, 0, -Math.sin(player.heading) * 0.36];
    ballPosition = [player.position[0] + side[0], 0.88, player.position[2] + side[2]];
  }
}

function updateEmotion(dt) {
  const distanceFromGroup = distance2D(player.position, groupPosition);
  lens.setTarget(director.emotionalTarget({ distanceFromGroup }));
  const value = lens.update(dt);
  audio.setMood(value);
  return lens.getVisuals();
}

function updateCamera(dt) {
  const profile = cameraProfile(player.position[2]);
  if (!dragActive || reducedMotion) {
    lookYaw = damp(lookYaw, 0, 2.0, dt);
    lookPitch = damp(lookPitch, 0, 2.3, dt);
  }

  const yaw = profile.authoredYaw + lookYaw;
  const sin = Math.sin(yaw);
  const cos = Math.cos(yaw);
  const desired = new THREE.Vector3(
    player.position[0] + sin * profile.distance + cos * profile.lateral,
    profile.height + lookPitch * 2.8,
    player.position[2] + cos * profile.distance - sin * profile.lateral,
  );
  desired.x = clamp(desired.x, -9.65, 9.65);
  desired.z = clamp(desired.z, -12.55, 11.05);

  const alpha = 1 - Math.exp(-dt * (reducedMotion ? 16 : 7.3));
  threeCamera.position.lerp(desired, alpha);
  threeCamera.fov = damp(threeCamera.fov, profile.fov, 5.5, dt);
  threeCamera.updateProjectionMatrix();

  const forward = new THREE.Vector3(-sin, 0, -cos);
  const target = new THREE.Vector3(player.position[0], profile.targetHeight, player.position[2])
    .addScaledVector(forward, profile.lead);
  threeCamera.lookAt(target);
}

function applyEnvironment(visuals) {
  const warm = visuals.warmth;
  const fogColor = interpolateColor([0.23, 0.28, 0.33], [0.72, 0.58, 0.39], warm);
  const ambientColor = interpolateColor([0.22, 0.24, 0.28], [0.45, 0.40, 0.31], warm);
  const lightColor = interpolateColor([0.58, 0.65, 0.76], [1.08, 0.84, 0.54], warm);
  scene.fog.color.setRGB(...fogColor);
  scene.fog.near = visuals.fogNear;
  scene.fog.far = visuals.fogFar;
  sun.color.setRGB(...lightColor);
  hemi.groundColor.setRGB(...ambientColor);
  renderer.toneMappingExposure = lerp(0.82, 1.12, warm);
  document.documentElement.style.setProperty('--vignette', visuals.vignette.toFixed(3));
  document.documentElement.style.setProperty('--warmth', warm.toFixed(3));
  document.documentElement.style.setProperty('--sky-top', warm > 0.55 ? '#798b91' : '#4f6070');
  document.documentElement.style.setProperty('--sky-bottom', warm > 0.55 ? '#e8c486' : '#aa917b');
}

function updateScene(time, visuals, dt) {
  playerGroup.position.set(player.position[0], 0, player.position[2]);
  playerGroup.rotation.y = player.heading;
  if (playerCharacter) {
    if (playerCharacter.actions) {
      const next = player.moving
        ? (player.running ? playerCharacter.actions.run : playerCharacter.actions.walk)
        : playerCharacter.actions.idle;
      playerCharacter.actions.current = switchAction(playerCharacter.actions.current, next);
      playerCharacter.mixer?.update(dt);
    } else {
      fallbackPhase = animateFallback(playerCharacter.root, player.moving ? 1 : 0, player.running, dt, fallbackPhase);
    }
  }
  for (const character of npcCharacters) character.mixer?.update(dt);

  const pulse = (Math.sin(time * 2.1) + 1) / 2;
  chalkCircle.update(pulse, director.state === EpisodeState.ARRIVE || director.state === EpisodeState.INVITED);

  const hiddenWithGroup = [EpisodeState.INVITED, EpisodeState.GO_HOME, EpisodeState.COMPLETE].includes(director.state);
  const ballVisible = !hiddenWithGroup || carryingBall;
  ballObject.setVisible(ballVisible);
  if (ballVisible) {
    ballObject.setPosition(ballPosition);
    ballObject.setEmissive(director.state === EpisodeState.FIND_BALL ? visuals.curiosityGlow * 0.55 : 0);
  }

  if (director.state === EpisodeState.FIND_BALL) {
    fireflies.update(time, visuals.curiosityGlow, ballPosition);
  } else {
    fireflies.update(time, 0, ballPosition);
  }

  homeGlow.update(director.state === EpisodeState.GO_HOME || director.state === EpisodeState.COMPLETE ? 0.65 + pulse * 0.25 : 0);
}

function updateUI(visuals) {
  activePrompt = nearestInteraction();
  prompt.hidden = !activePrompt;
  if (activePrompt) promptText.textContent = activePrompt.label;
  if (debugVisible) {
    debugPanel.textContent = [
      `state: ${director.state}`,
      `emotion: ${visuals.emotion}`,
      `comfort: ${lens.value.comfort.toFixed(2)}`,
      `energy: ${lens.value.energy.toFixed(2)}`,
      `curiosity: ${lens.value.curiosity.toFixed(2)}`,
      `position: ${player.position[0].toFixed(2)}, ${player.position[2].toFixed(2)}`,
      `ball: ${ballPosition.map((value) => value.toFixed(2)).join(', ')}`,
      `reducedMotion: ${reducedMotion}`
    ].join('\n');
  }
}

function showEnding() {
  hud.hidden = true;
  endScreen.hidden = false;
  const seconds = Math.round(director.elapsed() / 1000);
  const minutes = Math.max(1, Math.round(seconds / 60));
  endSummary.textContent = `The children made room for you. You finished this playtest in about ${minutes} minute${minutes === 1 ? '' : 's'}. No emotion score was shown; the world changed around the feeling instead.`;
}

function feedbackText() {
  const data = new FormData(document.querySelector('#feedback-form'));
  const notes = document.querySelector('#feedback-notes').value.trim();
  const elapsed = Math.round(director.elapsed() / 1000);
  return [
    'SMALL WORLD — THE LOST BALL PLAYTEST',
    `Date: ${new Date().toISOString()}`,
    `Browser: ${navigator.userAgent}`,
    `Approx. completion time: ${elapsed}s`,
    `World felt child-sized: ${data.get('scale') || 'not answered'}`,
    `Emotional shift: ${data.get('emotion') || 'not answered'}`,
    `Would play another afternoon: ${data.get('continue') || 'not answered'}`,
    `Notes: ${notes || 'none'}`
  ].join('\n');
}

copyFeedback.addEventListener('click', async () => {
  const text = feedbackText();
  try {
    await navigator.clipboard.writeText(text);
    copyStatus.textContent = 'Playtest notes copied.';
  } catch {
    const blob = new Blob([text], { type: 'text/plain' });
    const url = URL.createObjectURL(blob);
    const link = document.createElement('a');
    link.href = url;
    link.download = 'small-world-playtest.txt';
    link.click();
    URL.revokeObjectURL(url);
    copyStatus.textContent = 'Playtest notes downloaded.';
  }
});

function resize() {
  const width = canvas.clientWidth || window.innerWidth;
  const height = canvas.clientHeight || window.innerHeight;
  renderer.setSize(width, height, false);
  threeCamera.aspect = width / Math.max(1, height);
  threeCamera.updateProjectionMatrix();
}

function frame(now) {
  const dt = Math.min(0.05, Math.max(0, (now - lastFrame) / 1000));
  lastFrame = now;
  if (started && endScreen.hidden) {
    movePlayer(dt);
    updateBall(dt);
    if (dialogueTimer > 0) {
      dialogueTimer -= dt;
      if (dialogueTimer <= 0) hideDialogue();
    }
  }
  const visuals = updateEmotion(dt);
  updateCamera(dt);
  applyEnvironment(visuals);
  updateScene(now / 1000, visuals, dt);
  if (started && endScreen.hidden) updateUI(visuals);
  renderer.render(scene, threeCamera);
  requestAnimationFrame(frame);
}

window.addEventListener('resize', resize);
resize();
requestAnimationFrame(frame);

// Intentional smoke-test/debug hook; not shown in the player UI.
window.__SMALL_WORLD__ = {
  director,
  lens,
  player,
  camera: threeCamera,
  dispatch,
  resetGame,
  get ballPosition() { return [...ballPosition]; },
  get activePrompt() { return activePrompt; }
};
