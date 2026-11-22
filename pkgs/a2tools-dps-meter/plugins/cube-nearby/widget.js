/* SPDX-License-Identifier: GPL-3.0-only */
(() => {
  'use strict';
  const sdk = window.a2, $ = id => document.getElementById(id);
  if (!sdk) return;
  let locked = true, editing = false;
  const caught = p => Promise.resolve(p).catch(() => {});
  function movable() {
    document.body.classList.toggle('movable', !locked || editing);
    $('move-hint').hidden = locked && !editing;
  }
  sdk.on('locked', value => { locked = Boolean(value); movable(); });
  sdk.on('layout', value => { editing = Boolean(value?.editing); movable(); });
  sdk.on('widget', data => {
    if (!data || data.kind !== 'cube-compass') return;
    const r = data.relative;
    const hasDirection = r && Number.isFinite(r.bearing) && Number.isFinite(r.distance);
    $('arrow').hidden = !hasDirection;
    $('no-fix').hidden = Boolean(hasDirection);
    if (hasDirection) $('arrow').style.transform = `rotate(${r.bearing}deg)`;
    document.body.classList.toggle('stale', !data.positionFresh);
    $('distance').textContent = hasDirection ? `≈ ${Math.round(r.distance)} m ${r.compass}` : data.hasCube ? 'Cube detected' : 'No cube nearby';
    $('no-fix').textContent = data.hasCube ? 'No position' : 'Waiting';
    $('detail').textContent = data.hasCube ? !hasDirection ? 'Use a self buff for direction'
      : !data.positionFresh ? `Position ${Math.floor(data.playerAge / 1000)}s old · map north`
      : `${Math.abs(r.height) < 3 ? 'Similar height' : `${Math.round(Math.abs(r.height))} m ${r.height > 0 ? 'above' : 'below'}`} · map north`
      : 'Map north · drag then lock';
    $('session').textContent = `${Number.isSafeInteger(data.sessionOpened) ? data.sessionOpened : 0} opened this session`;
  });
  $('compass').addEventListener('mousedown', event => {
    if (event.button === 0 && (!locked || editing)) { event.preventDefault(); caught(sdk.widget.drag()); }
  });
  caught(sdk.widget.area({x: 6, y: 6, width: 198, height: 220}));
  caught(sdk.ready());
  caught(sdk.widget.post({kind: 'compass-ready'}));
})();
