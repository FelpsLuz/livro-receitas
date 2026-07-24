// Service Worker — jogo 100% offline após a primeira visita
const CACHE = 'reino-v7';
const ARQUIVOS = [
  './', './index.html', './manifest.json',
  './css/style.css', './fonts/VT323.ttf',
  './js/data.js', './js/sfx.js', './js/portraits.js', './js/clans.js',
  './js/dialogue.js', './js/economy.js', './js/combat.js', './js/intrigue.js',
  './js/city.js', './js/game.js', './js/ui.js',
  './icons/icon-192.png', './icons/icon-512.png',
];

self.addEventListener('install', (e) => {
  e.waitUntil(caches.open(CACHE).then((c) => c.addAll(ARQUIVOS)).then(() => self.skipWaiting()));
});

self.addEventListener('activate', (e) => {
  e.waitUntil(
    caches.keys().then((ks) => Promise.all(ks.filter((k) => k !== CACHE).map((k) => caches.delete(k))))
      .then(() => self.clients.claim())
  );
});

self.addEventListener('fetch', (e) => {
  e.respondWith(
    caches.match(e.request).then((hit) => hit ||
      fetch(e.request).then((resp) => {
        if (resp.ok && e.request.method === 'GET' && new URL(e.request.url).origin === location.origin) {
          const clone = resp.clone();
          caches.open(CACHE).then((c) => c.put(e.request, clone));
        }
        return resp;
      })
    ).catch(() => caches.match('./index.html'))
  );
});
