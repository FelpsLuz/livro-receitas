// ============================================================
// CONTORNO — realce de entidade interativa.
//
// O contorno é desenhado FORA da silhueta, e é por isso que o nó precisa de
// margem: um sprite sem pixel transparente na borda não tem onde pôr a
// linha. Em Sprite2D isso se resolve ligando `region_enabled` com um retângulo
// alguns pixels maior, ou deixando a arte com 2px de folga — o que é a
// prática normal em pixel art de qualquer jeito.
//
// AMOSTRAGEM EM 8 VIZINHOS, NÃO 4. Com 4 (cruz), a diagonal de uma silhueta
// serrilhada fica com buraco: o pixel na quina não tem vizinho opaco em cima
// nem ao lado, só na diagonal. Oito custa o dobro e fecha o contorno.
//
// O PASSO É EM PIXEL DE TEXTURA, não em UV. `TEXTURE_PIXEL_SIZE` já dá o
// tamanho de um pixel da arte em UV, então `espessura = 1.0` é exatamente um
// pixel da arte, em qualquer tamanho de sprite e qualquer zoom. Contorno
// medido em UV encolheria nos sprites grandes.
//
// O passo é arredondado para INTEIRO: contorno em meio pixel vira uma linha
// cinza translúcida, que é o oposto de pixel art.
// ============================================================
shader_type canvas_item;

uniform vec4 cor : source_color = vec4(1.0, 0.92, 0.45, 1.0);
uniform float espessura : hint_range(0.0, 6.0) = 1.0;    // em pixels de arte
uniform float alfa_minimo : hint_range(0.0, 1.0) = 0.35; // o que conta como "dentro"
/// Pulsação: 0 deixa o contorno fixo. Um realce que respira lê como
/// "clicável"; um fixo lê como "selecionado". São estados diferentes.
uniform float pulso : hint_range(0.0, 4.0) = 0.0;
uniform float pulso_min : hint_range(0.0, 1.0) = 0.45;

// NADA DE `return` AQUI. A Godot recusa `return` dentro de fragment() com
// "Using 'return' in the 'fragment' processor function is incorrect" — e o
// shader falha em SILÊNCIO: ele carrega como Shader, a lista de uniformes
// vem vazia e o nó desenha sem efeito nenhum. Foi assim que a primeira
// versão disto passou despercebida até o teste contar os uniformes.
void fragment() {
	vec4 c = texture(TEXTURE, UV);
	vec4 saida = c;

	if (espessura > 0.0 && c.a < alfa_minimo) {
		vec2 passo = TEXTURE_PIXEL_SIZE * floor(espessura + 0.5);
		float vizinho = 0.0;
		// 8 vizinhos: as 4 diagonais fecham a quina que a cruz deixa aberta
		vizinho = max(vizinho, texture(TEXTURE, UV + vec2( passo.x, 0.0)).a);
		vizinho = max(vizinho, texture(TEXTURE, UV + vec2(-passo.x, 0.0)).a);
		vizinho = max(vizinho, texture(TEXTURE, UV + vec2(0.0,  passo.y)).a);
		vizinho = max(vizinho, texture(TEXTURE, UV + vec2(0.0, -passo.y)).a);
		vizinho = max(vizinho, texture(TEXTURE, UV + vec2( passo.x,  passo.y)).a);
		vizinho = max(vizinho, texture(TEXTURE, UV + vec2( passo.x, -passo.y)).a);
		vizinho = max(vizinho, texture(TEXTURE, UV + vec2(-passo.x,  passo.y)).a);
		vizinho = max(vizinho, texture(TEXTURE, UV + vec2(-passo.x, -passo.y)).a);

		if (vizinho >= alfa_minimo) {
			float a = 1.0;
			if (pulso > 0.0) {
				a = mix(pulso_min, 1.0, 0.5 + 0.5 * sin(TIME * pulso));
			}
			saida = vec4(cor.rgb, cor.a * a);
		}
	}
	COLOR = saida;
}
