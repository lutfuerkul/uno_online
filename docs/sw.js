// Kart Oyunları — Service Worker
// Amaç: "Kart Oyunları" (UNO + Pişti) uygulamasını yüklenebilir (PWA) yapmak
// ve çevrimdışı açılışa izin vermek. Tek bir service worker tüm siteyi
// (kök seçim ekranı + uno/ + pisti/) kapsar; her sayfa bunu ("./sw.js" ya da
// "../sw.js" göreceli yoluyla) kaydeder.
// Strateji: kendi dosyalarımız için ağ-öncelikli (online'da hep en güncel
// sürüm, çevrimdışıyken önbellekten). Firebase/gstatic gibi dış istekler
// dokunulmadan doğrudan ağa gider.

const CACHE = "kartoyunlari-cache-v24";
const ASSETS = [
  "./",
  "./index.html",
  "./manifest.webmanifest",
  "./icons/icon-192.png",
  "./icons/icon-512.png",

  "./uno/",
  "./uno/index.html",
  "./uno/game.js?v=23",
  "./uno/firebase-config.js",
  "./uno/icons/icon-192.png",
  "./uno/icons/icon-512.png",

  "./pisti/",
  "./pisti/index.html",
  "./pisti/game.js?v=19",
  "./pisti/firebase-config.js",
  "./pisti/icons/icon-192.png",
  "./pisti/icons/icon-512.png",
];

self.addEventListener("install", (e) => {
  e.waitUntil(
    caches.open(CACHE).then((c) => c.addAll(ASSETS)).then(() => self.skipWaiting())
  );
});

self.addEventListener("activate", (e) => {
  e.waitUntil(
    caches.keys()
      .then((keys) => Promise.all(keys.filter((k) => k !== CACHE).map((k) => caches.delete(k))))
      .then(() => self.clients.claim())
  );
});

self.addEventListener("fetch", (e) => {
  const req = e.request;
  if (req.method !== "GET" || new URL(req.url).origin !== self.location.origin) return;

  e.respondWith(
    fetch(req)
      .then((res) => {
        const copy = res.clone();
        caches.open(CACHE).then((c) => c.put(req, copy)).catch(() => {});
        return res;
      })
      .catch(() => caches.match(req))
  );
});
