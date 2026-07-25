// Service Worker — jogo 100% offline após a primeira visita
const CACHE = 'reino-v15';
const ARQUIVOS = [
  './', './index.html', './manifest.json',
  './css/style.css', './fonts/VT323.ttf',
  './js/data.js', './js/assets.js', './js/sfx.js', './js/portraits.js', './js/clans.js', './js/production.js', './js/politics.js',
  './js/dialogue.js', './js/economy.js', './js/combat.js', './js/intrigue.js',
  './js/city.js', './js/game.js', './js/ui.js',
  './icons/icon-192.png', './icons/icon-512.png',
  './img/hud/logo.png', './img/hud/moldura.png', './img/hud/barra_vazia.png', './img/hud/barra_vida.png',
  './img/hud/barra_ouro.png', './img/hud/dialogo.png', './img/hud/painel.png', './img/hud/painel_fundo.png',
  './img/armas/lanca.png', './img/armas/arco.png', './img/armas/espada.png', './img/armas/espada_dourada.png',
  './img/armas/claymore.png', './img/armas/adaga.png', './img/armas/machado.png', './img/armas/machado_grande.png',
  './img/armas/martelo.png', './img/armas/escudo.png', './img/armas/escudo_redondo.png',
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
