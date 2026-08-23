import { EpisodeDirector, EpisodeState, EmotionalLens, clamp, lerp } from './logic.mjs';
import { WebGLRenderer, vec3 } from './renderer.mjs';
import {
  canMoveTo,
  drawBall,
  drawChalkCircle,
  drawChild,
  drawFireflies,
  drawHomeGlow,
  drawStaticWorld,
  interpolateColor
} from './world.mjs';
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

let renderer;
try {
  renderer = new WebGLRenderer(canvas);
} catch (error) {
  console.error(error);
  unsupported.hidden = false;
  startScreen.hidden = true;
  throw error;
}

const director = new EpisodeDirector();
const lens = new EmotionalLens();
const audio = new AudioDirector();
const keys = new Set();
const player = {
  position: [0,0,6.5],
  heading: Math.PI,
  walkCycle: 0,
  moving: false,
  running: false
};
const camera = {
  yaw: Math.PI,
  pitch: 0.10,
  position: [0,2.35,10.8],
  target: [0,1,6.5],
  fov: 56
};
const groupPosition = [0,0,-3.8];
const ballStart = [0.5,0.45,-3.7];
const ballEnd = [8.6,0.45,-6.6];
let ballPosition = [...ballStart];
let ballFlight = 0;
let carryingBall = false;
let started = false;
let reducedMotion = window.matchMedia('(prefers-reduced-motion: reduce)').matches;
let lastFrame = performance.now();
let dialogueTimer = 0;
let debugVisible = false;
let dragActive = false;
let previousPointer = [0,0];
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
  return Math.hypot(a[0]-b[0], a[2]-b[2]);
}

function nearestInteraction() {
  const state = director.state;
  if (state === EpisodeState.ARRIVE && distance2D(player.position,[0,0,-1.2]) < 2.3) {
    return { label: 'Watch the children', event: 'observe' };
  }
  if (state === EpisodeState.FIND_BALL && distance2D(player.position,ballEnd) < 1.45) {
    return { label: 'Pick up the ball', event: 'ball_picked_up' };
  }
  if (state === EpisodeState.RETURN_BALL && distance2D(player.position,groupPosition) < 2.1) {
    return { label: 'Give the ball back', event: 'ball_returned' };
  }
  if (state === EpisodeState.INVITED && distance2D(player.position,[0,0,-3.1]) < 2.2) {
    return { label: 'Join the circle', event: 'joined' };
  }
  if (state === EpisodeState.GO_HOME && distance2D(player.position,[0,0,10.8]) < 1.8) {
    return { label: 'Go inside', event: 'entered_home' };
  }
  return null;
}

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
      ballPosition = [0.45,0.42,-3.9];
      showDialogue(dialogues.return, 3.7);
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
  lens.value = { comfort:0.38, energy:0.48, curiosity:0.58 };
  lens.target = { ...lens.value };
  player.position = [0,0,6.5];
  player.heading = Math.PI;
  player.walkCycle = 0;
  player.moving = false;
  camera.yaw = Math.PI;
  camera.pitch = 0.10;
  camera.position = [0,2.35,10.8];
  camera.target = [0,1,6.5];
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
  if (['ArrowUp','ArrowDown','ArrowLeft','ArrowRight','Space'].includes(event.code)) {
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
  previousPointer = [event.clientX,event.clientY];
  canvas.setPointerCapture?.(event.pointerId);
});
canvas.addEventListener('pointerup', (event) => {
  dragActive = false;
  canvas.releasePointerCapture?.(event.pointerId);
});
canvas.addEventListener('pointercancel', () => { dragActive = false; });
canvas.addEventListener('pointermove', (event) => {
  if (!dragActive || reducedMotion) return;
  const dx = event.clientX-previousPointer[0];
  const dy = event.clientY-previousPointer[1];
  previousPointer = [event.clientX,event.clientY];
  camera.yaw -= dx*0.006;
  camera.pitch = clamp(camera.pitch+dy*0.004, -0.02, 0.62);
});

