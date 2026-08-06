// ============================================================
// ESCAMBO — a mesa de troca que a CONVERSA abre.
// Quando o diálogo chega num ponto de negócio ("me dê ouro",
// "vamos negociar", "quero seus soldados"), abre-se um inventário
// de dois lados: o que você põe na mesa e o que pede em troca.
// O NPC avalia pelo VALOR real, ajustado por relação, personalidade
// e pelo que ele mesmo precisa naquele mês (guerra, fome, cofres).
// ============================================================
'use strict';

const Escambo = (() => {
  // valor de referência de cada coisa negociável
  const VALOR_TROPA = { campones: 8, lanceiro: 26, arqueiro: 32, cavaleiro: 150 };

  function valorMercadoria(state, id) {
    const base = MERCADORIAS[id] ? MERCADORIAS[id].precoBase : 10;
    try { return Economia.precoDe(state, state.local, id) || base; } catch (e) { return base; }
  }

  // o que o NPC tem para oferecer (estimado pelo cargo e pelo mundo)
  function estoqueDele(state, npc) {
    const rei = npc.id.startsWith('rei_');
    const reino = rei ? state.reinos.find(r => r.id === npc.id.slice(4)) : null;
    const emGuerra = reino && (state.guerras || []).some(g => g.a === reino.id || g.b === reino.id);
    const rel = Dialogo.tagsDe(state, npc.id).relacao;
    const escala = Math.max(0.2, (rel + 100) / 200);          // amigos abrem mais o cofre
    const est = { ouro: Math.round((rei ? 3000 : 400) * escala), tropas: {}, bens: {} };
    if (rei) {
      // um rei em guerra não vende os próprios soldados
      est.tropas = emGuerra
        ? { campones: Math.round(20 * escala) }
        : { campones: Math.round(40 * escala), lanceiro: Math.round(18 * escala), arqueiro: Math.round(12 * escala),
            cavaleiro: Math.round(4 * escala) };
      for (const g of (reino.producao || [])) est.bens[g] = Math.round(30 * escala);
      est.bens.trigo = Math.round((est.bens.trigo || 0) + 20 * escala);
    } else if (npc.barbaro) {
      est.tropas = { campones: Math.round(25 * escala), lanceiro: Math.round(14 * escala) };
      est.bens = { madeira: Math.round(25 * escala), trigo: Math.round(15 * escala) };
    } else {
      est.tropas = { campones: Math.round(10 * escala) };
      est.bens = { trigo: Math.round(20 * escala), sal: Math.round(10 * escala) };
    }
    return est;
  }

  // quanto o NPC PRECISA de cada coisa neste mês (multiplica o valor que ele enxerga)
  function apetite(state, npc) {
    const ap = { ouro: 1, campones: 1, lanceiro: 1, arqueiro: 1, cavaleiro: 1 };
    for (const g of Object.keys(MERCADORIAS)) ap[g] = 1;
    const rei = npc.id.startsWith('rei_');
    const reino = rei ? state.reinos.find(r => r.id === npc.id.slice(4)) : null;
    if (reino) {
      const emGuerra = (state.guerras || []).some(g => g.a === reino.id || g.b === reino.id);
      if (emGuerra) { ap.armas = 1.8; ap.ferro = 1.6; ap.trigo = 1.5; ap.lanceiro = 1.4; ap.cavaleiro = 1.4; ap.ouro = 0.9; }
      for (const g of (reino.producao || [])) ap[g] = 0.6;   // o que ele já produz vale pouco
    }
    if (npc.personalidade === 'ganancioso') ap.ouro = 1.3;
    if (npc.barbaro) { ap.armas = 1.5; ap.trigo = 1.4; ap.ouro = 0.85; }
    return ap;
  }

  // valor total de um lado da mesa, sob a ótica do NPC
  function avaliar(state, npc, lado) {
    const ap = apetite(state, npc);
    let v = (lado.ouro || 0) * (ap.ouro || 1);
    for (const [t, n] of Object.entries(lado.tropas || {})) v += (VALOR_TROPA[t] || 10) * n * (ap[t] || 1);
    for (const [g, n] of Object.entries(lado.bens || {})) v += valorMercadoria(state, g) * n * (ap[g] || 1);
    return Math.round(v);
  }

  // margem que ele exige para fechar: inimigo cobra caro, amigo faz favor
  function margemExigida(state, npc) {
    const rel = Dialogo.tagsDe(state, npc.id).relacao;
    const base = { ganancioso: 1.35, calculista: 1.25, cruel: 1.3, orgulhoso: 1.2, honrado: 1.1, romantica: 1.1 };
    const m = (base[npc.personalidade] || 1.2) - (rel / 100) * 0.35;
    return Math.max(0.75, Math.round(m * 100) / 100);
  }

  function podePagar(state, lado) {
    if ((lado.ouro || 0) > state.jogador.ouro) return 'Você não tem esse ouro.';
    for (const [t, n] of Object.entries(lado.tropas || {}))
      if (n > (state.jogador.tropas[t] || 0)) return `Você não tem ${n} ${TROPAS[t].nome.toLowerCase()}.`;
    for (const [g, n] of Object.entries(lado.bens || {}))
      if (n > (state.carga[g] || 0)) return `Você não tem ${n}× ${MERCADORIAS[g].nome}.`;
    return null;
  }

  function eleTem(state, npc, lado) {
    const est = estoqueDele(state, npc);
    if ((lado.ouro || 0) > est.ouro) return `${npc.nome} não tem tanto ouro assim à mão (até ${est.ouro}).`;
    for (const [t, n] of Object.entries(lado.tropas || {}))
      if (n > (est.tropas[t] || 0)) return `${npc.nome} não cede ${n} ${TROPAS[t].nome.toLowerCase()} (até ${est.tropas[t] || 0}).`;
    for (const [g, n] of Object.entries(lado.bens || {}))
      if (n > (est.bens[g] || 0)) return `${npc.nome} não tem ${n}× ${MERCADORIAS[g].nome} para dar (até ${est.bens[g] || 0}).`;
    return null;
  }

  const vazio = (lado) => !(lado.ouro || 0) &&
    !Object.values(lado.tropas || {}).some(Boolean) && !Object.values(lado.bens || {}).some(Boolean);

  // ---------- a proposta ----------
  function propor(state, npc, ofereco, peco, log) {
    const falta = podePagar(state, ofereco);
    if (falta) return { ok: false, msg: falta };
    const semEstoque = eleTem(state, npc, peco);
    if (semEstoque) return { ok: false, msg: semEstoque };
    if (vazio(ofereco) && vazio(peco)) return { ok: false, msg: 'A mesa está vazia. Ponha algo nela.' };

    const vOf = avaliar(state, npc, ofereco), vPe = avaliar(state, npc, peco);
    const margem = margemExigida(state, npc);
    const rel = Dialogo.tagsDe(state, npc.id).relacao;

    // presente puro (só oferece, não pede nada): relação sobe pelo valor
    if (vazio(peco)) {
      transferir(state, npc, ofereco, 'jogador->npc');
      const ganho = Math.max(2, Math.min(25, Math.round(vOf / 80)));
      const tag = Dialogo.mudarRelacao(state, npc.id, ganho, 'presente').tag;
      Dialogo.lembrar(state, npc.id, 'presente', `presente no valor de ${vOf}`);
      log(`🎁 Você entrega o presente a ${npc.nome}. ${tag}`);
      return { ok: true, aceito: true, efeitos: [tag],
        fala: falaPresente(npc, vOf), msg: 'Presente entregue.' };
    }
    // pedido puro (só pede, não oferece): é esmola — depende de relação
    if (vazio(ofereco)) {
      const limite = Math.max(60, (rel + 40) * 12);
      if (rel >= 25 && vPe <= limite) {
        transferir(state, npc, peco, 'npc->jogador');
        const tag = Dialogo.mudarRelacao(state, npc.id, -3, 'pediu de graça').tag;
        log(`🤲 ${npc.nome} cede sem cobrar. ${tag}`);
        return { ok: true, aceito: true, efeitos: [tag],
          fala: `*empurra na sua direção* Leve. Mas favor cobrado é favor perdido — não faça disso hábito.`,
          msg: 'Ele cedeu de graça.' };
      }
      return { ok: true, aceito: false, efeitos: [],
        fala: rel < 25
          ? 'De graça? *ri* Nem para meus próprios lordes. Ponha ALGO na mesa.'
          : 'Isso é muito para um pedido sem contrapartida. Ofereça algo e reconsidero.',
        msg: 'Recusado: ele quer contrapartida.' };
    }

    const razao = vOf / Math.max(1, vPe);
    if (razao >= margem) {
      transferir(state, npc, ofereco, 'jogador->npc');
      transferir(state, npc, peco, 'npc->jogador');
      const bonus = razao >= margem * 1.4 ? 6 : 3;
      const tag = Dialogo.mudarRelacao(state, npc.id, bonus, 'negócio fechado').tag;
      Dialogo.lembrar(state, npc.id, 'negocio', `troca fechada (${vOf} por ${vPe})`);
      log(`🤝 Negócio fechado com ${npc.nome}.`);
      return { ok: true, aceito: true, efeitos: [tag], fala: falaAceite(npc, razao, margem), msg: 'Negócio fechado!' };
    }
    // recusa com CONTRAPROPOSTA concreta — a mesa continua aberta
    const faltaOuro = Math.max(1, Math.round(vPe * margem - vOf));
    const tagR = razao < margem * 0.5 ? Dialogo.mudarRelacao(state, npc.id, -3, 'proposta ofensiva').tag : null;
    return { ok: true, aceito: false, efeitos: tagR ? [tagR] : [],
      contraproposta: { ouroFaltante: faltaOuro },
      fala: razao < margem * 0.5
        ? `*empurra tudo de volta* Você me insulta. Isso não paga nem metade do que pede. Acrescente uns ${faltaOuro} de ouro e talvez eu ouça.`
        : `Perto, mas não fecha. Junte mais ${faltaOuro} de ouro (ou o equivalente) e apertamos as mãos.`,
      msg: `Recusado. Faltam cerca de ${faltaOuro} de ouro em valor.` };
  }

  function falaAceite(npc, razao, margem) {
    const generoso = razao >= margem * 1.4;
    const F = {
      orgulhoso: generoso ? 'Aceito. E note que fui eu quem levou vantagem em ser generoso com você.' : 'Feito. Que fique registrado que cumpri minha parte.',
      calculista: generoso ? '*sorri* Você paga acima do valor. Ou é tolo, ou quer algo mais. Vou descobrir qual.' : 'Os números fecham. Negócio feito.',
      ganancioso: generoso ? '*abraça a bolsa* AGORA sim! Volte sempre, amigo.' : 'Fechado. Aperto de mão vale mais que pergaminho — quase.',
      honrado: 'Mão dada, palavra dada. Está feito.',
      cruel: generoso ? '*guarda tudo sem pressa* Aceito. E ainda fico com a impressão de que você precisava mais do que eu.' : 'Feito. Não me faça arrepender.',
      romantica: 'Que negociação encantadora. Feito!',
    };
    return F[npc.personalidade] || F.honrado;
  }
  function falaPresente(npc, valor) {
    const grande = valor >= 800;
    const F = {
      orgulhoso: grande ? '*ergue as sobrancelhas* Isto não é um presente, é uma declaração. Recebida.' : 'Um presente. Hm. Registrado.',
      calculista: grande ? 'Generosidade desse tamanho sempre cobra depois. Aceito — e aguardo o depois.' : 'Aceito. Anotado na coluna certa.',
      ganancioso: grande ? '*olhos brilhando* Você entende como o mundo funciona!' : 'Aceito, claro. Nunca recusei nada de graça.',
      honrado: grande ? 'Isto é demais. Aceito, mas fique sabendo: agora a dívida é minha.' : 'Gentileza reconhecida. Obrigado.',
      cruel: grande ? '*sorri de lado* Presentes assim compram silêncio... ou tempo. Qual dos dois você quer?' : 'Aceito. Continue.',
      romantica: 'Um presente! Você sabe conquistar as pessoas.',
    };
    return F[npc.personalidade] || F.honrado;
  }

  function transferir(state, npc, lado, direcao) {
    const s = direcao === 'jogador->npc' ? -1 : 1;
    state.jogador.ouro += s * (lado.ouro || 0);
    for (const [t, n] of Object.entries(lado.tropas || {}))
      state.jogador.tropas[t] = Math.max(0, (state.jogador.tropas[t] || 0) + s * n);
    for (const [g, n] of Object.entries(lado.bens || {}))
      state.carga[g] = Math.max(0, (state.carga[g] || 0) + s * n);
  }

  return { propor, avaliar, estoqueDele, margemExigida, VALOR_TROPA, valorMercadoria };
})();
