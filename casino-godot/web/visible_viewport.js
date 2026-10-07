/* Shared by the wrapper and exported game. CSS pixels are the UI coordinate
 * system; canvas pixels also account for DPR. No animation-frame polling. */
(() => {
  'use strict';
  if (window.PitBossViewport) return;
  const meta = document.querySelector('meta[name="viewport"]');
  if (meta && !meta.content.includes('viewport-fit')) meta.content += ', viewport-fit=cover';
  const listeners = new Set();
  let snapshot, pending = false, probe, observer;
  const source = (() => {
    try { return window.parent.PitBossViewport ? window.parent : window; }
    catch { return window; }
  })();
  const wrapped = source !== window;

  function read() {
    const viewport = window.visualViewport;
    const width = Math.max(1, Math.floor(viewport?.width || window.innerWidth));
    const height = Math.max(1, Math.floor(viewport?.height || window.innerHeight));
    // The wrapper pads the iframe for all four safe areas, including fullscreen.
    // A directly opened game instead applies these in its Godot mobile layout.
    const style = probe && !wrapped ? getComputedStyle(probe) : null;
    const inset = name => style ? Math.max(0, parseFloat(style[name]) || 0) : 0;
    return { width, height, left: inset('paddingLeft'), top: inset('paddingTop'),
      right: inset('paddingRight'), bottom: inset('paddingBottom'),
      x: viewport?.offsetLeft || 0, y: viewport?.offsetTop || 0,
      dpr: window.devicePixelRatio || 1 };
  }

  function syncCanvas(value) {
    const canvas = document.getElementById('canvas');
    if (!canvas) return;
    // Export uses canvasResizePolicy=0: the browser-visible size owns both CSS
    // and drawing-buffer dimensions, rather than Godot's innerHeight sizing.
    canvas.style.position = 'fixed';
    canvas.style.left = `${value.x}px`;
    canvas.style.top = `${value.y}px`;
    canvas.style.width = `${value.width}px`;
    canvas.style.height = `${value.height}px`;
    const width = Math.round(value.width * value.dpr);
    const height = Math.round(value.height * value.dpr);
    if (canvas.width !== width) canvas.width = width;
    if (canvas.height !== height) canvas.height = height;
  }

  function sync() {
    pending = false;
    const next = read();
    syncCanvas(next);
    if (JSON.stringify(next) === JSON.stringify(snapshot)) return;
    snapshot = next;
    const json = JSON.stringify(snapshot);
    for (const listener of listeners) listener(json);
  }
  function schedule() {
    if (pending) return;
    pending = true;
    requestAnimationFrame(sync);
  }
  window.PitBossViewport = {
    getSnapshot() { if (!snapshot) sync(); return JSON.stringify(snapshot); },
    subscribe(callback) { listeners.add(callback); callback(this.getSnapshot()); },
    unsubscribe(callback) { listeners.delete(callback); },
    schedule,
  };

  for (const target of new Set([window, source])) {
    target.addEventListener('resize', schedule);
    target.addEventListener('orientationchange', schedule);
    target.addEventListener('pageshow', schedule);
    target.addEventListener('load', schedule);
    target.document.addEventListener('fullscreenchange', schedule);
    target.document.addEventListener('webkitfullscreenchange', schedule);
    target.visualViewport?.addEventListener('resize', schedule);
    target.visualViewport?.addEventListener('scroll', schedule);
  }
  document.addEventListener('visibilitychange', schedule);
  function start() {
    probe = document.createElement('div');
    probe.setAttribute('aria-hidden', 'true');
    probe.setAttribute('data-pit-boss-safe-area', '');
    probe.style.cssText = 'position:fixed;visibility:hidden;pointer-events:none;width:0;height:0;' +
      'padding:env(safe-area-inset-top,0px) env(safe-area-inset-right,0px) env(safe-area-inset-bottom,0px) env(safe-area-inset-left,0px);';
    document.body.appendChild(probe);
    if (window.ResizeObserver) {
      observer = new ResizeObserver(schedule);
      observer.observe(document.documentElement);
      if (wrapped && window.frameElement) observer.observe(window.frameElement);
    }
    sync();
    // Browser chrome and iframe flex sizing can settle after DOMContentLoaded.
    // These are bounded startup retries, each still guarded by snapshot equality.
    requestAnimationFrame(() => requestAnimationFrame(schedule));
    for (const delay of [100, 350, 1000]) setTimeout(schedule, delay);
  }
  if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', start, { once: true });
  else start();
})();
