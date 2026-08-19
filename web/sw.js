// Offline is not a feature here, it is the point: a caregiver at 3am in a hallway with one bar of
// signal should still get the day. The shell is cached on install; the engine is big, so it is
// cached the first time it is actually fetched.

const VERSION = "nido-v1";
const SHELL = [
  "./",
  "index.html",
  "app.js",
  "styles.css",
  "manifest.webmanifest",
  "sample-day.json",
  "vendor/browser_wasi_shim/index.js",
  "vendor/browser_wasi_shim/wasi.js",
  "vendor/browser_wasi_shim/wasi_defs.js",
  "vendor/browser_wasi_shim/fd.js",
  "vendor/browser_wasi_shim/fs_mem.js",
  "vendor/browser_wasi_shim/fs_opfs.js",
  "vendor/browser_wasi_shim/strace.js",
  "vendor/browser_wasi_shim/debug.js",
  "icons/icon-180.png",
  "icons/icon-192.png",
  "icons/icon-512.png",
];

self.addEventListener("install", (event) => {
  event.waitUntil(
    caches.open(VERSION).then((cache) => cache.addAll(SHELL)).then(() => self.skipWaiting())
  );
});

self.addEventListener("activate", (event) => {
  event.waitUntil(
    caches.keys()
      .then((keys) => Promise.all(keys.filter((key) => key !== VERSION).map((key) => caches.delete(key))))
      .then(() => self.clients.claim())
  );
});

self.addEventListener("fetch", (event) => {
  if (event.request.method !== "GET") return;
  event.respondWith(
    caches.match(event.request).then((hit) => {
      if (hit) return hit;
      return fetch(event.request).then((response) => {
        if (response.ok && new URL(event.request.url).origin === self.location.origin) {
          const copy = response.clone();
          caches.open(VERSION).then((cache) => cache.put(event.request, copy));
        }
        return response;
      });
    })
  );
});
