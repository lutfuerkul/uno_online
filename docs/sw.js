// UNO Online — Service Worker
// Amaç: uygulamayı "yüklenebilir" (PWA) yapmak ve çevrimdışı açılışa izin vermek.
// Strateji: kendi dosyalarımız için ağ-öncelikli (online'da hep en güncel sürüm,
// çevrimdışıyken önbellekten). Firebase/gstatic gibi dış istekler dokunulmadan
// doğrudan ağa gider.

const CACHE = "uno-cache-v1";
const ASSETS = [
  "./",
  "./index.html",
  "./game.js",
  "./firebase-config.js",
  "./manifest.webmanifest",
  "./icons/icon-192.png",
  "./icons/icon-512.png",
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
  // Sadece kendi kaynaklarımızı ve GET isteklerini yönet.
  if (req.method !== "GET" || new URL(req.url).origin !== self.location.origin) return;

  // Ağ-öncelikli: online'da güncel sürümü al, kopyasını önbelleğe yaz;
  // ağ yoksa önbellekten sun.
  e.respondWith(
    fetch(req)
      .then((res) => {
        const copy = res.clone();
        caches.open(CACHE).then((c) => c.put(req, copy)).catch(() => {});
        return res;
      })
      .catch(() => caches.match(req).then((r) => r || caches.match("./index.html")))
  );
});
