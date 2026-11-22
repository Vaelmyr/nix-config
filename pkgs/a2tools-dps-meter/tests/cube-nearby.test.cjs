const {test} = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const folder = path.join(__dirname, '../plugins/cube-nearby');
const {Tracker, relative} = require(path.join(folder, 'core.js'));
const manifest = JSON.parse(fs.readFileSync(path.join(folder, 'manifest.json')));
const fixture = JSON.parse(fs.readFileSync(path.join(__dirname, 'cube-nearby-capture.json')));
const start = Date.parse('2026-11-19T19:42:11.496+01:00');
function word(n) { const b = Buffer.alloc(4); b.writeFloatLE(n); return b.readUInt32LE(); }
function point(x, y, z) { return {x: word(x), y: word(y), z: word(z)}; }
function spawn(template = 1301199, entity = 21163) { return {entity, template, ...point(-134819.90625, -25.34668731689453, 12688)}; }
// Test-side transcription of the host's numeric manifest decoder and self filter.
function decode(spec, hex, own = 6336) {
  const b = Buffer.from(hex, 'hex'), out = {}; let p = 0;
  const take = n => { if (p + n > b.length) throw Error('short'); const part = b.subarray(p, p += n); return part; };
  try {
    for (const f of spec.fields) {
      if (f.type.startsWith('skip:')) { take(Number(f.type.slice(5))); continue; }
      if (f.type === 'varint') {
        let value = 0, done = false;
        for (let i = 0; i < 10; i++) { const byte = take(1)[0]; value += (byte & 127) * 2 ** (7 * i); if (byte < 128) { done = true; break; } }
        if (!done) return null;
        out[f.name] = value;
      } else {
        const n = {u8: 1, u16: 2, u32: 4}[f.type];
        if (!n) throw Error('unsupported field in test decoder');
        out[f.name] = take(n).readUIntLE(0, n);
      }
    }
  } catch { return null; }
  if (spec.self && out[spec.self] !== own) return null;
  return out;
}
function applyFrame(tracker, frame, own = 6336) {
  for (const d of manifest.decoders.filter(d => d.opcode.replace(/ /g, '').toLowerCase() === frame.op)) {
    const data = decode(d, frame.body, own);
    if (data) tracker.event(d.name, data, Date.parse(frame.t));
  }
}
test('captured encounter: self position, one early alert, then opening and removal', () => {
  let now = start, alerts = 0;
  const tracker = new Tracker({now: () => now, onFound: () => alerts++});
  let atSpawn, atOpening, atOpened;
  for (const frame of fixture) {
    now = Date.parse(frame.t); applyFrame(tracker, frame);
    const view = tracker.view();
    if (frame.op === '3436') atSpawn = view;
    if (frame.op === '3836') atOpening = view;
    if (frame.op === '3a36') atOpened = view;
  }
  assert.equal(alerts, 1);
  assert.equal(atSpawn.cubes.length, 1);
  assert.equal(atSpawn.cubes[0].entity, 21163);
  assert.equal(atSpawn.cubes[0].x, -134819.90625);
  assert.equal(atOpening.cubes[0].state, 'opening');
  assert.equal(atOpening.positionFresh, true);
  assert.ok(atOpening.cubes[0].relative.distance < 3, 'last reported position is within interaction range');
  assert.equal(atOpened.cubes.length, 0);
  assert.equal(tracker.view().cubes.length, 0);
  assert.equal(tracker.lastOpened.at, Date.parse('2026-11-19T19:42:24.646+01:00'));
  assert.equal(tracker.view().sessionOpened, 1);
});
test('manifest self filters reject another player before its position or opening reaches the tracker', () => {
  const playerFrame = fixture.find(f => f.op === '2a38');
  const openFrame = fixture.find(f => f.op === '3a36');
  for (const frame of [playerFrame, openFrame]) {
    for (const d of manifest.decoders.filter(d => d.opcode.replace(/ /g, '').toLowerCase() === frame.op)) {
      assert.equal(decode(d, frame.body, 999), null);
    }
  }
});
test('buff decoder variants accept only the matching flag layout; malformed positions cannot replace a fix', () => {
  const tracker = new Tracker({now: () => start});
  applyFrame(tracker, fixture.find(f => f.op === '2a38'));
  const player = {...tracker.player};
  tracker.event('buff-add-skill', {mode: 1, flags: 0x11, marker: 0, ...point(20000, 20000, 5000)}, start + 1);
  tracker.event('buff-add-plain', {mode: 1, flags: 0x11, marker: 0, ...point(20000, 20000, 5000), x: 0x7fc00000}, start + 2);
  tracker.event('self-cast', {kind: 1, flags: 0, ...point(30000, 30000, 5000)}, start + 3);
  assert.deepEqual(tracker.player, player);
  for (const d of manifest.decoders) assert.equal(decode(d, '01'), null, d.name);
});
test('plain and skill-bearing buff add/change layouts locate the same own position', () => {
  const tracker = new Tracker({now: () => start});
  const base = fixture.find(f => f.op === '2a38');
  const b = Buffer.from(base.body, 'hex');
  // Actual fixture has two-byte target/caster, flags 0x11, one-byte instance.
  const skill = Buffer.concat([b.subarray(0, 28), Buffer.from('78563412', 'hex'), b.subarray(28)]);
  skill[3] = 0x13;
  for (const frame of [base, {op: '2a38', body: skill.toString('hex'), t: base.t},
    {op: '2b38', body: Buffer.concat([b.subarray(0, 2), b.subarray(3)]).toString('hex'), t: base.t},
    {op: '2b38', body: Buffer.concat([skill.subarray(0, 2), skill.subarray(3)]).toString('hex'), t: base.t}]) {
    tracker.player = null; applyFrame(tracker, frame);
    assert.ok(tracker.player, frame.op);
    assert.equal(tracker.player.x, -145584.203125);
  }
});
test('unknown objects do not alert; only matching completed cube-key opening learns the type', () => {
  let now = start, alerts = 0; const learned = [];
  const tracker = new Tracker({now: () => now, onFound: () => alerts++, onLearn: id => learned.push(id)});
  tracker.event('object-spawn', spawn(1409999));
  tracker.event('cube-opened', {entity: 21163, count: 1, item: 0});
  assert.equal(tracker.view().cubes.length, 0); assert.deepEqual(learned, []);
  tracker.event('cube-opened', {entity: 21163, count: 1, item: 630900003});
  assert.deepEqual(learned, [1409999]);
  tracker.event('object-spawn', spawn(1409999, 21164));
  assert.equal(alerts, 1); assert.equal(tracker.view().cubes[0].entity, 21164);
});
test('old replays never alert, duplicate sightings do not repeat alerts, removed sightings are not called nearby', () => {
  let now = start + 60000, alerts = 0;
  const tracker = new Tracker({now: () => now, onFound: () => alerts++});
  tracker.event('object-spawn', spawn(), start); assert.equal(alerts, 0);
  tracker.event('object-spawn', spawn(), now); assert.equal(alerts, 1);
  tracker.event('object-spawn', spawn(), now); assert.equal(alerts, 1);
  tracker.event('object-remove', {entity: 21163, reason: 1}, now);
  assert.equal(tracker.view().cubes[0].state, 'out-of-view');
  tracker.event('object-remove', {entity: 21163, reason: 4}, now);
  assert.equal(tracker.view().cubes.length, 0);
});
test('age, map load, teleport, character switches and bounds stop stale sightings from persisting', () => {
  let now = start;
  const tracker = new Tracker({now: () => now});
  tracker.event('object-spawn', spawn());
  tracker.setPosition(point(-134800, -30, 12600), now);
  now += 9000; assert.equal(tracker.view().positionFresh, false);
  now += 120000; assert.equal(tracker.view().cubes[0].state, 'last-seen');
  now += 600000; assert.equal(tracker.view().cubes.length, 0);
  tracker.event('object-spawn', spawn());
  tracker.event('map-load', {map: 1110, ...point(-134800, -30, 12600)});
  assert.equal(tracker.view().cubes.length, 0); assert.equal(tracker.map, 1110);
  tracker.event('object-spawn', spawn());
  tracker.event('teleport', {entity: 7, ...point(-10000, 30000, 5000)});
  assert.equal(tracker.view().cubes.length, 1);
  tracker.event('teleport', {entity: 0, ...point(-10000, 30000, 5000)});
  assert.equal(tracker.view().cubes.length, 0);
  tracker.setCharacter({name: 'A', serverId: 1}); tracker.event('object-spawn', spawn());
  tracker.setCharacter({name: 'B', serverId: 1}); assert.equal(tracker.view().cubes.length, 0);
  for (let i = 1; i <= 3000; i++) tracker.event('object-spawn', spawn(1400000, i));
  assert.equal(tracker.objects.size, 2048);
});
test('compass respects selected map north and converts height and world centimetres to metres', () => {
  const from = {x: 0, y: 0, z: 1000};
  assert.equal(relative(from, {x: 0, y: -10000, z: 1500}).compass, 'N');
  const east = relative(from, {x: 10000, y: 0, z: 1500});
  assert.equal(east.compass, 'E'); assert.equal(east.distance, 100); assert.equal(east.height, 5);
  assert.equal(relative(from, {x: 10000, y: 0, z: 1500}, '+x').compass, 'N');
});