function movePlayer(dt) {
  const x = (keys.has('KeyD') || keys.has('ArrowRight') ? 1 : 0)
    - (keys.has('KeyA') || keys.has('ArrowLeft') ? 1 : 0);
  const z = (keys.has('KeyW') || keys.has('ArrowUp') ? 1 : 0)
    - (keys.has('KeyS') || keys.has('ArrowDown') ? 1 : 0);
  const magnitude = Math.hypot(x,z);
  player.moving = magnitude > 0.01;
  player.running = keys.has('ShiftLeft') || keys.has('ShiftRight');
  if (!player.moving) return;

  const nx = x/magnitude;
  const nz = z/magnitude;
  const forward = [Math.sin(camera.yaw),0,Math.cos(camera.yaw)];
  const right = [-Math.cos(camera.yaw),0,Math.sin(camera.yaw)];
  const direction = vec3.normalize([
    right[0]*nx + forward[0]*nz,
    0,
    right[2]*nx + forward[2]*nz
  ]);
  const speed = player.running ? 4.1 : 2.65;
  const dx = direction[0]*speed*dt;
  const dz = direction[2]*speed*dt;

  const nextX = player.position[0]+dx;
  if (canMoveTo(nextX, player.position[2])) player.position[0] = nextX;
  const nextZ = player.position[2]+dz;
  if (canMoveTo(player.position[0], nextZ)) player.position[2] = nextZ;

  const targetHeading = Math.atan2(direction[0], direction[2]);
  const delta = ((targetHeading-player.heading+Math.PI)%(Math.PI*2))-Math.PI;
  player.heading += delta*Math.min(1,dt*10);
  player.walkCycle += dt*(player.running ? 10 : 7);
  audio.step(performance.now()/1000, player.running);
}

function updateBall(dt) {
  if (director.state === EpisodeState.BALL_IN_FLIGHT) {
    ballFlight = clamp(ballFlight+dt/1.8);
    const arc = Math.sin(ballFlight*Math.PI)*2.1;
    ballPosition = [
      lerp(ballStart[0],ballEnd[0],ballFlight),
      lerp(ballStart[1],ballEnd[1],ballFlight)+arc,
      lerp(ballStart[2],ballEnd[2],ballFlight)
    ];
    if (ballFlight >= 1) dispatch('ball_landed');
  } else if (carryingBall) {
    const side = [Math.cos(player.heading)*0.36,0,-Math.sin(player.heading)*0.36];
    ballPosition = [player.position[0]+side[0],0.88,player.position[2]+side[2]];
  }
}

function updateEmotion(dt) {
  const distanceFromGroup = distance2D(player.position,groupPosition);
  lens.setTarget(director.emotionalTarget({ distanceFromGroup }));
  const value = lens.update(dt);
  audio.setMood(value);
  return lens.getVisuals();
}

function updateCamera(dt, visuals, time) {
  const target = [player.position[0],1.08,player.position[2]];
  const sway = reducedMotion ? 0 : Math.sin(time*1.3)*visuals.sway;
  const horizontal = visuals.cameraDistance*Math.cos(camera.pitch);
  const desired = [
    target[0]-Math.sin(camera.yaw+sway)*horizontal,
    target[1]+0.82+Math.sin(camera.pitch)*visuals.cameraDistance,
    target[2]-Math.cos(camera.yaw+sway)*horizontal
  ];
  // Keep the camera inside the courtyard shell. A production build will use a swept camera collider.
  desired[0] = clamp(desired[0], -9.65, 9.65);
  desired[2] = clamp(desired[2], -12.55, 11.05);
  const smoothing = 1-Math.exp(-dt*(reducedMotion ? 16 : 7));
  camera.position = vec3.lerp(camera.position,desired,smoothing);
  camera.target = vec3.lerp(camera.target,target,smoothing);
  camera.fov = lerp(camera.fov,visuals.cameraFov,smoothing);
}

function environmentFor(visuals) {
  const warm = visuals.warmth;
  const fogColor = interpolateColor([0.23,0.28,0.33],[0.72,0.58,0.39],warm);
  const ambient = interpolateColor([0.22,0.24,0.28],[0.45,0.40,0.31],warm);
  const lightColor = interpolateColor([0.58,0.65,0.76],[1.08,0.84,0.54],warm);
  document.documentElement.style.setProperty('--vignette',visuals.vignette.toFixed(3));
  document.documentElement.style.setProperty('--warmth',warm.toFixed(3));
  document.documentElement.style.setProperty('--sky-top',warm > 0.55 ? '#798b91' : '#4f6070');
  document.documentElement.style.setProperty('--sky-bottom',warm > 0.55 ? '#e8c486' : '#aa917b');
  return {
    lightDirection: [-0.55,-1,-0.35],
    lightColor,
    ambient,
    fogColor,
    fogNear: visuals.fogNear,
    fogFar: visuals.fogFar
  };
}

