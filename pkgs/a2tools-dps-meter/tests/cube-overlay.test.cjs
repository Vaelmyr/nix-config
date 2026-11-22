const {test} = require('node:test');
const assert = require('node:assert/strict');
const Overlay = require('../plugins/cube-nearby/overlay.js');
const {Tracker} = require('../plugins/cube-nearby/core.js');
function host() {
  const calls = [];
  const widgets = Object.fromEntries(['open', 'close', 'lock', 'send'].map(name => [name, async (...args) => calls.push([name, ...args])]));
  return {calls, sdk: {widgets}};
}
test('floating overlay opens once, applies click-through lock, updates and closes', async () => {
  const {sdk, calls} = host(); const overlay = new Overlay(sdk);
  const state = {visible: true, locked: true, data: {kind: 'cube-compass', sessionOpened: 2}};
  await overlay.update(state); await overlay.update(state);
  assert.equal(calls.filter(c => c[0] === 'open').length, 1);
  assert.equal(calls.filter(c => c[0] === 'lock').length, 1);
  assert.equal(calls.filter(c => c[0] === 'send').length, 2);
  await overlay.update({...state, locked: false});
  assert.deepEqual(calls.filter(c => c[0] === 'lock').at(-1), ['lock', false]);
  await overlay.update({visible: false});
  assert.deepEqual(calls.at(-1), ['close', 'compass']);
  assert.equal(overlay.open, false);
});
test('disabling while a widget opens never leaves a ghost compass on screen', async () => {
  const {sdk, calls} = host(); let finish;
  sdk.widgets.open = () => new Promise(resolve => { finish = resolve; });
  const overlay = new Overlay(sdk);
  const pending = overlay.update({visible: true, locked: true, data: {}});
  await overlay.update({visible: false});
  finish(); await pending;
  assert.equal(overlay.open, false);
  assert.ok(calls.some(c => c[0] === 'close'));
  assert.equal(calls.filter(c => c[0] === 'send').length, 0);
});
test('failed widget creation is reported and can retry on the next update', async () => {
  const {sdk, calls} = host(); let failures = 0, attempts = 0;
  sdk.widgets.open = async () => { if (!attempts++) throw Error('host temporarily unavailable'); };
  const overlay = new Overlay(sdk, () => failures++);
  const state = {visible: true, locked: true, data: {}};
  await overlay.update(state); assert.equal(overlay.open, false); assert.equal(failures, 1);
  await overlay.update(state); assert.equal(overlay.open, true);
  assert.equal(calls.filter(c => c[0] === 'send').length, 1);
});
test('session count ignores old buffered completions, duplicate events and non-cube interactions', () => {
  let now = 10000; const tracker = new Tracker({now: () => now});
  const done = {entity: 123, actor: 6336, count: 1, item: 630900003};
  tracker.event('cube-opened', done, now - 1000);
  now += 1000; tracker.event('cube-opened', {...done, item: 1}, now);
  assert.equal(tracker.view().sessionOpened, 0);
  // No spawn needed: an already nearby cube still counts when opened.
  tracker.event('cube-opened', done, now); tracker.event('cube-opened', done, now);
  assert.equal(tracker.view().sessionOpened, 1);
  tracker.clear(); assert.equal(tracker.view().sessionOpened, 1);
  tracker.event('map-load', {map: 1110}, now);
  assert.equal(tracker.view().sessionOpened, 1);
});
test('session reset prevents old replays from restoring the count and accepts later openings', () => {
  let now = 10000; const tracker = new Tracker({now: () => now});
  const done = {entity: 123, actor: 6336, count: 1, item: 630900003};
  now += 1000; tracker.event('cube-opened', done, now);
  now += 1000; tracker.resetSession();
  tracker.event('cube-opened', done, now - 1000);
  assert.equal(tracker.view().sessionOpened, 0);
  assert.equal(tracker.view().sessionStartedAt, now);
  now += 1000; tracker.event('cube-opened', done, now);
  assert.equal(tracker.view().sessionOpened, 1);
});
