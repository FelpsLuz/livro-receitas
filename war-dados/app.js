/* Dados do War — rolador de 3 dados de ataque x 3 de defesa */
(function () {
  'use strict';

  var STORAGE_KEY = 'war-dados:v1';
  var MAX_HISTORY = 12;

  var state = {
    counts: { atk: 3, def: 3 },
    values: { atk: [], def: [] },
    troops: { atk: 10, def: 10 },
    troopsVisible: false,
    history: [],
    rolling: false
  };

  var el = {
    diceAtk: document.getElementById('dice-atk'),
    diceDef: document.getElementById('dice-def'),
    result: document.getElementById('result'),
    roll: document.getElementById('btn-roll'),
    troopsPanel: document.getElementById('tropas'),
    troopsToggle: document.getElementById('btn-tropas'),
    troopAtk: document.getElementById('troop-atk'),
    troopDef: document.getElementById('troop-def'),
    historyList: document.getElementById('history-list'),
    clear: document.getElementById('btn-clear')
  };

  /* ---------- sorteio ---------- */

  // d6 sem viés: descarta os valores que não caem em um múltiplo de 6.
  function d6() {
    if (window.crypto && window.crypto.getRandomValues) {
      var buf = new Uint8Array(1);
      var limit = 252; // 42 * 6
      do {
        window.crypto.getRandomValues(buf);
      } while (buf[0] >= limit);
      return (buf[0] % 6) + 1;
    }
    return Math.floor(Math.random() * 6) + 1;
  }

  function rollValues(n) {
    var out = [];
    for (var i = 0; i < n; i++) out.push(d6());
    return out.sort(function (a, b) { return b - a; });
  }

  /* ---------- regras do War ---------- */

  // Compara par a par (maior x maior). Empate é vitória da defesa.
  function resolve(atk, def) {
    var duels = [];
    var losses = { atk: 0, def: 0 };
    var pairs = Math.min(atk.length, def.length);

    for (var i = 0; i < pairs; i++) {
      var attackerWins = atk[i] > def[i];
      duels.push({ atk: atk[i], def: def[i], winner: attackerWins ? 'atk' : 'def' });
      if (attackerWins) losses.def++;
      else losses.atk++;
    }
    return { duels: duels, losses: losses };
  }

  /* ---------- dados na tela ---------- */

  function makeDie(side, value) {
    var die = document.createElement('div');
    die.className = 'die die--' + side;
    die.setAttribute('data-value', String(value));
    die.setAttribute('role', 'img');
    die.setAttribute('aria-label', (side === 'atk' ? 'Ataque' : 'Defesa') + ': ' + value);
    for (var i = 0; i < 9; i++) {
      var pip = document.createElement('span');
      pip.className = 'pip';
      die.appendChild(pip);
    }
    return die;
  }

  function renderDice(side) {
    var row = side === 'atk' ? el.diceAtk : el.diceDef;
    var values = state.values[side];
    var count = state.counts[side];

    row.textContent = '';
    for (var i = 0; i < count; i++) {
      row.appendChild(makeDie(side, values[i] || 1));
    }
  }

  function dice(side) {
    return (side === 'atk' ? el.diceAtk : el.diceDef).querySelectorAll('.die');
  }

  function setDieValue(node, value, side) {
    node.setAttribute('data-value', String(value));
    node.setAttribute('aria-label', (side === 'atk' ? 'Ataque' : 'Defesa') + ': ' + value);
  }

  /* ---------- resultado ---------- */

  function renderResult(outcome) {
    el.result.textContent = '';

    var list = document.createElement('ul');
    list.className = 'duels';

    outcome.duels.forEach(function (duel) {
      var li = document.createElement('li');
      li.className = 'duel win-' + duel.winner;

      var a = document.createElement('span');
      a.className = 'duel-atk';
      a.textContent = String(duel.atk);

      var mark = document.createElement('span');
      mark.className = 'duel-mark';
      mark.textContent = duel.winner === 'atk' ? '›' : '‹';

      var d = document.createElement('span');
      d.className = 'duel-def';
      d.textContent = String(duel.def);

      li.appendChild(a);
      li.appendChild(mark);
      li.appendChild(d);
      list.appendChild(li);
    });

    var losses = document.createElement('div');
    losses.className = 'losses';
    losses.appendChild(lossBox('atk', 'Ataque perde', outcome.losses.atk));
    losses.appendChild(lossBox('def', 'Defesa perde', outcome.losses.def));

    el.result.appendChild(list);
    el.result.appendChild(losses);
  }

  function lossBox(side, label, value) {
    var box = document.createElement('div');
    box.className = 'loss loss--' + side;

    var l = document.createElement('span');
    l.className = 'loss-label';
    l.textContent = label;

    var v = document.createElement('span');
    v.className = 'loss-value';
    v.textContent = '−' + value;

    box.appendChild(l);
    box.appendChild(v);
    return box;
  }

  function markDice(outcome) {
    var atkNodes = dice('atk');
    var defNodes = dice('def');

    outcome.duels.forEach(function (duel, i) {
      var winner = duel.winner === 'atk' ? atkNodes[i] : defNodes[i];
      var loser = duel.winner === 'atk' ? defNodes[i] : atkNodes[i];
      if (winner) winner.classList.add('is-winner');
      if (loser) loser.classList.add('is-loser');
    });
  }

  /* ---------- histórico ---------- */

  function renderHistory() {
    el.historyList.textContent = '';

    state.history.forEach(function (entry) {
      var li = document.createElement('li');
      li.className = 'history-item';

      var dicePart = document.createElement('span');
      var a = document.createElement('span');
      a.className = 'hist-dice-atk';
      a.textContent = entry.atk.join(' ');
      var sep = document.createElement('span');
      sep.className = 'hist-sep';
      sep.textContent = 'x';
      var d = document.createElement('span');
      d.className = 'hist-dice-def';
      d.textContent = entry.def.join(' ');
      dicePart.appendChild(a);
      dicePart.appendChild(sep);
      dicePart.appendChild(d);

      var res = document.createElement('span');
      res.className = 'hist-result';
      res.textContent = 'A −' + entry.losses.atk + ' · D −' + entry.losses.def;

      li.appendChild(dicePart);
      li.appendChild(res);
      el.historyList.appendChild(li);
    });
  }

  /* ---------- tropas ---------- */

  function renderTroops() {
    el.troopAtk.textContent = String(state.troops.atk);
    el.troopDef.textContent = String(state.troops.def);
  }

  function changeTroops(side, delta) {
    state.troops[side] = Math.max(0, Math.min(99, state.troops[side] + delta));
    renderTroops();
    save();
  }

  /* ---------- persistência ---------- */

  function save() {
    try {
      localStorage.setItem(STORAGE_KEY, JSON.stringify({
        counts: state.counts,
        troops: state.troops,
        troopsVisible: state.troopsVisible,
        history: state.history
      }));
    } catch (e) { /* modo privado: segue sem salvar */ }
  }

  function load() {
    var raw;
    try {
      raw = localStorage.getItem(STORAGE_KEY);
    } catch (e) { return; }
    if (!raw) return;

    try {
      var data = JSON.parse(raw);
      if (data.counts) {
        state.counts.atk = clampCount(data.counts.atk);
        state.counts.def = clampCount(data.counts.def);
      }
      if (data.troops) {
        state.troops.atk = clampTroop(data.troops.atk);
        state.troops.def = clampTroop(data.troops.def);
      }
      state.troopsVisible = !!data.troopsVisible;
      if (Array.isArray(data.history)) {
        state.history = data.history.slice(0, MAX_HISTORY);
      }
    } catch (e) { /* dado corrompido: ignora */ }
  }

  function clampCount(n) {
    n = parseInt(n, 10);
    return (n >= 1 && n <= 3) ? n : 3;
  }

  function clampTroop(n) {
    n = parseInt(n, 10);
    return (n >= 0 && n <= 99) ? n : 10;
  }

  /* ---------- rolagem ---------- */

  function buzz(pattern) {
    if (navigator.vibrate) {
      try { navigator.vibrate(pattern); } catch (e) { /* ignora */ }
    }
  }

  function roll() {
    if (state.rolling) return;
    state.rolling = true;
    el.roll.disabled = true;
    el.roll.textContent = 'Rolando…';
    buzz(20);

    var atk = rollValues(state.counts.atk);
    var def = rollValues(state.counts.def);
    var nodes = [].slice.call(dice('atk')).concat([].slice.call(dice('def')));

    nodes.forEach(function (node) {
      node.classList.remove('is-winner', 'is-loser');
      node.classList.add('is-rolling');
    });

    var ticks = 0;
    var spin = setInterval(function () {
      nodes.forEach(function (node) {
        node.setAttribute('data-value', String(d6()));
      });
      if (++ticks >= 9) {
        clearInterval(spin);
        settle(atk, def);
      }
    }, 70);
  }

  function settle(atk, def) {
    var atkNodes = dice('atk');
    var defNodes = dice('def');

    atk.forEach(function (v, i) { setDieValue(atkNodes[i], v, 'atk'); });
    def.forEach(function (v, i) { setDieValue(defNodes[i], v, 'def'); });

    [].forEach.call(atkNodes, function (n) { n.classList.remove('is-rolling'); });
    [].forEach.call(defNodes, function (n) { n.classList.remove('is-rolling'); });

    state.values.atk = atk;
    state.values.def = def;

    var outcome = resolve(atk, def);
    markDice(outcome);
    renderResult(outcome);

    state.troops.atk = Math.max(0, state.troops.atk - outcome.losses.atk);
    state.troops.def = Math.max(0, state.troops.def - outcome.losses.def);
    renderTroops();

    state.history.unshift({ atk: atk, def: def, losses: outcome.losses });
    state.history = state.history.slice(0, MAX_HISTORY);
    renderHistory();
    save();

    buzz(outcome.losses.def > outcome.losses.atk ? [30, 40, 60] : 40);

    state.rolling = false;
    el.roll.disabled = false;
    el.roll.textContent = 'Rolar dados';
  }

  /* ---------- eventos ---------- */

  function setCount(side, count) {
    state.counts[side] = count;
    state.values[side] = [];

    var picker = document.querySelectorAll('.count-picker button[data-side="' + side + '"]');
    [].forEach.call(picker, function (btn) {
      var active = parseInt(btn.getAttribute('data-count'), 10) === count;
      btn.classList.toggle('is-active', active);
      btn.setAttribute('aria-pressed', active ? 'true' : 'false');
    });

    renderDice(side);
    clearResult();
    save();
  }

  function clearResult() {
    el.result.textContent = '';
    var p = document.createElement('p');
    p.className = 'result-empty';
    p.textContent = 'Escolha os dados e role.';
    el.result.appendChild(p);
  }

  function toggleTroops() {
    state.troopsVisible = !state.troopsVisible;
    el.troopsPanel.hidden = !state.troopsVisible;
    el.troopsToggle.setAttribute('aria-pressed', state.troopsVisible ? 'true' : 'false');
    save();
  }

  document.addEventListener('click', function (event) {
    var btn = event.target.closest('button');
    if (!btn) return;

    if (btn.hasAttribute('data-count')) {
      setCount(btn.getAttribute('data-side'), parseInt(btn.getAttribute('data-count'), 10));
      return;
    }
    if (btn.hasAttribute('data-troop')) {
      changeTroops(btn.getAttribute('data-troop'), parseInt(btn.getAttribute('data-delta'), 10));
      return;
    }
    if (btn === el.roll) { roll(); return; }
    if (btn === el.troopsToggle) { toggleTroops(); return; }
    if (btn === el.clear) {
      state.history = [];
      renderHistory();
      save();
    }
  });

  // espaço/enter para rolar no desktop
  document.addEventListener('keydown', function (event) {
    if (event.code === 'Space' && event.target === document.body) {
      event.preventDefault();
      roll();
    }
  });

  /* ---------- init ---------- */

  load();
  setCount('atk', state.counts.atk);
  setCount('def', state.counts.def);
  renderTroops();
  renderHistory();
  el.troopsPanel.hidden = !state.troopsVisible;
  el.troopsToggle.setAttribute('aria-pressed', state.troopsVisible ? 'true' : 'false');

  if ('serviceWorker' in navigator) {
    window.addEventListener('load', function () {
      navigator.serviceWorker.register('sw.js').catch(function () { /* offline opcional */ });
    });
  }
})();
