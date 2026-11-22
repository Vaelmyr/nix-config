/* Local Cube Nearby plugin. SPDX-License-Identifier: GPL-3.0-only */
((root) => {
  'use strict';
  const BUILTIN = [1301199, 1200039, 1200041];
  const KEY_ITEM = 630900003;
  const MAX_OBJECTS = 2048;
  const MAX_AGE = 10 * 60 * 1000;
  const FRESH_POSITION = 8000;
  const scratch = new DataView(new ArrayBuffer(4));
  function float(word) {
    if (!Number.isInteger(word) || word < 0 || word > 0xffffffff) return NaN;
    scratch.setUint32(0, word, true);
    return scratch.getFloat32(0, true);
  }
  function position(data) {
    const p = {x: float(data.x), y: float(data.y), z: float(data.z)};
    return Object.values(p).every(v => Number.isFinite(v) && Math.abs(v) < 1e7)
      && Math.hypot(p.x, p.y, p.z) > 2000 ? p : null;
  }
  // Compass coordinates, with a selectable north axis; this is not camera heading.
  function relative(from, to, north = '-y') {
    const dx = to.x - from.x, dy = to.y - from.y;
    const axes = {'-y': [dx, -dy], '+y': [-dx, dy], '+x': [dy, dx], '-x': [-dy, -dx]};
    const [east, n] = axes[north] || axes['-y'];
    const bearing = (Math.atan2(east, n) * 180 / Math.PI + 360) % 360;
    return {distance: Math.hypot(dx, dy) / 100, height: (to.z - from.z) / 100,
      bearing, compass: ['N', 'NE', 'E', 'SE', 'S', 'SW', 'W', 'NW'][Math.round(bearing / 45) % 8]};
  }
  class Tracker {
    constructor({now = () => Date.now(), learned = [], onFound = () => {}, onLearn = () => {}} = {}) {
      this.now = now;
      this.templates = new Set([...BUILTIN, ...learned.filter(x => Number.isInteger(x) && x > 0 && x <= 0xffffffff)]);
      this.onFound = onFound;
      this.onLearn = onLearn;
      this.objects = new Map();
      this.player = null;
      this.map = null;
      this.character = null;
      this.lastPacket = null;
      this.lastOpened = null;
      this.running = true;
      this.resetSession();
    }
    clear() { this.objects.clear(); this.player = null; this.lastOpened = null; }
    resetSession() {
      this.sessionStartedAt = this.now();
      this.sessionOpened = 0;
      this.countedOpenings = new Set();
    }
    setCharacter(c) {
      const key = c?.name && c?.serverId ? `${c.serverId}:${c.name}` : null;
      if (key && this.character && key !== this.character) { this.clear(); this.map = null; }
      if (key) this.character = key;
    }
    setPosition(data, at) {
      const p = position(data);
      if (p && (!this.player || at >= this.player.at)) this.player = {...p, at};
    }
    event(name, d, at = this.now()) {
      if (!d || !Number.isFinite(at)) return;
      this.lastPacket = Math.max(this.lastPacket || 0, at);
      if (name === 'map-load') {
        // A map load also happens on an intra-map teleport: old streamed objects go.
        this.clear(); this.map = d.map; this.setPosition(d, at); return;
      }
      if (name === 'teleport') {
        if (d.entity === 0) { this.clear(); this.setPosition(d, at); }
        return;
      }
      if (name.startsWith('buff-')) {
        const added = name.startsWith('buff-add');
        const skill = name.endsWith('-skill');
        // Both manifest variants can decode the same frame; only one has the right offsets.
        if ((added && d.mode !== 1) || ![0x10, 0x11, 0x13].includes(d.flags)
          || Boolean(d.flags & 2) !== skill || ![0, 1, 2].includes(d.marker)) return;
        this.setPosition(d, at); return;
      }
      if (name === 'self-cast') {
        if (d.kind === 2 && d.flags === 0) this.setPosition(d, at);
        return;
      }
      if (name === 'self-hit') {
        if (d.kind === 2) this.setPosition(d, at);
        return;
      }
      if (name === 'object-spawn') {
        const p = position(d);
        if (!p || !Number.isInteger(d.entity) || d.entity <= 0) return;
        const old = this.objects.get(d.entity);
        if (old && at < old.at) return;
        const known = this.templates.has(d.template);
        const same = old && old.template === d.template && old.state !== 'opened' && old.state !== 'gone';
        const object = {...p, entity: d.entity, template: d.template, at,
          firstAt: same ? old.firstAt : at, state: 'visible', known,
          alerted: same ? old.alerted : false, changedAt: at};
        this.objects.delete(d.entity); this.objects.set(d.entity, object);
        while (this.objects.size > MAX_OBJECTS) this.objects.delete(this.objects.keys().next().value);
        // Replay events build state, but never generate old notifications.
        if (known && !object.alerted && Math.abs(this.now() - at) <= 5000) {
          object.alerted = true;
          this.onFound(object);
        }
        return;
      }
      const object = this.objects.get(d.entity);
      if (name === 'cube-opened' && d.count === 1 && d.item === KEY_ITEM) {
        // Completion is enough to count even when its spawn preceded plugin loading.
        // Ignore buffered events from before this session/reset and exact duplicates.
        const key = `${d.entity}:${d.actor}:${at}`;
        if (at > this.sessionStartedAt && !this.countedOpenings.has(key) && object?.state !== 'opened') {
          this.countedOpenings.add(key);
          this.sessionOpened++;
        }
      }
      if (!object || at < object.changedAt) return;
      if (name === 'cube-opened' && d.count === 1 && d.item === KEY_ITEM) {
        if (!this.templates.has(object.template)) {
          this.templates.add(object.template); this.onLearn(object.template);
        }
        object.known = true; object.state = 'opened'; object.changedAt = at;
        this.lastOpened = {at, template: object.template};
      } else if (name === 'cube-opening' && d.kind === 1 && object.known) {
        object.state = 'opening'; object.changedAt = at;
      } else if (name === 'object-remove') {
        // 01 means outside the streamed area; 04 is removal after opening.
        object.state = object.state === 'opened' ? 'opened' : d.reason === 1 ? 'out-of-view' : 'gone';
        object.changedAt = at;
        if (!object.known) this.objects.delete(d.entity);
      }
    }
    view(north = '-y') {
      const now = this.now();
      const playerAge = this.player ? Math.max(0, now - this.player.at) : null;
      const cubes = [];
      for (const [id, o] of this.objects) {
        if (now - Math.max(o.at, o.changedAt) > MAX_AGE) { this.objects.delete(id); continue; }
        if (!o.known || ['opened', 'gone'].includes(o.state)) continue;
        const age = Math.max(0, now - o.at);
        // Old streamed data is a remembered sighting, not proof the cube is still nearby.
        const state = o.state === 'opening' && now - o.changedAt < 12000 ? 'opening'
          : o.state === 'out-of-view' ? o.state : age > 120000 ? 'last-seen' : 'visible';
        cubes.push({...o, state, age, relative: this.player ? relative(this.player, o, north) : null});
      }
      cubes.sort((a, b) => (a.state === 'out-of-view') - (b.state === 'out-of-view')
        || (a.relative?.distance ?? Infinity) - (b.relative?.distance ?? Infinity) || b.at - a.at);
      return {cubes, player: this.player, playerAge, positionFresh: playerAge !== null && playerAge <= FRESH_POSITION,
        map: this.map, lastPacket: this.lastPacket, lastOpened: this.lastOpened, running: this.running,
        sessionOpened: this.sessionOpened, sessionStartedAt: this.sessionStartedAt};
    }
  }
  const api = {Tracker, float, position, relative, BUILTIN, KEY_ITEM, FRESH_POSITION};
  root.CubeNearby = api;
  if (typeof module !== 'undefined') module.exports = api;
})(globalThis);
