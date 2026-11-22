/* SPDX-License-Identifier: GPL-3.0-only */
(() => {
  'use strict';
  const $ = id => document.getElementById(id);
  const sdk = window.a2;
  if (!sdk) { $('status').textContent = 'Open this plugin in A2Tools'; return; }
  const prefs = {north: '-y', autoShow: true, alerts: true, overlay: true, overlayLocked: true};
  let storageError = false;
  let initialized = false;
  const queued = [];
  const caught = promise => Promise.resolve(promise).catch(() => { storageError = true; });
  const overlay = new CubeCompassOverlay(sdk, () => { storageError = true; });
  let positioningOverlay = false;
  let overlayTimer = null, overlayState = null;
  function scheduleOverlay(state) {
    overlayState = state;
    // Burst decoders must not flood the host's rate-limited widget API.
    if (overlayTimer !== null) return;
    overlayTimer = setTimeout(() => { overlayTimer = null; overlay.update(overlayState); }, 250);
  }
  const tracker = new CubeNearby.Tracker({
    onFound() {
      if (prefs.autoShow) caught(sdk.window.show());
      if (prefs.alerts) caught(sdk.notify('Hidden Cube nearby'));
    },
    onLearn() { caught(sdk.storage.set('learnedTemplates', [...tracker.templates].filter(x => !CubeNearby.BUILTIN.includes(x)))); }
  });
  const age = ms => ms < 1000 ? 'just now' : ms < 60000 ? `${Math.floor(ms / 1000)}s ago` : `${Math.floor(ms / 60000)}m ago`;
  const coords = p => `X ${p.x.toFixed(0)} · Y ${p.y.toFixed(0)} · Z ${p.z.toFixed(0)}`;
  const stateLabel = state => ({visible: 'In view', opening: 'Opening', 'out-of-view': 'Out of view', 'last-seen': 'Last seen'})[state];
  function render() {
    const v = tracker.view(prefs.north), cube = v.cubes[0];
    const live = v.cubes.filter(c => ['visible', 'opening'].includes(c.state));
    $('lamp').classList.toggle('found', live.length > 0 && v.running);
    $('status').textContent = !v.running ? 'Game is closed' : live.length ? `${live.length === 1 ? 'Hidden Cube' : `${live.length} Hidden Cubes`} nearby`
      : cube ? 'Remembered cube position' : 'Listening for cubes';
    $('hint').textContent = !v.running ? 'Waiting for AION 2.' : cube ? `${stateLabel(cube.state)} · detected ${age(cube.age)}`
      : 'No known cube is currently detected. Keep exploring.';
    $('nearest').hidden = !cube || !v.running;
    if (cube) {
      $('coordinates').textContent = coords(cube);
      const r = cube.relative;
      const navigable = r && v.positionFresh;
      $('arrow').style.transform = r ? `rotate(${r.bearing}deg)` : '';
      $('arrow').style.opacity = navigable ? '1' : '.28';
      $('arrow').hidden = !r;
      $('distance').textContent = r ? `≈ ${Math.round(r.distance)} m` : 'Position saved';
      $('bearing').textContent = r ? `${r.compass} · ${Math.round(r.bearing)}°${navigable ? '' : ' · last fix'}` : 'Waiting for your position';
      $('height').textContent = r ? Math.abs(r.height) < 3 ? 'Similar height' : `${Math.round(Math.abs(r.height))} m ${r.height > 0 ? 'above' : 'below'} you` : '';
      $('position-age').textContent = v.player ? `Your position: ${age(v.playerAge)}.${v.positionFresh ? '' : ' Direction and distance may be outdated. Use a self buff to refresh.'}`
        : 'Use a self buff to obtain your position and direction.';
    }
    $('cubes').replaceChildren();
    for (const c of v.cubes.slice(1, 8)) {
      const row = document.createElement('div'); row.className = 'cube-row';
      const title = document.createElement('span');
      title.textContent = c.relative ? `≈ ${Math.round(c.relative.distance)} m · ${c.relative.compass}` : 'Hidden Cube';
      const info = document.createElement('small'); info.textContent = `${stateLabel(c.state)} · ${coords(c)}`;
      row.append(title, info); $('cubes').append(row);
    }
    $('last-opened').textContent = v.lastOpened ? `Cube opened ${age(Date.now() - v.lastOpened.at)}.` : '';
    $('session-count').textContent = String(v.sessionOpened);
    $('session-since').textContent = `Since ${new Date(v.sessionStartedAt).toLocaleTimeString([], {hour: '2-digit', minute: '2-digit'})}`;
    $('diagnostics').textContent = `${tracker.templates.size} known cube types · ${v.map ? `map ${v.map}` : 'map not received yet'} · ${v.lastPacket ? `data ${age(Date.now() - v.lastPacket)}` : 'waiting for game data'}${storageError ? ' · a host request failed; check plugin permissions' : ''}`;
    if (initialized) {
      const target = live[0];
      scheduleOverlay({visible: prefs.overlay && v.running && (Boolean(target) || positioningOverlay), locked: prefs.overlayLocked,
        data: {kind: 'cube-compass', hasCube: Boolean(target), relative: target?.relative || null,
          positionFresh: v.positionFresh, playerAge: v.playerAge, sessionOpened: v.sessionOpened}});
    }
  }
  function receive(name, data, meta) {
    if (!initialized) { queued.push([name, data, meta]); return; }
    if (meta?.character) tracker.setCharacter(meta.character);
    tracker.event(name, data, Number.isFinite(meta?.at) ? meta.at : Date.now());
    render();
  }
  const events = ['object-spawn', 'object-remove', 'cube-opening', 'cube-opened', 'map-load', 'teleport', 'self-cast', 'self-hit',
    'buff-add-plain', 'buff-add-skill', 'buff-change-plain', 'buff-change-skill'];
  for (const name of events) sdk.on(`decoded:${name}`, (data, meta) => receive(name, data, meta));
  sdk.on('character', c => { tracker.setCharacter(c); render(); });
  sdk.on('game', ({running}) => { tracker.running = Boolean(running); if (!running) tracker.clear(); render(); });
  sdk.on('compact', compact => { document.body.classList.toggle('compact', Boolean(compact)); });
  sdk.on('widget-message', ({name, data}) => { if (name === 'compass' && data?.kind === 'compass-ready') render(); });
  async function initialize() {
    const results = await Promise.allSettled([sdk.storage.get('preferences'), sdk.storage.get('learnedTemplates')]);
    const settings = results[0].status === 'fulfilled' ? results[0].value : null;
    const learned = results[1].status === 'fulfilled' ? results[1].value : null;
    if (settings && typeof settings === 'object') {
      if (['-y', '+y', '+x', '-x'].includes(settings.north)) prefs.north = settings.north;
      for (const key of ['autoShow', 'alerts', 'overlay', 'overlayLocked']) if (typeof settings[key] === 'boolean') prefs[key] = settings[key];
    }
    if (Array.isArray(learned)) for (const id of learned.slice(0, 128)) if (Number.isInteger(id) && id > 0 && id <= 0xffffffff) tracker.templates.add(id);
    if (results.some(r => r.status === 'rejected')) storageError = true;
    $('north').value = prefs.north; $('auto-show').checked = prefs.autoShow; $('alerts').checked = prefs.alerts;
    $('show-overlay').checked = prefs.overlay; $('lock-overlay').checked = prefs.overlayLocked;
    initialized = true;
    for (const args of queued.splice(0)) receive(...args);
    render();
  }
  // Storage calls need the host handshake. Register everything before ready; events queue during loading.
  caught(sdk.ready());
  initialize().catch(() => { storageError = true; initialized = true; render(); });
  for (const [id, key] of [['auto-show', 'autoShow'], ['alerts', 'alerts'], ['north', 'north'], ['show-overlay', 'overlay'], ['lock-overlay', 'overlayLocked']]) {
    $(id).addEventListener('change', () => {
      if (!initialized) return;
      prefs[key] = id === 'north' ? $(id).value : $(id).checked;
      if ((key === 'overlayLocked' && prefs.overlayLocked) || (key === 'overlay' && !prefs.overlay)) positioningOverlay = false;
      caught(sdk.storage.set('preferences', prefs)); render();
    });
  }
  $('clear').addEventListener('click', () => { tracker.clear(); render(); });
  $('reset-session').addEventListener('click', () => { tracker.resetSession(); render(); });
  $('move-overlay').addEventListener('click', () => {
    prefs.overlay = true; prefs.overlayLocked = false; positioningOverlay = true;
    $('show-overlay').checked = true; $('lock-overlay').checked = false;
    caught(sdk.storage.set('preferences', prefs)); render();
  });
  setInterval(render, 1000);
  render();
})();
