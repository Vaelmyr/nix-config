/* SPDX-License-Identifier: GPL-3.0-only */
((root) => {
  'use strict';
  // Serialize host mutations: a slow open must never overtake a later close.
  class CompassOverlay {
    constructor(sdk, onError = () => {}) {
      this.sdk = sdk;
      this.onError = onError;
      this.open = false;
      this.locked = null;
      this.desired = {visible: false};
      this.busy = false;
      this.dirty = false;
    }
    update(state) {
      this.desired = state;
      this.dirty = true;
      return this.flush();
    }
    async flush() {
      if (this.busy) return;
      this.busy = true;
      try {
        while (this.dirty) {
          this.dirty = false;
          const state = this.desired;
          if (state.visible) {
            if (!this.open) {
              await this.sdk.widgets.open('compass', {width: 210, height: 232});
              this.open = true;
            }
            if (this.locked !== state.locked) {
              await this.sdk.widgets.lock(state.locked);
              this.locked = state.locked;
            }
            if (this.desired.visible) await this.sdk.widgets.send('compass', state.data);
          } else if (this.open) {
            await this.sdk.widgets.close('compass');
            this.open = false;
          }
        }
      } catch (e) { this.onError(e); }
      finally { this.busy = false; }
    }
  }
  root.CubeCompassOverlay = CompassOverlay;
  if (typeof module !== 'undefined') module.exports = CompassOverlay;
})(globalThis);
