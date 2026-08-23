export const EpisodeState = Object.freeze({
  ARRIVE: 'ARRIVE',
  OBSERVED: 'OBSERVED',
  BALL_IN_FLIGHT: 'BALL_IN_FLIGHT',
  FIND_BALL: 'FIND_BALL',
  RETURN_BALL: 'RETURN_BALL',
  INVITED: 'INVITED',
  GO_HOME: 'GO_HOME',
  COMPLETE: 'COMPLETE'
});

export const clamp = (value, min = 0, max = 1) => Math.min(max, Math.max(min, value));
export const lerp = (a, b, t) => a + (b - a) * t;
export const smoothstep = (edge0, edge1, value) => {
  const x = clamp((value - edge0) / Math.max(1e-6, edge1 - edge0));
  return x * x * (3 - 2 * x);
};

export function dominantEmotion({ comfort, energy, curiosity }) {
  if (comfort < 0.35 && energy > 0.62) return 'anxious';
  if (comfort < 0.4 && energy <= 0.62) return 'lonely';
  if (curiosity > 0.72 && comfort >= 0.35) return 'curious';
  if (comfort > 0.72 && energy > 0.55) return 'happy';
  if (comfort > 0.65 && energy <= 0.55) return 'secure';
  return 'uncertain';
}

export class EmotionalLens {
  constructor(initial = { comfort: 0.38, energy: 0.48, curiosity: 0.58 }) {
    this.value = { ...initial };
    this.target = { ...initial };
  }
  setTarget(target) {
    this.target = {
      comfort: clamp(target.comfort),
      energy: clamp(target.energy),
      curiosity: clamp(target.curiosity)
    };
  }
  nudge(delta) {
    this.setTarget({
      comfort: this.target.comfort + (delta.comfort ?? 0),
      energy: this.target.energy + (delta.energy ?? 0),
      curiosity: this.target.curiosity + (delta.curiosity ?? 0)
    });
  }
  update(dt) {
    const t = 1 - Math.exp(-Math.max(0, dt) * 1.7);
    this.value.comfort = lerp(this.value.comfort, this.target.comfort, t);
    this.value.energy = lerp(this.value.energy, this.target.energy, t);
    this.value.curiosity = lerp(this.value.curiosity, this.target.curiosity, t);
    return this.value;
  }
  getVisuals() {
    const { comfort, energy, curiosity } = this.value;
    const unease = 1 - comfort;
    return {
      emotion: dominantEmotion(this.value),
      cameraDistance: lerp(4.55, 6.15, comfort),
      cameraFov: lerp(52, 61, comfort),
      vignette: clamp(0.12 + unease * 0.34 + energy * unease * 0.12, 0.1, 0.58),
      saturation: lerp(0.76, 1.08, comfort) + curiosity * 0.06,
      warmth: clamp(0.25 + comfort * 0.7, 0, 1),
      curiosityGlow: smoothstep(0.52, 0.9, curiosity),
      sway: unease * energy * 0.035,
      fogNear: lerp(10, 18, comfort),
      fogFar: lerp(27, 42, comfort)
    };
  }
}

const STATE_COPY = Object.freeze({
  [EpisodeState.ARRIVE]: { objective: 'Stand near the chalk circle and watch the game.', prompt: 'Watch quietly' },
  [EpisodeState.OBSERVED]: { objective: 'Stay nearby. See how their game works.', prompt: null },
  [EpisodeState.BALL_IN_FLIGHT]: { objective: 'The ball is getting away.', prompt: null },
  [EpisodeState.FIND_BALL]: { objective: 'Find the ball beyond the low garden wall.', prompt: 'Pick up the ball' },
  [EpisodeState.RETURN_BALL]: { objective: 'Carry the ball back to the children.', prompt: 'Give the ball back' },
  [EpisodeState.INVITED]: { objective: 'Stay for one small turn.', prompt: 'Join the circle' },
  [EpisodeState.GO_HOME]: { objective: 'Follow the warm light home.', prompt: 'Go inside' },
  [EpisodeState.COMPLETE]: { objective: 'The afternoon is complete.', prompt: null }
});

const ALLOWED = Object.freeze({
  [EpisodeState.ARRIVE]: { observe: EpisodeState.OBSERVED },
  [EpisodeState.OBSERVED]: { ball_kicked: EpisodeState.BALL_IN_FLIGHT },
  [EpisodeState.BALL_IN_FLIGHT]: { ball_landed: EpisodeState.FIND_BALL },
  [EpisodeState.FIND_BALL]: { ball_picked_up: EpisodeState.RETURN_BALL },
  [EpisodeState.RETURN_BALL]: { ball_returned: EpisodeState.INVITED },
  [EpisodeState.INVITED]: { joined: EpisodeState.GO_HOME },
  [EpisodeState.GO_HOME]: { entered_home: EpisodeState.COMPLETE },
  [EpisodeState.COMPLETE]: {}
});

export class EpisodeDirector {
  constructor() {
    this.state = EpisodeState.ARRIVE;
    this.history = [{ state: this.state, at: 0 }];
    this.startedAt = 0;
  }
  start(now = performance.now()) {
    this.startedAt = now;
    this.history = [{ state: this.state, at: 0 }];
  }
  dispatch(eventName, now = performance.now()) {
    const next = ALLOWED[this.state]?.[eventName];
    if (!next) return false;
    this.state = next;
    this.history.push({ state: next, at: Math.max(0, now - this.startedAt) });
    return true;
  }
  copy() { return STATE_COPY[this.state]; }
  emotionalTarget(context = {}) {
    const distanceFromGroup = clamp((context.distanceFromGroup ?? 0) / 15);
    switch (this.state) {
      case EpisodeState.ARRIVE: return { comfort: 0.36, energy: 0.48, curiosity: 0.62 };
      case EpisodeState.OBSERVED: return { comfort: 0.42, energy: 0.53, curiosity: 0.78 };
      case EpisodeState.BALL_IN_FLIGHT: return { comfort: 0.28, energy: 0.78, curiosity: 0.72 };
      case EpisodeState.FIND_BALL:
        return { comfort: clamp(0.38 - distanceFromGroup * 0.16), energy: 0.68, curiosity: 0.86 };
      case EpisodeState.RETURN_BALL: return { comfort: 0.58, energy: 0.66, curiosity: 0.72 };
      case EpisodeState.INVITED: return { comfort: 0.82, energy: 0.7, curiosity: 0.7 };
      case EpisodeState.GO_HOME: return { comfort: 0.7, energy: 0.45, curiosity: 0.48 };
      case EpisodeState.COMPLETE: return { comfort: 0.9, energy: 0.35, curiosity: 0.45 };
      default: return { comfort: 0.5, energy: 0.5, curiosity: 0.5 };
    }
  }
  elapsed(now = performance.now()) { return Math.max(0, now - this.startedAt); }
}
