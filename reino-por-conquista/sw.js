// Service Worker — jogo 100% offline após a primeira visita
const CACHE = 'reino-v28';
const ARQUIVOS = [
  './', './index.html', './manifest.json',
  './css/style.css', './fonts/VT323.ttf',
  './js/data.js', './js/assets.js', './js/duelo.js', './js/sfx.js', './js/portraits.js', './js/clans.js', './js/production.js', './js/politics.js',
  './js/barbaras.js', './js/gossip.js', './js/agenda.js', './js/mapa.js',
  './js/lore.js', './js/dialogue.js', './js/llm_nuvem.js', './js/economy.js', './js/combat.js', './js/intrigue.js',
  './js/escambo.js', './js/city.js', './js/game.js', './js/ui.js',
  './icons/icon-192.png', './icons/icon-512.png',
  './img/hud/logo.png', './img/hud/moldura.png', './img/hud/barra_vazia.png', './img/hud/barra_vida.png',
  './img/hud/barra_ouro.png', './img/hud/dialogo.png', './img/hud/painel.png', './img/hud/painel_fundo.png',
  './img/armas/lanca.png', './img/armas/arco.png', './img/armas/espada.png', './img/armas/espada_dourada.png',
  './img/armas/claymore.png', './img/armas/adaga.png', './img/armas/machado.png', './img/armas/machado_grande.png',
  './img/armas/martelo.png', './img/armas/escudo.png', './img/armas/escudo_redondo.png',
  './img/retratos/rei_imperio.png', './img/retratos/rei_touros.png', './img/retratos/rei_alvorecer.png',
  './img/retratos/rei_leoes.png', './img/retratos/rei_aguias.png', './img/retratos/rei_rosa.png',
  './img/retratos/taverneiro.png', './img/retratos/capitao.png', './img/retratos/espiao.png',
  './img/retratos/nobre_1.png', './img/retratos/nobre_2.png', './img/retratos/nobre_3.png',
  './img/retratos/nobre_4.png', './img/retratos/nobre_5.png', './img/retratos/nobre_6.png',
  './img/retratos/nobre_7.png', './img/retratos/nobre_8.png',
  './img/duelo/heroi_idle.png', './img/duelo/heroi_run.png', './img/duelo/heroi_atk.png',
  './img/duelo/heroi_hit.png', './img/duelo/heroi_morte.png',
  './img/duelo/guerreiro_idle.png', './img/duelo/guerreiro_atk.png', './img/duelo/guerreiro_hit.png',
  './img/duelo/guerreiro_morte.png',
  './img/duelo/rei_idle.png', './img/duelo/rei_atk.png', './img/duelo/rei_hit.png', './img/duelo/rei_morte.png',
  './img/duelo/bandido_idle.png', './img/duelo/bandido_atk.png', './img/duelo/bandido_hit.png',
  './img/duelo/bandido_morte.png', './img/duelo/heroi_parry.png',
  './img/hud/banner_vitoria.png', './img/hud/banner_derrota.png',
  './img/retratos/cla_lobos.png', './img/retratos/cla_corvos.png', './img/retratos/cla_estepe.png',
  './img/retratos/cla_machados.png',
  './img/armas/foice.png', './img/armas/arco_dourado.png', './img/armas/escudo_celta.png',
  ...['imperio', 'touros', 'alvorecer', 'leoes', 'aguias', 'rosa', 'jogador_1', 'jogador_2', 'jogador_3']
    .map((b) => './img/bandeiras/' + b + '.png'),
  ...[['imperio', 10], ['touros', 3], ['alvorecer', 6], ['leoes', 5], ['aguias', 4], ['rosa', 5]]
    .flatMap(([r, n]) => Array.from({ length: n }, (_, i) => './img/retratos/lorde_' + r + '_' + (i + 1) + '.png')),
  ...['terra', 'mapa', 'mercado', 'taverna', 'corte', 'exercito', 'clas', 'intrigas', 'familia', 'cronica']
    .map((i) => './img/icones/' + i + '.png'),
  ...['heroi_parado', 'heroi_anda_frente', 'heroi_anda_lado'].map((e) => './img/pessoas/' + e + '.png'),
  ...['muralha_portao', 'mesa', 'lareira', 'planta', 'saco', 'cesta', 'toco', 'poste_2', 'banco_2', 'placa_2',
      'estandarte', 'caixa_agua', 'caixa_grande', 'feno_2', 'flor_v1', 'flor_v2', 'flor_b1', 'flor_b2',
      'sombra_curta', 'sombra_longa']
    .map((e) => './img/estruturas/' + e + '.png'),
  ...['casa_1', 'casa_2', 'casa_3', 'casa_4', 'poco', 'arco', 'poste', 'feno', 'caixa', 'barril', 'placa', 'mural', 'banco',
      'arvore_1', 'arvore_2', 'arvore_3', 'arvore_4', 'arbusto_1', 'arbusto_2', 'arbusto_3',
      'grama_a', 'grama_b', 'grama_c', 'estrada_a', 'estrada_b', 'estrada_c',
      'fogueira', 'pedra_1', 'pedra_2', 'pedra_3']
    .map((e) => './img/estruturas/' + e + '.png'),
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
