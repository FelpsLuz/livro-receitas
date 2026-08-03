// ============================================================
// IA NA NUVEM — conversas abertas com os reis via API (Claude/GPT).
// O motor de diálogo (dialogue.js) continua sendo a FONTE DA VERDADE
// da mecânica (relação, ouro, memórias, ações); a IA só reveste a FALA
// com linguagem natural, guiada pelo prompt rico de montarPromptLLM.
// A chave da API fica SÓ no aparelho do jogador (localStorage), nunca
// no código nem no save. Sem internet/chave → cai no motor offline.
// ============================================================
'use strict';

const LLMNuvem = (() => {
  const K = { prov: 'rpc_ia_provider', key: 'rpc_ia_key', model: 'rpc_ia_model' };
  const arm = (typeof ARMAZEM !== 'undefined') ? ARMAZEM : localStorage;

  const SISTEMA = 'Você interpreta um personagem de um jogo de estratégia medieval, em português do Brasil. ' +
    'Incorpore o personagem descrito a seguir, com a personalidade, a relação e a MEMÓRIA indicadas. ' +
    'Fale em 1 a 3 frases, no tom do personagem, sem quebrar a imersão (nada de mencionar "IA", "jogo" ou "sistema"). ' +
    'Responda SEMPRE e SOMENTE com um JSON válido: {"fala": "...", "emocao": "neutro|feliz|raiva"}. ' +
    'Nunca invente fatos, números, nomes ou eventos que não estejam no contexto fornecido.';

  // resposta no formato da OpenAI (Groq e OpenRouter falam o mesmo dialeto)
  function estiloOpenAI(endpoint, extraHeaders) {
    return {
      endpoint,
      montarReq(prompt, model, key) {
        return {
          headers: Object.assign({ 'content-type': 'application/json', 'authorization': 'Bearer ' + key }, extraHeaders || {}),
          body: JSON.stringify({
            model, max_tokens: 320, temperature: 0.85,
            messages: [{ role: 'system', content: SISTEMA }, { role: 'user', content: prompt }],
          }),
        };
      },
      extrai(json) {
        return json && json.choices && json.choices[0] && json.choices[0].message && json.choices[0].message.content;
      },
    };
  }

  const PROVEDORES = {
    // ---- GRATUITOS (camada free de verdade, só pede cadastro) ----
    groq: Object.assign({
      nome: 'Groq — GRÁTIS e muito rápido',
      gratis: true,
      modeloPadrao: 'llama-3.3-70b-versatile',
      dica: 'GRÁTIS: crie conta em console.groq.com → API Keys → Create. A chave começa com "gsk_". É o mais rápido e tem cota diária generosa.',
    }, estiloOpenAI('https://api.groq.com/openai/v1/chat/completions')),

    gemini: {
      nome: 'Google Gemini — GRÁTIS',
      gratis: true,
      endpoint: '',   // montado com o modelo na URL
      modeloPadrao: 'gemini-2.0-flash',
      dica: 'GRÁTIS: pegue em aistudio.google.com/apikey (a chave começa com "AIza"). Cota diária gratuita, sem cartão.',
      url(model, key) {
        return `https://generativelanguage.googleapis.com/v1beta/models/${encodeURIComponent(model)}:generateContent?key=${encodeURIComponent(key)}`;
      },
      montarReq(prompt, model, key) {
        return {
          headers: { 'content-type': 'application/json' },
          body: JSON.stringify({
            systemInstruction: { parts: [{ text: SISTEMA }] },
            contents: [{ role: 'user', parts: [{ text: prompt }] }],
            generationConfig: { temperature: 0.85, maxOutputTokens: 320, responseMimeType: 'application/json' },
          }),
        };
      },
      extrai(json) {
        const c = json && json.candidates && json.candidates[0];
        return c && c.content && c.content.parts && c.content.parts.map(p => p.text || '').join('');
      },
    },

    openrouter: Object.assign({
      nome: 'OpenRouter — modelos :free',
      gratis: true,
      modeloPadrao: 'meta-llama/llama-3.3-70b-instruct:free',
      dica: 'GRÁTIS: crie a chave em openrouter.ai/keys (começa com "sk-or-"). Use modelos terminados em ":free".',
    }, estiloOpenAI('https://openrouter.ai/api/v1/chat/completions', { 'x-title': 'Reino por Conquista' })),

    // ---- PAGOS (melhor qualidade) ----
    claude: {
      nome: 'Claude (Anthropic) — pago',
      endpoint: 'https://api.anthropic.com/v1/messages',
      modeloPadrao: 'claude-haiku-4-5-20251001',
      dica: 'PAGO (melhor qualidade): chave em console.anthropic.com, começa com "sk-ant-".',
      montarReq(prompt, model, key) {
        return {
          headers: {
            'content-type': 'application/json',
            'x-api-key': key,
            'anthropic-version': '2023-06-01',
            'anthropic-dangerous-direct-browser-access': 'true',
          },
          body: JSON.stringify({
            model, max_tokens: 320, temperature: 0.85, system: SISTEMA,
            messages: [{ role: 'user', content: prompt }],
          }),
        };
      },
      extrai(json) { return json && json.content && json.content[0] && json.content[0].text; },
    },
    openai: {
      nome: 'OpenAI (GPT) — pago',
      endpoint: 'https://api.openai.com/v1/chat/completions',
      modeloPadrao: 'gpt-4o-mini',
      dica: 'PAGO: chave em platform.openai.com, começa com "sk-".',
      montarReq(prompt, model, key) {
        return {
          headers: { 'content-type': 'application/json', 'authorization': 'Bearer ' + key },
          body: JSON.stringify({
            model, max_tokens: 320, temperature: 0.85,
            messages: [{ role: 'system', content: SISTEMA }, { role: 'user', content: prompt }],
          }),
        };
      },
      extrai(json) {
        return json && json.choices && json.choices[0] && json.choices[0].message && json.choices[0].message.content;
      },
    },
  };

  const provedor = () => arm.getItem(K.prov);
  const chave = () => arm.getItem(K.key) || '';
  const modelo = () => arm.getItem(K.model) || (PROVEDORES[provedor()] && PROVEDORES[provedor()].modeloPadrao) || '';
  const estaConfigurado = () => !!(provedor() && chave() && PROVEDORES[provedor()]);

  // extrai {fala, emocao} do texto que o modelo devolveu (tolerante a lixo em volta do JSON)
  function interpretar(texto) {
    try {
      const j = JSON.parse(texto.slice(texto.indexOf('{'), texto.lastIndexOf('}') + 1));
      if (j && j.fala) return { fala: String(j.fala).trim(), emocao: j.emocao || 'neutro' };
    } catch (e) { /* não era JSON: usa como fala direta */ }
    return { fala: texto.trim(), emocao: 'neutro' };
  }

  // o adaptador que dialogue.falarAsync chama; recebe o prompt pronto e devolve {fala, emocao}
  async function chamar(prompt, opts) {
    const p = PROVEDORES[provedor()];
    if (!p) throw new Error('nenhum provedor configurado');
    const req = p.montarReq(prompt, modelo(), chave());
    const alvo = p.url ? p.url(modelo(), chave()) : p.endpoint;   // Gemini leva a chave na URL
    const ctrl = new AbortController();
    const timer = setTimeout(() => ctrl.abort(), (opts && opts.timeout) || 20000);
    try {
      const resp = await fetch(alvo, { method: 'POST', headers: req.headers, body: req.body, signal: ctrl.signal });
      if (!resp.ok) {
        let detalhe = '';
        try { const e = await resp.json(); detalhe = (e.error && (e.error.message || e.error.type)) || ''; } catch (_) {}
        throw new Error('HTTP ' + resp.status + (detalhe ? ' — ' + detalhe : ''));
      }
      const json = await resp.json();
      const texto = p.extrai(json);
      if (!texto) throw new Error('a IA respondeu vazio');
      return interpretar(texto);
    } finally { clearTimeout(timer); }
  }

  function registrar() {
    if (typeof Dialogo === 'undefined') return;
    Dialogo.llmAdapter = estaConfigurado() ? chamar : null;
  }

  function configurar(prov, key, model) {
    if (!PROVEDORES[prov]) return { ok: false, msg: 'Provedor inválido.' };
    if (!key || !key.trim()) return { ok: false, msg: 'Cole a sua chave de API.' };
    arm.setItem(K.prov, prov);
    arm.setItem(K.key, key.trim());
    if (model && model.trim()) arm.setItem(K.model, model.trim()); else arm.removeItem(K.model);
    registrar();
    return { ok: true };
  }

  function desligar() {
    arm.removeItem(K.prov); arm.removeItem(K.key); arm.removeItem(K.model);
    if (typeof Dialogo !== 'undefined') Dialogo.llmAdapter = null;
  }

  // teste de fumaça: uma fala curta para validar chave/modelo/conexão
  async function testar() {
    try {
      const r = await chamar(
        'Você é Bram, um velho taverneiro rabugento e bem-humorado. Personalidade: ganancioso. ' +
        'O jogador (Sir Teste) diz: "boa noite, tudo bem?". Responda no formato pedido.',
        { timeout: 15000 });
      return { ok: true, fala: r.fala };
    } catch (e) { return { ok: false, erro: String((e && e.message) || e) }; }
  }

  registrar(); // ao carregar a página, religa a IA se já estava configurada
  return { PROVEDORES, estaConfigurado, configurar, desligar, testar, chamar,
    provedor, modelo, registrar, get chave() { return chave(); } };
})();