function drawScene(time, visuals) {
  renderer.begin(camera,environmentFor(visuals));
  drawStaticWorld(renderer);
  const pulse = (Math.sin(time*2.1)+1)/2;
  drawChalkCircle(
    renderer,
    pulse,
    director.state === EpisodeState.ARRIVE || director.state === EpisodeState.INVITED
  );

  const groupWave = director.state === EpisodeState.INVITED || director.state === EpisodeState.GO_HOME ? 0.8 : 0;
  drawChild(renderer,{position:[-0.95,0,-3.8],heading:0.2,shirt:[0.52,0.31,0.24],shorts:[0.23,0.25,0.28],skin:[0.58,0.38,0.25],hair:[0.08,0.06,0.05],walk:time*0.7,wave:groupWave,scale:0.95});
  drawChild(renderer,{position:[0.35,0,-4.25],heading:-0.1,shirt:[0.31,0.44,0.28],shorts:[0.29,0.24,0.21],skin:[0.72,0.52,0.35],hair:[0.16,0.11,0.07],walk:time*0.6,scale:0.98});
  drawChild(renderer,{position:[1.45,0,-3.55],heading:-0.4,shirt:[0.38,0.36,0.54],shorts:[0.2,0.23,0.3],skin:[0.46,0.30,0.22],hair:[0.07,0.05,0.04],walk:time*0.5,scale:0.92});

  drawChild(renderer,{position:player.position,heading:player.heading,shirt:[0.25,0.42,0.5],shorts:[0.16,0.24,0.31],skin:[0.68,0.47,0.32],hair:[0.10,0.075,0.055],walk:player.moving?player.walkCycle:0,scale:1});

  const hiddenWithGroup = [EpisodeState.INVITED,EpisodeState.GO_HOME,EpisodeState.COMPLETE].includes(director.state);
  if (!hiddenWithGroup || carryingBall) {
    drawBall(renderer,ballPosition,1,director.state === EpisodeState.FIND_BALL ? visuals.curiosityGlow*0.55 : 0);
  }
  if (director.state === EpisodeState.FIND_BALL) {
    drawFireflies(renderer,time,visuals.curiosityGlow,ballPosition);
  }
  if (director.state === EpisodeState.GO_HOME || director.state === EpisodeState.COMPLETE) {
    drawHomeGlow(renderer,0.65+pulse*0.25);
  }
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
      `ball: ${ballPosition.map((value)=>value.toFixed(2)).join(', ')}`,
      `reducedMotion: ${reducedMotion}`
    ].join('\n');
  }
}

function showEnding() {
  hud.hidden = true;
  endScreen.hidden = false;
  const seconds = Math.round(director.elapsed()/1000);
  const minutes = Math.max(1,Math.round(seconds/60));
  endSummary.textContent = `The children made room for you. You finished this playtest in about ${minutes} minute${minutes === 1 ? '' : 's'}. No emotion score was shown; the world changed around the feeling instead.`;
}

function feedbackText() {
  const data = new FormData(document.querySelector('#feedback-form'));
  const notes = document.querySelector('#feedback-notes').value.trim();
  const elapsed = Math.round(director.elapsed()/1000);
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
    const blob = new Blob([text],{type:'text/plain'});
    const url = URL.createObjectURL(blob);
    const link = document.createElement('a');
    link.href = url;
    link.download = 'small-world-playtest.txt';
    link.click();
    URL.revokeObjectURL(url);
    copyStatus.textContent = 'Playtest notes downloaded.';
  }
});

function frame(now) {
  const dt = Math.min(0.05,Math.max(0,(now-lastFrame)/1000));
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
  updateCamera(dt,visuals,now/1000);
  drawScene(now/1000,visuals);
  if (started && endScreen.hidden) updateUI(visuals);
  requestAnimationFrame(frame);
}

window.addEventListener('resize', () => renderer.resize());
requestAnimationFrame(frame);

// Intentional smoke-test/debug hook; not shown in the player UI.
window.__SMALL_WORLD__ = {
  director,
  lens,
  player,
  camera,
  dispatch,
  resetGame,
  get ballPosition() { return [...ballPosition]; },
  get activePrompt() { return activePrompt; }
};
