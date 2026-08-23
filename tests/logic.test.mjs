import test from 'node:test';
import assert from 'node:assert/strict';
import {
  dominantEmotion,
  EmotionalLens,
  EpisodeDirector,
  EpisodeState
} from '../src/logic.mjs';
import { canMoveTo } from '../src/world.mjs';

test('dominant emotions are derived rather than stored as independent meters', () => {
  assert.equal(dominantEmotion({ comfort: 0.2, energy: 0.8, curiosity: 0.4 }), 'anxious');
  assert.equal(dominantEmotion({ comfort: 0.3, energy: 0.4, curiosity: 0.4 }), 'lonely');
  assert.equal(dominantEmotion({ comfort: 0.6, energy: 0.5, curiosity: 0.9 }), 'curious');
  assert.equal(dominantEmotion({ comfort: 0.9, energy: 0.8, curiosity: 0.5 }), 'happy');
});

test('emotional lens eases toward a target and clamps values', () => {
  const lens = new EmotionalLens({ comfort: 0, energy: 0, curiosity: 0 });
  lens.setTarget({ comfort: 2, energy: -1, curiosity: 0.5 });
  lens.update(1);
  assert.ok(lens.value.comfort > 0 && lens.value.comfort <= 1);
  assert.equal(lens.target.energy, 0);
  assert.equal(lens.target.curiosity, 0.5);
});

test('episode state machine rejects out-of-order events', () => {
  const director = new EpisodeDirector();
  director.start(0);
  assert.equal(director.dispatch('ball_picked_up', 10), false);
  assert.equal(director.state, EpisodeState.ARRIVE);
});

test('episode completes only through the intended sequence', () => {
  const director = new EpisodeDirector();
  director.start(0);
  for (const event of [
    'observe',
    'ball_kicked',
    'ball_landed',
    'ball_picked_up',
    'ball_returned',
    'joined',
    'entered_home'
  ]) {
    assert.equal(director.dispatch(event, 100), true, event);
  }
  assert.equal(director.state, EpisodeState.COMPLETE);
  assert.equal(director.history.length, 8);
});


test('garden wall leaves the intended child-sized opening traversable', () => {
  assert.equal(canMoveTo(5.4, -5.9), false);
  assert.equal(canMoveTo(5.4, -1.1), false);
  assert.equal(canMoveTo(5.4, -3.0), true);
  assert.equal(canMoveTo(5.4, -2.6), true);
});
