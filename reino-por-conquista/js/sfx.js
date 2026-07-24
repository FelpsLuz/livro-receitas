// ============================================================
// EFEITOS SONOROS — WebAudio puro, zero arquivos externos
// Moedas, espadas, páginas de pergaminho, tambor de batalha.
// ============================================================
'use strict';

const Sfx = (() => {
  let ctx = null;
  let mudo = localStorage.getItem('rpc_mudo') === '1';

  function ac() {
    if (!ctx) { try { ctx = new (window.AudioContext || window.webkitAudioContext)(); } catch (e) { return null; } }
    if (ctx.state === 'suspended') ctx.resume();
    return ctx;
  }

  function tom(freq, dur, tipo, vol, atraso) {
    const a = ac(); if (!a || mudo) return;
    const t0 = a.currentTime + (atraso || 0);
    const osc = a.createOscillator(), g = a.createGain();
    osc.type = tipo || 'sine';
    osc.frequency.setValueAtTime(freq, t0);
    g.gain.setValueAtTime(vol || 0.12, t0);
    g.gain.exponentialRampToValueAtTime(0.001, t0 + dur);
    osc.connect(g); g.connect(a.destination);
    osc.start(t0); osc.stop(t0 + dur);
  }

  function ruido(dur, vol, freqCorte, atraso) {
    const a = ac(); if (!a || mudo) return;
    const t0 = a.currentTime + (atraso || 0);
    const n = Math.floor(a.sampleRate * dur);
    const buf = a.createBuffer(1, n, a.sampleRate);
    const d = buf.getChannelData(0);
    for (let i = 0; i < n; i++) d[i] = (Math.random() * 2 - 1) * (1 - i / n);
    const src = a.createBufferSource(); src.buffer = buf;
    const f = a.createBiquadFilter(); f.type = 'lowpass'; f.frequency.value = freqCorte || 3000;
    const g = a.createGain(); g.gain.value = vol || 0.1;
    src.connect(f); f.connect(g); g.connect(a.destination);
    src.start(t0);
  }

  return {
    moeda()   { tom(988, 0.08, 'square', 0.05); tom(1319, 0.12, 'square', 0.05, 0.07); },
    pagina()  { ruido(0.12, 0.06, 2200); },
    espada()  { ruido(0.05, 0.12, 6500); tom(2400, 0.06, 'sawtooth', 0.03, 0.02); },
    tambor()  { tom(82, 0.28, 'sine', 0.22); tom(55, 0.34, 'sine', 0.18, 0.12); ruido(0.1, 0.08, 900); },
    vitoria() { [523, 659, 784, 1047].forEach((f, i) => tom(f, 0.22, 'triangle', 0.09, i * 0.13)); },
    derrota() { [392, 330, 262, 196].forEach((f, i) => tom(f, 0.3, 'triangle', 0.09, i * 0.16)); },
    sino()    { tom(1568, 0.5, 'sine', 0.06); tom(2093, 0.4, 'sine', 0.03, 0.02); },
    tique()   { tom(660, 0.05, 'square', 0.03); },
    alerta()  { tom(440, 0.14, 'sawtooth', 0.07); tom(415, 0.2, 'sawtooth', 0.07, 0.14); },
    get mudo() { return mudo; },
    alternarMudo() { mudo = !mudo; localStorage.setItem('rpc_mudo', mudo ? '1' : '0'); return mudo; },
  };
})();
