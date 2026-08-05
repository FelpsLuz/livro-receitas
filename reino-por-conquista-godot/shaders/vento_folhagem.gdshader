// ============================================================
// VENTO — balanço sutil de folhagem, pelo VERTEX.
//
// Este vai no vertex de propósito, e o contrário do que o shader de vida da
// cena achatada tinha que fazer. Lá a imagem era UMA textura de tela cheia:
// deslocar VERTEX.x movia o quadro inteiro, e o balanço teve que ir para a
// amostragem. Aqui cada árvore é o SEU próprio nó, então o vertex é
// exatamente o lugar certo — é mais barato e não borra nada.
//
// PESO PELA ALTURA. O tronco não balança; a copa balança. `UV.y` vai de 0 no
// topo a 1 na base, então o peso é (1 - UV.y) elevado ao quadrado: cai rápido
// e deixa os dois terços de baixo praticamente parados.
//
// FASE PELA POSIÇÃO NO MUNDO. Sem ela, um bosque inteiro balança em uníssono
// e vira uma esteira. Com a origem do nó entrando na fase, cada árvore pega
// o vento num tempo diferente e o bosque respira.
//
// AMPLITUDE EM PIXEL DE TEXTURA. `amplitude` é medida em pixels da ARTE, não
// em UV: uma folha de 32x32 e uma copa de 128x128 balançam a mesma coisa
// visível quando o número é o mesmo.
// ============================================================
shader_type canvas_item;

uniform float amplitude : hint_range(0.0, 12.0) = 2.0;   // em pixels de arte
uniform float frequencia : hint_range(0.0, 6.0) = 1.1;
uniform float rajada : hint_range(0.0, 1.0) = 0.35;      // 0 = brisa constante
uniform float peso_topo : hint_range(1.0, 6.0) = 2.0;    // expoente da queda
uniform vec2 direcao = vec2(1.0, 0.0);

void vertex() {
	// fase própria por nó: a origem do sprite no mundo desafina o bosque
	float semente = MODEL_MATRIX[3][0] * 0.035 + MODEL_MATRIX[3][1] * 0.021;

	// a rajada é uma segunda onda LENTA multiplicando a primeira — o vento
	// acalma e volta, em vez de oscilar como um metrônomo
	float onda = sin(TIME * frequencia + semente);
	float sopro = mix(1.0, 0.5 + 0.5 * sin(TIME * 0.23 + semente * 0.5), rajada);

	// peso pela altura: 1 no topo do sprite, 0 no pé
	float t = pow(clamp(1.0 - UV.y, 0.0, 1.0), peso_topo);

	VERTEX += direcao * (onda * sopro * amplitude * t);
}