test('map-load position is decoded from the actual capture; an invalid near-origin cast cannot replace it', () => {
  const tracker = new Tracker({now: () => start});
  applyFrame(tracker, {op: '2136', body: '01000000560400002ee31800000000006067e7c7deed21c6002ab646bc3ad3420000000000000000000000000000', t: new Date(start).toISOString()});
  assert.equal(tracker.map, 1110); assert.ok(tracker.player);
  const before = {...tracker.player};
  applyFrame(tracker, {op: '0238', body: 'c03100651bb7000202c0317209d8c168f19842addf80c200000000904e01f403', t: new Date(start + 1).toISOString()});
  assert.deepEqual(tracker.player, before);
});

test('full private capture replay when provided', {skip: !process.env.CUBE_REPLAY_FRAMES}, t => {
  const frames = JSON.parse(fs.readFileSync(process.env.CUBE_REPLAY_FRAMES));
  let now = 0, alerts = 0;
  const tracker = new Tracker({now: () => now, onFound: () => alerts++});
  let observed = null;
  for (const frame of frames) {
    now = Date.parse(frame.t); applyFrame(tracker, frame);
    if (frame.op === '3836' && frame.body.startsWith('aba501')) observed = tracker.view();
  }
  assert.equal(alerts, 2);
  assert.equal(observed.cubes.length, 1);
  assert.equal(observed.cubes[0].template, 1301199);
  assert.ok(observed.cubes[0].relative.distance < 3);
  assert.equal(tracker.view().cubes.length, 0);
  t.diagnostic(`Replayed ${frames.length} decoded game frames; two known cube sightings; opened cube cleared.`);
});
